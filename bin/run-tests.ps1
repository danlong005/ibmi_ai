# Run an RPGUnit test suite on IBM i

param (
    [Parameter(Mandatory)][string]$TestProgram,
    [string]$Environment,
    [string]$Library
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

Write-Host "=== Running Test Suite: $TestProgram ==="
Write-Host "Environment: $EnvName  Library: $ResolvedLibrary"

$FullCommand = "qsh -c `"liblist -a RPGUNIT 2>/dev/null; system 'RPGUNIT/RUCALLTST TSTPGM($ResolvedLibrary/$TestProgram)'`""
& "$PlinkPath" -batch -P 22 -pw $DecryptedPassword "$IBMiUser@$IBMiHost" $FullCommand 2>&1 | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nERROR: Test run failed with exit code $LASTEXITCODE"
    exit 1
}

Write-Host "`n=== Test Run Complete: $TestProgram ==="
