# ⚡ Windows Professional Setup

> One PowerShell command to fully configure a fresh Windows installation.
> Security hardening · Core apps · Full Python stack · Student tools · **Real-time dashboard**.

[![CI/CD](https://github.com/rose1996iv/windows-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/rose1996iv/windows-setup/actions)
[![Deploy](https://img.shields.io/badge/Vercel-deployed-black?logo=vercel)](https://windows-setup.vercel.app)

---

## 🚀 Quick Start (One Command)

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/rose1996iv/windows-setup/main/install.ps1 | iex
```

A **live dashboard** opens at `http://localhost:9876` showing real-time progress across all 6 phases.

---

## 📊 Real-Time Dashboard

When you run the one-liner, a local web dashboard automatically launches in your browser:

- **Live progress bars** for each of the 6 phases
- **Activity log** with timestamps
- **Auto-refresh** every 2 seconds
- Runs on `localhost:9876` — no internet needed after download

---

## 📦 What Gets Installed

### 🔒 Security (Advanced Hardening)
| Feature | Details |
|---|---|
| Windows Defender | Cloud protection + PUA + Network protection |
| Firewall | All profiles active, inbound blocked by default |
| ASR Rules | 10 Attack Surface Reduction rules enabled |
| SMBv1 | Disabled (anti-ransomware) |
| UAC | Maximum level + secure desktop |
| DNS | Cloudflare 1.1.1.1 / 1.0.0.1 |
| LLMNR | Disabled (prevents credential-relay attacks) |
| Spectre/Meltdown | CPU mitigations enabled |
| Audit Logging | Logon, Account, Privilege, Policy events |
| Telemetry | Reduced to security-only level |
| **Bitwarden** | Password manager |
| **Malwarebytes** | Anti-malware scanner |

### 🌐 Browser & Daily Tools
- **Google Chrome** — browser
- **VLC** — media player
- **7-Zip** — archive manager
- **Notepad++** — text editor
- **PowerToys** — Windows utilities
- **Everything** — instant file search
- **WireGuard** — VPN client
- **RustDesk** — remote desktop

### 🏢 Office & Communication
- **LibreOffice** — Writer, Calc, Impress (free Office suite)
- **Adobe Acrobat Reader** — PDF viewer
- **Zoom** — video meetings
- **Discord** — chat & community
- **WinSCP** — secure file transfer

### 🐍 Python Full Stack
| Tool | Purpose |
|---|---|
| Python 3.12 | Latest stable release |
| VS Code | Code editor + 12 extensions |
| PyCharm Community | Full Python IDE |
| Git + GitHub Desktop | Version control |
| Node.js | For Jupyter/web tools |
| Rust toolchain | For native Python packages |

**pip packages (30+):**
`numpy` `pandas` `scipy` `sympy` `matplotlib` `seaborn` `plotly`
`scikit-learn` `jupyter` `jupyterlab` `ipywidgets` `flask` `fastapi`
`uvicorn` `requests` `httpx` `black` `flake8` `pylint` `mypy`
`pytest` `pytest-cov` `virtualenv` `pipenv` `rich` `click`
`python-dotenv` `pydantic` `sqlalchemy` `psycopg2-binary`

**VS Code extensions:**
`ms-python.python` `ms-python.vscode-pylance` `ms-toolsai.jupyter`
`github.copilot-chat` `eamodio.gitlens` `pkief.material-icon-theme` and more

### 🎓 Student Tools
- **Obsidian** — linked note-taking
- **Anki** — spaced repetition flashcards
- **DBeaver** — database management
- **Postman** — API testing
- **Docker Desktop** — containers
- **Calibre** — e-book manager

---

## 📁 Repo Structure

```
windows-setup/
├── index.html                       ← Vercel landing page
├── install.ps1                      ← Bootstrap launcher + dashboard
├── WindowsSetup_Pro.ps1             ← Main setup script (6 phases)
├── vercel.json                      ← Vercel deployment config
├── README.md
└── .github/
    └── workflows/
        └── ci.yml                   ← GitHub Actions CI/CD
```

---

## 🔄 CI/CD Pipeline

On every push to `main`:

1. **PowerShell Lint** — Parses `install.ps1` and `WindowsSetup_Pro.ps1` for syntax errors
2. **HTML Check** — Validates `index.html` exists and is non-empty
3. **Vercel Deploy** — Auto-deploys the landing page to production

### Required GitHub Secrets

| Secret | Source |
|---|---|
| `VERCEL_TOKEN` | Vercel → Settings → Tokens |
| `VERCEL_ORG_ID` | `.vercel/project.json` after first deploy |
| `VERCEL_PROJECT_ID` | `.vercel/project.json` after first deploy |

---

## ⚙️ Windows Settings Applied
- Dark mode (system + apps)
- File extensions visible
- Hidden files visible
- Long file path support (32,767 chars)
- Cortana web search disabled
- Balanced power plan

---

## 📋 Requirements
- Windows 10 21H2+ or Windows 11
- PowerShell (Run as Administrator)
- Internet connection
- ~25–35 minutes

---

## 📄 Log File
A detailed log is saved to your Desktop after the script completes:
`setup_log_YYYYMMDD_HHMM.txt`

---

## ⚠️ Disclaimer
This script modifies system settings and installs software. Review the scripts before running on production machines. All apps are installed via Microsoft's official `winget` package manager.

---

*Maintained by [rose1996iv](https://github.com/rose1996iv) · MIT License*
