# Compile a bound RPG program on IBM i
#
# Conventions (all overridable):
#   Source member : {Pgm}
#
# Use -SqlPgm for SQLRPGLE source (uses CRTSQLRPGI instead of CRTBNDRPG)

param (
    [Parameter(Mandatory)][string]$Pgm,
    [string]$Environment,
    [string]$Library,
    [string]$SrcMbr,    # defaults to {Pgm}
    [string]$BndDir,    # optional binding directory (e.g. UTILBD)
    [switch]$SqlPgm     # use CRTSQLRPGI instead of CRTBNDRPG
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
$ResolvedSrcMbr = if ($SrcMbr) { $SrcMbr } else { $Pgm }

# On UAT the user profile's lib list is already correct — only ensure OBJLIB is present (added last).
# On dev we build the full list so OBJLIB precedes the developer library for /Include resolution.
if ($EnvName -eq 'uat') {
    $LibListCmds = "liblist -a OBJLIB 2>/dev/null"
} else {
    $LibList = @('APPLIB', 'YAJL', 'XMLILIB', 'LIBHTTP', 'OBJLIB', 'DATALIB', 'RPGUNIT', 'QDEVTOOLS')
    $LibListCmds = (($LibList | ForEach-Object { "liblist -a $_ 2>/dev/null" }) -join '; ') + "; liblist -a $ResolvedLibrary 2>/dev/null"
}

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

Write-Host "=== Compiling $Pgm Program ==="
Write-Host "Environment: $EnvName  Library: $ResolvedLibrary"

if ($SqlPgm) {
    # CRTSQLRPGI does not accept BNDDIR — binding directory must be in Ctl-Opt in source
    if ($BndDir) { Write-Host "Note: -BndDir ignored for -SqlPgm; specify BndDir in Ctl-Opt in source." }
    if (-not (Invoke-Remote "system 'CRTSQLRPGI OBJ($ResolvedLibrary/$Pgm) SRCFILE($ResolvedLibrary/ILESRC) SRCMBR($ResolvedSrcMbr) OBJTYPE(*PGM) RPGPPOPT(*LVL2) DBGVIEW(*SOURCE)'")) {
        exit 1
    }
} else {
    $BndDirParam = if ($BndDir) { " BNDDIR($BndDir)" } else { "" }
    if (-not (Invoke-Remote "system 'CRTBNDRPG PGM($ResolvedLibrary/$Pgm) SRCFILE($ResolvedLibrary/ILESRC) SRCMBR($ResolvedSrcMbr) DBGVIEW(*SOURCE)$BndDirParam'")) {
        exit 1
    }
}

Write-Host "`n=== Compilation Complete ==="
