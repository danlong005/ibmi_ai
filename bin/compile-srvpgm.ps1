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
    [string]$BndSrc       # defaults to {SrvPgm}_B
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

Write-Host "=== Compiling $SrvPgm Service Program ==="
Write-Host "Environment: $EnvName  Library: $ResolvedLibrary"

# Step 1: Compile module
Write-Host "`n--- Step 1: Creating $SrvPgm module ---"
if (-not (Invoke-Remote "system 'CRTRPGMOD MODULE($ResolvedLibrary/$SrvPgm) SRCFILE($ResolvedLibrary/ILESRC) SRCMBR($ResolvedModuleSrc) DBGVIEW(*SOURCE)'")) {
    exit 1
}

# Step 2: Create service program
Write-Host "`n--- Step 2: Creating $SrvPgm service program ---"
if (-not (Invoke-Remote "system 'CRTSRVPGM SRVPGM($ResolvedLibrary/$SrvPgm) MODULE($ResolvedLibrary/$SrvPgm) EXPORT(*SRCFILE) SRCFILE($ResolvedLibrary/ILESRC) SRCMBR($ResolvedBndSrc) ACTGRP(*CALLER)'")) {
    exit 1
}

Write-Host "`n=== Compilation Complete ==="
