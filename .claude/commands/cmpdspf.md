Compile a display file on IBM i.

The user will provide a display file name and optional overrides.

## Platform

- **Linux / macOS / WSL:** run `bin/compile-dspf.sh` with Bash (requires `jq`, `openssl`, `expect`).
- **Windows:** run `bin/compile-dspf.ps1` with PowerShell 7 (`pwsh`, requires PuTTY).

The two scripts use different flag names — translate the user's arguments to the style of the script you run.

## Script reference

| Meaning | Bash | PowerShell | Default |
|---------|------|------------|---------|
| Display file name | `<NAME>` (positional) | `-DspF NAME` | required |
| Environment | `-e ENV` | `-Environment ENV` | default env from config |
| Library | `-l LIB` | `-Library LIB` | from config |
| Source member | `-s MBR` | `-SrcMbr MBR` | `{NAME}` |

## Steps

1. Parse the user's request to extract the display file name and any optional overrides.
2. Run the script from the project root:

   **Linux / macOS / WSL:**
   ```bash
   bash bin/compile-dspf.sh <NAME> [-e ENV] [-l LIB] [-s MBR]
   ```

   **Windows:**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File bin/compile-dspf.ps1 -DspF <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
