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
plink as400.example.com
```

**Bash (macOS/Linux):**
```bash
ssh as400.example.com
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

## Project Structure

```
ibmi/
├── bin/                        # Scripts and tooling
│   ├── setup-ibmi.ps1          # Config setup wizard (PowerShell)
│   ├── setup-ibmi.sh           # Config setup wizard (Bash)
│   ├── ibmi-common.ps1         # Shared functions (PowerShell)
│   ├── cpysrc.ps1              # Download source member (PowerShell)
│   ├── cpysrc.sh               # Download source member (Bash)
│   ├── putsrc.ps1              # Upload source member (PowerShell)
│   ├── putsrc.sh               # Upload source member (Bash)
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

## Journaling Setup

Before using the SRCEXT file, you must set up journaling in the LONGDM1 library. Run these commands on IBM i:

```
CRTJRNRCV JRNRCV(LONGDM1/JRNRCV)
CRTJRN JRN(LONGDM1/JRN) JRNRCV(LONGDM1/JRNRCV)
STRJRNPF FILE(LONGDM1/SRCEXT) JRN(LONGDM1/JRN)
```

## Security

- Credentials are stored locally in `bin/.ibmi-config.json` using Windows DPAPI encryption (PowerShell) or AES-256 encryption (Bash)
- The config file lives at `bin/.ibmi-config.json` and is excluded via `.gitignore`
- `source/` and `production_source/` are in `.gitignore` to prevent accidental source commits
- No plaintext passwords exist anywhere in the repository
