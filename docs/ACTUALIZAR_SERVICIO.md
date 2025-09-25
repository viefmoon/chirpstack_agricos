# 📋 Guía de Actualización del Servicio ChirpStack-Supabase

## Descripción
Guía completa para actualizar el código del servicio ChirpStack-Supabase tanto desde tu PC local como directamente desde el servidor.

---

## 🚀 Método 1: Actualización desde el Servidor Linux

### Pasos completos estando conectado al servidor:

#### 1. Conectarse al servidor
```bash
ssh root@143.244.144.51
```

#### 2. Navegar a la carpeta del proyecto
```bash
cd chirpstack_agricos
```

#### 3. Verificar archivos disponibles
```bash
ls -la services/supabase/
```

#### 4. Crear backup del archivo actual
```bash
cp /opt/chirpstack-supabase-service/chirpstack-supabase-service.js \
   /opt/chirpstack-supabase-service/chirpstack-supabase-service.js.backup_$(date +%Y%m%d_%H%M%S)
```

#### 5. Copiar el archivo actualizado
```bash
cp services/supabase/chirpstack-supabase-service.js /opt/chirpstack-supabase-service/
```

#### 6. Verificar sintaxis del archivo
```bash
cd /opt/chirpstack-supabase-service
node -c chirpstack-supabase-service.js
```

#### 7. Reiniciar el servicio
```bash
systemctl restart chirpstack-supabase
```

#### 8. Verificar estado del servicio
```bash
systemctl status chirpstack-supabase
```

#### 9. Ver los logs recientes
```bash
journalctl -u chirpstack-supabase -n 20
```

### 🎯 Comando Todo-en-Uno (desde el servidor)

Si ya estás conectado en `root@chirpstack-server:~#`, ejecuta:

```bash
cd chirpstack_agricos && \
cp /opt/chirpstack-supabase-service/chirpstack-supabase-service.js \
   /opt/chirpstack-supabase-service/chirpstack-supabase-service.js.backup_$(date +%Y%m%d_%H%M%S) && \
cp services/supabase/chirpstack-supabase-service.js /opt/chirpstack-supabase-service/ && \
cd /opt/chirpstack-supabase-service && \
node -c chirpstack-supabase-service.js && \
systemctl restart chirpstack-supabase && \
echo "✅ Servicio actualizado exitosamente" && \
systemctl status chirpstack-supabase
```

---

## 💻 Método 2: Actualización desde tu PC (Windows/Linux/Mac)

### Usando el script automático:

```bash
# Desde el directorio del proyecto en tu PC
./scripts/update-service-ssh.sh
```

### Opciones del script:

```bash
# Ver ayuda
./scripts/update-service-ssh.sh --help

# Actualizar sin crear backup
./scripts/update-service-ssh.sh --no-backup

# Actualizar sin reiniciar el servicio
./scripts/update-service-ssh.sh --no-restart

# Actualizar también package.json
./scripts/update-service-ssh.sh --package

# Solo ver el estado del servicio
./scripts/update-service-ssh.sh --status
```

### Comando directo (sin script):

```bash
# Desde PowerShell o Git Bash en tu PC
scp services/supabase/chirpstack-supabase-service.js root@143.244.144.51:/opt/chirpstack-supabase-service/ && \
ssh root@143.244.144.51 "systemctl restart chirpstack-supabase && systemctl status chirpstack-supabase"
```

---

## 📁 Estructura de Archivos

### En el servidor (`/opt/chirpstack-supabase-service/`):
```
/opt/chirpstack-supabase-service/
├── chirpstack-supabase-service.js    # Archivo principal del servicio
├── package.json                      # Dependencias
├── package-lock.json                 # Lock de dependencias
├── node_modules/                     # Módulos de Node.js
├── .env                              # Configuración y credenciales
└── *.backup_*                        # Archivos de backup
```

### En el repositorio local (`~/chirpstack_agricos/`):
```
chirpstack_agricos/
├── services/
│   └── supabase/
│       ├── chirpstack-supabase-service.js  # Código actualizado
│       ├── package.json                    # Dependencias
│       └── .env.example                    # Plantilla de configuración
└── scripts/
    └── update-service-ssh.sh               # Script de actualización
```

---

## 🔍 Verificación Post-Actualización

### Ver estado del servicio:
```bash
systemctl status chirpstack-supabase
```

### Ver logs en tiempo real:
```bash
journalctl -u chirpstack-supabase -f
```

### Verificar que no hay errores:
```bash
journalctl -u chirpstack-supabase -n 50 | grep -i error
```

### Ver proceso activo:
```bash
ps aux | grep chirpstack-supabase
```

---

## 💾 Gestión de Backups

### Crear backup manual:
```bash
cd /opt/chirpstack-supabase-service
cp chirpstack-supabase-service.js chirpstack-supabase-service.js.backup_$(date +%Y%m%d_%H%M%S)
```

### Listar backups disponibles:
```bash
ls -lht /opt/chirpstack-supabase-service/*.backup_* | head -10
```

### Restaurar un backup:
```bash
# Identificar el backup a restaurar
ls -la /opt/chirpstack-supabase-service/*.backup_*

# Restaurar
cp /opt/chirpstack-supabase-service/chirpstack-supabase-service.js.backup_FECHA \
   /opt/chirpstack-supabase-service/chirpstack-supabase-service.js

# Reiniciar servicio
systemctl restart chirpstack-supabase
```

### Eliminar backups antiguos (más de 30 días):
```bash
find /opt/chirpstack-supabase-service -name "*.backup_*" -mtime +30 -delete
```

---

## 🛠️ Comandos Útiles

### Gestión del servicio:
```bash
# Iniciar servicio
systemctl start chirpstack-supabase

# Detener servicio
systemctl stop chirpstack-supabase

# Reiniciar servicio
systemctl restart chirpstack-supabase

# Ver estado detallado
systemctl status chirpstack-supabase -l

# Habilitar inicio automático
systemctl enable chirpstack-supabase

# Deshabilitar inicio automático
systemctl disable chirpstack-supabase
```

### Monitoreo de logs:
```bash
# Logs en tiempo real
journalctl -u chirpstack-supabase -f

# Últimas 100 líneas
journalctl -u chirpstack-supabase -n 100

# Logs de las últimas 2 horas
journalctl -u chirpstack-supabase --since "2 hours ago"

# Logs de hoy
journalctl -u chirpstack-supabase --since today

# Buscar errores específicos
journalctl -u chirpstack-supabase | grep -i "error\|fail"

# Exportar logs a archivo
journalctl -u chirpstack-supabase > /tmp/service-logs.txt
```

### Verificación del archivo:
```bash
# Ver primeras 30 líneas
head -30 /opt/chirpstack-supabase-service/chirpstack-supabase-service.js

# Ver últimas 30 líneas
tail -30 /opt/chirpstack-supabase-service/chirpstack-supabase-service.js

# Buscar configuración específica
grep -n "SENSOR_CONFIG" /opt/chirpstack-supabase-service/chirpstack-supabase-service.js

# Verificar sintaxis
cd /opt/chirpstack-supabase-service && node -c chirpstack-supabase-service.js

# Ver tamaño del archivo
ls -lh /opt/chirpstack-supabase-service/chirpstack-supabase-service.js

# Comparar con backup
diff /opt/chirpstack-supabase-service/chirpstack-supabase-service.js \
     /opt/chirpstack-supabase-service/chirpstack-supabase-service.js.backup_*
```

---

## 🔐 Configuración del Servicio

### Ver configuración actual (sin credenciales):
```bash
grep -v "KEY\|PASSWORD" /opt/chirpstack-supabase-service/.env
```

### Editar configuración:
```bash
nano /opt/chirpstack-supabase-service/.env
# Guardar: Ctrl+X, Y, Enter
```

### Verificar permisos:
```bash
ls -la /opt/chirpstack-supabase-service/.env
# Debe ser: -rw------- (600) propiedad de chirpstack-service
```

### Arreglar permisos si es necesario:
```bash
chown chirpstack-service:chirpstack-service /opt/chirpstack-supabase-service/.env
chmod 600 /opt/chirpstack-supabase-service/.env
```

---

## ❗ Solución de Problemas

### El servicio no inicia:

1. **Ver el error completo:**
```bash
journalctl -u chirpstack-supabase -n 50
```

2. **Verificar sintaxis:**
```bash
cd /opt/chirpstack-supabase-service
node -c chirpstack-supabase-service.js
```

3. **Verificar dependencias:**
```bash
cd /opt/chirpstack-supabase-service
npm list
```

4. **Reinstalar dependencias si es necesario:**
```bash
cd /opt/chirpstack-supabase-service
npm install --production
```

### Error de permisos:

```bash
# Verificar propietario
ls -la /opt/chirpstack-supabase-service/

# Corregir permisos
chown -R chirpstack-service:chirpstack-service /opt/chirpstack-supabase-service/
chmod 755 /opt/chirpstack-supabase-service/
chmod 644 /opt/chirpstack-supabase-service/*.js
chmod 600 /opt/chirpstack-supabase-service/.env
```

### Error de conexión MQTT:

```bash
# Verificar que Mosquitto está activo
systemctl status mosquitto

# Probar conexión MQTT
mosquitto_sub -h localhost -t 'test' -C 1 -W 5

# Ver logs de Mosquitto
journalctl -u mosquitto -n 50
```

### Error de Supabase:

```bash
# Verificar configuración
cat /opt/chirpstack-supabase-service/.env | grep SUPABASE_URL

# Probar conectividad (reemplaza con tu URL)
curl -I https://tu-proyecto.supabase.co
```

---

## 📊 Información del Sistema

### Detalles del servidor:
- **IP:** 143.244.144.51
- **Sistema:** Ubuntu 24.04.2 LTS
- **Usuario SSH:** root
- **Directorio del proyecto:** ~/chirpstack_agricos

### Rutas importantes:
- **Servicio:** /opt/chirpstack-supabase-service/
- **Systemd:** /etc/systemd/system/chirpstack-supabase.service
- **Logs:** journalctl -u chirpstack-supabase
- **MQTT:** localhost:1883
- **ChirpStack:** localhost:8080

---

## 📝 Mejores Prácticas

1. **Siempre crear backup** antes de actualizar
2. **Verificar sintaxis** antes de reiniciar el servicio
3. **Revisar logs** después de cada actualización
4. **Documentar cambios** realizados
5. **Mantener backups** de las últimas 5 versiones
6. **Probar en desarrollo** antes de actualizar producción

---

## 🚨 Comandos de Emergencia

Si algo sale muy mal:

```bash
# Detener el servicio inmediatamente
systemctl stop chirpstack-supabase

# Restaurar último backup conocido
cd /opt/chirpstack-supabase-service
cp $(ls -t *.backup_* | head -1) chirpstack-supabase-service.js

# Reiniciar servicio
systemctl start chirpstack-supabase

# Verificar que funciona
systemctl status chirpstack-supabase
journalctl -u chirpstack-supabase -n 50
```

---

**Última actualización:** Documentación completa con procesos desde servidor y PC local