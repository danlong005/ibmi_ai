Compile a bound RPG or SQLRPGLE program on IBM i.

The user will provide a program name and optional overrides.

## Platform

- **Linux / macOS / WSL:** run `bin/compile-pgm.sh` with Bash (requires `jq`, `openssl`, `expect`).
- **Windows:** run `bin/compile-pgm.ps1` with PowerShell 7 (`pwsh`, requires PuTTY).

The two scripts use different flag names — translate the user's arguments to the style of the script you run.

## Script reference

| Meaning | Bash | PowerShell | Default |
|---------|------|------------|---------|
| Program name | `<NAME>` (positional) | `-Pgm NAME` | required |
| Environment | `-e ENV` | `-Environment ENV` | default env from config |
| Library | `-l LIB` | `-Library LIB` | from config |
| Source member | `-s MBR` | `-SrcMbr MBR` | `{NAME}` |
| Binding directory | `-b DIR` | `-BndDir DIR` | none |
| Use CRTSQLRPGI (SQLRPGLE) | `--sql` | `-SqlPgm` | off |

## Steps

1. Parse the user's request to extract the program name and any optional overrides.
   - If the source file has a `.sqlrpgle` extension or the user mentions embedded SQL, add the SQL flag.
2. Run the script from the project root:

   **Linux / macOS / WSL:**
   ```bash
   bash bin/compile-pgm.sh <NAME> [-e ENV] [-l LIB] [-s MBR] [-b DIR] [--sql]
   ```

   **Windows:**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File bin/compile-pgm.ps1 -Pgm <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR] [-BndDir DIR] [-SqlPgm]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
