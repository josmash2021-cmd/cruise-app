# ── Cruise Backend Persistent Service ─────────────────────────
# Keeps the FastAPI server + Cloudflare Tunnel running forever
# with auto-restart on crash.
# Also maintains the ADB reverse tunnel for the Android device.
# Run via Task Scheduler at logon for always-on behavior.
# ──────────────────────────────────────────────────────────────

$ErrorActionPreference = "Continue"

# ── Paths ──
$python      = "C:\Users\josma\AppData\Local\Programs\Python\Python312\python.exe"
$backend     = "C:\Users\josma\cruise-app\backend"
$adb         = "C:\Users\josma\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$cloudflared = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
$logFile     = Join-Path $backend "service.log"
$tunnelLog   = Join-Path $env:USERPROFILE ".cloudflared\tunnel.log"
$tunnelUrl   = Join-Path $backend "tunnel_url.txt"

# ── Helpers ──
function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] $msg"
    Add-Content -Path $logFile -Value $entry -ErrorAction SilentlyContinue
    Write-Host $entry
}

function Start-AdbReverse {
    if (Test-Path $adb) {
        try {
            & $adb reverse tcp:8000 tcp:8000 2>$null
            Write-Log "ADB reverse tunnel established"
        } catch {
            Write-Log "ADB reverse failed (device may not be connected)"
        }
    }
}

function Start-CloudflareTunnel {
    # Kill any existing cloudflared
    Stop-Process -Name cloudflared -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    if (-not (Test-Path $cloudflared)) {
        Write-Log "cloudflared not found at $cloudflared — skipping tunnel"
        return
    }

    # Clear old log
    New-Item -Path (Split-Path $tunnelLog) -ItemType Directory -Force | Out-Null
    if (Test-Path $tunnelLog) { Remove-Item $tunnelLog -Force }

    Write-Log "Starting Cloudflare Tunnel..."
    Start-Process -FilePath $cloudflared `
        -ArgumentList "tunnel", "--url", "http://localhost:8000", "--logfile", $tunnelLog `
        -WindowStyle Hidden

    # Wait up to 30s for the URL to appear in the log
    $maxWait = 30
    $elapsed = 0
    while ($elapsed -lt $maxWait) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        if (Test-Path $tunnelLog) {
            $match = Select-String -Path $tunnelLog -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($match) {
                $url = ($match.Line | Select-String -Pattern "https://[a-z0-9-]+\.trycloudflare\.com").Matches[0].Value
                Set-Content -Path $tunnelUrl -Value $url
                Write-Log "Tunnel active: $url"
                Write-Log "URL saved to $tunnelUrl"
                return
            }
        }
    }
    Write-Log "WARNING: Tunnel did not produce a URL within ${maxWait}s"
}

# ── Trim log file if it gets too large (>5 MB) ──
function Trim-Log {
    if (Test-Path $logFile) {
        $size = (Get-Item $logFile).Length
        if ($size -gt 5MB) {
            $lines = Get-Content $logFile -Tail 200
            Set-Content -Path $logFile -Value $lines
            Write-Log "Log trimmed (was $([math]::Round($size/1MB, 1)) MB)"
        }
    }
}

# ── Main loop ──
Write-Log "=== Cruise Service starting ==="
$restartDelay = 3          # seconds between restarts
$maxRapidRestarts = 5      # if it crashes this many times in $rapidWindow …
$rapidWindow = 60          # … seconds, back off
$backoffDelay = 30         # wait this long before trying again
$crashTimes = @()

# Start the Cloudflare Tunnel (runs alongside the server)
Start-CloudflareTunnel

while ($true) {
    Trim-Log
    Start-AdbReverse

    # Ensure cloudflared is still running; restart if not
    $cfProc = Get-Process -Name cloudflared -ErrorAction SilentlyContinue
    if (-not $cfProc) {
        Write-Log "Cloudflare Tunnel not running — restarting..."
        Start-CloudflareTunnel
    }

    Write-Log "Starting uvicorn server..."
    $proc = Start-Process -FilePath $python `
        -ArgumentList "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "warning" `
        -WorkingDirectory $backend `
        -WindowStyle Hidden -PassThru

    Write-Log "Server PID: $($proc.Id)"

    # Wait for the process to exit
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode
    Write-Log "Server exited with code $exitCode"

    # Track crash times for rapid-restart detection
    $now = Get-Date
    $crashTimes += $now
    $crashTimes = $crashTimes | Where-Object { ($now - $_).TotalSeconds -lt $rapidWindow }

    if ($crashTimes.Count -ge $maxRapidRestarts) {
        Write-Log "Too many rapid restarts ($($crashTimes.Count) in ${rapidWindow}s) — backing off ${backoffDelay}s"
        Start-Sleep -Seconds $backoffDelay
        $crashTimes = @()
    } else {
        Write-Log "Restarting in ${restartDelay}s..."
        Start-Sleep -Seconds $restartDelay
    }
}
