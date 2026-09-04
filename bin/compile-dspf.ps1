# Compile a display file on IBM i
#
# Conventions (all overridable):
#   Source member : {DspF}

param (
    [Parameter(Mandatory)][string]$DspF,
    [string]$Environment,
    [string]$Library,
    [string]$SrcMbr     # defaults to {DspF}
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
$ResolvedSrcMbr = if ($SrcMbr) { $SrcMbr } else { $DspF }

# Set $ResolvedLibrary as *CURLIB so its includes take precedence over OBJLIB in *USRLIBL
$LibList = @('YAJL', 'XMLILIB', 'LIBHTTP', 'OBJLIB', 'RPGUNIT', 'QDEVTOOLS')
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

Write-Host "=== Compiling $DspF Display File ==="
Write-Host "Environment: $EnvName  Library: $ResolvedLibrary"

if (-not (Invoke-Remote "system 'CRTDSPF FILE($ResolvedLibrary/$DspF) SRCFILE($ResolvedLibrary/ILESRC) SRCMBR($ResolvedSrcMbr)'")) {
    exit 1
}

Write-Host "`n=== Compilation Complete ==="
