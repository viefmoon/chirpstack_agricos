# Guía de Instalación y Configuración del Servicio ChirpStack-Supabase

Esta guía te ayudará a instalar, configurar e iniciar el servicio **chirpstack-supabase-service** que permite integrar automáticamente los datos de sensores LoRaWAN de ChirpStack con tu base de datos Supabase.

## 📋 Requisitos Previos

- ChirpStack v4 funcionando correctamente
- Acceso a una cuenta de Supabase
- Permisos de administrador en el servidor

## 🚀 Instalación del Servicio

### Opción 1: Instalación Automática (Recomendada)

Si ya tienes ChirpStack instalado, ejecuta solo el script del servicio Supabase:

```bash
cd chirpstack_agricos
sudo ./scripts/setup-supabase-service.sh
```

### Opción 2: Instalación Manual

```bash
# 1. Instalar Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Crear directorio del servicio
sudo mkdir -p /opt/chirpstack-supabase-service

# 3. Copiar archivos
sudo cp -r services/supabase/* /opt/chirpstack-supabase-service/

# 4. Instalar dependencias
cd /opt/chirpstack-supabase-service
sudo npm install

# 5. Crear usuario del sistema
sudo useradd --system --shell /bin/false chirpstack-supabase

# 6. Configurar permisos
sudo chown -R chirpstack-supabase:chirpstack-supabase /opt/chirpstack-supabase-service

# 7. Crear servicio systemd
sudo cp /opt/chirpstack-supabase-service/chirpstack-supabase.service /etc/systemd/system/
sudo systemctl daemon-reload
```

## ⚙️ Configuración

### 1. Obtener Credenciales de Supabase

En tu proyecto de Supabase:

1. Ve a **Settings** → **API**
2. Copia la **URL** del proyecto
3. Copia la **service_role key** (no la anon key)

### 2. Configuración Interactiva (Recomendada)

```bash
sudo /opt/chirpstack-supabase-service/configure-env.sh
```

El script te pedirá:
- URL de Supabase
- Service Role Key
- Host MQTT (por defecto: localhost)
- Puerto MQTT (por defecto: 1883)
- Tópico MQTT (por defecto: application/#)

### 3. Configuración Manual

```bash
# Crear archivo de configuración
sudo nano /opt/chirpstack-supabase-service/.env
```

Agregar estas variables:

```env
# Configuración de Supabase
SUPABASE_URL=https://tu-proyecto-id.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Configuración MQTT (ChirpStack)
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_TOPIC=application/#

# Configuración del servicio
LOG_LEVEL=info
RECONNECT_DELAY=5000
```

### 4. Verificar Configuración

```bash
# Verificar que el archivo existe
sudo ls -la /opt/chirpstack-supabase-service/.env

# Verificar permisos
sudo chown chirpstack-supabase:chirpstack-supabase /opt/chirpstack-supabase-service/.env
sudo chmod 600 /opt/chirpstack-supabase-service/.env
```

## ▶️ Iniciar el Servicio

### Comandos Básicos

```bash
# Habilitar inicio automático
sudo systemctl enable chirpstack-supabase

# Iniciar servicio
sudo systemctl start chirpstack-supabase

# Ver estado
sudo systemctl status chirpstack-supabase

# Reiniciar servicio
sudo systemctl restart chirpstack-supabase

# Detener servicio
sudo systemctl stop chirpstack-supabase
```

### Verificar que Funciona

```bash
# Ver logs en tiempo real
sudo journalctl -u chirpstack-supabase -f

# Ver últimas 50 líneas de logs
sudo journalctl -u chirpstack-supabase -n 50

# Ver logs de errores
sudo journalctl -u chirpstack-supabase -p err
```

**Logs esperados al iniciar:**
```
✅ Conectado a Supabase
✅ Conectado a MQTT broker
🎯 Escuchando mensajes en tópico: application/#
```

## 📊 Estructura de Base de Datos

El servicio crea automáticamente estas tablas en Supabase:

### Tablas Principales

1. **stations** - Estaciones de medición
   ```sql
   - id (uuid, primary key)
   - name (varchar)
   - location (varchar)
   - created_at (timestamp)
   ```

2. **devices** - Dispositivos LoRaWAN
   ```sql
   - id (uuid, primary key)
   - device_eui (varchar, unique)
   - name (varchar)
   - station_id (uuid, foreign key)
   - created_at (timestamp)
   ```

3. **sensor_types** - Tipos de sensores
   ```sql
   - id (uuid, primary key)
   - name (varchar, unique)
   - unit (varchar)
   - description (varchar)
   ```

4. **sensors** - Sensores individuales
   ```sql
   - id (uuid, primary key)
   - device_id (uuid, foreign key)
   - sensor_type_id (uuid, foreign key)
   - channel (integer)
   - created_at (timestamp)
   ```

5. **readings** - Lecturas de sensores
   ```sql
   - id (uuid, primary key)
   - sensor_id (uuid, foreign key)
   - value (decimal)
   - timestamp (timestamp)
   - created_at (timestamp)
   ```

6. **voltage_readings** - Lecturas de voltaje
   ```sql
   - id (uuid, primary key)
   - device_id (uuid, foreign key)
   - voltage (decimal)
   - timestamp (timestamp)
   - created_at (timestamp)
   ```

## 🔍 Sensores Soportados

### Sensores Individuales
- **N100K/N10K** → Temperatura (°C)
- **HDS10** → Humedad (%)
- **RTD/DS18B20** → Temperatura (°C)
- **PH** → pH (pH)
- **COND** → Conductividad (μS/cm)
- **SOILH** → Humedad del suelo (%)
- **VEML7700** → Luminosidad (lux)

### Sensores Múltiples
- **SHT30/SHT40** → Temperatura + Humedad
- **BME280/BME680** → Temperatura + Humedad + Presión (+ Gas)
- **CO2** → CO2 + Temperatura + Humedad
- **ENV4** → Humedad + Temperatura + Presión + Luminosidad

## 🚨 Troubleshooting

### Problema: El servicio no inicia

```bash
# Ver logs detallados
sudo journalctl -u chirpstack-supabase -n 100

# Verificar configuración
sudo cat /opt/chirpstack-supabase-service/.env

# Verificar permisos
sudo ls -la /opt/chirpstack-supabase-service/
```

**Causas comunes:**
- Archivo `.env` no existe o tiene permisos incorrectos
- Credenciales de Supabase incorrectas
- Node.js no instalado correctamente

### Problema: No se conecta a MQTT

```bash
# Verificar que ChirpStack MQTT está funcionando
sudo netstat -tlnp | grep 1883

# Verificar logs de ChirpStack
cd /opt/chirpstack-docker
docker-compose logs mosquitto
```

**Solución:**
- Verificar que ChirpStack esté funcionando
- Confirmar puerto MQTT en configuración

### Problema: Error de conexión a Supabase

```bash
# Verificar logs del servicio
sudo journalctl -u chirpstack-supabase -f
```

**Causas comunes:**
- URL de Supabase incorrecta
- Service Role Key incorrecta o expirada
- Problemas de conectividad a internet

**Solución:**
```bash
# Reconfigurar credenciales
sudo /opt/chirpstack-supabase-service/configure-env.sh
sudo systemctl restart chirpstack-supabase
```

### Problema: Datos no aparecen en Supabase

1. **Verificar que llegan datos MQTT:**
   ```bash
   # Monitorear tópico MQTT manualmente
   mosquitto_sub -h localhost -p 1883 -t "application/#"
   ```

2. **Verificar logs del servicio:**
   ```bash
   sudo journalctl -u chirpstack-supabase -f
   ```

3. **Verificar tablas en Supabase:**
   - Ve a Supabase Dashboard → Table Editor
   - Verifica que las tablas se hayan creado correctamente

## 🔧 Comandos Útiles

### Scripts de Utilidad Creados

```bash
# Configurar variables de entorno
sudo /opt/chirpstack-supabase-service/configure-env.sh

# Ver logs del servicio
sudo /opt/chirpstack-supabase-service/view-logs.sh

# Verificar estado del servicio
sudo /opt/chirpstack-supabase-service/status.sh
```

### Comandos de Mantenimiento

```bash
# Limpiar logs antiguos
sudo journalctl --rotate
sudo journalctl --vacuum-time=7d

# Actualizar dependencias npm
cd /opt/chirpstack-supabase-service
sudo npm update

# Reiniciar todos los servicios relacionados
sudo systemctl restart chirpstack-supabase
cd /opt/chirpstack-docker && docker-compose restart mosquitto
```

## 📈 Monitoreo del Servicio

### Verificar Funcionamiento

```bash
# Estado del servicio
sudo systemctl is-active chirpstack-supabase

# Tiempo de ejecución
sudo systemctl show chirpstack-supabase --property=ActiveEnterTimestamp

# Uso de memoria
sudo systemctl show chirpstack-supabase --property=MemoryCurrent
```

### Logs Importantes

```bash
# Logs de inicio del servicio
sudo journalctl -u chirpstack-supabase --since "1 hour ago"

# Logs de errores solamente
sudo journalctl -u chirpstack-supabase -p err --since today

# Logs en tiempo real con filtros
sudo journalctl -u chirpstack-supabase -f | grep -E "(ERROR|WARN|✅|❌)"
```

## 🔄 Actualización del Servicio

```bash
# 1. Detener servicio
sudo systemctl stop chirpstack-supabase

# 2. Hacer backup de configuración
sudo cp /opt/chirpstack-supabase-service/.env /opt/chirpstack-supabase-service/.env.backup

# 3. Actualizar archivos
cd chirpstack_agricos
sudo cp -r services/supabase/* /opt/chirpstack-supabase-service/

# 4. Actualizar dependencias
cd /opt/chirpstack-supabase-service
sudo npm install

# 5. Restaurar configuración
sudo cp /opt/chirpstack-supabase-service/.env.backup /opt/chirpstack-supabase-service/.env

# 6. Reiniciar servicio
sudo systemctl start chirpstack-supabase
```

## 📞 Soporte

### Archivos de Log
- **Servicio:** `sudo journalctl -u chirpstack-supabase -f`
- **Sistema:** `/var/log/syslog`
- **Aplicación:** `/opt/chirpstack-supabase-service/logs/` (si está configurado)

### Información de Debug

```bash
# Información completa del servicio
sudo systemctl show chirpstack-supabase

# Verificar configuración Node.js
node --version
npm --version

# Verificar conectividad
ping tu-proyecto.supabase.co
```

---

¡El servicio ChirpStack-Supabase debería estar funcionando correctamente! Los datos de tus sensores LoRaWAN se almacenarán automáticamente en tu base de datos Supabase.