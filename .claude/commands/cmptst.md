Compile an RPGUnit test program on IBM i.

The user will provide a test program name and optional overrides.

## Platform

- **Linux / macOS / WSL:** run `bin/compile-tst.sh` with Bash (requires `jq`, `openssl`, `expect`).
- **Windows:** run `bin/compile-tst.ps1` with PowerShell 7 (`pwsh`, requires PuTTY).

The two scripts use different flag names — translate the user's arguments to the style of the script you run.

## Script reference

| Meaning | Bash | PowerShell | Default |
|---------|------|------------|---------|
| Test program name | `<NAME>` (positional) | `-TstPgm NAME` | required |
| Environment | `-e ENV` | `-Environment ENV` | default env from config |
| Library | `-l LIB` | `-Library LIB` | from config |
| Source member | `-s MBR` | `-SrcMbr MBR` | `{NAME}` |
| Service program to bind | `-b SRVPGM` | `-BndSrvPgm SRVPGM` | `{NAME}` with `_T` stripped |

## Steps

1. Parse the user's request to extract the test program name and any optional overrides.
2. Run the script from the project root:

   **Linux / macOS / WSL:**
   ```bash
   bash bin/compile-tst.sh <NAME> [-e ENV] [-l LIB] [-s MBR] [-b SRVPGM]
   ```

   **Windows:**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File bin/compile-tst.ps1 -TstPgm <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR] [-BndSrvPgm SRVPGM]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
