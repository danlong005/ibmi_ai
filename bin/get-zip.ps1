# ---------------------------------------
# IBM i Zip File Download Script
# Downloads .zip files from the configured user's home directory (or specified remote dir)
# Uses PuTTY (plink + psftp)
#
# Usage:
#   pwsh -ExecutionPolicy Bypass -File bin/get-zip.ps1              # List available zip files
#   pwsh -ExecutionPolicy Bypass -File bin/get-zip.ps1 report.zip   # Download a specific zip
# ---------------------------------------

param (
    [Parameter(Position=0)]
    [string]$FileName,                          # Zip filename to download; omit to list available

    [string]$RemoteDir = "",                      # Remote directory; defaults to /home/<IBMiUser>

    [string]$LocalDir = ".",                    # Local destination directory

    [string]$Environment,

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
$IBMiPassword = if ($Config.IBMiPassword) {
    $secure = $Config.IBMiPassword | ConvertTo-SecureString
    (New-Object System.Net.NetworkCredential '', $secure).Password
} else { "" }

$IBMiHost = $Config.IBMiHost
$IBMiUser = $Config.IBMiUser
$SSHPort  = if ($Config.SSHPort) { $Config.SSHPort } else { 22 }
if (-not $RemoteDir) { $RemoteDir = "/home/$IBMiUser" }

# Helper: run a command on IBM i via plink
function Invoke-Remote {
    param([string]$Command, [switch]$PassThru)
    $output = & "$PlinkPath" -batch -P $SSHPort -pw $IBMiPassword "$IBMiUser@$IBMiHost" $Command 2>&1
    $output | ForEach-Object { Write-Host "LOG [plink]: $_" }
    if ($PassThru) { return $output }
}

# --- List mode: no filename given ---
if (-not $FileName) {
    Write-Host "=== Zip files available in ${RemoteDir} ==="
    $listing = Invoke-Remote -Command "ls $RemoteDir/*.zip 2>/dev/null" -PassThru
    if (-not $listing) {
        Write-Host "No .zip files found in $RemoteDir"
    }
    exit 0
}

# --- Download mode ---
$RemotePath = "$RemoteDir/$FileName"
$LocalDir   = (Resolve-Path $LocalDir).Path
$LocalPath  = Join-Path $LocalDir $FileName

Write-Host "=== Downloading $FileName ==="
Write-Host "LOG Remote path: $RemotePath"
Write-Host "LOG Local path:  $LocalPath"

# Verify the remote file exists
Write-Host "LOG Checking remote file..."
$check = Invoke-Remote -Command "ls $RemotePath 2>/dev/null" -PassThru
if (-not ($check | Out-String).Trim()) {
    Write-Host "ERROR: $RemotePath not found on IBM i."
    exit 1
}

# Download via SFTP
Write-Host "LOG Downloading via SFTP..."
$SftpCommands = @"
get $RemotePath $LocalPath
quit
"@

$TempFile = [System.IO.Path]::GetTempFileName()
$SftpCommands | Out-File -FilePath $TempFile -Encoding ascii

& "$PsftpPath" -batch -P $SSHPort -pw $IBMiPassword "$IBMiUser@$IBMiHost" -b $TempFile 2>&1 |
    ForEach-Object { Write-Host "LOG [sftp]: $_" }

Remove-Item $TempFile

if (Test-Path $LocalPath) {
    Write-Host "=== Download complete: $LocalPath ==="
} else {
    Write-Host "ERROR: Download failed — file not found at $LocalPath"
    exit 1
}
