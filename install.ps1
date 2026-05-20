#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Professional Setup — Bootstrap Launcher + Real-Time Dashboard
    Source: https://github.com/rose1996iv/windows-setup
.DESCRIPTION
    Downloads and runs WindowsSetup_Pro.ps1 from GitHub.
    Launches a local HTTP dashboard at localhost:9876 for real-time progress monitoring.
    This is the entry point for the one-liner remote install.
#>

$ErrorActionPreference = "Stop"

# ── Config ──────────────────────────────────────────────────────────────────
$REPO_RAW      = "https://raw.githubusercontent.com/rose1996iv/windows-setup/main"
$SCRIPT        = "WindowsSetup_Pro.ps1"
$TEMP_PATH     = "$env:TEMP\$SCRIPT"
$DASH_PORT     = 9876
$DASH_LOG      = "$env:TEMP\winsetup_dashboard.json"

# ── Banner ───────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║       Windows Professional Setup  — Remote Launcher      ║" -ForegroundColor Cyan
Write-Host "  ║       github.com/rose1996iv/windows-setup                ║" -ForegroundColor Cyan
Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── TLS 1.2 (required for GitHub raw HTTPS) ─────────────────────────────────
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ── Winget prerequisite check ────────────────────────────────────────────────
Write-Host "  Checking prerequisites..." -ForegroundColor Gray
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  [ERROR] winget not found." -ForegroundColor Red
    Write-Host "  Install 'App Installer' from the Microsoft Store, then re-run." -ForegroundColor Yellow
    Write-Host "  https://apps.microsoft.com/detail/9NBLGGH4NNS1" -ForegroundColor Cyan
    Write-Host ""
    Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
    exit 1
}
Write-Host "  winget found — OK" -ForegroundColor Green

# ── Download main script ─────────────────────────────────────────────────────
Write-Host "  Downloading setup script from GitHub..." -ForegroundColor Gray
try {
    Invoke-RestMethod -Uri "$REPO_RAW/$SCRIPT" -OutFile $TEMP_PATH -UseBasicParsing
    Write-Host "  Download complete — OK" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "  [ERROR] Failed to download script." -ForegroundColor Red
    Write-Host "  Check your internet connection and try again." -ForegroundColor Yellow
    Write-Host "  Error: $_" -ForegroundColor DarkGray
    exit 1
}

# ── Verify file size (sanity check) ─────────────────────────────────────────
$fileSize = (Get-Item $TEMP_PATH).Length
if ($fileSize -lt 5000) {
    Write-Host ""
    Write-Host "  [ERROR] Downloaded file seems too small ($fileSize bytes)." -ForegroundColor Red
    Write-Host "  The GitHub URL might be wrong or the repo is private." -ForegroundColor Yellow
    Remove-Item $TEMP_PATH -Force
    exit 1
}
Write-Host "  File verified ($([math]::Round($fileSize / 1KB, 1)) KB) — OK" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════
#  REAL-TIME DASHBOARD (localhost:9876)
# ══════════════════════════════════════════════════════════════════

# Initialize dashboard state JSON
# Structure matches what dashboard.html JavaScript expects:
# d.percent, d.phase, d.installed, d.skipped, d.errors, d.done, d.log[].{time,msg,status}
$initialState = @{
    startTime = (Get-Date).ToString("o")
    phase     = 0
    percent   = 0
    step      = ""
    installed = 0
    skipped   = 0
    errors    = 0
    done      = $false
    error     = $false
    log       = @()
} | ConvertTo-Json -Depth 4
$initialState | Set-Content $DASH_LOG -Force

# Dashboard HTML (served by the HTTP listener)
$dashboardHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Windows Setup — Live Dashboard</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet">
<style>
:root {
  --bg:      #070B14;
  --bg2:     #0C1220;
  --bg3:     #111827;
  --border:  #1E293B;
  --border2: #263347;
  --text:    #E2E8F0;
  --muted:   #64748B;
  --dim:     #334155;
  --green:   #22D3A5;
  --blue:    #38BDF8;
  --purple:  #A78BFA;
  --amber:   #FCD34D;
  --red:     #F87171;
  --pink:    #F472B6;
  --mono:    'Space Mono', monospace;
  --sans:    'DM Sans', sans-serif;
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }

body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--sans);
  font-size: 14px;
  min-height: 100vh;
  overflow-x: hidden;
}

/* ── Animated grid background ── */
body::before {
  content: '';
  position: fixed;
  inset: 0;
  background-image:
    linear-gradient(rgba(56,189,248,.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(56,189,248,.03) 1px, transparent 1px);
  background-size: 40px 40px;
  pointer-events: none;
  z-index: 0;
}

/* ── Orb glow ── */
.orb {
  position: fixed;
  border-radius: 50%;
  filter: blur(80px);
  pointer-events: none;
  z-index: 0;
  animation: orbFloat 8s ease-in-out infinite;
}
.orb-1 { width:320px;height:320px;background:rgba(34,211,165,.06);top:-80px;right:10%;animation-delay:0s; }
.orb-2 { width:280px;height:280px;background:rgba(167,139,250,.05);bottom:10%;left:-60px;animation-delay:-3s; }
.orb-3 { width:200px;height:200px;background:rgba(56,189,248,.04);top:40%;right:5%;animation-delay:-5s; }
@keyframes orbFloat {
  0%,100% { transform: translateY(0) scale(1); }
  50%      { transform: translateY(-30px) scale(1.05); }
}

/* ── Layout ── */
.wrap { position: relative; z-index: 1; max-width: 1080px; margin: 0 auto; padding: 24px 20px 40px; }

/* ── Header ── */
header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 22px;
  background: rgba(12,18,32,.7);
  backdrop-filter: blur(16px);
  border: 1px solid var(--border);
  border-radius: 14px;
  margin-bottom: 20px;
  animation: fadeDown .5s ease both;
}
.header-left { display:flex; align-items:center; gap:12px; }
.pulse-ring {
  position: relative; width: 10px; height: 10px;
}
.pulse-ring::before {
  content:''; position:absolute; inset:0;
  border-radius:50%; background:var(--green);
  animation: pulseRing 2s ease-out infinite;
}
.pulse-ring::after {
  content:''; position:absolute; inset:-4px;
  border-radius:50%; border:2px solid var(--green);
  animation: pulseRing 2s ease-out infinite .4s;
  opacity:0;
}
@keyframes pulseRing {
  0%   { transform:scale(1); opacity:1; }
  100% { transform:scale(2.2); opacity:0; }
}
.header-title { font-family:var(--mono); font-size:13px; font-weight:700; color:var(--text); letter-spacing:-.3px; }
.header-sub   { font-size:11.5px; color:var(--muted); margin-top:1px; }
#statusBadge  {
  font-family:var(--mono); font-size:11px; padding:5px 14px;
  border-radius:20px; border:1px solid; transition:all .4s;
}
.badge-run  { background:rgba(34,211,165,.08);  border-color:rgba(34,211,165,.3);  color:var(--green); }
.badge-done { background:rgba(56,189,248,.08);  border-color:rgba(56,189,248,.3);  color:var(--blue); }
.badge-err  { background:rgba(248,113,113,.08); border-color:rgba(248,113,113,.3); color:var(--red); }

/* ── Notice bar ── */
#noticeBar {
  border-radius: 12px;
  padding: 13px 18px;
  margin-bottom: 16px;
  border: 1px solid;
  display: flex;
  align-items: flex-start;
  gap: 12px;
  animation: fadeDown .4s ease both .1s;
  transition: all .4s ease;
}
.notice-icon { font-size: 18px; flex-shrink: 0; margin-top: 1px; }
.notice-text { flex: 1; }
.notice-title { font-size: 13px; font-weight: 600; margin-bottom: 2px; }
.notice-desc  { font-size: 12px; line-height: 1.5; opacity: .85; }
.notice-tip   { background:rgba(252,211,77,.06);  border-color:rgba(252,211,77,.25);  color:#FCD34D; }
.notice-warn  { background:rgba(248,113,113,.06); border-color:rgba(248,113,113,.25); color:#F87171; }
.notice-info  { background:rgba(56,189,248,.06);  border-color:rgba(56,189,248,.25);  color:#38BDF8; }
.notice-done  { background:rgba(34,211,165,.06);  border-color:rgba(34,211,165,.25);  color:#22D3A5; }

/* ── Main grid ── */
.grid { display: grid; grid-template-columns: 1fr 320px; gap: 16px; }

/* ── Card ── */
.card {
  background: rgba(12,18,32,.6);
  backdrop-filter: blur(10px);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 18px 20px;
  animation: fadeUp .5s ease both;
}
.card-title {
  font-family: var(--mono);
  font-size: 10px;
  letter-spacing: 2px;
  text-transform: uppercase;
  color: var(--muted);
  margin-bottom: 16px;
}

/* ── Overall progress ── */
.progress-wrap { margin-bottom: 20px; }
.progress-meta { display:flex; justify-content:space-between; font-size:12px; color:var(--muted); margin-bottom:8px; }
.progress-meta strong { color:var(--text); }
.track {
  height: 8px; background: var(--bg3);
  border-radius: 4px; overflow: hidden;
  position: relative;
}
.track::before {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(90deg, transparent 0%, rgba(255,255,255,.04) 50%, transparent 100%);
  animation: shimmer 2s linear infinite;
}
@keyframes shimmer { 0%{transform:translateX(-100%)} 100%{transform:translateX(100%)} }
.fill {
  height: 100%;
  background: linear-gradient(90deg, var(--green), var(--blue));
  border-radius: 4px;
  transition: width .6s cubic-bezier(.4,0,.2,1);
  position: relative;
}
.fill::after {
  content:'';
  position:absolute; right:0; top:50%;
  transform:translate(50%,-50%);
  width:14px; height:14px;
  border-radius:50%;
  background:var(--blue);
  box-shadow: 0 0 10px var(--blue), 0 0 20px rgba(56,189,248,.4);
  transition: opacity .3s;
}

/* ── Phase list ── */
.phase-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-radius: 10px;
  border: 1px solid transparent;
  margin-bottom: 8px;
  transition: all .35s ease;
  position: relative;
  overflow: hidden;
}
.phase-item::before {
  content:'';
  position:absolute; left:0; top:0; bottom:0;
  width:3px; border-radius:2px;
  transition: all .3s;
}
.phase-done   { background:rgba(34,211,165,.04);  border-color:rgba(34,211,165,.15); }
.phase-done::before   { background:var(--green); }
.phase-active { background:rgba(56,189,248,.06);  border-color:rgba(56,189,248,.3); box-shadow:0 0 20px rgba(56,189,248,.08); }
.phase-active::before { background:var(--blue); }
.phase-pending{ opacity:.35; }
.phase-icon { font-size:18px; flex-shrink:0; }
.phase-body { flex:1; min-width:0; }
.phase-name { font-size:13px; font-weight:500; }
.phase-step { font-size:11px; font-family:var(--mono); margin-top:5px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.phase-step.st-dl     { color:var(--blue);   }
.phase-step.st-verify { color:var(--amber);  }
.phase-step.st-inst   { color:var(--purple); }
.phase-step.st-done   { color:var(--green);  }
.phase-step.st-skip   { color:var(--muted);  }
.phase-step.st-fail   { color:var(--red);    }
.phase-step.st-info   { color:var(--blue);   opacity:.7; }
.phase-dl-bar {
  height:3px; background:rgba(56,189,248,.15);
  border-radius:2px; margin-top:6px; overflow:hidden;
  position:relative;
}
.phase-dl-bar::after {
  content:'';
  position:absolute; left:-60%; top:0; bottom:0;
  width:60%;
  background:linear-gradient(90deg, transparent, var(--blue), transparent);
  animation: dlSweep 1.6s linear infinite;
}
@keyframes dlSweep { to { left:100%; } }
.phase-check { font-size:14px; margin-left:auto; flex-shrink:0; }

/* ── Spinner ── */
.spinner {
  width:14px; height:14px;
  border:2px solid rgba(56,189,248,.2);
  border-top-color:var(--blue);
  border-radius:50%;
  animation:spin .7s linear infinite;
  flex-shrink:0;
}
@keyframes spin { to { transform:rotate(360deg); } }

/* ── Stats ── */
.stats-grid { display:grid; grid-template-columns:1fr 1fr; gap:8px; margin-top:16px; }
.stat-card {
  background:var(--bg3); border-radius:10px;
  padding:12px 14px; text-align:center;
  border:1px solid var(--border);
}
.stat-num { font-family:var(--mono); font-size:22px; font-weight:700; }
.stat-num.c-green{color:var(--green)} .stat-num.c-red{color:var(--red)}
.stat-num.c-amber{color:var(--amber)} .stat-num.c-blue{color:var(--blue)}
.stat-lbl { font-size:11px; color:var(--muted); margin-top:3px; }

/* ── Log panel ── */
.log-panel { display:flex; flex-direction:column; }
.log-body {
  flex:1; overflow-y:auto;
  font-family:var(--mono);
  font-size:11.5px; line-height:2;
  max-height:460px;
  padding-right:4px;
}
.log-body::-webkit-scrollbar{width:3px}
.log-body::-webkit-scrollbar-track{background:transparent}
.log-body::-webkit-scrollbar-thumb{background:var(--dim);border-radius:2px}
.log-entry { display:flex; gap:8px; padding:1px 0; animation:fadeIn .2s ease; }
.log-time  { color:var(--dim); flex-shrink:0; }
.log-ok    { color:var(--green); }
.log-work  { color:var(--amber); }
.log-fail  { color:var(--red); }
.log-info  { color:var(--blue); }
.log-skip  { color:var(--muted); }
@keyframes fadeIn { from{opacity:0;transform:translateX(-4px)} to{opacity:1;transform:none} }

/* ── Current-op banner ── */
#currentOp {
  font-family:var(--mono); font-size:11px;
  padding:8px 12px; border-radius:8px;
  margin-bottom:10px;
  background:rgba(56,189,248,.06);
  border:1px solid rgba(56,189,248,.18);
  color:var(--blue);
  min-height:34px;
  display:flex; align-items:center; gap:8px;
  transition: all .3s;
  word-break:break-all;
}
#currentOp.op-dl     { background:rgba(56,189,248,.07);  border-color:rgba(56,189,248,.25);  color:var(--blue);   }
#currentOp.op-verify { background:rgba(252,211,77,.06);  border-color:rgba(252,211,77,.25);  color:var(--amber);  }
#currentOp.op-inst   { background:rgba(167,139,250,.07); border-color:rgba(167,139,250,.25); color:var(--purple); }
#currentOp.op-ok     { background:rgba(34,211,165,.05);  border-color:rgba(34,211,165,.2);   color:var(--green);  }
#currentOp.op-skip   { background:rgba(100,116,139,.05); border-color:rgba(100,116,139,.2);  color:var(--muted);  }
#currentOp.op-fail   { background:rgba(248,113,113,.06); border-color:rgba(248,113,113,.25); color:var(--red);    }
#currentOp.op-idle   { opacity:.45; }

/* ── Cursor blink ── */
.cursor {
  display:inline-block; width:7px; height:12px;
  background:var(--blue); vertical-align:-2px;
  animation:blink 1.1s infinite;
}
@keyframes blink{0%,49%{opacity:1}50%,100%{opacity:0}}

/* ── Tips ticker ── */
.tips-wrap {
  margin-top:16px;
  padding:12px 16px;
  background:rgba(167,139,250,.05);
  border:1px solid rgba(167,139,250,.2);
  border-radius:10px;
  min-height:64px;
}
.tips-label { font-size:10px; font-family:var(--mono); letter-spacing:1.5px; color:var(--purple); text-transform:uppercase; margin-bottom:6px; }
.tips-text  { font-size:12.5px; color:var(--muted); line-height:1.6; transition:all .4s; }

/* ── Done banner ── */
#doneBanner {
  display:none; margin-top:16px;
  padding:20px; text-align:center;
  border-top:1px solid var(--border);
}
#doneBanner.show { display:block; animation:fadeUp .5s ease; }
.done-title { font-size:22px; font-weight:600; margin-bottom:6px; }
.done-sub   { font-size:13px; color:var(--muted); }
.restart-pill {
  display:inline-block; margin-top:14px;
  background:rgba(34,211,165,.08);
  border:1px solid rgba(34,211,165,.25);
  color:var(--green); font-family:var(--mono);
  font-size:11.5px; padding:8px 20px; border-radius:20px;
}

/* ── Elapsed ── */
.elapsed { font-family:var(--mono); font-size:12px; color:var(--dim); text-align:right; margin-top:10px; }

/* ── Animations ── */
@keyframes fadeDown { from{opacity:0;transform:translateY(-12px)} to{opacity:1;transform:none} }
@keyframes fadeUp   { from{opacity:0;transform:translateY(12px)}  to{opacity:1;transform:none} }

@media(max-width:720px){
  .grid{grid-template-columns:1fr;}
  .log-panel{grid-row:auto;}
}
</style>
</head>
<body>

<div class="orb orb-1"></div>
<div class="orb orb-2"></div>
<div class="orb orb-3"></div>

<div class="wrap">

  <!-- Header -->
  <header>
    <div class="header-left">
      <div class="pulse-ring"></div>
      <div>
        <div class="header-title">Windows Professional Setup</div>
        <div class="header-sub">github.com/rose1996iv/windows-setup</div>
      </div>
    </div>
    <div id="statusBadge" class="badge-run">● Installing...</div>
  </header>

  <!-- Notice bar -->
  <div id="noticeBar" class="notice-tip">
    <div class="notice-icon">💡</div>
    <div class="notice-text">
      <div class="notice-title" id="noticeTitle">Getting started...</div>
      <div class="notice-desc" id="noticeDesc">Preparing your system for setup.</div>
    </div>
  </div>

  <div class="grid">

    <!-- Left: phases + stats -->
    <div>
      <div class="card" style="margin-bottom:16px;">
        <div class="card-title">Overall Progress</div>

        <div class="progress-wrap">
          <div class="progress-meta">
            <span id="progLabel">Phase <strong id="progCurrent">0</strong> / 6</span>
            <span id="progPct">0%</span>
          </div>
          <div class="track">
            <div class="fill" id="progFill" style="width:0%"></div>
          </div>
        </div>

        <div id="phaseList"></div>

        <div class="stats-grid">
          <div class="stat-card">
            <div class="stat-num c-green" id="sInstalled">0</div>
            <div class="stat-lbl">Installed</div>
          </div>
          <div class="stat-card">
            <div class="stat-num c-amber" id="sSkipped">0</div>
            <div class="stat-lbl">Skipped</div>
          </div>
          <div class="stat-card">
            <div class="stat-num c-red" id="sErrors">0</div>
            <div class="stat-lbl">Errors</div>
          </div>
          <div class="stat-card">
            <div class="stat-num c-blue" id="sElapsed">0:00</div>
            <div class="stat-lbl">Elapsed</div>
          </div>
        </div>

        <!-- Tips ticker -->
        <div class="tips-wrap">
          <div class="tips-label">💜 Did you know?</div>
          <div class="tips-text" id="tipsText">Loading tip...</div>
        </div>

        <div id="doneBanner">
          <div class="done-title">✓ Setup Complete!</div>
          <div class="done-sub">All phases finished. Your system is ready.</div>
          <div class="restart-pill">⚠ Restart your PC to apply all changes</div>
        </div>

        <div class="elapsed" id="elapsedFull">Started just now</div>
      </div>
    </div>

    <!-- Right: live log -->
    <div class="card log-panel" style="animation-delay:.1s;">
      <div class="card-title">Live Log</div>
      <div id="currentOp" class="op-idle">Waiting for setup to begin...</div>
      <div class="log-body" id="logBody">
        <div class="log-entry">
          <span class="log-time">--:--:--</span>
          <span class="log-info">Connecting to dashboard... <span class="cursor"></span></span>
        </div>
      </div>
    </div>

  </div>
</div>

<script>
// ── Config ──────────────────────────────────────────────────────
const PHASES = [
  { icon:'🔒', name:'Security Hardening' },
  { icon:'⚙️', name:'Windows Settings'   },
  { icon:'📦', name:'Core Applications'  },
  { icon:'🐍', name:'Python Environment' },
  { icon:'🎓', name:'Student Tools'      },
  { icon:'🔄', name:'Update & Finalize'  },
];

const TIPS = [
  "Bitwarden ကို install ပြီးရင် browser extension လည်း ထည့်ပါ — password autofill အဆင်ပြေမယ်",
  "Malwarebytes ကို weekly scan schedule ချပေးပါ — Settings → Scheduler",
  "VS Code မှာ Ctrl+` နဲ့ integrated terminal ဖွင့်လို့ရတယ် — PowerShell ထပ် မဖွင့်ရတော့ဘူး",
  "Obsidian မှာ Zettelkasten method သုံးကြည့်ပါ — note ချိတ်ဆက်မှု တော်သွားလိမ့်မယ်",
  "Anki flashcard မှာ image + audio ထည့်ရင် retention rate 40% ကျော် မြင့်တက်တယ်",
  "PyCharm Professional ကို student email နဲ့ JetBrains မှာ free ရနိုင်တယ်",
  "Git blame = 'ဒါ ဘယ်သူ ရေးလဲ?' — git log = 'ဘာ ဖြစ်ခဲ့လဲ?' — မှတ်ထားပါ",
  "winget upgrade --all ဆိုတဲ့ command တစ်ကြောင်းနဲ့ app အကုန် update ပြုလုပ်နိုင်တယ်",
  "Cloudflare 1.1.1.1 DNS ကို ဒီ setup မှာ set လုပ်ပြီး — browsing မြန်သွားပါမယ်",
  "Jupyter Notebook မှာ Shift+Enter = run cell, Ctrl+Enter = run without moving",
  "Python venv ကို project တိုင်းအတွက် သီးသန့် ဆောက်ပါ — package conflict မဖြစ်ဘူး",
  "WireGuard VPN ဟာ OpenVPN ထက် 3x မြန်ပြီး battery drain လည်း နည်းတယ်",
  "Docker Desktop install ပြီးရင် WSL2 backend on ထားပါ — faster performance",
  "Everything search မှာ file name ရိုက်ရုံနဲ့ တစ်ကျော့ချင်း results ထွက်တယ် — Windows Search ထက် 100x မြန်တယ်",
  "Ctrl+Shift+V နဲ့ VS Code မှာ Markdown preview တိုက်ရိုက် ကြည့်နိုင်တယ်",
];

// ── State ────────────────────────────────────────────────────────
let lastLog    = 0;
let startTime  = Date.now();
let tipIndex   = 0;
let tipTimer   = null;
let pollTimer  = null;
let isDone     = false;

const NOTICES = {
  0: { type:'info',  icon:'⚙️',  title:'System preparation',         desc:'winget updating... security hardening running soon.' },
  1: { type:'warn',  icon:'🔒',  title:'Security phase — stay online', desc:'Defender, Firewall, ASR rules being configured. Do NOT close PowerShell.' },
  2: { type:'tip',   icon:'💡',  title:'Windows settings applying',   desc:'Dark mode, Explorer settings, DNS — taking effect soon.' },
  3: { type:'info',  icon:'📦',  title:'App installation in progress', desc:'Sit back and relax. Chrome, LibreOffice, Telegram and more being installed.' },
  4: { type:'warn',  icon:'🐍',  title:'Python environment',          desc:'30+ packages downloading. May take 10–15 min. Keep internet connection stable.' },
  5: { type:'tip',   icon:'🎓',  title:'Almost there!',               desc:'Student tools installing. Obsidian, Anki, Docker, Postman...' },
  6: { type:'done',  icon:'✅',  title:'Windows Update running',      desc:'Final updates being applied. PC restart will be required.' },
};

// ── Helpers ──────────────────────────────────────────────────────
function fmtTime(ms) {
  const s = Math.floor(ms / 1000);
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}

function setNotice(type, icon, title, desc) {
  const bar = document.getElementById('noticeBar');
  bar.className = 'notice-' + type;
  document.getElementById('noticeTitle').textContent = title;
  document.getElementById('noticeDesc').textContent  = desc;
}

function rotateTip() {
  const el = document.getElementById('tipsText');
  el.style.opacity = '0';
  setTimeout(() => {
    tipIndex = (tipIndex + 1) % TIPS.length;
    el.textContent = TIPS[tipIndex];
    el.style.opacity = '1';
  }, 400);
}

function buildPhaseList(activePhase, activeStep) {
  return PHASES.map((p, i) => {
    const phaseNum = i + 1;
    const done     = phaseNum < activePhase;
    const active   = phaseNum === activePhase;
    const cls      = done ? 'phase-done' : active ? 'phase-active' : 'phase-pending';
    const check    = done   ? '<span style="color:var(--green)">✓</span>'
                   : active ? '<div class="spinner"></div>'
                   : '';
    const step     = active && activeStep
                   ? `<div class="phase-step">${activeStep}</div>` : '';
    return `
      <div class="phase-item ${cls}">
        <div class="phase-icon">${p.icon}</div>
        <div class="phase-body">
          <div class="phase-name">${p.name}</div>${step}
        </div>
        <div class="phase-check">${check}</div>
      </div>`;
  }).join('');
}

function appendLog(entries, from) {
  const body = document.getElementById('logBody');
  if (from === 0) body.innerHTML = '';
  for (let i = from; i < entries.length; i++) {
    const e = entries[i];
    const cls = e.status === 'OK'   ? 'log-ok'
              : e.status === 'FAIL' ? 'log-fail'
              : e.status === 'SKIP' ? 'log-skip'
              : e.status === 'INFO' ? 'log-info'
              : 'log-work';
    const sym = e.status === 'OK'   ? '✓'
              : e.status === 'FAIL' ? '✗'
              : e.status === 'SKIP' ? '─'
              : e.status === 'INFO' ? 'ℹ'
              : '○';
    body.innerHTML +=
      `<div class="log-entry">
         <span class="log-time">${e.time}</span>
         <span class="${cls}">${sym} ${e.msg}</span>
       </div>`;
  }
  body.scrollTop = body.scrollHeight;
}

// ── Poll ─────────────────────────────────────────────────────────
async function poll() {
  try {
    const r = await fetch('/api/progress');
    if (!r.ok) throw new Error();
    const d = await r.json();

    // Progress bar
    const pct = d.percent || 0;
    document.getElementById('progFill').style.width  = pct + '%';
    document.getElementById('progPct').textContent   = pct + '%';
    document.getElementById('progCurrent').textContent = d.phase || 0;

    // Phases
    const stepText = d.step || '';
    document.getElementById('phaseList').innerHTML =
      buildPhaseList(d.phase || 0, stepText);

    // Current-operation banner
    if (stepText) {
      const op    = document.getElementById('currentOp');
      const sc    = stepClass(stepText);
      const opCls = sc === 'st-dl'     ? 'op-dl'
                  : sc === 'st-verify' ? 'op-verify'
                  : sc === 'st-inst'   ? 'op-inst'
                  : sc === 'st-done'   ? 'op-ok'
                  : sc === 'st-fail'   ? 'op-fail'
                  : sc === 'st-skip'   ? 'op-skip'
                  : 'op-idle';
      op.className  = opCls;
      op.textContent = stepText;
    }

    // Stats
    document.getElementById('sInstalled').textContent = d.installed || 0;
    document.getElementById('sSkipped').textContent   = d.skipped   || 0;
    document.getElementById('sErrors').textContent    = d.errors    || 0;
    document.getElementById('sElapsed').textContent   = fmtTime(Date.now() - startTime);
    document.getElementById('elapsedFull').textContent =
      `Elapsed: ${fmtTime(Date.now() - startTime)}`;

    // Notice
    const n = NOTICES[d.phase] || NOTICES[0];
    const bar = document.getElementById('noticeBar');
    bar.className = 'notice-' + n.type;
    document.getElementById('noticeTitle').textContent = n.title;
    document.getElementById('noticeDesc').textContent  = n.desc;

    // Log
    if (d.log && d.log.length > lastLog) {
      appendLog(d.log, lastLog);
      lastLog = d.log.length;
    }

    // Done state
    if (d.done && !isDone) {
      isDone = true;
      clearInterval(tipTimer);
      const badge = document.getElementById('statusBadge');
      badge.className   = 'badge-done';
      badge.textContent = '✓  Complete';
      document.getElementById('doneBanner').classList.add('show');
      document.getElementById('progFill').style.background = 'linear-gradient(90deg, var(--green), var(--blue))';
      const bar = document.getElementById('noticeBar');
      bar.className = 'notice-done';
      document.getElementById('noticeTitle').textContent = '🎉 Setup finished!';
      document.getElementById('noticeDesc').textContent  =
        'All apps installed and system configured. Please restart your PC to apply all changes.';
      return;
    }

    if (d.error) {
      const badge = document.getElementById('statusBadge');
      badge.className   = 'badge-err';
      badge.textContent = '✗  Error';
      const bar = document.getElementById('noticeBar');
      bar.className = 'notice-warn';
      document.getElementById('noticeTitle').textContent = 'An error occurred';
      document.getElementById('noticeDesc').textContent  =
        'Check the log panel. Some steps may have failed. The setup will continue.';
    }

  } catch (_) {}

  if (!isDone) pollTimer = setTimeout(poll, 1500);
}

// ── Init ─────────────────────────────────────────────────────────
document.getElementById('tipsText').textContent = TIPS[0];
tipTimer = setInterval(rotateTip, 7000);

// Build initial phase list
document.getElementById('phaseList').innerHTML = buildPhaseList(0, '');

poll();
</script>
</body>
</html>
'@

# Start HTTP listener in a background job
$dashJob = Start-Job -ArgumentList $DASH_PORT, $dashboardHtml, $DASH_LOG -ScriptBlock {
    param($port, $html, $logFile)
    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$port/")
    try { $listener.Start() } catch { exit 1 }

    while ($listener.IsListening) {
        try {
            $ctx = $listener.GetContext()
            $resp = $ctx.Response
            $resp.Headers.Add("Access-Control-Allow-Origin", "*")
            $resp.Headers.Add("Cache-Control", "no-cache, no-store")

            $path = $ctx.Request.Url.AbsolutePath
            if ($path -eq "/api/progress" -or $path -eq "/api/status") {
                # Serve the JSON progress state — field names match dashboard.html JS
                $resp.ContentType = "application/json; charset=utf-8"
                $body = if (Test-Path $logFile) { Get-Content $logFile -Raw } else { '{"phase":0,"percent":0,"installed":0,"skipped":0,"errors":0,"done":false,"log":[]}' }
            } else {
                $resp.ContentType = "text/html; charset=utf-8"
                $body = $html
            }

            $buf = [System.Text.Encoding]::UTF8.GetBytes($body)
            $resp.ContentLength64 = $buf.Length
            $resp.OutputStream.Write($buf, 0, $buf.Length)
            $resp.OutputStream.Close()
        } catch { }
    }
}

Start-Sleep -Seconds 1

# Open browser to dashboard
Write-Host ""
Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor Magenta
Write-Host "  │  📊  Dashboard: http://localhost:$DASH_PORT              │" -ForegroundColor Magenta
Write-Host "  │      Opening in your default browser...                 │" -ForegroundColor Magenta
Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor Magenta
Write-Host ""
Start-Process "http://localhost:$DASH_PORT"

# Export dashboard helper function for the main script
$env:WINSETUP_DASH_LOG = $DASH_LOG

function Update-Dashboard {
    param(
        [int]$Phase,
        [string]$Status,
        [int]$Progress,
        [string]$LogMessage,
        [int]$Installed = -1,
        [int]$Skipped   = -1,
        [int]$Errors    = -1,
        [switch]$Done
    )
    if (-not (Test-Path $env:WINSETUP_DASH_LOG)) { return }
    try {
        $state = Get-Content $env:WINSETUP_DASH_LOG -Raw | ConvertFrom-Json

        # Update phase / percent fields (these match dashboard.html JS: d.phase, d.percent)
        $state.phase   = $Phase + 1   # JS uses 1-based phase numbers
        $state.percent = $Progress
        if ($LogMessage) { $state.step = $LogMessage }

        # Update counters if provided
        if ($Installed -ge 0) { $state.installed = $Installed }
        if ($Skipped   -ge 0) { $state.skipped   = $Skipped   }
        if ($Errors    -ge 0) { $state.errors     = $Errors    }
        if ($Done)             { $state.done       = $true      }
        if ($Status -eq "fail") { $state.error = $true }

        # Append log entry as object (dashboard JS reads .time and .msg and .status)
        if ($LogMessage) {
            $ts     = Get-Date -Format "HH:mm:ss"
            $logSt  = switch ($Status) {
                "done"    { "OK"   }
                "running" { "WORK" }
                "fail"    { "FAIL" }
                default   { "INFO" }
            }
            $logArr = [System.Collections.Generic.List[object]]::new()
            if ($state.log) { $state.log | ForEach-Object { $logArr.Add($_) } }
            $logArr.Add([PSCustomObject]@{ time = $ts; msg = $LogMessage; status = $logSt })
            $state.log = $logArr.ToArray()
        }

        $state | ConvertTo-Json -Depth 4 | Set-Content $env:WINSETUP_DASH_LOG -Force
    } catch { }
}
# Save function definition to temp file so WindowsSetup_Pro.ps1 can dot-source it
@'
function Update-Dashboard {
    param(
        [int]$Phase,
        [string]$Status,
        [int]$Progress,
        [string]$LogMessage,
        [int]$Installed = -1,
        [int]$Skipped   = -1,
        [int]$Errors    = -1,
        [switch]$Done
    )
    $dashLog = $env:WINSETUP_DASH_LOG
    if (-not $dashLog -or -not (Test-Path $dashLog)) { return }
    try {
        $state = Get-Content $dashLog -Raw | ConvertFrom-Json

        # d.phase is 1-based in the JS (phase 1..6)
        $state.phase   = $Phase + 1
        $state.percent = $Progress
        if ($LogMessage) { $state.step = $LogMessage }

        if ($Installed -ge 0) { $state.installed = $Installed }
        if ($Skipped   -ge 0) { $state.skipped   = $Skipped   }
        if ($Errors    -ge 0) { $state.errors     = $Errors    }
        if ($Done)             { $state.done       = $true      }
        if ($Status -eq "fail") { $state.error = $true }

        if ($LogMessage) {
            $ts    = Get-Date -Format "HH:mm:ss"
            $logSt = switch ($Status) {
                "done"    { "OK"   }
                "running" { "WORK" }
                "fail"    { "FAIL" }
                default   { "INFO" }
            }
            $logArr = [System.Collections.Generic.List[object]]::new()
            if ($state.log) { $state.log | ForEach-Object { $logArr.Add($_) } }
            $logArr.Add([PSCustomObject]@{ time = $ts; msg = $LogMessage; status = $logSt })
            $state.log = $logArr.ToArray()
        }

        $state | ConvertTo-Json -Depth 4 | Set-Content $dashLog -Force
    } catch { }
}
'@ | Set-Content "$env:TEMP\Update-Dashboard.ps1" -Force

# ── Confirm before running ───────────────────────────────────────────────────
Write-Host ""
Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
Write-Host "  │  Ready to start Windows Professional Setup.             │" -ForegroundColor Yellow
Write-Host "  │  This will install apps and modify system settings.     │" -ForegroundColor Yellow
Write-Host "  │  Estimated time: 25–35 minutes.                         │" -ForegroundColor Yellow
Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
Write-Host ""
# (Removed manual confirmation prompt to ensure true one-click execution)

# ── Execute ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Launching main setup..." -ForegroundColor Cyan
Write-Host ""

Set-ExecutionPolicy Bypass -Scope Process -Force
& $TEMP_PATH

# ── Cleanup ───────────────────────────────────────────────────────────────────
# Mark setup as fully complete on dashboard
Update-Dashboard -Phase 5 -Status "done" -Progress 100 -LogMessage "✓ Setup complete! Restart your PC." -Done
Start-Sleep -Seconds 5

Stop-Job $dashJob -ErrorAction SilentlyContinue
Remove-Job $dashJob -Force -ErrorAction SilentlyContinue
Remove-Item $TEMP_PATH -Force -ErrorAction SilentlyContinue
Remove-Item $DASH_LOG -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\Update-Dashboard.ps1" -Force -ErrorAction SilentlyContinue
