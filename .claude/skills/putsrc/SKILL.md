---
name: putsrc
description: Upload a source member to IBM i
disable-model-invocation: true
allowed-tools: Bash
argument-hint: <MEMBER> [-e environment] [-l library] [-f srcfile]
---

Upload a source member to IBM i. The script finds the file under `source/<srcfile>/` and uses that folder name as the target source file (an explicit `-f`/`-File` overrides it and limits the search to that folder; files directly in `source/` use the configured file). It uploads it via SFTP and copies it into the source physical file on IBM i using CPYFRMSTMF.

## Platform

- **Windows:** run `bin/putsrc.ps1` with PowerShell 7 (`pwsh`). Requires PuTTY (`plink`/`psftp`).
- **Linux / macOS / WSL:** run `bin/putsrc.sh` with Bash. Requires `jq`, `openssl`, `expect`.

## Script reference

| Meaning | Bash | PowerShell | Default |
|---------|------|------------|---------|
| Member name (first positional) | `<MEMBER>` | `<MEMBER>` | required |
| Environment | `-e ENV` | `-Environment ENV` | default env from config |
| Library | `-l LIB` | `-Library LIB` | from config |
| Source physical file | `-f FILE` | `-File FILE` | folder the member is in (else config file) |

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
