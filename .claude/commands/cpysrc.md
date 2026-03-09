Download a source member from IBM i.

The user will provide a member name. The script retrieves the source type attribute, copies the member to an IFS stream file, and downloads it locally to the `source/` directory with the correct file extension.

## Platform detection

Detect the platform by checking the environment. Use `win32` platform detection (or check if `pwsh` and PuTTY are available) to decide:

- **Windows (win32):** Use the PowerShell script `bin/cpysrc.ps1`
- **Linux / macOS / WSL:** Use the bash script `bin/cpysrc.sh`

## Script reference

### Windows (PowerShell)
```
cpysrc.ps1 <MEMBER> [-Library LIBRARY] [-File SRCFILE] [-Environment ENV]

  MEMBER        Source member name (required, first positional parameter)
  -Library      Target library (default: from config)
  -File         Source physical file (default: ILESRC)
  -Environment  Environment name from config (default: default env)
```

### Linux / macOS / WSL (Bash)
```
cpysrc.sh <MEMBER> [-l LIBRARY] [-f SRCFILE] [-e ENV]

  MEMBER     Source member name (required, first positional parameter)
  -l         Target library (default: from config)
  -f         Source physical file (default: ILESRC)
  -e         Environment name from config (default: default env)
```

Requires: `jq`, `openssl`, `expect` (install via `brew install` or `apt install`).

## Steps

1. Parse the user's request to extract the member name and any optional library/file/environment overrides.
2. Detect the platform and run the appropriate script from the project root:

   **Windows:**
   ```
   pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 <MEMBER> [-Library LIB] [-File FILE] [-Environment ENV]
   ```

   **Linux / macOS / WSL:**
   ```
   bash bin/cpysrc.sh <MEMBER> [-l LIB] [-f FILE] [-e ENV]
   ```
3. Show the full output to the user.
4. If the download failed, summarise the error and suggest a fix (e.g., member not found, object in use).
