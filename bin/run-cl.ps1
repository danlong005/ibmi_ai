# Run a CL program on IBM i by name (no parameters supported).

param (
    [Parameter(Mandatory)][string]$Pgm,
    [string]$Environment,
    [string]$Library
)

$ConfigPath = Join-Path $PSScriptRoot ".ibmi-config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: Config file not found."
    exit 1
}
$RootConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$EnvName = if ($Environment) { $Environment } else { $RootConfig.DefaultEnvironment }
$Config = $RootConfig.Environments.$EnvName

$DecryptedPassword = if ($Config.IBMiPassword) {
    $secure = $Config.IBMiPassword | ConvertTo-SecureString
    (New-Object System.Net.NetworkCredential '', $secure).Password
} else { "" }

$PlinkPath = "C:\Program Files\PuTTY\plink.exe"
$IBMiHost = $Config.IBMiHost
$IBMiUser = $Config.IBMiUser
$ResolvedLibrary = if ($Library) { $Library } else { $Config.Library }

Write-Host "=== Calling CL: $ResolvedLibrary/$Pgm ==="
Write-Host "Environment: $EnvName"

$LibList = @('YAJL', 'XMLILIB', 'LIBHTTP', 'PRODLIB', 'RPGUNIT', 'QDEVTOOLS')
$LibListCmds = "liblist -c $ResolvedLibrary 2>/dev/null; " + (($LibList | ForEach-Object { "liblist -a $_ 2>/dev/null" }) -join '; ')

$FullCommand = "qsh -c `"$LibListCmds; system 'CALL PGM($ResolvedLibrary/$Pgm)'`""
& "$PlinkPath" -batch -P 22 -pw $DecryptedPassword "$IBMiUser@$IBMiHost" $FullCommand 2>&1 | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nERROR: CL run failed with exit code $LASTEXITCODE"
    exit 1
}

Write-Host "`n=== CL Complete: $Pgm ==="
