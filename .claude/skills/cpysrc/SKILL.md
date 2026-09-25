---
name: cpysrc
description: Download a source member from IBM i
disable-model-invocation: true
allowed-tools: Bash
argument-hint: <MEMBER> [-e environment] [-l library] [-f srcfile]
---

Download a source member from IBM i. The script retrieves the source type attribute, copies the member to an IFS stream file, and downloads it locally to the `source/` directory with the correct file extension.

## Platform

- **Windows:** run `bin/cpysrc.ps1` with PowerShell 7 (`pwsh`). Requires PuTTY (`plink`/`psftp`).
- **Linux / macOS / WSL:** run `bin/cpysrc.sh` with Bash. Requires `jq`, `openssl`, `expect`.

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
   bash bin/cpysrc.sh <MEMBER> [-e ENV] [-l LIB] [-f FILE]
   ```

   **Windows:**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 <MEMBER> [-Environment ENV] [-Library LIB] [-File FILE]
   ```
3. Show the full output to the user.
4. If the download failed, summarise the error and suggest a fix (e.g., member not found, object in use).
