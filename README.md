# Windows Professional Setup

> A single PowerShell command to fully provision, harden, and equip a fresh Windows installation — with a real-time browser dashboard.

[![CI/CD](https://github.com/rose1996iv/windows-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/rose1996iv/windows-setup/actions)
[![Deploy](https://img.shields.io/badge/Vercel-deployed-black?logo=vercel)](https://windows-setup.vercel.app)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://learn.microsoft.com/en-us/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078d4?logo=windows)](https://www.microsoft.com/windows)

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Real-Time Dashboard](#real-time-dashboard)
- [The Six Phases](#the-six-phases-in-detail)
  - [Phase 1 — Security Hardening](#phase-1--advanced-security-hardening)
  - [Phase 2 — Windows Settings & QoL](#phase-2--windows-settings--quality-of-life)
  - [Phase 3 — Core Applications](#phase-3--core-applications--myanmar-input)
  - [Phase 4 — Python Full Stack](#phase-4--python-full-development-stack)
  - [Phase 5 — Student & Productivity Tools](#phase-5--student--productivity-tools)
  - [Phase 6 — Updates & Finalization](#phase-6--windows-update--finalization)
- [Requirements](#requirements)
- [Alternative Installation Methods](#alternative-installation-methods)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Repository Structure](#repository-structure)
- [CI/CD Pipeline](#cicd-pipeline)
- [FAQ](#faq)
- [Disclaimer & License](#disclaimer--license)

---

## Overview

`windows-setup` is an opinionated automation kit that turns a clean Windows 10/11 installation into a hardened, developer-ready workstation in **20–35 minutes**. The script runs in six clearly-defined phases, with progress streamed to a local web dashboard so you can monitor every step in real time.

**Design goals**

| Goal | How it is achieved |
|---|---|
| Reproducible | Every install goes through Microsoft's official `winget` package manager |
| Safe by default | Security hardening runs **before** any apps are installed |
| Transparent | All actions are logged to `~/Desktop/setup_log_YYYYMMDD_HHMM.txt` |
| Resumable-friendly | `winget` detects existing apps and skips them — re-running is safe |
| Localized | Built-in Myanmar keyboard selector (KeyMagic / Keyman) |

---

## Quick Start

### One-line install (recommended)

Open **Windows Terminal** or **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/rose1996iv/windows-setup/main/install.ps1 | iex
```

What happens next:

1. `install.ps1` checks for `winget` and downloads the main script.
2. A local HTTP dashboard starts at <http://localhost:9876> and your default browser opens to it.
3. You are asked to confirm with `Y` before any system changes are made.
4. The six phases run sequentially. During Phase 3 you are prompted to choose a Myanmar keyboard.
5. When finished, the dashboard shows 100% and a summary is printed to the console.

> **Tip:** Don't close the PowerShell window while the script runs. The dashboard depends on the same process.

---

## Real-Time Dashboard

When the bootstrap script launches, it spawns a lightweight `HttpListener` on `localhost:9876` and writes state to `%TEMP%\winsetup_dashboard.json`. The HTML page polls `/api/status` every 2 seconds.

**The dashboard shows:**

- An overall progress percentage (averaged across all 6 phases)
- Per-phase progress bars with status icons: `waiting` / `running` / `done`
- A scrolling activity log with timestamps (last 30 entries)
- Elapsed time counter

If your browser does not open automatically, navigate to <http://localhost:9876> manually.

---

## The Six Phases in Detail

### Phase 1 — Advanced Security Hardening

Runs **before** any internet-facing apps are installed, so the machine is hardened by the time apps arrive.

| Control | What it does |
|---|---|
| Windows Defender | Enables real-time + cloud protection, PUA, network protection, MAPS reporting, controlled folder access; refreshes signatures |
| Firewall | All three profiles (Domain / Public / Private) active; default inbound = **Block**, default outbound = **Allow**; logs blocked traffic |
| ASR (Attack Surface Reduction) | Enables **10** ASR rules — blocks email/web executable content, Office child processes, JavaScript-launched executables, LSASS credential theft, WMI persistence, USB untrusted binaries, etc. |
| SMBv1 | Disabled (WannaCry / EternalBlue mitigation) |
| AutoRun / AutoPlay | Disabled on all drive types (USB malware mitigation) |
| UAC | Set to maximum: `EnableLUA=1`, secure desktop prompt, always notify |
| Legacy services | Stops and disables: `RemoteRegistry`, `Telnet`, `FTP`, `SNMP`, `WMPNetworkSvc`, `XblGameSave`, `XboxNetApiSvc` |
| Telemetry | Reduced to security level only (`AllowTelemetry=0`, `DiagTrack` disabled) |
| Spectre/Meltdown | CPU mitigations enabled via `FeatureSettingsOverride` |
| LLMNR | Disabled — closes a common credential-relay vector |
| Audit Policy | `Logon/Logoff`, `Account Logon`, `Account Management`, `Privilege Use`, `Policy Change` all set to success+failure |
| DNS | Cloudflare DoH-friendly resolvers (`1.1.1.1`, `1.0.0.1`, IPv6 equivalents) on all up adapters |
| Security apps | Bitwarden, Malwarebytes |

### Phase 2 — Windows Settings & Quality of Life

Targets the friction points every developer hits on a fresh install.

| Setting | Value |
|---|---|
| File extensions | **Visible** |
| Hidden files | **Visible** |
| Explorer launch target | This PC (not Quick Access) |
| Long path support | **Enabled** (32,767 characters — required for Python/Node deep trees) |
| Dark mode | System + apps |
| Power plan | Balanced |
| Cortana web search | Disabled |
| Taskbar | News/Widgets hidden, search collapsed to icon |

### Phase 3 — Core Applications + Myanmar Input

All apps installed silently via `winget`. Skipped if already present.

**Daily utilities & browser**

| App | winget ID | Purpose |
|---|---|---|
| Google Chrome | `Google.Chrome` | Browser |
| 7-Zip | `7zip.7zip` | Archive manager |
| VLC | `VideoLAN.VLC` | Media player |
| Notepad++ | `Notepad++.Notepad++` | Text editor |
| PowerToys | `Microsoft.PowerToys` | FancyZones, PowerRename, Color Picker, etc. |
| Everything | `voidtools.Everything` | Instant file search |
| RustDesk | `Rustdesk.Rustdesk` | Open-source remote desktop |
| WireGuard | `WireGuard.WireGuard` | Modern VPN client |
| WinSCP | `WinSCP.WinSCP` | SFTP/SCP/FTP file transfer |

**Office & communication**

| App | winget ID | Purpose |
|---|---|---|
| LibreOffice | `TheDocumentFoundation.LibreOffice` | Writer, Calc, Impress |
| Acrobat Reader | `Adobe.Acrobat.Reader.64-bit` | PDF viewing |
| Zoom | `Zoom.Zoom` | Video meetings |
| Discord | `Discord.Discord` | Chat |

**Myanmar Keyboard Selector** *(new — interactive prompt)*

After core apps are installed, Phase 3 presents this menu:

```
╔══════════════════════════════════════════════╗
║     Myanmar Keyboard Input — Select One      ║
╠══════════════════════════════════════════════╣
║  [1]  KeyMagic   (lightweight, open source)  ║
║  [2]  Keyman     (feature-rich, Unicode)     ║
║  [3]  Both       (install both)              ║
║  [S]  Skip       (install neither)           ║
╚══════════════════════════════════════════════╝
```

| Key | Action | winget ID |
|---|---|---|
| `1` | Install **KeyMagic** only | `KeyMagic.KeyMagic` |
| `2` | Install **Keyman** only | `SIL.Keyman` |
| `3` | Install **both** | both of the above |
| `S` | Skip — install neither | — |

The selection is logged and surfaced in the Phase 3 dashboard line as `Myanmar keyboard: KeyMagic` (or the chosen option).

> Press `S` if you are setting up a non-Burmese machine. You can run `winget install KeyMagic.KeyMagic` later if you change your mind.

### Phase 4 — Python Full Development Stack

The flagship phase. Installs the language, IDEs, version control, and ~30 packages in one shot.

**Toolchain**

| Tool | winget ID | Notes |
|---|---|---|
| Python 3.12 | `Python.Python.3.12` | Latest stable; pip auto-upgraded |
| Git | `Git.Git` | Configured with sensible defaults |
| GitHub Desktop | `GitHub.GitHubDesktop` | GUI option |
| VS Code | `Microsoft.VisualStudioCode` | Plus 12 extensions |
| PyCharm Community | `JetBrains.PyCharm.Community` | Full IDE option |
| Node.js | `OpenJS.NodeJS` | For Jupyter widgets, web tools |
| Rust toolchain | `Rustlang.Rustup` | Required by some native Python packages (`cryptography`, `polars`, etc.) |

**pip packages** *(installed with `--quiet`, individual failures logged)*

```text
Data:           numpy pandas scipy sympy
Visualization:  matplotlib seaborn plotly
ML:             scikit-learn
Web/APIs:       requests httpx flask fastapi uvicorn
Notebooks:      jupyter jupyterlab ipywidgets nbconvert
Dev tools:      virtualenv pipenv black flake8 pylint mypy pytest pytest-cov
Utilities:      rich click python-dotenv pydantic
Database:       sqlalchemy psycopg2-binary
```

**VS Code extensions installed**

`ms-python.python` · `ms-python.debugpy` · `ms-python.vscode-pylance` · `ms-toolsai.jupyter` · `ms-toolsai.jupyter-keymap` · `ms-toolsai.jupyter-renderers` · `github.copilot-chat` · `eamodio.gitlens` · `esbenp.prettier-vscode` · `streetsidesoftware.code-spell-checker` · `pkief.material-icon-theme` · `zhuangtongfa.material-theme`

**Git defaults applied**

```
init.defaultBranch = main
core.autocrlf      = true
core.editor        = code --wait
pull.rebase        = false
credential.helper  = manager
```

**Project scaffold created at `~/Desktop/my_python_project/`**

```
my_python_project/
├── src/
│   └── main.py
├── tests/
│   └── test_main.py
├── notebooks/
├── data/
├── requirements.txt    (numpy, pandas, matplotlib, requests, python-dotenv)
├── .gitignore          (.venv, __pycache__, .env, *.log, *.pyc)
└── README.md           (setup + run + test instructions)
```

To start using it:

```powershell
cd $env:USERPROFILE\Desktop\my_python_project
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python src\main.py
```

### Phase 5 — Student & Productivity Tools

| App | winget ID | Purpose |
|---|---|---|
| Obsidian | `Obsidian.Obsidian` | Markdown-based linked note-taking |
| Anki | `Anki.Anki` | Spaced-repetition flashcards |
| Calibre | `calibre.calibre` | E-book library and converter |
| DBeaver | `dbeaver.dbeaver` | Universal database client (Postgres/MySQL/SQLite/…) |
| Postman | `Postman.Postman` | REST/GraphQL API testing |
| Docker Desktop | `Docker.DockerDesktop` | Container runtime (requires WSL2 — installs prompt if missing) |

### Phase 6 — Windows Update & Finalization

| Step | What happens |
|---|---|
| `PSWindowsUpdate` | NuGet provider + module installed silently |
| Windows Updates | Fetches and installs available updates with `-IgnoreReboot` |
| Explorer restart | Recycles `explorer.exe` to apply Phase 2 visual settings |
| Defender Quick Scan | Started as a background job |
| Summary | Counts of installed / skipped / errors, elapsed time, log path |
| Reboot prompt | Displays "Please RESTART your PC to apply all changes" |

---

## Requirements

| Item | Minimum |
|---|---|
| OS | Windows 10 21H2 (build 19041+) or Windows 11 |
| Privileges | Administrator |
| Package manager | `winget` (App Installer — pre-installed on Win11; install from Microsoft Store on Win10) |
| Disk space | ~10 GB free recommended (apps + Python packages) |
| Network | Reliable broadband (the script downloads ~3–5 GB of installers + packages) |
| Time | 20–35 minutes typical, depending on connection |

### Checking prerequisites manually

```powershell
# 1. Confirm winget is present
winget --version

# 2. Confirm you are elevated
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")

# 3. Confirm execution policy allows the script
Get-ExecutionPolicy
# If "Restricted", run: Set-ExecutionPolicy Bypass -Scope Process -Force
```

---

## Alternative Installation Methods

### A. Clone and run locally

If you want to read or modify the script before running it:

```powershell
git clone https://github.com/rose1996iv/windows-setup.git
cd windows-setup
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install.ps1
```

### B. Run the main script directly (no dashboard)

Skip the bootstrap and dashboard layer:

```powershell
git clone https://github.com/rose1996iv/windows-setup.git
cd windows-setup
.\WindowsSetup_Pro.ps1
```

You will still get the console output and log file, but no browser dashboard.

### C. Run individual phases

Open `WindowsSetup_Pro.ps1` in VS Code, comment out the phases you don't need (search for `# PHASE 1`, `# PHASE 2`, …), and run the script. Each phase is self-contained.

---

## Customization

The script is designed to be forked. Common edits:

### Add or remove apps

Edit the `$coreApps`, `$devApps`, or `$studentApps` arrays in `WindowsSetup_Pro.ps1`:

```powershell
$coreApps = @(
    @{ id="Google.Chrome";  name="Google Chrome" }
    @{ id="Mozilla.Firefox"; name="Firefox" }    # ← added
    # remove a line to skip an app
)
```

Find a `winget` ID with:

```powershell
winget search "<app name>"
```

### Adjust Python packages

Edit the `$pyPackages` array (around line 410):

```powershell
$pyPackages = @(
    "numpy", "pandas",
    "torch",         # ← add PyTorch
    "polars"         # ← add Polars
)
```

### Change DNS servers

In Phase 1, find the `Set-DnsClientServerAddress` call and replace the IPs:

```powershell
# Default: Cloudflare
"1.1.1.1","1.0.0.1"
# Alternative: Google
"8.8.8.8","8.8.4.4"
# Alternative: Quad9 (security-filtering)
"9.9.9.9","149.112.112.112"
```

### Skip the security phase

If you only want apps and not the hardening, comment out the entire **PHASE 1** block (lines starting at `Show-Phase 1 6 "Advanced Security Hardening"`).

### Add a new keyboard layout

Extend `Select-MyanmarKeyboard` or create a similar `Select-<Language>Keyboard` function. Look up the winget ID with `winget search keyboard`.

---

## Troubleshooting

### `winget` not found

Install **App Installer** from the Microsoft Store (the script will open the page for you), then re-run.

### "Running scripts is disabled on this system"

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

Then re-run the one-liner. This only affects the current PowerShell session.

### The dashboard doesn't open

Manually open <http://localhost:9876>. If the port is busy:

```powershell
Get-NetTCPConnection -LocalPort 9876 | Select-Object OwningProcess
Stop-Process -Id <pid> -Force
```

Or edit `$DASH_PORT` in `install.ps1` to a free port.

### A specific app fails to install

Check the log file on your Desktop (`setup_log_YYYYMMDD_HHMM.txt`). Failures are recorded as `FAIL  <name> (<winget id>)`. Try installing manually:

```powershell
winget install --id <winget-id> --silent --accept-package-agreements --accept-source-agreements
```

### Phase 6 hangs on Windows Update

`Get-WindowsUpdate` can take several minutes on a fresh install with months of updates queued. The dashboard log keeps streaming — give it time. To skip, press `Ctrl+C`; the script will exit but apps already installed will remain.

### Group Policy blocks security changes

In a domain-joined / managed environment, Group Policy will override registry-based hardening. Run on personal machines or coordinate with your IT team.

---

## Repository Structure

```
windows-setup/
├── install.ps1                   ← Bootstrap launcher + dashboard server
├── WindowsSetup_Pro.ps1          ← Main setup script (6 phases)
├── index.html                    ← Public landing page (Vercel)
├── vercel.json                   ← Vercel build/route config
├── README.md
└── .github/
    └── workflows/
        └── ci.yml                ← GitHub Actions: lint + deploy
```

| File | Role |
|---|---|
| `install.ps1` | Downloaded by the one-liner; verifies prerequisites, starts the HTTP dashboard, fetches and runs the main script, cleans up after |
| `WindowsSetup_Pro.ps1` | The six-phase setup logic — runs on the user's machine |
| `index.html` | Marketing/landing page showing the one-liner and feature list |
| `vercel.json` | Static deploy config (serves `index.html` at the root) |

---

## CI/CD Pipeline

Every push to `main` triggers `.github/workflows/ci.yml`:

| Job | Runs on | What it checks |
|---|---|---|
| `lint-powershell` | `windows-latest` (pwsh) | Parses both `.ps1` files with `[Parser]::ParseFile` using a typed `List[ParseError]`; fails the build on any syntax error |
| `lint-html` | `ubuntu-latest` | Confirms `index.html` exists and is non-empty |
| `deploy` | `ubuntu-latest` | Runs **only after both lint jobs pass**. Installs the Vercel CLI and ships `index.html` to production via `vercel deploy --prod --token=$VERCEL_TOKEN --yes` |

### Required GitHub Secrets

| Secret | Where to get it |
|---|---|
| `VERCEL_TOKEN` | Vercel → Account Settings → Tokens → Create |
| `VERCEL_ORG_ID` | Run `vercel link` locally, then read `.vercel/project.json` |
| `VERCEL_PROJECT_ID` | Same `.vercel/project.json` |

Set them at <https://github.com/rose1996iv/windows-setup/settings/secrets/actions>.

---

## FAQ

**Q. Is it safe to run on my main computer?**
The script is open and auditable — read both `install.ps1` and `WindowsSetup_Pro.ps1` before running. It installs only well-known apps via Microsoft's `winget` and applies documented security policies. That said, system-wide changes are non-trivial; run on a fresh install or a snapshotted VM first if you're unsure.

**Q. Can I re-run it?**
Yes. `winget` detects already-installed apps and marks them as `SKIP`. Registry-based settings are idempotent. The Myanmar keyboard prompt will appear again — choose `S` to skip if you've already installed your preferred layout.

**Q. Does it work on Windows Server?**
Untested. Several cmdlets (`Set-MpPreference`, `Get-NetAdapter` filters) behave differently on Server SKUs. Most apps will install, but security hardening may need adjustment.

**Q. Does it remove bloatware (Candy Crush, Xbox apps, etc.)?**
Not currently. The script disables a few Xbox **services** but does not uninstall pre-installed UWP apps. A debloat phase is on the roadmap.

**Q. What languages does the Myanmar keyboard selector support?**
KeyMagic and Keyman both support Unicode Burmese (and many other scripts in Keyman's case). Switching layouts after install: **Settings → Time & language → Language → Add a language → Burmese**.

**Q. Can I run this without internet?**
No — `winget` fetches installers from Microsoft and vendor CDNs. The dashboard itself does not need internet once `install.ps1` has downloaded the main script.

---

## Disclaimer & License

> **This script modifies system settings, registry keys, security policies, and installs software with administrator privileges.** Review both `.ps1` files before running, especially on machines with existing data or in managed/corporate environments.

All third-party software is installed via Microsoft's official `winget` package manager from the vendor's published source. No bundled binaries are distributed by this repository.

Licensed under the [MIT License](LICENSE). Use at your own risk.

---

*Maintained by [rose1996iv](https://github.com/rose1996iv) · Issues and pull requests welcome.*
