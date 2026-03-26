Compile a display file on IBM i.

The user will provide a display file name and optional overrides.

## Script reference

```
compile-dspf.ps1 -DspF <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR]

  -DspF         Display file name (required)
  -Environment  Environment name from config (default: default env)
  -Library      Library override (default: from config)
  -SrcMbr       Source member (default: {DspF})
```

## Steps

1. Parse the user's request to extract the display file name and any optional overrides.
2. Run the script from the project root:

   ```
   pwsh -ExecutionPolicy Bypass -File bin/compile-dspf.ps1 -DspF <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
