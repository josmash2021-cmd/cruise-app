@echo off
echo ========================================
echo   CRUISE BACKEND - CLOUDFLARE TUNNEL
echo ========================================
echo.
echo Este script inicia un tunnel de Cloudflare
echo para acceso remoto al backend desde cualquier red.
echo.
echo Instalando cloudflared si no esta instalado...
echo.

REM Verificar si cloudflared esta instalado
where cloudflared >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo cloudflared no encontrado. Descargando...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile 'cloudflared.exe'"
    echo cloudflared descargado exitosamente.
) else (
    echo cloudflared ya esta instalado.
)

echo.
echo Iniciando tunnel...
echo La URL publica se mostrara abajo:
echo.

REM Iniciar tunnel apuntando al backend local
cloudflared tunnel --url http://localhost:8000

pause
