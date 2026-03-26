Compile a service program on IBM i.

The user will provide a service program name and optional overrides.

## Script reference

```
compile-srvpgm.ps1 -SrvPgm <NAME> [-Environment ENV] [-Library LIB] [-ModuleSrc MBR] [-BndSrc MBR] [-SqlModule]

  -SrvPgm       Service program name (required)
  -Environment  Environment name from config (default: default env)
  -Library      Library override (default: from config)
  -ModuleSrc    Module source member (default: {SrvPgm})
  -BndSrc       Binder source member (default: {SrvPgm}_B)
  -SqlModule    Use CRTSQLRPGI instead of CRTRPGMOD (for source with embedded SQL)
```

## Steps

1. Parse the user's request to extract the service program name and any optional overrides.
2. Run the script from the project root:

   ```
   pwsh -ExecutionPolicy Bypass -File bin/compile-srvpgm.ps1 -SrvPgm <NAME> [-Environment ENV] [-Library LIB] [-ModuleSrc MBR] [-BndSrc MBR]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
