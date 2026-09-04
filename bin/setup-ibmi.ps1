# ---------------------------------------
# IBM i Configuration Setup Wizard
# Creates ~/.ibmi-config.json with DPAPI-encrypted password
# Supports multiple named environments (dev, qa, prod, etc.)
# Re-runnable: loads existing values as defaults
#
# Usage:
#   setup-ibmi.ps1                    # Add/edit an environment (prompts for name)
#   setup-ibmi.ps1 -Environment dev   # Add/edit the "dev" environment
#   setup-ibmi.ps1 -List              # List all configured environments
#   setup-ibmi.ps1 -Remove qa         # Remove an environment
# ---------------------------------------

param (
    [string]$Environment,
    [switch]$List,
    [string]$Remove
)

# --- Prerequisite checks ---
function Install-Winget {
    $answer = Read-Host "  winget (Windows Package Manager) is not installed. Install it now? (y/n)"
    if ($answer -ne 'y') { return $false }
    try {
        Write-Host "  Fetching latest winget release info..."
        $release  = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
        $bundle   = $release.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
        if (-not $bundle) {
            Write-Host "  Could not locate winget installer bundle. Install manually from the Microsoft Store (App Installer)."
            return $false
        }
        $tmpPath = Join-Path $env:TEMP $bundle.name
        Write-Host "  Downloading $($bundle.name)..."
        Invoke-WebRequest -Uri $bundle.browser_download_url -OutFile $tmpPath -UseBasicParsing
        Write-Host "  Installing..."
        Add-AppxPackage -Path $tmpPath
        Remove-Item $tmpPath -ErrorAction SilentlyContinue
        # Refresh PATH so winget is usable in this session
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH","User")
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "  winget installed successfully."
            return $true
        }
        Write-Host "  winget installed. You may need to open a new terminal for PATH to update."
        return $true
    } catch {
        Write-Host "  Failed to install winget: $_"
        Write-Host "  Install manually from the Microsoft Store (search 'App Installer')."
        return $false
    }
}

function Install-WithWinget {
    param([string]$PackageId, [string]$DisplayName)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        $ok = Install-Winget
        if (-not $ok -or -not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    }
    $answer = Read-Host "  Install $DisplayName via winget? (y/n)"
    if ($answer -ne 'y') { return $false }
    Write-Host "  Running: winget install --id $PackageId -e"
    winget install --id $PackageId -e
    return $true
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "ERROR: PowerShell 7 (pwsh) is required. You are running PowerShell $($PSVersionTable.PSVersion)."
    Write-Host "       DPAPI encryption will not work correctly in PowerShell 5.x."
    $installed = Install-WithWinget -PackageId "Microsoft.PowerShell" -DisplayName "PowerShell 7"
    if ($installed) {
        Write-Host ""
        Write-Host "PowerShell 7 installed. Please close this window and re-run setup using 'pwsh'."
    } else {
        Write-Host "  Install from: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows"
    }
    exit 1
}

$PlinkDefault = "C:\Program Files\PuTTY\plink.exe"
$PsftpDefault = "C:\Program Files\PuTTY\psftp.exe"
$plinkFound   = (Get-Command plink -ErrorAction SilentlyContinue) -or (Test-Path $PlinkDefault)
$psftpFound   = (Get-Command psftp -ErrorAction SilentlyContinue) -or (Test-Path $PsftpDefault)
if (-not $plinkFound -or -not $psftpFound) {
    Write-Host "WARNING: PuTTY (plink.exe / psftp.exe) not found. Required by cpysrc.ps1 and putsrc.ps1."
    $installed = Install-WithWinget -PackageId "PuTTY.PuTTY" -DisplayName "PuTTY"
    if ($installed) {
        Write-Host "  PuTTY installed. You may need to open a new terminal for PATH to update."
    } else {
        Write-Host "  Install from: https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html"
    }
    Write-Host ""
}

$ConfigPath = Join-Path $PSScriptRoot ".ibmi-config.json"

# Load existing config or initialize empty structure
$RootConfig = $null
if (Test-Path $ConfigPath) {
    $RootConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
}

# Migrate flat (pre-environment) config to new structure
if ($RootConfig -and -not $RootConfig.PSObject.Properties['Environments']) {
    Write-Host "Migrating existing config to multi-environment format..."
    $legacyEnv = @{}
    foreach ($prop in @('IBMiHost','IBMiUser','IBMiPassword','SSHPort','Library','File','HomeDir','UtilityLibrary')) {
        if ($RootConfig.PSObject.Properties[$prop]) {
            $legacyEnv[$prop] = $RootConfig.$prop
        }
    }
    $RootConfig = [PSCustomObject]@{
        DefaultEnvironment = "dev"
        Environments = [PSCustomObject]@{
            dev = [PSCustomObject]$legacyEnv
        }
    }
    $RootConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $ConfigPath -Encoding utf8
    Write-Host "Migrated to multi-environment format with existing settings under 'dev'."
}

if (-not $RootConfig) {
    $RootConfig = [PSCustomObject]@{
        DefaultEnvironment = ""
        Environments = [PSCustomObject]@{}
    }
}

# --- List mode ---
if ($List) {
    $envs = $RootConfig.Environments.PSObject.Properties
    if (-not $envs -or ($envs | Measure-Object).Count -eq 0) {
        Write-Host "No environments configured. Run setup-ibmi.ps1 to add one."
    } else {
        Write-Host "Configured environments:"
        foreach ($env in $envs) {
            $marker = if ($env.Name -eq $RootConfig.DefaultEnvironment) { " (default)" } else { "" }
            Write-Host "  $($env.Name)$marker — $($env.Value.IBMiUser)@$($env.Value.IBMiHost) lib=$($env.Value.Library)"
        }
    }
    exit 0
}

# --- Remove mode ---
if ($Remove) {
    if (-not $RootConfig.Environments.PSObject.Properties[$Remove]) {
        Write-Host "ERROR: Environment '$Remove' not found."
        exit 1
    }
    $RootConfig.Environments.PSObject.Properties.Remove($Remove)
    if ($RootConfig.DefaultEnvironment -eq $Remove) {
        $RootConfig.DefaultEnvironment = ""
        Write-Host "Warning: Removed default environment. Run setup again to set a new default."
    }
    $RootConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $ConfigPath -Encoding utf8
    Write-Host "Removed environment '$Remove'."
    exit 0
}

# --- Add/Edit mode ---
function Prompt-Value {
    param([string]$Default, [string]$Prompt)
    $displayDefault = if ($Default) { " [$Default]" } else { "" }
    $val = Read-Host "$Prompt$displayDefault"
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default } else { return $val }
}

# Determine environment name
if (-not $Environment) {
    $Environment = Prompt-Value -Default "" -Prompt "Environment name (e.g., dev, qa, prod)"
}
if (-not $Environment) {
    Write-Host "ERROR: Environment name is required."
    exit 1
}

# Load existing environment values as defaults
$Existing = @{}
if ($RootConfig.Environments.PSObject.Properties[$Environment]) {
    Write-Host "Editing existing environment '$Environment' — press Enter to keep current values."
    $raw = $RootConfig.Environments.$Environment
    foreach ($prop in $raw.PSObject.Properties) {
        $Existing[$prop.Name] = $prop.Value
    }
}
else {
    Write-Host "Creating new environment '$Environment'."
}

Write-Host ""
Write-Host "--- Environment: $Environment ---"

$IBMiHost = Prompt-Value `
    -Default $(if ($Existing.IBMiHost) { $Existing.IBMiHost } else { "myhost.example.com" }) `
    -Prompt "IBM i Host"

$IBMiUser = Prompt-Value `
    -Default $(if ($Existing.IBMiUser) { $Existing.IBMiUser } else { "" }) `
    -Prompt "IBM i User"

if (-not $IBMiUser) {
    Write-Host "ERROR: IBMiUser is required."
    exit 1
}

$hasExisting = [bool]$Existing.IBMiPassword
if ($hasExisting) {
    Write-Host "IBM i Password (press Enter to keep existing, or type new password):"
} else {
    Write-Host "IBM i Password (input hidden):"
}

$EncryptedPassword = $null
while (-not $EncryptedPassword) {
    $SecurePassword = Read-Host -AsSecureString
    $testBstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $testPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($testBstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($testBstr)

    if ([string]::IsNullOrEmpty($testPlain) -and $hasExisting) {
        $EncryptedPassword = $Existing.IBMiPassword
        Write-Host "  (keeping existing password)"
    } elseif ([string]::IsNullOrEmpty($testPlain)) {
        Write-Host "ERROR: Password is required. Try again."
    } else {
        Write-Host "Confirm password:"
        $SecureConfirm = Read-Host -AsSecureString
        $confirmBstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureConfirm)
        $confirmPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($confirmBstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($confirmBstr)

        if ($testPlain -eq $confirmPlain) {
            $EncryptedPassword = $SecurePassword | ConvertFrom-SecureString
        } else {
            Write-Host "Passwords do not match. Try again."
            Write-Host "IBM i Password (input hidden):"
        }
    }
}

$SSHPort = Prompt-Value `
    -Default $(if ($Existing.SSHPort) { $Existing.SSHPort } else { "22" }) `
    -Prompt "SSH Port"
$SSHPort = [int]$SSHPort

$Library = Prompt-Value `
    -Default $(if ($Existing.Library) { $Existing.Library } else { $IBMiUser.ToUpper() }) `
    -Prompt "Library"

$File = Prompt-Value `
    -Default $(if ($Existing.File) { $Existing.File } else { "ILESRC" }) `
    -Prompt "Source File"

$HomeDir = Prompt-Value `
    -Default $(if ($Existing.HomeDir) { $Existing.HomeDir } else { "/home/$($IBMiUser.ToUpper())" }) `
    -Prompt "Home Directory"

$UtilityLibrary = Prompt-Value `
    -Default $(if ($Existing.UtilityLibrary) { $Existing.UtilityLibrary } else { $IBMiUser.ToUpper() }) `
    -Prompt "Utility Library (for CPYSRC etc.)"

# Build environment entry
$EnvConfig = [PSCustomObject]@{
    IBMiHost       = $IBMiHost
    IBMiUser       = $IBMiUser
    IBMiPassword   = $EncryptedPassword
    SSHPort        = $SSHPort
    Library        = $Library.ToUpper()
    File           = $File.ToUpper()
    HomeDir        = $HomeDir
    UtilityLibrary = $UtilityLibrary.ToUpper()
}

# Add or update environment
if ($RootConfig.Environments.PSObject.Properties[$Environment]) {
    $RootConfig.Environments.$Environment = $EnvConfig
} else {
    $RootConfig.Environments | Add-Member -NotePropertyName $Environment -NotePropertyValue $EnvConfig
}

# Set as default if it's the only one, or ask
$envCount = ($RootConfig.Environments.PSObject.Properties | Measure-Object).Count
if ($envCount -eq 1 -or -not $RootConfig.DefaultEnvironment) {
    $RootConfig.DefaultEnvironment = $Environment
    Write-Host "Set '$Environment' as the default environment."
} else {
    $setDefault = Prompt-Value -Default "n" -Prompt "Set '$Environment' as default? (y/n)"
    if ($setDefault -eq 'y') {
        $RootConfig.DefaultEnvironment = $Environment
    }
}

$RootConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $ConfigPath -Encoding utf8

Write-Host ""
Write-Host "Environment '$Environment' saved to $ConfigPath"
Write-Host "Password is DPAPI-encrypted (only decryptable by your Windows account)."
