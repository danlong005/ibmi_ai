Compile a service program on IBM i.

The user will provide a service program name and optional overrides.

## Platform

- **Linux / macOS / WSL:** run `bin/compile-srvpgm.sh` with Bash (requires `jq`, `openssl`, `expect`).
- **Windows:** run `bin/compile-srvpgm.ps1` with PowerShell 7 (`pwsh`, requires PuTTY).

The two scripts use different flag names — translate the user's arguments to the style of the script you run.

## Script reference

| Meaning | Bash | PowerShell | Default |
|---------|------|------------|---------|
| Service program name | `<NAME>` (positional) | `-SrvPgm NAME` | required |
| Environment | `-e ENV` | `-Environment ENV` | default env from config |
| Library | `-l LIB` | `-Library LIB` | from config |
| Module source member | `-m MBR` | `-ModuleSrc MBR` | `{NAME}` |
| Binder source member | `-b MBR` | `-BndSrc MBR` | `{NAME}_B` |
| Binding directory | `-d DIR` | `-BndDir DIR` | none |
| Bound service program | `-p LIB/SRVPGM` | `-BndSrvPgm LIB/SRVPGM` | none |
| Use CRTSQLRPGI for the module | `--sql` | `-SqlModule` | off (CRTRPGMOD) |

## Steps

1. Parse the user's request to extract the service program name and any optional overrides.
   - If the module source has a `.sqlrpgle` extension or the user mentions embedded SQL, add the SQL flag.
2. Run the script from the project root:

   **Linux / macOS / WSL:**
   ```bash
   bash bin/compile-srvpgm.sh <NAME> [-e ENV] [-l LIB] [-m MBR] [-b MBR] [-d DIR] [-p SRVPGM] [--sql]
   ```

   **Windows:**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File bin/compile-srvpgm.ps1 -SrvPgm <NAME> [-Environment ENV] [-Library LIB] [-ModuleSrc MBR] [-BndSrc MBR] [-BndDir DIR] [-BndSrvPgm SRVPGM] [-SqlModule]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
