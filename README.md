# IBM i Development Toolkit

Local development tooling for IBM i (iSeries/AS400) source management. Provides PowerShell scripts to download and upload source members between your PC and IBM i, with multi-environment support and encrypted credential storage.

## Prerequisites

- **PowerShell 7 (pwsh)** — [Install from Microsoft](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)
- **PuTTY** (plink + psftp) — [Download latest](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
- IBM i user account with access to the target system

## Getting Started

### 1. Clone the repo

```bash
git clone <repo-url>
cd ibmi
```

### 2. Configure your first environment

Run the interactive setup wizard. It will prompt for your IBM i host, user, password, library, and other settings. Your password is encrypted with Windows DPAPI and stored in `bin/ibmi-config.json` (never committed to Git).

```powershell
pwsh -ExecutionPolicy Bypass -File bin/setup-ibmi.ps1 -Environment dev
```

### 3. Accept the IBM i host key

Connect once manually so PuTTY caches the host key:

```powershell
plink as400e.pplsi.com
```

Accept the key when prompted, then close the session.

### 4. Download and upload source

```powershell
# Download a source member to source/
pwsh -ExecutionPolicy Bypass -File bin/cpysrc.ps1 MYPGM

# Upload a source member from source/
pwsh -ExecutionPolicy Bypass -File bin/putsrc.ps1 MYPGM
```

## Multi-Environment Support

You can configure multiple environments (dev, qa, prod) with different libraries, credentials, or hosts. The default environment is used when no `-Environment` flag is provided.

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

See [bin/README.md](bin/README.md) for full script documentation, all parameters, and troubleshooting.

## Project Structure

```
ibmi/
├── bin/                        # PowerShell scripts and tooling
│   ├── setup-ibmi.ps1          # Interactive config setup wizard
│   ├── ibmi-common.ps1         # Shared functions (config loader, remote commands)
│   ├── cpysrc.ps1              # Download source member from IBM i
│   ├── putsrc.ps1              # Upload source member to IBM i
│   ├── ibmi-config.json        # Local config (gitignored, created by setup)
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

- Credentials are stored locally in `bin/ibmi-config.json` using Windows DPAPI encryption
- The config file lives at `bin/ibmi-config.json` and is excluded via `.gitignore`
- `source/` and `production_source/` are in `.gitignore` to prevent accidental source commits
- No plaintext passwords exist anywhere in the repository
