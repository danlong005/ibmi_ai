# IBM i Source Management Scripts

Scripts for downloading, uploading, and compiling source members to/from IBM i. Available in two forms:

- **PowerShell** (`*.ps1`) — Windows, uses PuTTY (plink + psftp) with DPAPI-encrypted credentials.
- **Bash** (`*.sh`) — macOS/Linux, uses `ssh`/`sftp` (via `expect` for password auth) with AES-256 encrypted credentials (key derived from machine + user identity, analogous to DPAPI).

Both forms support multiple named environments (dev, qa, prod, etc.) and share the same config file (`bin/.ibmi-config.json`), but the password is encrypted differently by each platform — an environment must be (re-)configured with the setup script matching the platform you're running on.

## Prerequisites

### Windows (PowerShell)

- **PowerShell 7 (pwsh)** — required for DPAPI encryption compatibility. Download from [Microsoft](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows).
- **PuTTY** — `plink.exe` and `psftp.exe` must be installed. Default location: `C:\Program Files\PuTTY\`. Download from [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html).
- **IBM i host key** — you must connect to the host at least once with PuTTY or plink to accept the host key before the scripts will work non-interactively.

### macOS / Linux (Bash)

- **jq**, **openssl**, **expect** — install with `brew install jq openssl expect` (macOS) or `apt install jq openssl expect` (Linux).
- No PuTTY/host-key priming needed — the scripts use OpenSSH (`ssh`/`sftp`) with `StrictHostKeyChecking=no`.

## Quick Start

```powershell
# PowerShell (Windows)
# 1. Set up your first environment
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev

# 2. Download a source member
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM

# 3. Upload a source member
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MYPGM
```

```bash
# Bash (macOS/Linux)
# 1. Set up your first environment
bash bin/setup-ibmi.sh -e dev

# 2. Download a source member
bash bin/cpysrc.sh MYPGM

# 3. Upload a source member
bash bin/putsrc.sh MYPGM
```

## Configuration Setup (`setup-ibmi.ps1`)

The setup wizard creates `bin/ibmi-config.json` in your user profile directory. Your password is encrypted with Windows DPAPI, meaning it can only be decrypted by your Windows account on your machine. The config file is safe to leave on disk but should **not** be committed to Git.

### First-time setup — create an environment

```powershell
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev
```

You will be prompted for:

| Setting | Description | Default |
|---------|-------------|---------|
| IBM i Host | Hostname of the IBM i system | *(none — required)* |
| IBM i User | Your IBM i user profile | *(none — required)* |
| IBM i Password | Your IBM i password (hidden input, confirmed) | *(none — required)* |
| Library | Target source library | Same as user (uppercase) |
| Source File | Source physical file name | `ILESRC` |
| Home Directory | IFS home directory for temp files | `/home/<USER>` |
| Utility Library | Reserved for future use | Same as user (uppercase) |

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
  dev (default) — myuser@myhost.example.com lib=DEVLIB
  qa — myuser@myhost.example.com lib=QALIB
  prod — myuser@myhost.example.com lib=PRODLIB
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

Downloads a source member from IBM i to the local `source/` directory with the correct file extension (e.g., `.rpgle`, `.sqlrpgle`, `.clle`). The source type is looked up directly from `QSYS2.SYSPARTITIONSTAT` via the `db2` CLI (over `qsh`) — no custom program needs to be installed on the IBM i side.

```powershell
# Download using the default environment
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM

# Download from a specific environment
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM -Environment qa

# Override library or file for a single call
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM -Library YOURLIB -File ILESRC
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
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MYPGM -Library YOURLIB
```

### Parameters

Same as `cpysrc.ps1` above.

## Bash Equivalents (`cpysrc.sh` / `putsrc.sh`)

Same behavior as the PowerShell scripts above, using flags instead of named parameters:

```bash
bash bin/cpysrc.sh MYPGM -e qa -l YOURLIB -f ILESRC -d .
bash bin/putsrc.sh MYPGM -e qa -l YOURLIB
```

| Flag | Description |
|------|-------------|
| `<MEMBER>` | Source member name (first positional argument) |
| `-e`, `--environment` | Environment name from config (uses default if omitted) |
| `-l`, `--library` | Override target library |
| `-f`, `--file` | Override source physical file |
| `-d`, `--dir` | Local base directory (default: current directory) |
| `-h`, `--host` / `-u`, `--user` / `-p`, `--password` / `-P`, `--port` | Override connection settings for a single call |

## Compiling (`compile-*.sh` / `run-tests.sh`)

Bash scripts that compile source directly on IBM i over SSH (`qsh`), mirroring `compile-*.ps1`. Each sets the target library as `*CURLIB` and adds `YAJL`, `XMLILIB`, `LIBHTTP`, `PRODLIB`, `RPGUNIT`, `QDEVTOOLS` to the library list before compiling.

```bash
# Bound RPG program (add --sql for SQLRPGLE via CRTSQLRPGI)
bash bin/compile-pgm.sh MYPGM -e qa [-l LIBRARY] [-s SRCMBR] [-b BNDDIR] [--sql]

# CL program (add --ile for CLLE via CRTBNDCL)
bash bin/compile-cl.sh MYPGM -e qa [-l LIBRARY] [-s SRCMBR] [--ile]

# Display file
bash bin/compile-dspf.sh MYDSPF -e qa [-l LIBRARY] [-s SRCMBR]

# Service program (module + CRTSRVPGM; add --sql for SQLRPGLE module;
# -p optionally binds an existing service program via BNDSRVPGM)
bash bin/compile-srvpgm.sh MYSRVPGM -e qa [-l LIBRARY] [-m MODULESRC] [-b BNDSRC] [-d BNDDIR] [-p BNDSRVPGM] [--sql]

# RPGUnit test program: compiled as CRTSQLRPGI module + CRTSRVPGM EXPORT(*ALL)
# (not RUCRTTST, which doesn't play well with **free + RPGPPOPT(*LVL2)).
# Bound service pgm under test defaults to {TSTPGM} with trailing _T stripped;
# pass -b '*NONE' to skip binding a service program under test.
bash bin/compile-tst.sh MYPGM_T -e qa [-l LIBRARY] [-s SRCMBR] [-b BNDSRVPGM]

# Run an RPGUnit test suite (add -p to run a single test procedure via TSTPRC)
bash bin/run-tests.sh MYPGM_T -e qa [-l LIBRARY] [-p TESTPROC]

# Call a CL program by name (no parameters)
bash bin/run-cl.sh MYPGM -e qa [-l LIBRARY]

# List or download .zip files from the configured user's IFS home directory
bash bin/get-zip.sh -e qa                        # list
bash bin/get-zip.sh report.zip -e qa [-r REMOTE_DIR] [-d LOCAL_DIR]
```

## Config File Structure

The config file (`bin/.ibmi-config.json`) looks like this:

```json
{
  "DefaultEnvironment": "dev",
  "Environments": {
    "dev": {
      "IBMiHost": "myhost.example.com",
      "IBMiUser": "myuser",
      "IBMiPassword": "01000000d08c9ddf...(DPAPI encrypted)...",
      "Library": "MYUSER",
      "File": "ILESRC",
      "HomeDir": "/home/MYUSER",
      "UtilityLibrary": "MYUSER"
    },
    "qa": {
      "IBMiHost": "myhost.example.com",
      "IBMiUser": "myuser",
      "IBMiPassword": "01000000d08c9ddf...(DPAPI encrypted)...",
      "Library": "QALIB",
      "File": "ILESRC",
      "HomeDir": "/home/MYUSER",
      "UtilityLibrary": "MYUSER"
    }
  }
}
```

The password field is either DPAPI-encrypted (written by `setup-ibmi.ps1` on Windows) or AES-256 encrypted (written by `setup-ibmi.sh` on macOS/Linux) — only decryptable by the platform/account that created it. If you use both platforms against the same environment, re-run the matching setup script on each to (re-)encrypt the password for that platform.

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Config file not found` | Haven't run setup yet | Run `setup-ibmi.ps1 -Environment <name>` or `setup-ibmi.sh -e <name>` |
| `Environment 'X' not found` | Typo or environment not created | Run `setup-ibmi.ps1 -List` / `setup-ibmi.sh -l` to see available environments |
| `Access denied / password not accepted` | Wrong password or expired | Re-run setup for that environment and enter current password |
| `ConvertTo-SecureString` errors | Using Windows PowerShell 5.1 instead of pwsh 7 | Use `pwsh` instead of `powershell` to run scripts |
| `no valid host name provided` | Password decryption failed silently | Ensure you run scripts with `pwsh`, not `powershell` |
| `plink: no host key found` | First time connecting to host (Windows) | Run `plink <host>` manually once to accept the host key |
| Password decrypts to empty (bash) | Config was encrypted on a different machine/account | Re-run `setup-ibmi.sh -e <name>` on this machine to re-encrypt |
| `command not found: jq/openssl/expect` | Missing dependency (bash) | `brew install jq openssl expect` (macOS) or `apt install jq openssl expect` (Linux) |
| `Member not found locally` | File not in `source/` directory | Download it first with `cpysrc.ps1` / `cpysrc.sh` |

## Files

| File | Purpose |
|------|---------|
| `bin/setup-ibmi.ps1` / `bin/setup-ibmi.sh` | Interactive setup wizard for config |
| `bin/cpysrc.ps1` / `bin/cpysrc.sh` | Download source member from IBM i |
| `bin/putsrc.ps1` / `bin/putsrc.sh` | Upload source member to IBM i |
| `bin/compile-pgm.ps1` / `bin/compile-pgm.sh` | Compile a bound RPG program (CRTBNDRPG / CRTSQLRPGI) |
| `bin/compile-cl.ps1` / `bin/compile-cl.sh` | Compile a CL program (CRTCLPGM / CRTBNDCL) |
| `bin/compile-dspf.ps1` / `bin/compile-dspf.sh` | Compile a display file (CRTDSPF) |
| `bin/compile-srvpgm.ps1` / `bin/compile-srvpgm.sh` | Compile a service program (CRTRPGMOD/CRTSQLRPGI + CRTSRVPGM) |
| `bin/compile-tst.ps1` / `bin/compile-tst.sh` | Compile an RPGUnit test program (CRTSQLRPGI module + CRTSRVPGM) |
| `bin/run-tests.ps1` / `bin/run-tests.sh` | Run an RPGUnit test suite (RUCALLTST) |
| `bin/run-cl.ps1` / `bin/run-cl.sh` | Call a CL program by name (no parameters) |
| `bin/get-zip.ps1` / `bin/get-zip.sh` | List/download `.zip` files from the configured user's IFS home directory |
| `bin/.ibmi-config.json` | Environment config with encrypted credentials (gitignored, do not commit) |
