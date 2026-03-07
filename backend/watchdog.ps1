# Cruise Backend Watchdog — Auto-restart on crash
# Run this script to keep the backend alive permanently
# Usage: powershell -ExecutionPolicy Bypass -File watchdog.ps1

$PYPATH = "C:\Users\josma\AppData\Local\Programs\Python\Python312\python.exe"
$BACKEND = "C:\Users\josma\cruise-app\backend"
$ADB = "C:\Users\josma\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$CHECK_INTERVAL = 10  # seconds between health checks
$MAX_RESTARTS = 100   # safety limit

$restartCount = 0

function Start-Backend {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Starting Cruise backend..." -ForegroundColor Green
    $process = Start-Process -FilePath $PYPATH `
        -ArgumentList "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000" `
        -WorkingDirectory $BACKEND `
        -WindowStyle Minimized `
        -PassThru
    Start-Sleep -Seconds 3

    # Set up ADB reverse tunnel
    try {
        & $ADB reverse tcp:8000 tcp:8000 2>$null
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ADB reverse tunnel configured" -ForegroundColor Cyan
    } catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ADB not available (OK for non-USB)" -ForegroundColor Yellow
    }

    return $process
}

function Test-Backend {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 5 -ErrorAction Stop
        return $response.status -eq "ok"
    } catch {
        return $false
    }
}

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  CRUISE BACKEND WATCHDOG" -ForegroundColor Yellow
Write-Host "  Auto-restart on crash" -ForegroundColor Yellow
Write-Host "  Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# Kill any existing backend
Get-Process python -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -eq $PYPATH
} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$process = Start-Backend

while ($restartCount -lt $MAX_RESTARTS) {
    Start-Sleep -Seconds $CHECK_INTERVAL

    if (-not (Test-Backend)) {
        $restartCount++
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Backend DOWN! Restarting... (attempt $restartCount)" -ForegroundColor Red

        # Kill zombie process
        try { $process | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
        Get-Process python -ErrorAction SilentlyContinue | Where-Object {
            $_.Path -eq $PYPATH
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        $process = Start-Backend

        if (Test-Backend) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Backend recovered successfully!" -ForegroundColor Green
        } else {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Backend failed to start. Retrying in 10s..." -ForegroundColor Red
        }
    }
}

Write-Host "Max restarts reached. Exiting watchdog." -ForegroundColor Red
