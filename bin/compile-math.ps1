# Compile MATH service program and test suite on IBM i

param (
    [string]$Environment
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
$Library = $Config.Library

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

Write-Host "=== Compiling MATH Service Program ==="

# Step 1: Compile MATH module from SQLRPGLE source
Write-Host "`n--- Step 1: Creating MATH module ---"
if (-not (Invoke-Remote "system 'CRTRPGMOD MODULE($Library/MATH) SRCFILE($Library/ILESRC) SRCMBR(MATH_SRC) DBGVIEW(*SOURCE)'")) {
    exit 1
}

# Step 2: Create service program with binding directory
Write-Host "`n--- Step 2: Creating MATH service program ---"
if (-not (Invoke-Remote "system 'CRTSRVPGM SRVPGM($Library/MATH) MODULE($Library/MATH) EXPORT(*SRCFILE) SRCFILE($Library/ILESRC) SRCMBR(MATHBND) ACTGRP(*CALLER)'")) {
    exit 1
}

# Step 3: Compile MATH_T module and create test program using RPGUnit RUCRTTST
# RUCRTTST handles its own library list setup internally, resolving RPGUNIT includes
Write-Host "`n--- Step 3: Creating MATH_T test program (compile + bind) ---"
if (-not (Invoke-Remote "system 'RPGUNIT/RUCRTTST TSTPGM($Library/MATH_T) SRCFILE($Library/ILESRC) SRCMBR(MATH_T) BNDSRVPGM($Library/MATH) BNDDIR(RPGUNIT/IRPGUNIT) DBGVIEW(*SOURCE)'")) {
    exit 1
}

Write-Host "`n=== Compilation Complete ==="
Write-Host "`nTo run tests, execute:"
Write-Host "  RUCALLTST TSTPGM($Library/MATH_T)"
