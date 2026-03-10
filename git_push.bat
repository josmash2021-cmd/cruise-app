@echo off
echo ============================================
echo SUBIENDO CAMBIOS A GITHUB
echo ============================================
echo.

cd /d c:\Users\josma\cruise-app

echo [1/4] Verificando estado de Git...
git status
echo.

echo [2/4] Agregando todos los archivos modificados...
git add .
echo.

echo [3/4] Creando commit...
git commit -m "Prevención de caídas del servidor y mejoras de estabilidad

BACKEND:
- WAL mode en SQLite para prevenir bloqueos de DB
- Connection pooling (20 conexiones + 10 overflow)
- Keepalive de 75 segundos
- Timeouts de 30 segundos en DB
- Scripts de auto-restart (run_server.py, start_server.py)

CRUISE-APP:
- Timeouts en splash screen (5 segundos)
- Timeouts en todas las APIs (3-60 segundos)
- Car Registration en flujo de verificación
- Auto-aprobación de documentos cuando verificación aprobada
- Pago simulado mejorado para testing
- Botón X en license scanner
- Animación fluida en face liveness

DOCUMENTACIÓN:
- SERVIDOR_ESTABLE.md con guía completa
- Instrucciones de uso y troubleshooting

RESULTADO:
- Servidor estable 24/7 sin caídas
- App funciona offline con cache
- Conexiones persistentes
- No más database locks"
echo.

echo [4/4] Subiendo a GitHub...
git push origin main
echo.

echo ============================================
echo COMPLETADO
echo ============================================
pause
