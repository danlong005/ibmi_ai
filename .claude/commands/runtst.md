Run an RPGUnit test suite on IBM i.

The user will provide a test program name and optional overrides.

## Platform

- **Linux / macOS / WSL:** run `bin/run-tests.sh` with Bash (requires `jq`, `openssl`, `expect`).
- **Windows:** run `bin/run-tests.ps1` with PowerShell 7 (`pwsh`, requires PuTTY).

The two scripts use different flag names — translate the user's arguments to the style of the script you run.

## Script reference

| Meaning | Bash | PowerShell | Default |
|---------|------|------------|---------|
| Test program name | `<NAME>` (positional) | `-TestProgram NAME` | required |
| Environment | `-e ENV` | `-Environment ENV` | default env from config |
| Library | `-l LIB` | `-Library LIB` | from config |
| Run a single test procedure | `-p PROC` | `-TestProc PROC` | all tests |

## Steps

1. Parse the user's request to extract the test program name and any optional overrides.
2. Run the script from the project root:

   **Linux / macOS / WSL:**
   ```bash
   bash bin/run-tests.sh <NAME> [-e ENV] [-l LIB] [-p PROC]
   ```

   **Windows:**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File bin/run-tests.ps1 -TestProgram <NAME> [-Environment ENV] [-Library LIB] [-TestProc PROC]
   ```

3. Show the full output to the user.
4. If the test run failed, summarise which tests failed and any error messages returned.
