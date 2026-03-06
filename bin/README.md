# IBM i Source Management Scripts

PowerShell scripts for downloading and uploading source members to/from IBM i using PuTTY (plink + psftp). Supports multiple named environments (dev, qa, prod, etc.) with DPAPI-encrypted credentials.

## Prerequisites

- **PowerShell 7 (pwsh)** — required for DPAPI encryption compatibility. Download from [Microsoft](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows).
- **PuTTY** — `plink.exe` and `psftp.exe` must be installed. Default location: `C:\Program Files\PuTTY\`. Download from [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html).
- **IBM i host key** — you must connect to the host at least once with PuTTY or plink to accept the host key before the scripts will work non-interactively.

## Quick Start

```powershell
# 1. Set up your first environment
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev

# 2. Download a source member
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM

# 3. Upload a source member
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MYPGM
```

## Configuration Setup (`setup-ibmi.ps1`)

The setup wizard creates `~/.ibmi-config.json` in your user profile directory. Your password is encrypted with Windows DPAPI, meaning it can only be decrypted by your Windows account on your machine. The config file is safe to leave on disk but should **not** be committed to Git.

### First-time setup — create an environment

```powershell
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev
```

You will be prompted for:

| Setting | Description | Default |
|---------|-------------|---------|
| IBM i Host | Hostname of the IBM i system | `as400e.pplsi.com` |
| IBM i User | Your IBM i user profile | *(none — required)* |
| IBM i Password | Your IBM i password (hidden input, confirmed) | *(none — required)* |
| Library | Target source library | Same as user (uppercase) |
| Source File | Source physical file name | `ILESRC` |
| Home Directory | IFS home directory for temp files | `/home/<USER>` |
| Utility Library | Library containing CPYSRC program | Same as user (uppercase) |

The first environment you add is automatically set as the default.

### Add another environment

```powershell
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment qa
```

You will be asked if you want to make it the new default.

### Edit an existing environment

```powershell
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev
```

Existing values are shown as defaults — press Enter to keep them. For the password, press Enter with no input to keep the existing password, or type a new one (you will be asked to confirm).

### List all environments

```powershell
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -List
```

Example output:

```
Configured environments:
  dev (default) — longdm@as400e.pplsi.com lib=LONGDM
  qa — longdm@as400e.pplsi.com lib=MJDA73QUAL
  prod — longdm@as400e.pplsi.com lib=PPLOBJS
```

### Remove an environment

```powershell
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Remove qa
```

If you remove the default environment, you will need to run setup again to set a new default.

### Change your password

Re-run setup for the environment. Press Enter through all prompts until you reach the password, then type the new password and confirm it.

```powershell
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev
```

## Downloading Source (`cpysrc.ps1`)

Downloads a source member from IBM i to the local `source/` directory with the correct file extension (e.g., `.rpgle`, `.sqlrpgle`, `.clle`).

```powershell
# Download using the default environment
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM

# Download from a specific environment
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM -Environment qa

# Override library or file for a single call
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM -Library PPLOBJS -File ILESRC
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `Member` | Yes | Source member name (first positional parameter) |
| `-Environment` | No | Environment name from config (uses default if omitted) |
| `-Library` | No | Override target library |
| `-File` | No | Override source physical file |
| `-LocalDir` | No | Local base directory (default: current directory) |
| `-PlinkPath` | No | Path to plink.exe (default: `C:\Program Files\PuTTY\plink.exe`) |
| `-PsftpPath` | No | Path to psftp.exe (default: `C:\Program Files\PuTTY\psftp.exe`) |

## Uploading Source (`putsrc.ps1`)

Uploads a local source file from the `source/` directory to IBM i. The script finds the file by member name, determines the source type from the file extension, and sets it on the member.

```powershell
# Upload using the default environment
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MYPGM

# Upload to a specific environment
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MYPGM -Environment qa

# Override library for a single call
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MYPGM -Library MJDA73QUAL
```

### Parameters

Same as `cpysrc.ps1` above.

## Config File Structure

The config file (`~/.ibmi-config.json`) looks like this:

```json
{
  "DefaultEnvironment": "dev",
  "Environments": {
    "dev": {
      "IBMiHost": "as400e.pplsi.com",
      "IBMiUser": "myuser",
      "IBMiPassword": "01000000d08c9ddf...(DPAPI encrypted)...",
      "Library": "MYUSER",
      "File": "ILESRC",
      "HomeDir": "/home/MYUSER",
      "UtilityLibrary": "MYUSER"
    },
    "qa": {
      "IBMiHost": "as400e.pplsi.com",
      "IBMiUser": "myuser",
      "IBMiPassword": "01000000d08c9ddf...(DPAPI encrypted)...",
      "Library": "MJDA73QUAL",
      "File": "ILESRC",
      "HomeDir": "/home/MYUSER",
      "UtilityLibrary": "MYUSER"
    }
  }
}
```

The password field is a DPAPI-encrypted string that can only be decrypted by the Windows user account that created it.

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Config file not found` | Haven't run setup yet | Run `setup-ibmi.ps1 -Environment <name>` |
| `Environment 'X' not found` | Typo or environment not created | Run `setup-ibmi.ps1 -List` to see available environments |
| `Access denied / password not accepted` | Wrong password or expired | Re-run `setup-ibmi.ps1 -Environment <name>` and enter current password |
| `ConvertTo-SecureString` errors | Using Windows PowerShell 5.1 instead of pwsh 7 | Use `pwsh` instead of `powershell` to run scripts |
| `no valid host name provided` | Password decryption failed silently | Ensure you run scripts with `pwsh`, not `powershell` |
| `plink: no host key found` | First time connecting to host | Run `plink <host>` manually once to accept the host key |
| `Member not found locally` | File not in `source/` directory | Download it first with `cpysrc.ps1` |

## Files

| File | Purpose |
|------|---------|
| `bin/setup-ibmi.ps1` | Interactive setup wizard for config |
| `bin/ibmi-common.ps1` | Shared functions (config loader, remote command wrapper) |
| `bin/cpysrc.ps1` | Download source member from IBM i |
| `bin/putsrc.ps1` | Upload source member to IBM i |
| `~/.ibmi-config.json` | User config (DPAPI-encrypted, do not commit) |
