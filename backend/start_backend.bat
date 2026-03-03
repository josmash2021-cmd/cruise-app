@echo off
:: Cruise App Backend - Startup Script
:: This script starts the FastAPI backend and sets up ADB reverse for Android

set PYPATH=C:\Users\josma\AppData\Local\Programs\Python\Python312
set ADB=C:\Users\josma\AppData\Local\Android\Sdk\platform-tools\adb.exe
set BACKEND=C:\Users\josma\cruise-app\backend

:: Start backend server
start "Cruise Backend" /MIN "%PYPATH%\python.exe" -m uvicorn main:app --host 0.0.0.0 --port 8000

:: Wait 3 seconds then set up ADB reverse tunnel
timeout /t 3 /nobreak >nul
"%ADB%" reverse tcp:8000 tcp:8000 2>nul

echo Cruise backend started on port 8000
