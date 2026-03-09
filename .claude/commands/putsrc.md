Upload a local source file to IBM i.

The user will provide a member name. The script finds the file in the `source/` directory, uploads it via SFTP, and copies it into the source physical file on IBM i using CPYFRMSTMF.

## Platform detection

Detect the platform by checking the environment. Use `win32` platform detection (or check if `pwsh` and PuTTY are available) to decide:

- **Windows (win32):** Use the PowerShell script `bin/putsrc.ps1`
- **Linux / macOS / WSL:** Use the bash script `bin/putsrc.sh`

## Script reference

### Windows (PowerShell)
```
putsrc.ps1 <MEMBER> [-Library LIBRARY] [-File SRCFILE] [-Environment ENV]

  MEMBER        Source member name (required, first positional parameter)
  -Library      Target library (default: from config)
  -File         Source physical file (default: ILESRC)
  -Environment  Environment name from config (default: default env)
```

### Linux / macOS / WSL (Bash)
```
putsrc.sh <MEMBER> [-l LIBRARY] [-f SRCFILE] [-e ENV]

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
   pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 <MEMBER> [-Library LIB] [-File FILE] [-Environment ENV]
   ```

   **Linux / macOS / WSL:**
   ```
   bash bin/putsrc.sh <MEMBER> [-l LIB] [-f FILE] [-e ENV]
   ```
3. Show the full output to the user.
4. If the upload failed, summarise the error and suggest a fix (e.g., object in use, member not found locally).
