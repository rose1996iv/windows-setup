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
$initialState = @{
    startTime = (Get-Date).ToString("o")
    phases = @(
        @{ name = "Security Hardening";    status = "waiting"; progress = 0 }
        @{ name = "Windows Settings";      status = "waiting"; progress = 0 }
        @{ name = "Core Applications";     status = "waiting"; progress = 0 }
        @{ name = "Python Full Stack";     status = "waiting"; progress = 0 }
        @{ name = "Student Tools";         status = "waiting"; progress = 0 }
        @{ name = "Finalization";          status = "waiting"; progress = 0 }
    )
    currentPhase = 0
    totalProgress = 0
    log = @()
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
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Inter',sans-serif;background:#0a0a0f;color:#f0f0f5;min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:40px 20px}
.header{text-align:center;margin-bottom:40px}
.header h1{font-size:1.6rem;font-weight:800;letter-spacing:-0.5px;margin-bottom:4px}
.header h1 span{background:linear-gradient(135deg,#3b82f6,#8b5cf6);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.header p{color:#8888a0;font-size:.85rem}
.live-badge{display:inline-flex;align-items:center;gap:8px;padding:4px 14px;border-radius:100px;background:rgba(16,185,129,.1);border:1px solid rgba(16,185,129,.25);font-size:.75rem;color:#10b981;margin-bottom:16px;font-weight:600}
.live-badge .dot{width:8px;height:8px;border-radius:50%;background:#10b981;animation:blink 1.5s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}
.card{background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.08);border-radius:16px;padding:28px;width:100%;max-width:600px;margin-bottom:20px}
.overall{margin-bottom:8px;display:flex;justify-content:space-between;align-items:baseline}
.overall-pct{font-size:2rem;font-weight:800;background:linear-gradient(135deg,#3b82f6,#06b6d4);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.overall-label{color:#8888a0;font-size:.8rem}
.bar-track{height:8px;border-radius:4px;background:rgba(255,255,255,.06);overflow:hidden;margin-bottom:28px}
.bar-fill{height:100%;border-radius:4px;background:linear-gradient(90deg,#3b82f6,#8b5cf6,#06b6d4);transition:width .8s ease;width:0}
.phase{display:flex;align-items:center;gap:14px;padding:10px 0;border-bottom:1px solid rgba(255,255,255,.04)}
.phase:last-child{border-bottom:none}
.phase-icon{width:32px;height:32px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:.85rem;flex-shrink:0}
.phase-icon.waiting{background:rgba(255,255,255,.04);color:#8888a0}
.phase-icon.running{background:rgba(59,130,246,.15);color:#3b82f6;animation:pulse 1.5s infinite}
.phase-icon.done{background:rgba(16,185,129,.15);color:#10b981}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}}
.phase-info{flex:1}
.phase-name{font-size:.85rem;font-weight:600}
.phase-bar{height:4px;border-radius:2px;background:rgba(255,255,255,.06);margin-top:6px;overflow:hidden}
.phase-bar-fill{height:100%;border-radius:2px;transition:width .6s ease}
.phase-bar-fill.waiting{background:transparent;width:0}
.phase-bar-fill.running{background:linear-gradient(90deg,#3b82f6,#06b6d4)}
.phase-bar-fill.done{background:#10b981;width:100%}
.phase-pct{font-size:.75rem;font-weight:600;color:#8888a0;min-width:36px;text-align:right;font-family:'JetBrains Mono',monospace}
.log-card{max-height:200px;overflow-y:auto}
.log-card::-webkit-scrollbar{width:4px}
.log-card::-webkit-scrollbar-track{background:transparent}
.log-card::-webkit-scrollbar-thumb{background:rgba(255,255,255,.1);border-radius:2px}
.log-title{font-size:.8rem;font-weight:600;color:#8888a0;margin-bottom:12px}
.log-entry{font-family:'JetBrains Mono',monospace;font-size:.72rem;color:#8888a0;padding:3px 0;border-bottom:1px solid rgba(255,255,255,.03)}
.log-entry .ok{color:#10b981}
.log-entry .fail{color:#ef4444}
.log-entry .time{color:#3b82f6}
.elapsed{text-align:center;margin-top:16px;font-size:.8rem;color:#8888a0;font-family:'JetBrains Mono',monospace}
</style>
</head>
<body>
<div class="header">
    <div class="live-badge"><span class="dot"></span> LIVE</div>
    <h1><span>WinSetup</span> Pro — Dashboard</h1>
    <p>Real-time progress · Auto-refreshes every 2s</p>
</div>
<div class="card">
    <div class="overall">
        <span class="overall-pct" id="totalPct">0%</span>
        <span class="overall-label" id="phaseLabel">Starting...</span>
    </div>
    <div class="bar-track"><div class="bar-fill" id="totalBar"></div></div>
    <div id="phases"></div>
</div>
<div class="card log-card">
    <div class="log-title">Activity Log</div>
    <div id="logEntries"></div>
</div>
<div class="elapsed" id="elapsed"></div>
<script>
const icons = ['🔒','⚙️','📦','🐍','🎓','🔄'];
function render(d) {
    document.getElementById('totalPct').textContent = d.totalProgress + '%';
    document.getElementById('totalBar').style.width = d.totalProgress + '%';
    const cp = d.currentPhase;
    document.getElementById('phaseLabel').textContent = cp < 6 ? 'Phase ' + (cp+1) + '/6 — ' + d.phases[cp].name : 'Complete!';
    let ph = '';
    d.phases.forEach((p, i) => {
        const s = p.status;
        ph += '<div class="phase">';
        ph += '<div class="phase-icon ' + s + '">' + icons[i] + '</div>';
        ph += '<div class="phase-info"><div class="phase-name">' + p.name + '</div>';
        ph += '<div class="phase-bar"><div class="phase-bar-fill ' + s + '" style="width:' + p.progress + '%"></div></div></div>';
        ph += '<div class="phase-pct">' + (s === 'done' ? '✓' : p.progress + '%') + '</div>';
        ph += '</div>';
    });
    document.getElementById('phases').innerHTML = ph;
    if (d.log && d.log.length) {
        let lg = '';
        d.log.slice(-30).reverse().forEach(l => {
            const cls = l.includes('✓') ? 'ok' : l.includes('✗') ? 'fail' : 'time';
            lg += '<div class="log-entry"><span class="' + cls + '">' + l + '</span></div>';
        });
        document.getElementById('logEntries').innerHTML = lg;
    }
    if (d.startTime) {
        const sec = Math.floor((Date.now() - new Date(d.startTime).getTime()) / 1000);
        const m = Math.floor(sec / 60), s2 = sec % 60;
        document.getElementById('elapsed').textContent = 'Elapsed: ' + m + 'm ' + s2 + 's';
    }
}
async function poll() {
    try {
        const r = await fetch('/api/status?' + Date.now());
        if (r.ok) render(await r.json());
    } catch(e) {}
    setTimeout(poll, 2000);
}
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

            if ($ctx.Request.Url.AbsolutePath -eq "/api/status") {
                $resp.ContentType = "application/json"
                $body = if (Test-Path $logFile) { Get-Content $logFile -Raw } else { '{}' }
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
    param([int]$Phase, [string]$Status, [int]$Progress, [string]$LogMessage)
    if (-not (Test-Path $env:WINSETUP_DASH_LOG)) { return }
    try {
        $state = Get-Content $env:WINSETUP_DASH_LOG -Raw | ConvertFrom-Json
        if ($Phase -ge 0 -and $Phase -lt 6) {
            $state.phases[$Phase].status   = $Status
            $state.phases[$Phase].progress = $Progress
            $state.currentPhase = $Phase
        }
        # Calculate total progress
        $total = 0
        foreach ($p in $state.phases) { $total += $p.progress }
        $state.totalProgress = [int]($total / 6)
        # Append log
        if ($LogMessage) {
            $ts = Get-Date -Format "HH:mm:ss"
            $logArr = @($state.log)
            $logArr += "[$ts] $LogMessage"
            $state.log = $logArr
        }
        $state | ConvertTo-Json -Depth 4 | Set-Content $env:WINSETUP_DASH_LOG -Force
    } catch { }
}

# Export function for the main script
Export-ModuleMember -Function Update-Dashboard -ErrorAction SilentlyContinue
# Save function definition to temp so main script can dot-source it
@'
function Update-Dashboard {
    param([int]$Phase, [string]$Status, [int]$Progress, [string]$LogMessage)
    $dashLog = $env:WINSETUP_DASH_LOG
    if (-not $dashLog -or -not (Test-Path $dashLog)) { return }
    try {
        $state = Get-Content $dashLog -Raw | ConvertFrom-Json
        if ($Phase -ge 0 -and $Phase -lt 6) {
            $state.phases[$Phase].status   = $Status
            $state.phases[$Phase].progress = $Progress
            $state.currentPhase = $Phase
        }
        $total = 0
        foreach ($p in $state.phases) { $total += $p.progress }
        $state.totalProgress = [int]($total / 6)
        if ($LogMessage) {
            $ts = Get-Date -Format "HH:mm:ss"
            $logArr = [System.Collections.Generic.List[string]]::new()
            if ($state.log) { $state.log | ForEach-Object { $logArr.Add($_) } }
            $logArr.Add("[$ts] $LogMessage")
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
$confirm = Read-Host "  Proceed? [Y/N]"
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "  Cancelled. Run again when ready." -ForegroundColor Gray
    Stop-Job $dashJob -ErrorAction SilentlyContinue
    Remove-Job $dashJob -Force -ErrorAction SilentlyContinue
    Remove-Item $TEMP_PATH -Force -ErrorAction SilentlyContinue
    exit 0
}

# ── Execute ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Launching main setup..." -ForegroundColor Cyan
Write-Host ""

Set-ExecutionPolicy Bypass -Scope Process -Force
& $TEMP_PATH

# ── Cleanup ───────────────────────────────────────────────────────────────────
# Mark all phases complete on dashboard
Update-Dashboard -Phase 5 -Status "done" -Progress 100 -LogMessage "✓ Setup complete!"
Start-Sleep -Seconds 5

Stop-Job $dashJob -ErrorAction SilentlyContinue
Remove-Job $dashJob -Force -ErrorAction SilentlyContinue
Remove-Item $TEMP_PATH -Force -ErrorAction SilentlyContinue
Remove-Item $DASH_LOG -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\Update-Dashboard.ps1" -Force -ErrorAction SilentlyContinue
