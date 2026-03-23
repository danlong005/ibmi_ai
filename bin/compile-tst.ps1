# Compile an RPGUnit test program on IBM i
#
# Conventions (all overridable):
#   Test source member : {TstPgm}
#   Bound service pgm  : derived from {TstPgm} by stripping trailing _T

param (
    [Parameter(Mandatory)][string]$TstPgm,
    [string]$Environment,
    [string]$Library,
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

# Apply naming conventions
$ResolvedSrcMbr   = if ($SrcMbr)    { $SrcMbr }    else { $TstPgm }
$ResolvedBndSrvPgm = if ($BndSrvPgm) { $BndSrvPgm } else { $TstPgm -replace '_T$', '' }

function Invoke-Remote {
    param([string]$Command)
    Write-Host "Executing: $Command"
    $FullCommand = "qsh -c `"liblist -a RPGUNIT 2>/dev/null; $Command`""
    & "$PlinkPath" -batch -P 22 -pw $DecryptedPassword "$IBMiUser@$IBMiHost" $FullCommand 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Command failed with exit code $LASTEXITCODE"
        return $false
    }
    return $true
}

Write-Host "=== Compiling $TstPgm Test Program ==="
Write-Host "Environment: $EnvName  Library: $ResolvedLibrary"

if (-not (Invoke-Remote "system 'RPGUNIT/RUCRTTST TSTPGM($ResolvedLibrary/$TstPgm) SRCFILE($ResolvedLibrary/ILESRC) SRCMBR($ResolvedSrcMbr) BNDSRVPGM($ResolvedLibrary/$ResolvedBndSrvPgm) BNDDIR(RPGUNIT/IRPGUNIT) DBGVIEW(*SOURCE)'")) {
    exit 1
}

Write-Host "`n=== Compilation Complete ==="
Write-Host "`nTo run tests, execute:"
Write-Host "  pwsh -ExecutionPolicy Bypass -File bin/run-tests.ps1 -TestProgram $TstPgm"
