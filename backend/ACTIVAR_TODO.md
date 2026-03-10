# 🚀 ACTIVAR TODO EL SISTEMA CRUISE

## Instrucciones para activar backend, apps y acceso remoto

### OPCIÓN 1: Acceso Local (Solo WiFi de la PC)

```bash
cd C:\Users\josma\CascadeProjects\cruise-app\backend
python run_server.py
```

**Limitación:** Solo funciona cuando los dispositivos están en la misma red WiFi que la PC.

---

### OPCIÓN 2: Acceso Remoto (Funciona desde cualquier red) ⭐ RECOMENDADO

#### Paso 1: Ejecutar el script de configuración

```powershell
cd C:\Users\josma\CascadeProjects\cruise-app\backend
.\setup_remote_access.ps1
```

O usar el archivo .bat:

```bash
cd C:\Users\josma\CascadeProjects\cruise-app\backend
start_tunnel.bat
```

#### Paso 2: Copiar la URL pública

El script mostrará algo como:

```
https://random-name-1234.trycloudflare.com
```

#### Paso 3: Configurar la URL en las apps

**En Cruise App:**
1. Abre la app
2. Ve a Settings/Configuración
3. Cambia la URL del servidor a la URL de Cloudflare

**En Dispatch App:**
1. Abre la app
2. Ve a Settings
3. Cambia la URL del servidor a la URL de Cloudflare

---

### OPCIÓN 3: Acceso Permanente con Cloudflare Tunnel

Para tener una URL permanente que no cambie:

1. Crear cuenta en Cloudflare (gratis)
2. Instalar cloudflared
3. Ejecutar: `cloudflared tunnel login`
4. Crear tunnel: `cloudflared tunnel create cruise-backend`
5. Configurar tunnel en `config.yml`
6. Ejecutar: `cloudflared tunnel run cruise-backend`

---

## 📱 URLs de las Apps

### Backend Local:
- **Local:** `http://localhost:8000`
- **Red local:** `http://172.20.11.24:8000` (tu IP puede variar)

### Backend Remoto (Cloudflare):
- **URL temporal:** Cambia cada vez que inicias el tunnel
- **URL permanente:** Requiere configuración de cuenta Cloudflare

---

## ✅ Verificar que todo funciona

1. **Backend:** Abre `http://localhost:8000/docs` en el navegador
2. **Cruise App:** Intenta hacer login
3. **Dispatch App:** Intenta hacer login
4. **Chat:** Envía un mensaje de prueba

---

## 🔧 Solución de Problemas

### "Connection error" en el chat:
- Verifica que el backend esté corriendo
- Verifica la URL configurada en la app
- Revisa los logs del backend

### "No drivers available":
- Asegúrate de que hay drivers online en Dispatch
- Verifica que el servicio de geolocalización esté activo

### Apps se desconectan:
- Usa la OPCIÓN 2 (Acceso Remoto) para acceso desde cualquier red
- Mantén el tunnel de Cloudflare corriendo mientras uses las apps

---

## 📝 Notas Importantes

- **Backend debe estar corriendo** para que las apps funcionen
- **Cloudflare Tunnel debe estar activo** para acceso remoto
- **La URL de Cloudflare cambia** cada vez que reinicias el tunnel (a menos que configures una permanente)
- **Guarda la URL** en las apps para no tener que cambiarla cada vez

---

## 🎯 Comando Rápido para Activar Todo

```powershell
# Ejecuta este comando para iniciar todo:
cd C:\Users\josma\CascadeProjects\cruise-app\backend
.\setup_remote_access.ps1
```

Esto iniciará:
1. ✅ Backend de Cruise
2. ✅ Cloudflare Tunnel para acceso remoto
3. ✅ Mostrará la URL pública para usar en las apps
