# IBM i Development Toolkit

Local development tooling for IBM i (iSeries/AS400) source management. Provides PowerShell scripts to download and upload source members between your PC and IBM i, with multi-environment support and encrypted credential storage.

## Prerequisites

Scripts are available in both **PowerShell** (Windows) and **Bash** (macOS/Linux).

### PowerShell (Windows)
- **PowerShell 7 (pwsh)** — [Install from Microsoft](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)
- **PuTTY** (plink + psftp) — [Download latest](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)

### Bash (macOS/Linux)
- **jq** — `brew install jq` (macOS) or `apt install jq` (Linux)
- **openssl** — typically pre-installed
- **expect** — `brew install expect` (macOS) or `apt install expect` (Linux)

### Both
- IBM i user account with access to the target system

## Getting Started

### 1. Clone the repo

```bash
git clone <repo-url>
cd ibmi
```

### 2. Configure your first environment

Run the interactive setup wizard. It will prompt for your IBM i host, user, password, library, and other settings. Your password is encrypted and stored in `bin/.ibmi-config.json` (never committed to Git).

**PowerShell (Windows):**
```powershell
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev
```

**Bash (macOS/Linux):**
```bash
bash bin/setup-ibmi.sh -e dev
```

### 3. Accept the IBM i host key

Connect once manually so the host key is cached:

**PowerShell (Windows):**
```powershell
plink your-ibmi-host.example.com
```

**Bash (macOS/Linux):**
```bash
ssh your-ibmi-host.example.com
```

Accept the key when prompted, then close the session.

### 4. Download and upload source

**PowerShell (Windows):**
```powershell
# Download a source member to source/
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM

# Upload a source member from source/
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MYPGM
```

**Bash (macOS/Linux):**
```bash
# Download a source member to source/
bash bin/cpysrc.sh MYPGM

# Upload a source member from source/
bash bin/putsrc.sh MYPGM
```

## Multi-Environment Support

You can configure multiple environments (dev, qa, prod) with different libraries, credentials, or hosts. The default environment is used when no `-Environment` flag is provided.

**PowerShell (Windows):**
```powershell
# Add environments
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment qa
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment prod

# List configured environments
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -List

# Download from a specific environment
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM -Environment qa

# Upload to a specific environment
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MYPGM -Environment prod
```

**Bash (macOS/Linux):**
```bash
# Add environments
bash bin/setup-ibmi.sh -e dev
bash bin/setup-ibmi.sh -e qa
bash bin/setup-ibmi.sh -e prod

# List configured environments
bash bin/setup-ibmi.sh -l

# Download from a specific environment
bash bin/cpysrc.sh MYPGM -e qa

# Upload to a specific environment
bash bin/putsrc.sh MYPGM -e prod
```

See [bin/README.md](bin/README.md) for full script documentation, all parameters, and troubleshooting.

## Claude Code Skills

If you're working in [Claude Code](https://claude.com/claude-code), this repo defines skills (`.claude/skills/`) and slash commands (`.claude/commands/`) so you can drive the workflow above conversationally — ask in plain language ("download MYPGM from qa", "compile MYPGM") and Claude picks the right skill and runs the underlying script for you.

### Code-generation skills

These generate source following this repo's conventions. They don't call any scripts — they're prompt-only.

| Skill | Purpose |
|-------|---------|
| `/rpg` | Generate ILE RPG programs, service programs, modules, test programs, header files |
| `/cl` | Generate or review OPM (`.clp`) and ILE (`.clle`) CL programs |
| `/dds` | Generate or validate DDS source (PF, LF, DSPF, PRTF) |

### Script-invoking skills

These wrap the `bin/` scripts. `/cpysrc` and `/putsrc` detect Windows vs. macOS/Linux and run the matching `.ps1`/`.sh` script; the compile/test skills currently shell out to the PowerShell (`.ps1`) scripts.

| Skill | Runs |
|-------|------|
| `/cpysrc <MEMBER> [-e env]` | `bin/cpysrc.ps1` or `bin/cpysrc.sh` — download a source member |
| `/putsrc <MEMBER> [-e env]` | `bin/putsrc.ps1` or `bin/putsrc.sh` — upload a source member |
| `/cmppgm <NAME> ...` | `bin/compile-pgm.ps1` — compile a bound RPG/SQLRPGLE program |
| `/cmpcl <NAME> ...` | `bin/compile-cl.ps1` — compile a CL program |
| `/cmpdspf <NAME> ...` | `bin/compile-dspf.ps1` — compile a display file |
| `/cmpsrv <NAME> ...` | `bin/compile-srvpgm.ps1` — compile a service program |
| `/cmptst <NAME> ...` | `bin/compile-tst.ps1` — compile an RPGUnit test program |
| `/runtst <TSTPGM> ...` | `bin/run-tests.ps1` — run an RPGUnit test suite |
| `/mdtopdf <file.md>` | `bin/md_to_pdf.py` — convert a markdown file to PDF |

Each skill shows the script's full output and, on failure, summarizes the error and suggests a fix rather than just dumping the raw log.

## Project Structure

```
ibmi/
├── bin/                        # Scripts and tooling
│   ├── setup-ibmi.ps1          # Config setup wizard (PowerShell)
│   ├── setup-ibmi.sh           # Config setup wizard (Bash)
│   ├── cpysrc.ps1              # Download source member (PowerShell)
│   ├── cpysrc.sh               # Download source member (Bash)
│   ├── putsrc.ps1              # Upload source member (PowerShell)
│   ├── putsrc.sh               # Upload source member (Bash)
│   ├── compile-pgm.ps1/.sh     # Compile a bound RPG program
│   ├── compile-cl.ps1/.sh      # Compile a CL program
│   ├── compile-dspf.ps1/.sh    # Compile a display file
│   ├── compile-srvpgm.ps1/.sh  # Compile a service program
│   ├── compile-tst.ps1/.sh     # Compile an RPGUnit test program
│   ├── run-tests.ps1/.sh       # Run an RPGUnit test suite
│   ├── run-cl.ps1/.sh          # Call a CL program by name
│   ├── get-zip.ps1/.sh         # List/download .zip files from IBM i
│   ├── .ibmi-config.json       # Local config (gitignored, created by setup)
│   └── README.md               # Detailed script documentation
├── source/                     # Working source files (downloaded/edited here)
├── production_source/          # Production source reference (read-only)
│   └── ilesrc/                 # ILE source members (.rpgle, .sqlrpgle, .clle, .dspf, .pf, .lf, etc.)
├── documentation/              # Project documentation and design docs
├── test_docs/                  # Test documentation
├── .gitignore
└── README.md
```

## Source Types

| Extension | Object Type |
|-----------|-------------|
| `.rpgle` | ILE RPG program/module |
| `.sqlrpgle` | ILE RPG with embedded SQL |
| `.clle` | ILE CL program/module |
| `.clp` | OPM CL program |
| `.dspf` | Display file (5250 screens) |
| `.prtf` | Printer file |
| `.pf` | Physical file (DDS) |
| `.lf` | Logical file (DDS) |
| `.sql` | SQL DDL/DML |

## Security

- Credentials are stored locally in `bin/.ibmi-config.json` using Windows DPAPI encryption (PowerShell) or AES-256 encryption (Bash)
- The config file lives at `bin/.ibmi-config.json` and is excluded via `.gitignore`
- `source/` and `production_source/` are in `.gitignore` to prevent accidental source commits
- No plaintext passwords exist anywhere in the repository
