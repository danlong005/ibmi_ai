# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IBM i (iSeries/AS400) source management repository. This is a **source sync toolkit** — not a traditional build project. Source members are edited locally and compiled on IBM i using native commands (CRTBNDRPG, CRTBNDCL, CRTDSPF, etc.).

The repository contains ~24,000 production source files and scripts (PowerShell for Windows, Bash for macOS/Linux) for transferring source between local machines and IBM i systems.

## Key Commands

### Source Management (PowerShell — Windows)

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
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MBRNAME -Library YOURLIB

# Configure environments
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -List
```

### Source Management (Bash — macOS/Linux)

Requires `jq`, `openssl`, and `expect` (`brew install jq openssl expect`). Uses `ssh`/`sftp` instead of PuTTY. Shares the same `bin/.ibmi-config.json` as the PowerShell scripts, but each platform encrypts the password with its own key — run the setup script matching the platform you're on.

```bash
# Download / upload source member
bash bin/cpysrc.sh MBRNAME
bash bin/putsrc.sh MBRNAME

# Target a specific environment
bash bin/cpysrc.sh MBRNAME -e qa
bash bin/putsrc.sh MBRNAME -e prod

# Override library for a single call
bash bin/cpysrc.sh MBRNAME -l YOURLIB

# Configure environments
bash bin/setup-ibmi.sh -e dev
bash bin/setup-ibmi.sh -l
```

### Compilation

Objects are compiled on IBM i over SSH using the `bin/compile-*.ps1` / `bin/compile-*.sh` scripts (bound RPG programs, CL programs, display files, service programs, RPGUnit test programs), plus `bin/run-tests.ps1`/`.sh` to run a compiled RPGUnit suite. See `bin/README.md` for full parameters. Example:

```bash
bash bin/compile-pgm.sh MBRNAME -e dev
bash bin/run-tests.sh MBRNAME_T -e dev
```

## Architecture

### Directory Layout

- **`source/`** — Working directory for downloaded/edited source files (gitignored)
- **`production_source/ilesrc/`** — Read-only production source reference (~24,000 files, gitignored)
- **`bin/`** — PowerShell (`.ps1`) and Bash (`.sh`) tooling: `setup-ibmi`, `cpysrc`, `putsrc`, `compile-pgm`, `compile-cl`, `compile-dspf`, `compile-srvpgm`, `compile-tst`, `run-tests`, `run-cl`, `get-zip`
- **`documentation/`** — Project planning docs including repository split plan
- **`test_docs/`** — Test documentation

### Environment Mapping

Environments (dev, qa, prod, etc.) are user-defined and map to IBM i libraries via `bin/.ibmi-config.json` — see `bin/setup-ibmi.ps1 -List` / `bin/setup-ibmi.sh -l` for what's configured locally. Example mapping:

| Environment | IBM i Library | Purpose |
|-------------|---------------|---------|
| dev | DEVLIB | Active development |
| qa | QALIB | QA testing |
| prod | PRODLIB | Production |

Config stored in `bin/.ibmi-config.json` (encrypted, gitignored) — host, user, and library are all set per-environment via the setup script, not hardcoded.

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
4. Compile on IBM i: `bash bin/compile-pgm.sh MBRNAME` (or the matching `compile-*` script for the object type)
5. Test on IBM i: `bash bin/run-tests.sh MBRNAME_T` (RPGUnit)

## Claude Code Skills

This repo has custom skills for IBM i development:

- **`/rpg`** — Generate ILE RPG programs, service programs, modules, headers
- **`/dds`** — Generate/validate DDS source (PF, LF, DSPF, PRTF)
- **`/cl`** — Generate CL programs (OPM .clp and ILE .clle)
- **`/cpysrc`** — Download source member from IBM i
- **`/putsrc`** — Upload source member to IBM i

Compiling and testing are done via the `bin/compile-*` and `bin/run-tests` scripts directly (see Compilation above), not through a skill.

## IBM i Coding Conventions

- **RPG**: Use fully free-format (`**free`). Prefer modern BIFs over legacy opcodes. Use `/copy` or `/include` for shared definitions.
- **CL**: Use ILE CL (`.clle`) for new programs. Use `MONMSG` for error handling.
- **DDS**: Follow standard IBM column-based format. Physical files define data; logical files define access paths/views.
- **Member names**: Uppercase, max 10 characters (IBM i object naming rules).
- **Source file**: All members stored in `ILESRC` source physical file.

## Source Reference

- When looking up source code, check `source/` first (active working files). If not found there, reference `production_source/ilesrc/` as a read-only fallback.
- Do NOT download source from IBM i unless explicitly told to.

## Important Notes

- `source/` and `production_source/` are gitignored — source files are not committed
- The `bin/.ibmi-config.json` contains encrypted credentials — never commit
- PuTTY (`plink`/`psftp`) is required for IBM i connectivity on Windows; `ssh`/`sftp`/`expect` on macOS/Linux
- The repo is planned for future split into 16 domain-specific repositories (see `documentation/Git_Project_Split_Plan.md`)
