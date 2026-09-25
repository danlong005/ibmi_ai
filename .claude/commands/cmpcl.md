Compile a CL program on IBM i.

The user will provide a program name and optional overrides.

## Platform

- **Linux / macOS / WSL:** run `bin/compile-cl.sh` with Bash (requires `jq`, `openssl`, `expect`).
- **Windows:** run `bin/compile-cl.ps1` with PowerShell 7 (`pwsh`, requires PuTTY).

The two scripts use different flag names — translate the user's arguments to the style of the script you run.

## Script reference

| Meaning | Bash | PowerShell | Default |
|---------|------|------------|---------|
| Program name | `<NAME>` (positional) | `-Pgm NAME` | required |
| Environment | `-e ENV` | `-Environment ENV` | default env from config |
| Library | `-l LIB` | `-Library LIB` | from config |
| Source member | `-s MBR` | `-SrcMbr MBR` | `{NAME}` |
| Use CRTBNDCL (ILE CL) | `--ile` | `-IleCl` | off (CRTCLPGM) |

## Steps

1. Parse the user's request to extract the program name and any optional overrides.
   - If the source file has a `.clle` extension or the user mentions ILE CL, add the ILE flag.
2. Run the script from the project root:

   **Linux / macOS / WSL:**
   ```bash
   bash bin/compile-cl.sh <NAME> [-e ENV] [-l LIB] [-s MBR] [--ile]
   ```

   **Windows:**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File bin/compile-cl.ps1 -Pgm <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR] [-IleCl]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
