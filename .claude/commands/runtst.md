Run an RPGUnit test suite on IBM i.

The user will provide a test program name and optional environment or library overrides.

## Script reference

```
run-tests.ps1 -TestProgram <TSTPGM> [-Environment ENV] [-Library LIB]

  -TestProgram   RPGUnit test service program name (required)
  -Environment   Environment name from config (default: default env)
  -Library       Library override (default: from config)
```

## Steps

1. Parse the user's request to extract the test program name and any optional environment or library overrides.
2. Run the script from the project root:

   ```
   pwsh -ExecutionPolicy Bypass -File bin/run-tests.ps1 -TestProgram <TSTPGM> [-Environment ENV] [-Library LIB]
   ```

3. Show the full output to the user.
4. If the test run failed, summarise which tests failed and any error messages returned.
