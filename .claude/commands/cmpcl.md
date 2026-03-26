Compile a CL program on IBM i.

The user will provide a program name and optional overrides.

## Script reference

```
compile-cl.ps1 -Pgm <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR] [-IleCl]

  -Pgm          Program name (required)
  -Environment  Environment name from config (default: default env)
  -Library      Library override (default: from config)
  -SrcMbr       Source member (default: {Pgm})
  -IleCl        Use CRTBNDCL instead of CRTCLPGM (for .clle source)
```

## Steps

1. Parse the user's request to extract the program name and any optional overrides.
   - If the source file has a `.clle` extension or the user mentions ILE CL, add `-IleCl`.
2. Run the script from the project root:

   ```
   pwsh -ExecutionPolicy Bypass -File bin/compile-cl.ps1 -Pgm <NAME> [-Environment ENV] [-Library LIB] [-SrcMbr MBR] [-IleCl]
   ```

3. Show the full output to the user.
4. If compilation failed, summarise the error and suggest a fix.
