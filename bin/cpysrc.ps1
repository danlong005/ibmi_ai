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

Write-Host "=== Starting download of member: $Member ==="
Write-Host "LOG Library=$Library, File=$File, Member=$Member"

# Step 1: Call CPYSRC to get the source type attribute
Write-Host "LOG Step 1: Retrieving source member attribute..."
Invoke-Remote -Command "system ""CALL $($Config.UtilityLibrary)/CPYSRC PARM('$Library' '$File' '$Member')""" -Config $RunConfig

# Step 1b: Export SRCEXT file to .source_ext stream file
Write-Host "LOG Step 1b: Exporting source type to .source_ext..."
Invoke-Remote -Command "system ""CPYTOIMPF FROMFILE($($Config.UtilityLibrary)/SRCEXT) TOSTMF('$($Config.HomeDir)/.source_ext') MBROPT(*REPLACE) STMFCCSID(1208) RCDDLM(*CRLF) DTAFMT(*FIXED)""" -Config $RunConfig

# Step 2: Read the attribute from .source_ext
Write-Host "LOG Step 2: Reading .source_ext..."
$AttrResult = Invoke-Remote -Command "cat $($Config.HomeDir)/.source_ext 2>/dev/null | tr -d '[:space:]'" -Config $RunConfig

if ($AttrResult) {
    $Extension = ($AttrResult | Out-String).Trim().ToLower()
    Write-Host "LOG Source type: $Extension"
} else {
    $Extension = "txt"
    Write-Host "LOG Could not determine source type, defaulting to .txt"
}

# Step 3: Ensure remote source directory exists
Write-Host "LOG Step 3: Creating remote source directory..."
Invoke-Remote -Command "mkdir -p $($Config.HomeDir)/source" -Config $RunConfig

$RemoteStream = "$($Config.HomeDir)/source/$Member.$Extension"
Write-Host "LOG Remote IFS path: $RemoteStream"

# Step 4: Build local path
$SourceDir = Join-Path (Resolve-Path $LocalDir) "source"
if (-not (Test-Path $SourceDir)) { New-Item -ItemType Directory -Path $SourceDir | Out-Null }
$LocalPath = Join-Path $SourceDir "$Member.$Extension"
Write-Host "LOG Local path: $LocalPath"

# Step 5: CPYTOSTMF - copy source member to IFS stream file
Write-Host "LOG Step 5: Converting database member to stream file..."
Invoke-Remote -Command "system ""CPYTOSTMF FROMMBR('/QSYS.LIB/$Library.LIB/$File.FILE/$Member.MBR') TOSTMF('$RemoteStream') STMFCODPAG(1208) STMFOPT(*REPLACE)""" -Config $RunConfig

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

& "$PsftpPath" -batch -pw $IBMiPassword "$IBMiUser@$IBMiHost" -b $TempFile 2>&1 | ForEach-Object { Write-Host "LOG [sftp]: $_" }

Remove-Item $TempFile

Write-Host "=== Download complete: $LocalPath ==="
