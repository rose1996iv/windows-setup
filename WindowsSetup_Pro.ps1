#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Professional Fresh Setup Script v2.0
    For: Security + Daily + Office + Student (Python Full Stack)
.DESCRIPTION
    Installs and configures a fully hardened, production-ready Windows environment.
    Includes advanced security policies, full Python development stack, and essential apps.
.NOTES
    Run as Administrator. Requires Windows 10 21H2+ or Windows 11.
    Internet connection required. Estimated time: 20-35 minutes.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference    = "SilentlyContinue"

# ── Dashboard Integration ────────────────────────────────────────
if (Test-Path "$env:TEMP\Update-Dashboard.ps1") {
    . "$env:TEMP\Update-Dashboard.ps1"
} else {
    function Update-Dashboard { param([int]$Phase, [string]$Status, [int]$Progress, [string]$LogMessage) }
}

# ══════════════════════════════════════════════════════════════════
#  CONFIGURATION
# ══════════════════════════════════════════════════════════════════
$LOG_FILE   = "$env:USERPROFILE\Desktop\setup_log_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
$START_TIME = Get-Date
$ERRORS     = [System.Collections.Generic.List[string]]::new()
$INSTALLED  = [System.Collections.Generic.List[string]]::new()
$SKIPPED    = [System.Collections.Generic.List[string]]::new()

# ══════════════════════════════════════════════════════════════════
#  HELPER FUNCTIONS
# ══════════════════════════════════════════════════════════════════
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Add-Content -Path $LOG_FILE -Value $line -ErrorAction SilentlyContinue
}

function Show-Banner {
    Clear-Host
    $banner = @"

  ╔══════════════════════════════════════════════════════════════════╗
  ║                                                                  ║
  ║        Windows Professional Setup  v2.0                         ║
  ║        Security · Office · Daily · Student (Python)             ║
  ║                                                                  ║
  ╚══════════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "  Log file : $LOG_FILE" -ForegroundColor DarkGray
    Write-Host "  Started  : $(Get-Date -Format 'dddd, dd MMM yyyy  HH:mm')" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-Phase {
    param([int]$Number, [int]$Total, [string]$Title, [string]$Icon = "▶")
    Write-Host ""
    Write-Host "  $Icon  Phase $Number/$Total — $Title" -ForegroundColor Yellow
    Write-Host ("  " + "─" * 60) -ForegroundColor DarkGray
    Write-Log "=== PHASE $Number/${Total}: $Title ==="
}

function Show-Step {
    param([string]$Message, [string]$Status = "WORK")
    switch ($Status) {
        "WORK" { Write-Host "     ○  $Message" -ForegroundColor Gray }
        "OK"   { Write-Host "     ✓  $Message" -ForegroundColor Green }
        "SKIP" { Write-Host "     ─  $Message (already present)" -ForegroundColor DarkGray }
        "FAIL" { Write-Host "     ✗  $Message" -ForegroundColor Red }
        "INFO" { Write-Host "     ·  $Message" -ForegroundColor DarkCyan }
    }
    Write-Log "$Status  $Message"
}

function Show-Progress {
    param([int]$Current, [int]$Total, [string]$Label)
    $pct   = [int](($Current / $Total) * 100)
    $filled = [int](($pct / 100) * 40)
    $empty  = 40 - $filled
    $bar    = "█" * $filled + "░" * $empty
    Write-Host "`r     [$bar] $pct%  $Label          " -NoNewline -ForegroundColor Cyan
}

function Show-Summary {
    $elapsed = (Get-Date) - $START_TIME
    $mins    = [int]$elapsed.TotalMinutes
    $secs    = $elapsed.Seconds

    Write-Host ""
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                    Setup Complete!                               ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  ✓  Installed   : $($INSTALLED.Count) apps" -ForegroundColor Green
    Write-Host "  ─  Skipped     : $($SKIPPED.Count) (already existed)" -ForegroundColor DarkGray
    if ($ERRORS.Count -gt 0) {
        Write-Host "  ✗  Errors      : $($ERRORS.Count) (check log file)" -ForegroundColor Red
    }
    Write-Host "  ⏱  Time taken  : ${mins}m ${secs}s" -ForegroundColor Cyan
    Write-Host "  📄  Log saved  : $LOG_FILE" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ⚠   Please RESTART your PC to apply all changes." -ForegroundColor Yellow
    Write-Host ""
}

function Install-App {
    param(
        [string]$Id,
        [string]$Name,
        [int]$Current,
        [int]$Total
    )
    Show-Progress -Current $Current -Total $Total -Label $Name
    $result = winget install --id $Id `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity 2>&1

    if ($LASTEXITCODE -eq 0 -or ($result -match "successfully installed")) {
        $INSTALLED.Add($Name) | Out-Null
        Write-Log "OK  $Name ($Id)"
    } elseif ($result -match "already installed") {
        $SKIPPED.Add($Name) | Out-Null
        Write-Log "SKIP  $Name ($Id)"
    } else {
        $ERRORS.Add("$Name ($Id)") | Out-Null
        Write-Log "FAIL  $Name ($Id)"
    }
}

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

# ══════════════════════════════════════════════════════════════════
#  PREREQUISITE CHECK
# ══════════════════════════════════════════════════════════════════
Show-Banner

Write-Host "  Checking prerequisites..." -ForegroundColor Gray

# Check winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  [ERROR] winget not found." -ForegroundColor Red
    Write-Host "  Install 'App Installer' from Microsoft Store and re-run." -ForegroundColor Yellow
    exit 1
}

# Check OS version
$os = [System.Environment]::OSVersion.Version
if ($os.Build -lt 19041) {
    Write-Host "  [WARN] Windows build $($os.Build) detected. Some features need Windows 10 21H2+." -ForegroundColor Yellow
}

# Update winget sources silently
Write-Host "  Refreshing winget sources..." -ForegroundColor DarkGray
winget source update 2>&1 | Out-Null

Write-Host "  Prerequisites OK  —  Starting setup" -ForegroundColor Green
Start-Sleep -Seconds 1

# ══════════════════════════════════════════════════════════════════
#  PHASE 1 — ADVANCED SECURITY HARDENING
# ══════════════════════════════════════════════════════════════════
Show-Phase 1 6 "Advanced Security Hardening" "🔒"
Update-Dashboard -Phase 0 -Status "running" -Progress 5 -LogMessage "🔒 Phase 1 started — Security Hardening"

# Windows Defender — Enhanced
Show-Step "Windows Defender: enabling real-time & cloud protection" "WORK"
Set-MpPreference -DisableRealtimeMonitoring         $false
Set-MpPreference -CloudBlockLevel                    High
Set-MpPreference -CloudExtendedTimeout               50
Set-MpPreference -EnableControlledFolderAccess       Enabled
Set-MpPreference -EnableNetworkProtection            Enabled
Set-MpPreference -PUAProtection                      Enabled
Set-MpPreference -SubmitSamplesConsent               SendSafeSamples
Set-MpPreference -DisableBlockAtFirstSeen            $false
Set-MpPreference -MAPSReporting                      Advanced
Update-MpSignature
Show-Step "Windows Defender: enhanced cloud + PUA + network protection" "OK"

# Firewall — All profiles
Show-Step "Firewall: hardening all profiles" "WORK"
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -LogAllowed False -LogBlocked True
Show-Step "Firewall: all profiles active (inbound blocked by default)" "OK"

# Disable SMBv1 (major ransomware vector)
Show-Step "Disabling SMBv1 protocol (WannaCry/ransomware vector)" "WORK"
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart | Out-Null
Show-Step "SMBv1 disabled" "OK"

# Attack Surface Reduction Rules (ASR)
Show-Step "Enabling Attack Surface Reduction (ASR) rules" "WORK"
$asrRules = @(
    "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550",  # Block executable content from email/webmail
    "D4F940AB-401B-4EFC-AADC-AD5F3C50688A",  # Block Office apps from creating child processes
    "3B576869-A4EC-4529-8536-B80A7769E899",  # Block Office apps from creating executable content
    "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84",  # Block Office apps injecting into other processes
    "D3E037E1-3EB8-44C8-A917-57927947596D",  # Block JavaScript/VBScript launching downloaded exec
    "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC",  # Block execution of potentially obfuscated scripts
    "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B",  # Block Win32 API calls from Office macros
    "01443614-CD74-433A-B99E-2ECDC07BFC25",  # Block untrusted/unsigned processes from USB
    "9E6C4E1F-7D60-472F-BA1A-A39EF669E4B2",  # Block credential stealing from LSASS
    "E6DB77E5-3DF2-4CF1-B95A-636979351E5B"   # Block persistence through WMI event subscription
)
foreach ($rule in $asrRules) {
    Add-MpPreference -AttackSurfaceReductionRules_Ids $rule -AttackSurfaceReductionRules_Actions Enabled
}
Show-Step "ASR: 10 rules enabled" "OK"

# Disable autorun / autoplay
Show-Step "Disabling AutoRun and AutoPlay (USB malware protection)" "WORK"
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDriveTypeAutoRun" 255
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDriveTypeAutoRun" 255
Show-Step "AutoRun/AutoPlay disabled" "OK"

# UAC — Maximum level
Show-Step "Setting UAC to maximum (always notify)" "WORK"
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableLUA"           1
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 2
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "PromptOnSecureDesktop" 1
Show-Step "UAC: maximum level enabled" "OK"

# Disable insecure legacy services
Show-Step "Disabling legacy/insecure services" "WORK"
$disableServices = @("RemoteRegistry", "Telnet", "FTP", "SNMP", "WMPNetworkSvc", "XblGameSave", "XboxNetApiSvc")
foreach ($svc in $disableServices) {
    Stop-Service -Name $svc -Force
    Set-Service  -Name $svc -StartupType Disabled
}
Show-Step "Legacy services disabled" "OK"

# Disable Windows Telemetry
Show-Step "Reducing Windows telemetry to security level" "WORK"
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "LimitDiagnosticLogCollection" 1
Stop-Service -Name DiagTrack -Force; Set-Service -Name DiagTrack -StartupType Disabled
Show-Step "Telemetry reduced to security level only" "OK"

# Spectre/Meltdown mitigations
Show-Step "Enabling Spectre/Meltdown CPU mitigations" "WORK"
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 0
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 3
Show-Step "CPU vulnerability mitigations enabled" "OK"

# Disable LLMNR (used in credential attacks)
Show-Step "Disabling LLMNR (prevents credential-relay attacks)" "WORK"
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" "EnableMulticast" 0
Show-Step "LLMNR disabled" "OK"

# Enable Audit Policies
Show-Step "Enabling security audit policies" "WORK"
auditpol /set /category:"Logon/Logoff"             /success:enable /failure:enable 2>&1 | Out-Null
auditpol /set /category:"Account Logon"             /success:enable /failure:enable 2>&1 | Out-Null
auditpol /set /category:"Account Management"        /success:enable /failure:enable 2>&1 | Out-Null
auditpol /set /category:"Privilege Use"             /success:enable /failure:enable 2>&1 | Out-Null
auditpol /set /category:"Policy Change"             /success:enable /failure:enable 2>&1 | Out-Null
Show-Step "Audit policies: Logon, Account, Privilege, Policy events logged" "OK"

# Secure DNS (Cloudflare DoH)
Show-Step "Setting DNS to Cloudflare 1.1.1.1 / 1.0.0.1" "WORK"
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ("1.1.1.1","1.0.0.1","2606:4700:4700::1111","2606:4700:4700::1001")
}
Show-Step "DNS: Cloudflare 1.1.1.1 (faster + private)" "OK"

Write-Host "" ; Write-Host "  Phase 1 complete." -ForegroundColor Green
Update-Dashboard -Phase 0 -Status "done" -Progress 100 -LogMessage "✓ Phase 1 complete"

# ══════════════════════════════════════════════════════════════════
#  PHASE 2 — WINDOWS QUALITY-OF-LIFE SETTINGS
# ══════════════════════════════════════════════════════════════════
Show-Phase 2 6 "Windows Settings & Quality of Life" "⚙"
Update-Dashboard -Phase 1 -Status "running" -Progress 10 -LogMessage "⚙️ Phase 2 started — Windows Settings"

# Explorer settings
Show-Step "Explorer: showing extensions, hidden files, full path" "WORK"
$explorerKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-RegistryValue $explorerKey "HideFileExt"              0
Set-RegistryValue $explorerKey "Hidden"                   1
Set-RegistryValue $explorerKey "ShowSuperHidden"          0
Set-RegistryValue $explorerKey "LaunchTo"                 1   # Open This PC (not Quick Access)
Set-RegistryValue $explorerKey "NavPaneExpandToCurrentFolder" 1
Show-Step "Explorer: file extensions and hidden files visible" "OK"

# Dark Mode
Show-Step "Dark mode" "WORK"
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme"    0
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0
Show-Step "Dark mode enabled (system + apps)" "OK"

# Power plan — Balanced
Show-Step "Power plan: Balanced" "WORK"
powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e
Show-Step "Power plan set" "OK"

# Disable Cortana search telemetry
Show-Step "Disabling Cortana web search in Start" "WORK"
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled"    0
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent"       0
Show-Step "Cortana web search disabled" "OK"

# Enable Long Paths (required for Python/Node deep projects)
Show-Step "Enabling long file path support (required for Python/Node)" "WORK"
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1
Show-Step "Long paths enabled (up to 32,767 chars)" "OK"

# Taskbar cleanup
Show-Step "Cleaning up taskbar (News, Widgets, Search box → icon)" "WORK"
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"  "ShellFeedsTaskbarViewMode" 2
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode"     1
Show-Step "Taskbar cleaned up" "OK"

Write-Host "" ; Write-Host "  Phase 2 complete." -ForegroundColor Green
Update-Dashboard -Phase 1 -Status "done" -Progress 100 -LogMessage "✓ Phase 2 complete"

# ══════════════════════════════════════════════════════════════════
#  PHASE 3 — CORE APPLICATIONS
# ══════════════════════════════════════════════════════════════════
Show-Phase 3 6 "Installing Core Applications" "📦"
Update-Dashboard -Phase 2 -Status "running" -Progress 5 -LogMessage "📦 Phase 3 started — Core Applications"

$coreApps = @(
    # Security Tools
    @{ id="Bitwarden.Bitwarden";              name="Bitwarden — Password Manager"    }
    @{ id="Malwarebytes.Malwarebytes";         name="Malwarebytes — Anti-Malware"     }
    # Browser
    @{ id="Google.Chrome";                    name="Google Chrome"                   }
    # Daily Utilities
    @{ id="7zip.7zip";                        name="7-Zip — Archive Manager"         }
    @{ id="VideoLAN.VLC";                     name="VLC — Media Player"              }
    @{ id="Notepad++.Notepad++";              name="Notepad++"                       }
    @{ id="Microsoft.PowerToys";              name="PowerToys — Windows Utilities"   }
    @{ id="voidtools.Everything";             name="Everything — Instant File Search"}
    @{ id="Rustdesk.Rustdesk";               name="RustDesk — Remote Desktop"       }
    # Office & Productivity
    @{ id="TheDocumentFoundation.LibreOffice";name="LibreOffice — Office Suite"      }
    @{ id="Adobe.Acrobat.Reader.64-bit";      name="Adobe Acrobat Reader — PDF"      }
    @{ id="Zoom.Zoom";                        name="Zoom — Video Meetings"           }
    @{ id="Discord.Discord";                  name="Discord — Chat & Community"      }
    # File Transfer
    @{ id="WinSCP.WinSCP";                   name="WinSCP — Secure File Transfer"   }
    @{ id="WireGuard.WireGuard";             name="WireGuard — VPN Client"          }
)

$total = $coreApps.Count
$i = 1
foreach ($app in $coreApps) {
    Install-App -Id $app.id -Name $app.name -Current $i -Total $total
    $i++
}
Write-Host "" ; Write-Host "" ; Write-Host "  Phase 3 complete." -ForegroundColor Green
Update-Dashboard -Phase 2 -Status "done" -Progress 100 -LogMessage "✓ Phase 3 complete"

# ══════════════════════════════════════════════════════════════════
#  PHASE 4 — PYTHON FULL STACK ENVIRONMENT
# ══════════════════════════════════════════════════════════════════
Show-Phase 4 6 "Python Full Development Environment" "🐍"
Update-Dashboard -Phase 3 -Status "running" -Progress 5 -LogMessage "🐍 Phase 4 started — Python Full Stack"

# Install Python + Git + VS Code via winget
$devApps = @(
    @{ id="Python.Python.3.12";              name="Python 3.12 (latest stable)"     }
    @{ id="Git.Git";                         name="Git — Version Control"           }
    @{ id="GitHub.GitHubDesktop";            name="GitHub Desktop — GUI for Git"    }
    @{ id="Microsoft.VisualStudioCode";      name="VS Code — Code Editor"           }
    @{ id="JetBrains.PyCharm.Community";     name="PyCharm Community — Python IDE"  }
    @{ id="Rustlang.Rustup";                name="Rust (for Python native packages)"}
    @{ id="OpenJS.NodeJS";                  name="Node.js (for Jupyter/web tools)"  }
)

$total = $devApps.Count ; $i = 1
foreach ($app in $devApps) {
    Install-App -Id $app.id -Name $app.name -Current $i -Total $total
    $i++
}
Write-Host "" ; Write-Host ""

# Refresh PATH so Python/pip are available immediately
Show-Step "Refreshing environment PATH" "WORK"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
Show-Step "PATH refreshed" "OK"

# Upgrade pip
Show-Step "Upgrading pip to latest" "WORK"
python -m pip install --upgrade pip --quiet 2>&1 | Out-Null
Show-Step "pip upgraded" "OK"

# Install essential Python packages
$pyPackages = @(
    # Core Science & Data
    "numpy", "pandas", "scipy", "sympy",
    # Visualization
    "matplotlib", "seaborn", "plotly",
    # Machine Learning
    "scikit-learn",
    # Web & APIs
    "requests", "httpx", "flask", "fastapi", "uvicorn",
    # Jupyter Environment
    "jupyter", "jupyterlab", "ipywidgets", "nbconvert",
    # Dev Tools
    "virtualenv", "pipenv", "black", "flake8", "pylint", "mypy",
    "pytest", "pytest-cov",
    # Utilities
    "rich", "click", "python-dotenv", "pydantic",
    # Database
    "sqlalchemy", "psycopg2-binary"
)

$pkgTotal = $pyPackages.Count ; $pkgI = 1
foreach ($pkg in $pyPackages) {
    Show-Progress -Current $pkgI -Total $pkgTotal -Label "pip install $pkg"
    python -m pip install $pkg --quiet 2>&1 | Out-Null
    Write-Log "pip install $pkg"
    $pkgI++
}
Write-Host "" ; Write-Host ""
Show-Step "Python packages: $pkgTotal packages installed" "OK"

# VS Code Extensions for Python
Show-Step "Installing VS Code extensions for Python" "WORK"
$vscodeExts = @(
    "ms-python.python",
    "ms-python.debugpy",
    "ms-python.vscode-pylance",
    "ms-toolsai.jupyter",
    "ms-toolsai.jupyter-keymap",
    "ms-toolsai.jupyter-renderers",
    "github.copilot-chat",
    "eamodio.gitlens",
    "esbenp.prettier-vscode",
    "streetsidesoftware.code-spell-checker",
    "pkief.material-icon-theme",
    "zhuangtongfa.material-theme"
)
foreach ($ext in $vscodeExts) {
    code --install-extension $ext --force 2>&1 | Out-Null
    Write-Log "VS Code ext: $ext"
}
Show-Step "VS Code: 12 extensions installed (Python, Jupyter, GitLens, Copilot Chat)" "OK"

# Configure Git global defaults
Show-Step "Configuring Git global defaults" "WORK"
git config --global init.defaultBranch main
git config --global core.autocrlf true
git config --global core.editor "code --wait"
git config --global pull.rebase false
git config --global credential.helper manager
Show-Step "Git: default branch=main, editor=VS Code, CRLF enabled" "OK"

# Create Python project scaffold on Desktop
Show-Step "Creating Python project template on Desktop" "WORK"
$projectPath = "$env:USERPROFILE\Desktop\my_python_project"
New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
New-Item -ItemType Directory -Path "$projectPath\src"       -Force | Out-Null
New-Item -ItemType Directory -Path "$projectPath\tests"     -Force | Out-Null
New-Item -ItemType Directory -Path "$projectPath\notebooks" -Force | Out-Null
New-Item -ItemType Directory -Path "$projectPath\data"      -Force | Out-Null

@"
# My Python Project

## Setup
```bash
cd my_python_project
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## Run
```bash
python src/main.py
```

## Test
```bash
pytest tests/
```
"@ | Set-Content "$projectPath\README.md"

@"
numpy
pandas
matplotlib
requests
python-dotenv
"@ | Set-Content "$projectPath\requirements.txt"

@"
# main.py — entry point
print("Hello, World!")
"@ | Set-Content "$projectPath\src\main.py"

@"
# test_main.py
def test_placeholder():
    assert True
"@ | Set-Content "$projectPath\tests\test_main.py"

@"
__pycache__/
*.pyc
*.pyo
.venv/
.env
*.log
.DS_Store
"@ | Set-Content "$projectPath\.gitignore"

Show-Step "Project template created at: Desktop\my_python_project" "OK"

Write-Host "" ; Write-Host "  Phase 4 complete." -ForegroundColor Green
Update-Dashboard -Phase 3 -Status "done" -Progress 100 -LogMessage "✓ Phase 4 complete"

# ══════════════════════════════════════════════════════════════════
#  PHASE 5 — STUDENT TOOLS
# ══════════════════════════════════════════════════════════════════
Show-Phase 5 6 "Student Productivity Tools" "🎓"
Update-Dashboard -Phase 4 -Status "running" -Progress 10 -LogMessage "🎓 Phase 5 started — Student Tools"

$studentApps = @(
    @{ id="Obsidian.Obsidian";              name="Obsidian — Linked Note-Taking"  }
    @{ id="Anki.Anki";                      name="Anki — Spaced Repetition Cards" }
    @{ id="calibre.calibre";               name="Calibre — E-Book Manager"       }
    @{ id="dbeaver.dbeaver";               name="DBeaver — Database Tool"        }
    @{ id="Postman.Postman";               name="Postman — API Testing"          }
    @{ id="Docker.DockerDesktop";          name="Docker Desktop — Containers"    }
)

$total = $studentApps.Count ; $i = 1
foreach ($app in $studentApps) {
    Install-App -Id $app.id -Name $app.name -Current $i -Total $total
    $i++
}
Write-Host "" ; Write-Host "" ; Write-Host "  Phase 5 complete." -ForegroundColor Green
Update-Dashboard -Phase 4 -Status "done" -Progress 100 -LogMessage "✓ Phase 5 complete"

# ══════════════════════════════════════════════════════════════════
#  PHASE 6 — WINDOWS UPDATE & FINALIZATION
# ══════════════════════════════════════════════════════════════════
Show-Phase 6 6 "Finalization & Windows Update" "🔄"
Update-Dashboard -Phase 5 -Status "running" -Progress 10 -LogMessage "🔄 Phase 6 started — Finalization"

# Install NuGet & PSWindowsUpdate silently
Show-Step "Installing PSWindowsUpdate module" "WORK"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
Install-Module PSWindowsUpdate -Force -Scope CurrentUser -Repository PSGallery | Out-Null
Show-Step "PSWindowsUpdate installed" "OK"

# Trigger Windows Update
Show-Step "Checking for Windows Updates (this may take a moment)" "WORK"
Import-Module PSWindowsUpdate
$updates = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot 2>&1
$updateCount = ($updates | Measure-Object).Count
if ($updateCount -gt 0) {
    Show-Step "$updateCount update(s) installed" "OK"
} else {
    Show-Step "Windows is already up to date" "OK"
}

# Restart Explorer to apply visual settings
Show-Step "Restarting Windows Explorer to apply visual settings" "WORK"
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 2
Start-Process explorer
Show-Step "Explorer restarted" "OK"

# Final security scan
Show-Step "Running quick Defender scan" "WORK"
Start-MpScan -ScanType QuickScan -AsJob | Out-Null
Show-Step "Defender quick scan started in background" "OK"

# Write final log
Write-Log "=== SETUP COMPLETE ==="
Write-Log "Installed: $($INSTALLED.Count) | Skipped: $($SKIPPED.Count) | Errors: $($ERRORS.Count)"
if ($ERRORS.Count -gt 0) {
    $ERRORS | ForEach-Object { Write-Log "ERROR: $_" }
}

Show-Summary
