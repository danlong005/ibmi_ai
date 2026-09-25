---
name: putsrc
description: Upload a source member to IBM i
disable-model-invocation: true
allowed-tools: Bash
argument-hint: <MEMBER> [-e environment] [-l library] [-f srcfile]
---

Upload a source member to IBM i. The script finds the file in the `source/` directory, uploads it via SFTP, and copies it into the source physical file on IBM i using CPYFRMSTMF.

## Platform

- **Windows:** run `bin/putsrc.ps1` with PowerShell 7 (`pwsh`). Requires PuTTY (`plink`/`psftp`).
- **Linux / macOS / WSL:** run `bin/putsrc.sh` with Bash. Requires `jq`, `openssl`, `expect`.

## Script reference

| Meaning | Bash | PowerShell | Default |
|---------|------|------------|---------|
| Member name (first positional) | `<MEMBER>` | `<MEMBER>` | required |
| Environment | `-e ENV` | `-Environment ENV` | default env from config |
| Library | `-l LIB` | `-Library LIB` | from config |
| Source physical file | `-f FILE` | `-File FILE` | `ILESRC` |

## Steps

1. Take the member name and any overrides from `$ARGUMENTS` / the user's request. Arguments may be given in either flag style; translate them to the style of the script you run.
2. Run from the project root:

   **Linux / macOS / WSL:**
   ```bash
   bash bin/putsrc.sh <MEMBER> [-e ENV] [-l LIB] [-f FILE]
   ```

   **Windows:**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 <MEMBER> [-Environment ENV] [-Library LIB] [-File FILE]
   ```
3. Show the full output to the user.
4. If the upload failed, summarise the error and suggest a fix (e.g., object in use, member not found locally).
