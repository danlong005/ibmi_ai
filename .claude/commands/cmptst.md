Compile an RPGUnit test program on IBM i.

The user will provide a test program name and optional overrides.

## Script reference

```
compile-tst.ps1 -TstPgm <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR] [-BndSrvPgm PGM]

  -TstPgm      Test program name (required)
  -Environment Environment name from config (default: default env)
  -Library     Library override (default: from config)
  -SrcMbr      Source member (default: {TstPgm})
  -BndSrvPgm   Service program to bind against (default: {TstPgm} with _T stripped)
```

## Steps

1. Parse the user's request to extract the test program name and any optional overrides.
2. Run the script from the project root:

   ```
   pwsh -ExecutionPolicy Bypass -File bin/compile-tst.ps1 -TstPgm <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR] [-BndSrvPgm PGM]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
