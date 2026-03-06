# ---------------------------------------
# IBM i Shared Configuration & Utilities
# Dot-source this from cpysrc.ps1 / putsrc.ps1
# ---------------------------------------

function Get-IBMiConfig {
    param([string]$Environment)

    $ConfigPath = Join-Path $env:USERPROFILE ".ibmi-config.json"

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "ERROR: Config file not found at $ConfigPath"
        Write-Host "Run bin/setup-ibmi.ps1 to create it."
        exit 1
    }

    $root = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    # Resolve environment name
    if (-not $Environment) {
        $Environment = $root.DefaultEnvironment
    }
    if (-not $Environment) {
        Write-Host "ERROR: No environment specified and no default set."
        Write-Host "Run: bin/setup-ibmi.ps1 -Environment <name>"
        exit 1
    }
    if (-not $root.Environments.PSObject.Properties[$Environment]) {
        Write-Host "ERROR: Environment '$Environment' not found in config."
        Write-Host "Available: $(($root.Environments.PSObject.Properties | ForEach-Object { $_.Name }) -join ', ')"
        exit 1
    }

    $env = $root.Environments.$Environment

    # Decrypt DPAPI password
    $secure = $env.IBMiPassword | ConvertTo-SecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    return @{
        Environment    = $Environment
        IBMiHost       = $env.IBMiHost
        IBMiUser       = $env.IBMiUser
        IBMiPassword   = $plainPassword
        Library        = $env.Library
        File           = $env.File
        HomeDir        = $env.HomeDir
        UtilityLibrary = $env.UtilityLibrary
    }
}

function Invoke-Remote {
    param(
        [string]$Command,
        [hashtable]$Config
    )
    $tmpFile = [System.IO.Path]::GetTempFileName()
    $Command | Out-File -FilePath $tmpFile -Encoding ascii
    Write-Host "LOG [remote cmd]: $Command"
    $result = & $Config.PlinkPath -ssh -pw $Config.IBMiPassword "$($Config.IBMiUser)@$($Config.IBMiHost)" -m $tmpFile 2>&1
    Write-Host "LOG [remote out]: $result"
    Remove-Item $tmpFile
    return $result
}
