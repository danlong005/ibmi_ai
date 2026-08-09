# ---------------------------------------
# IBM i Database Member Download Script
# Uses PuTTY (plink + psftp)
# ---------------------------------------

param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Member,

    [string]$Environment,

    [string]$IBMiHost,
    [string]$IBMiUser,
    [string]$IBMiPassword,
    [int]$SSHPort,

    [string]$Library,
    [string]$File,

    [string]$LocalDir = ".",

    [string]$PlinkPath = "C:\Program Files\PuTTY\plink.exe",
    [string]$PsftpPath = "C:\Program Files\PuTTY\psftp.exe"
)

# Load config from .ibmi-config.json
$ConfigPath = Join-Path $PSScriptRoot ".ibmi-config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: Config file not found. Run setup-ibmi.ps1 first."
    exit 1
}
$RootConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$EnvName = if ($Environment) { $Environment } else { $RootConfig.DefaultEnvironment }
if (-not $RootConfig.Environments.PSObject.Properties[$EnvName]) {
    Write-Host "ERROR: Environment '$EnvName' not found in config."
    exit 1
}
$Config = $RootConfig.Environments.$EnvName

# Decrypt password from config
$DecryptedPassword = if ($Config.IBMiPassword) {
    $secure = $Config.IBMiPassword | ConvertTo-SecureString
    (New-Object System.Net.NetworkCredential '', $secure).Password
} else { "" }

# Apply param overrides — if explicitly passed, use it; otherwise use config
if (-not $PSBoundParameters.ContainsKey('IBMiHost'))     { $IBMiHost     = $Config.IBMiHost }
if (-not $PSBoundParameters.ContainsKey('IBMiUser'))     { $IBMiUser     = $Config.IBMiUser }
if (-not $PSBoundParameters.ContainsKey('IBMiPassword')) { $IBMiPassword = $DecryptedPassword }
if (-not $PSBoundParameters.ContainsKey('SSHPort'))      { $SSHPort      = if ($Config.SSHPort) { $Config.SSHPort } else { 22 } }
if (-not $PSBoundParameters.ContainsKey('Library'))      { $Library      = $Config.Library }
if (-not $PSBoundParameters.ContainsKey('File'))         { $File         = $Config.File }

# Helper: run a command on IBM i via plink
function Invoke-Remote {
    param([string]$Command, [switch]$PassThru)
    $output = & "$PlinkPath" -batch -P $SSHPort -pw $IBMiPassword "$IBMiUser@$IBMiHost" $Command 2>&1
    $output | ForEach-Object { Write-Host "LOG [plink]: $_" }
    if ($PassThru) { return $output }
}

Write-Host "=== Starting download of member: $Member ==="
Write-Host "LOG Library=$Library, File=$File, Member=$Member"

# Step 1: Query QSYS2.SYSPARTITIONSTAT directly for the source type — no need to
# populate UTILLIB/SRCEXT first.
Write-Host "LOG Step 1: Retrieving source member attribute via SYSPARTITIONSTAT..."
$sqlCmd = "qsh -c `"db2 \`"SELECT TRIM(SOURCE_TYPE) FROM QSYS2.SYSPARTITIONSTAT WHERE TABLE_SCHEMA='$Library' AND TABLE_NAME='$File' AND TABLE_PARTITION='$Member'\`"`""
$AttrResult = Invoke-Remote -Command $sqlCmd -PassThru
# db2 output format: blank, header, dashes, data, blank, "N RECORD(S) SELECTED."
# Take the first non-empty line AFTER the dashes separator.
$lines = @($AttrResult | ForEach-Object { $_.ToString().Trim() })
$dashIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^-+$') { $dashIdx = $i; break }
}
$Extension = ''
if ($dashIdx -ge 0) {
    $Extension = ($lines | Select-Object -Skip ($dashIdx + 1) | Where-Object { $_ -ne '' } | Select-Object -First 1)
}
$Extension = if ($Extension) { $Extension.ToLower() } else { '' }
if ($Extension -and $Extension -ne '-') {
    Write-Host "LOG Source type: $Extension"
} else {
    $Extension = "txt"
    Write-Host "LOG Could not determine source type, defaulting to .txt"
}

# Step 3: Ensure remote source directory exists
Write-Host "LOG Step 3: Creating remote source directory..."
Invoke-Remote -Command "mkdir -p $($Config.HomeDir)/source"
$RemoteStream = "$($Config.HomeDir)/source/$Member.$Extension"
Write-Host "LOG Remote IFS path: $RemoteStream"

# Step 4: Build local path
$SourceDir = Join-Path (Resolve-Path $LocalDir) "source"
if (-not (Test-Path $SourceDir)) { New-Item -ItemType Directory -Path $SourceDir | Out-Null }
$LocalPath = Join-Path $SourceDir "$Member.$Extension"
Write-Host "LOG Local path: $LocalPath"

# Step 5: CPYTOSTMF - copy source member to IFS stream file
Write-Host "LOG Step 5: Converting database member to stream file..."
Invoke-Remote -Command "system ""CPYTOSTMF FROMMBR('/QSYS.LIB/$Library.LIB/$File.FILE/$Member.MBR') TOSTMF('$RemoteStream') STMFCODPAG(1208) STMFOPT(*REPLACE)"""
# Step 6: Download via SFTP
Write-Host "LOG Step 6: Downloading file via SFTP..."
$SftpCommands = @"
get $RemoteStream $LocalPath
rm $RemoteStream
quit
"@

$TempFile = [System.IO.Path]::GetTempFileName()
$SftpCommands | Out-File -FilePath $TempFile -Encoding ascii
Write-Host "LOG SFTP batch commands:"
Write-Host $SftpCommands

& "$PsftpPath" -batch -P $SSHPort -pw $IBMiPassword "$IBMiUser@$IBMiHost" -b $TempFile 2>&1 | ForEach-Object { Write-Host "LOG [sftp]: $_" }

Remove-Item $TempFile

Write-Host "=== Download complete: $LocalPath ==="
