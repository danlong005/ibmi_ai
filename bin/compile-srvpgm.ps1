# Compile a service program on IBM i
#
# Conventions (all overridable):
#   Module source member : {SrvPgm}
#   Binder source member : {SrvPgm}_B

param (
    [Parameter(Mandatory)][string]$SrvPgm,
    [string]$Environment,
    [string]$Library,
    [string]$ModuleSrc,   # defaults to {SrvPgm}
    [string]$BndSrc,      # defaults to {SrvPgm}_B
    [string]$BndDir,      # optional binding directory (e.g. YAJL/YAJL)
    [string]$BndSrvPgm,   # optional bound service program (e.g. MYLIB/MYSRVPGM)
    [switch]$SqlModule    # use CRTSQLRPGI instead of CRTRPGMOD
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

# Apply naming conventions
$ResolvedModuleSrc = if ($ModuleSrc) { $ModuleSrc } else { $SrvPgm }
$ResolvedBndSrc    = if ($BndSrc)    { $BndSrc }    else { "${SrvPgm}_B" }

# Set $ResolvedLibrary as *CURLIB so its includes take precedence over OBJLIB in *USRLIBL
$LibList = @('APPLIB', 'YAJL', 'XMLILIB', 'LIBHTTP', 'OBJLIB', 'RPGUNIT', 'QDEVTOOLS')
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

Write-Host "=== Compiling $SrvPgm Service Program ==="
Write-Host "Environment: $EnvName  Library: $ResolvedLibrary"

# Step 1: Compile module
Write-Host "`n--- Step 1: Creating $SrvPgm module ---"
if ($SqlModule) {
    $step1 = Invoke-Remote "system 'CRTSQLRPGI OBJ($ResolvedLibrary/$SrvPgm) SRCFILE($ResolvedLibrary/ILESRC) SRCMBR($ResolvedModuleSrc) OBJTYPE(*MODULE) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)'"
} else {
    $step1 = Invoke-Remote "system 'CRTRPGMOD MODULE($ResolvedLibrary/$SrvPgm) SRCFILE($ResolvedLibrary/ILESRC) SRCMBR($ResolvedModuleSrc) DBGVIEW(*SOURCE)'"
}
if (-not $step1) { exit 1 }

# Step 2: Create service program
Write-Host "`n--- Step 2: Creating $SrvPgm service program ---"
$BndDirParam    = if ($BndDir)    { " BNDDIR($BndDir)" }       else { "" }
$BndSrvPgmParam = if ($BndSrvPgm) { " BNDSRVPGM($BndSrvPgm)" } else { "" }
if (-not (Invoke-Remote "system 'CRTSRVPGM SRVPGM($ResolvedLibrary/$SrvPgm) MODULE($ResolvedLibrary/$SrvPgm) EXPORT(*SRCFILE) SRCFILE($ResolvedLibrary/ILESRC) SRCMBR($ResolvedBndSrc) ACTGRP(*CALLER)$BndDirParam$BndSrvPgmParam'")) {
    exit 1
}

Write-Host "`n=== Compilation Complete ==="
