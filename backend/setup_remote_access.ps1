# ========================================
#   CRUISE BACKEND - CONFIGURACIÓN REMOTA
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CRUISE BACKEND - ACCESO REMOTO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar si cloudflared está instalado
Write-Host "[1/4] Verificando cloudflared..." -ForegroundColor Yellow
$cloudflaredPath = "cloudflared.exe"

if (-not (Test-Path $cloudflaredPath)) {
    Write-Host "Descargando cloudflared..." -ForegroundColor Yellow
    $url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    Invoke-WebRequest -Uri $url -OutFile $cloudflaredPath
    Write-Host "✓ cloudflared descargado" -ForegroundColor Green
} else {
    Write-Host "✓ cloudflared ya instalado" -ForegroundColor Green
}

Write-Host ""

# 2. Iniciar el backend si no está corriendo
Write-Host "[2/4] Verificando backend..." -ForegroundColor Yellow
$backendRunning = Get-Process python -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowTitle -like "*cruise*"}

if (-not $backendRunning) {
    Write-Host "Iniciando backend..." -ForegroundColor Yellow
    Start-Process python -ArgumentList "run_server.py" -WindowStyle Normal
    Start-Sleep -Seconds 5
    Write-Host "✓ Backend iniciado" -ForegroundColor Green
} else {
    Write-Host "✓ Backend ya está corriendo" -ForegroundColor Green
}

Write-Host ""

# 3. Iniciar Cloudflare Tunnel
Write-Host "[3/4] Iniciando Cloudflare Tunnel..." -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANTE: La URL pública aparecerá abajo." -ForegroundColor Cyan
Write-Host "Copia esa URL y úsala en la app para acceso remoto." -ForegroundColor Cyan
Write-Host ""
Write-Host "Presiona Ctrl+C para detener el tunnel cuando termines." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ejecutar cloudflared tunnel
& .\cloudflared.exe tunnel --url http://localhost:8000

Write-Host ""
Write-Host "Tunnel detenido." -ForegroundColor Yellow
