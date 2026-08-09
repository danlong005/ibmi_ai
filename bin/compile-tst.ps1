# Compile an RPGUnit test program on IBM i
#
# Conventions (all overridable):
#   Test source member : {TstPgm}
#   Bound service pgm  : derived from {TstPgm} by stripping trailing _T

param (
    [Parameter(Mandatory)][string]$TstPgm,
    [string]$Environment,
    [string]$Library,
    [string]$File,        # source physical file; defaults to config's File, then ILESRC
    [string]$SrcMbr,      # defaults to {TstPgm}
    [string]$BndSrvPgm    # defaults to {TstPgm} with _T stripped
)

# Load config
$ConfigPath = Join-Path $PSScriptRoot ".ibmi-config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: Config file not found."
    exit 1
}
$RootConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$EnvName = if ($Environment) { $Environment } else { $RootConfig.DefaultEnvironment }
$Config = $RootConfig.Environments.$EnvName

# Decrypt password
$DecryptedPassword = if ($Config.IBMiPassword) {
    $secure = $Config.IBMiPassword | ConvertTo-SecureString
    (New-Object System.Net.NetworkCredential '', $secure).Password
} else { "" }

$PlinkPath = "C:\Program Files\PuTTY\plink.exe"
$IBMiHost = $Config.IBMiHost
$IBMiUser = $Config.IBMiUser
$ResolvedLibrary = if ($Library) { $Library } else { $Config.Library }
$ResolvedFile = if ($File) { $File } elseif ($Config.File) { $Config.File } else { "ILESRC" }

# Apply naming conventions
$ResolvedSrcMbr   = if ($SrcMbr)    { $SrcMbr }    else { $TstPgm }
$ResolvedBndSrvPgm = if ($BndSrvPgm) { $BndSrvPgm } else { $TstPgm -replace '_T$', '' }

# Set $ResolvedLibrary as *CURLIB so its includes take precedence over PRODLIB in *USRLIBL
$LibList = @('YAJL', 'XMLILIB', 'LIBHTTP', 'PRODLIB', 'RPGUNIT', 'QDEVTOOLS')
$LibListCmds = "liblist -c $ResolvedLibrary 2>/dev/null; " + (($LibList | ForEach-Object { "liblist -a $_ 2>/dev/null" }) -join '; ')

function Invoke-Remote {
    param([string]$Command)
    Write-Host "Executing: $Command"
    $FullCommand = "qsh -c `"$LibListCmds; $Command`""
    & "$PlinkPath" -batch -P 22 -pw $DecryptedPassword "$IBMiUser@$IBMiHost" $FullCommand 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Command failed with exit code $LASTEXITCODE"
        return $false
    }
    return $true
}

Write-Host "=== Compiling $TstPgm Test Program ==="
Write-Host "Environment: $EnvName  Library: $ResolvedLibrary"

# Step 1: Compile SQLRPGLE test source as a module
# Uses CRTSQLRPGI directly (same approach as service program modules) rather
# than RUCRTTST, which uses OPTION(*SYSVAL) and does not play well with **free
# source when RPGPPOPT(*LVL2) expands the iRPGUnit TESTCASE include.
Write-Host "`n--- Step 1: Creating $TstPgm module ---"
$step1Cmd = "system 'CRTSQLRPGI OBJ($ResolvedLibrary/$TstPgm) SRCFILE($ResolvedLibrary/$ResolvedFile) SRCMBR($ResolvedSrcMbr) OBJTYPE(*MODULE) COMMIT(*NONE) DBGVIEW(*SOURCE)'"
if (-not (Invoke-Remote $step1Cmd)) { exit 1 }

# Step 2: Bind into a service program for RPGUnit
# EXPORT(*ALL) so RUCALLTST can discover SETUP/TEARDOWN/test_* procedures.
# BNDDIR(RPGUNIT/IRPGUNIT) pulls in the iRPGUnit assertion service programs.
# BNDSRVPGM adds the service program under test (omitted when *NONE).
Write-Host "`n--- Step 2: Creating $TstPgm service program ---"
$BndSrvPgmClause = if ($ResolvedBndSrvPgm -eq '*NONE') { '' } else { " BNDSRVPGM($ResolvedLibrary/$ResolvedBndSrvPgm)" }
$step2Cmd = "system 'CRTSRVPGM SRVPGM($ResolvedLibrary/$TstPgm) MODULE($ResolvedLibrary/$TstPgm) EXPORT(*ALL)$BndSrvPgmClause BNDDIR(RPGUNIT/IRPGUNIT) ACTGRP(*CALLER)'"
if (-not (Invoke-Remote $step2Cmd)) { exit 1 }

Write-Host "`n=== Compilation Complete ==="
Write-Host "`nTo run tests, execute:"
Write-Host "  pwsh -ExecutionPolicy Bypass -File bin/run-tests.ps1 -TestProgram $TstPgm"
