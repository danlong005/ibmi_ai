# ---------------------------------------
# IBM i Database Member Upload Script
# Uses PuTTY (plink + psftp)
# ---------------------------------------

param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Member,

    [string]$Environment,

    [string]$IBMiHost,
    [string]$IBMiUser,
    [string]$IBMiPassword,

    [string]$Library,
    [string]$File,

    [string]$LocalDir = ".",

    [string]$PlinkPath = "C:\Program Files\PuTTY\plink.exe",
    [string]$PsftpPath = "C:\Program Files\PuTTY\psftp.exe"
)

# Load shared config
. "$PSScriptRoot\ibmi-common.ps1"
$Config = Get-IBMiConfig -Environment $Environment

# Apply param overrides — if explicitly passed, use it; otherwise use config
if (-not $PSBoundParameters.ContainsKey('IBMiHost'))     { $IBMiHost     = $Config.IBMiHost }
if (-not $PSBoundParameters.ContainsKey('IBMiUser'))     { $IBMiUser     = $Config.IBMiUser }
if (-not $PSBoundParameters.ContainsKey('IBMiPassword')) { $IBMiPassword = $Config.IBMiPassword }
if (-not $PSBoundParameters.ContainsKey('Library'))      { $Library      = $Config.Library }
if (-not $PSBoundParameters.ContainsKey('File'))         { $File         = $Config.File }


# Build a runtime config hashtable for Invoke-Remote
$RunConfig = @{
    IBMiHost     = $IBMiHost
    IBMiUser     = $IBMiUser
    IBMiPassword = $IBMiPassword
    PlinkPath    = $PlinkPath
}

# Find the file in the source directory by member name
$Member = $Member.ToUpper()
$SourceDir = Join-Path (Resolve-Path $LocalDir) "source"
$Match = Get-ChildItem -Path $SourceDir -Filter "$Member.*" -File -ErrorAction SilentlyContinue

if (-not $Match) {
    Write-Host "ERROR: No file found for member $Member in $SourceDir"
    exit 1
}
if ($Match.Count -gt 1) {
    Write-Host "ERROR: Multiple files found for member $Member in $SourceDir"
    $Match | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$LocalPath = $Match.FullName
$Extension = $Match.Extension.TrimStart('.').ToLower()
$SourceType = $Extension.ToUpper()

$RemoteStream = "$($Config.HomeDir)/source/$Member.$Extension"

Write-Host "=== Starting upload of member: $Member ==="
Write-Host "LOG Library=$Library, File=$File, Member=$Member, SourceType=$SourceType"
Write-Host "LOG Local path: $LocalPath"
Write-Host "LOG Remote IFS path: $RemoteStream"

# Step 1: Ensure remote source directory exists
Write-Host "LOG Step 1: Creating remote source directory..."
Invoke-Remote -Command "mkdir -p $($Config.HomeDir)/source" -Config $RunConfig

# Step 2: Upload file via SFTP
Write-Host "LOG Step 2: Uploading file via SFTP..."
$SftpCommands = @"
put $LocalPath $RemoteStream
quit
"@

$TempFile = [System.IO.Path]::GetTempFileName()
$SftpCommands | Out-File -FilePath $TempFile -Encoding ascii
Write-Host "LOG SFTP batch commands:"
Write-Host $SftpCommands

& "$PsftpPath" -batch -pw $IBMiPassword "$IBMiUser@$IBMiHost" -b $TempFile 2>&1 | ForEach-Object { Write-Host "LOG [sftp]: $_" }

# Step 3: CPYFRMSTMF - copy IFS stream file back to source member
Write-Host "LOG Step 3: Copying stream file to database member..."
Invoke-Remote -Command "system ""CPYFRMSTMF FROMSTMF('$RemoteStream') TOMBR('/QSYS.LIB/$Library.LIB/$File.FILE/$Member.MBR') MBROPT(*REPLACE) STMFCODPAG(1208)""" -Config $RunConfig

# Step 4: Set the source type attribute on the member
Write-Host "LOG Step 4: Setting source type attribute to $SourceType..."
Invoke-Remote -Command "system ""CHGPFM FILE($Library/$File) MBR($Member) SRCTYPE($SourceType)""" -Config $RunConfig

# Step 5: Clean up temp file and remote IFS file
Remove-Item $TempFile
Write-Host "LOG Step 5: Cleaning up remote file..."
Invoke-Remote -Command "rm -f $RemoteStream" -Config $RunConfig

Write-Host "=== Upload complete: $Member ($SourceType) ==="
