Compile a bound RPG or SQLRPGLE program on IBM i.

The user will provide a program name and optional overrides.

## Script reference

```
compile-pgm.ps1 -Pgm <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR] [-BndDir DIR] [-SqlPgm]

  -Pgm          Program name (required)
  -Environment  Environment name from config (default: default env)
  -Library      Library override (default: from config)
  -SrcMbr       Source member (default: {Pgm})
  -BndDir       Binding directory (e.g. UTILBD)
  -SqlPgm       Use CRTSQLRPGI instead of CRTBNDRPG (for SQLRPGLE source)
```

## Steps

1. Parse the user's request to extract the program name and any optional overrides.
   - If the source file has a `.sqlrpgle` extension or the user mentions embedded SQL, add `-SqlPgm`.
2. Run the script from the project root:

   ```
   pwsh -ExecutionPolicy Bypass -File bin/compile-pgm.ps1 -Pgm <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR] [-BndDir DIR] [-SqlPgm]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
