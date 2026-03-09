# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IBM i (iSeries/AS400) source management repository for Example Corp This is a **source sync toolkit** — not a traditional build project. Source members are edited locally and compiled on IBM i using native commands (CRTBNDRPG, CRTBNDCL, CRTDSPF, etc.).

The repository contains ~24,000 production source files and PowerShell scripts for transferring source between Windows and IBM i systems.

## Key Commands

### Source Management (PowerShell)

All scripts require PowerShell 7 (`pwsh`), not Windows PowerShell 5.1.

```powershell
# Download source member from IBM i to source/
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MBRNAME

# Upload source member from source/ to IBM i
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MBRNAME

# Target a specific environment
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MBRNAME -Environment qa
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MBRNAME -Environment prod

# Override library for a single call
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MBRNAME -Library PRODLIB

# Configure environments
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -List
```

### Compilation (on IBM i via /create skill)

Objects are compiled on IBM i using the `create` shell script at `/z/bin/create`. Use the `/create` skill to invoke compilation.

## Architecture

### Directory Layout

- **`source/`** — Working directory for downloaded/edited source files (gitignored)
- **`production_source/ilesrc/`** — Read-only production source reference (~24,000 files, gitignored)
- **`bin/`** — PowerShell tooling: `cpysrc.ps1`, `putsrc.ps1`, `setup-ibmi.ps1`, `ibmi-common.ps1`
- **`documentation/`** — Project planning docs including repository split plan
- **`test_docs/`** — Test documentation

### Environment Mapping

| Environment | IBM i Library | Purpose |
|-------------|---------------|---------|
| dev | LONGDM | Active development |
| qa | QALIB | QA testing |
| prod | PRODLIB | Production |

Config stored in `bin/.ibmi-config.json` (DPAPI-encrypted, gitignored). Host: `as400.example.com`.

### Source File Types

| Extension | Type | Compile Command |
|-----------|------|-----------------|
| `.rpgle` | ILE RPG program/module | CRTBNDRPG / CRTRPGMOD |
| `.sqlrpgle` | ILE RPG with embedded SQL | CRTSQLRPGI |
| `.clle` | ILE CL program | CRTBNDCL / CRTCLMOD |
| `.clp` | OPM CL program | CRTCLPGM |
| `.dspf` | Display file (5250 screens) | CRTDSPF |
| `.prtf` | Printer file | CRTPRTF |
| `.pf` | Physical file (DDS) | CRTPF |
| `.lf` | Logical file (DDS) | CRTLF |
| `.sql` | SQL DDL/DML | RUNSQLSTM |
| `.bnd` | Binder source | Used with CRTSRVPGM |
| `.cmd` | Command definition | CRTCMD |

### Source Workflow

1. Download source from IBM i: `/cpysrc MBRNAME`
2. Edit locally in `source/` directory
3. Upload back to IBM i: `/putsrc MBRNAME`
4. Compile on IBM i: `/create`
5. Test on IBM i

## Claude Code Skills

This repo has custom skills for IBM i development:

- **`/rpg`** — Generate ILE RPG programs, service programs, modules, headers
- **`/dds`** — Generate/validate DDS source (PF, LF, DSPF, PRTF)
- **`/cl`** — Generate CL programs (OPM .clp and ILE .clle)
- **`/cpysrc`** — Download source member from IBM i
- **`/putsrc`** — Upload source member to IBM i
- **`/create`** — Compile an ILE object on IBM i
- **`/create_test_doc`** — Generate test documentation for changes

## IBM i Coding Conventions

- **RPG**: Use fully free-format (`**free`). Prefer modern BIFs over legacy opcodes. Use `/copy` or `/include` for shared definitions.
- **CL**: Use ILE CL (`.clle`) for new programs. Use `MONMSG` for error handling.
- **DDS**: Follow standard IBM column-based format. Physical files define data; logical files define access paths/views.
- **Member names**: Uppercase, max 10 characters (IBM i object naming rules).
- **Source file**: All members stored in `ILESRC` source physical file.

## Important Notes

- `source/` and `production_source/` are gitignored — source files are not committed
- The `bin/.ibmi-config.json` contains encrypted credentials — never commit
- PuTTY (`plink`/`psftp`) is required for IBM i connectivity
- The repo is planned for future split into 16 domain-specific repositories (see `documentation/Git_Project_Split_Plan.md`)
