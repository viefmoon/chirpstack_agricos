# ChirpStack v4 en DigitalOcean - Guía de Despliegue Automático v2.0

Esta es una guía completa para deployar ChirpStack v4 en un droplet de DigitalOcean desde cero, incluyendo scripts de automatización y servicio opcional de integración con Supabase.

> **ChirpStack v4 + Ubuntu 24.04 LTS:** Combinación optimizada que unifica el Network Server y Application Server en un solo componente, aprovechando las últimas mejoras de seguridad y rendimiento de Ubuntu 24.04.

## ⚡ Instalación Súper Rápida

```bash
# 1. Conectar al servidor
ssh root@143.244.144.51

# 2. Descargar y ejecutar (100% automático con HTTPS)
git clone https://github.com/viefmoon/chirpstack_agricos.git
cd chirpstack_agricos
chmod +x install.sh
sudo ./install.sh

# ¡Eso es todo! El script hace TODO automáticamente:
# - Instala dependencias (Docker, Node.js, Nginx)
# - Configura ChirpStack v4 con regiones oficiales
# - Configura HTTPS automático para network.sense.lat
# - Configura firewall y seguridad avanzada
# - Instala servicio ChirpStack-Supabase (opcional)

# 3. CAMBIAR CONTRASEÑA (CRÍTICO):
#    - Ir a: https://network.sense.lat
#    - Login: admin/admin
#    - Avatar → Change password

# DNS ya configurado: network.sense.lat → 143.244.144.51
# Acceso final: https://network.sense.lat
```

## 📁 Estructura del Repositorio

```
chirpstack_agricos/
├── install.sh                          # 🚀 Instalador principal
├── README.md                           # 📖 Esta documentación
├── scripts/                            # 📜 Scripts de instalación
│   ├── install-dependencies.sh         #   • Dependencias del sistema
│   ├── configure-chirpstack.sh         #   • Configuración de ChirpStack
│   ├── setup-security.sh               #   • Configuración de seguridad
│   ├── setup-supabase-service.sh       #   • Servicio ChirpStack-Supabase
│   └── backup-chirpstack.sh            #   • Backup y restauración
├── services/                           # 🔗 Servicios adicionales
│   └── supabase/                       #   • Integración con Supabase
│       ├── chirpstack-supabase-service.js  #   • Servicio Node.js
│       ├── package.json                #   • Dependencias npm
│       └── .env.example                #   • Plantilla de configuración
└── docs/                               # 📚 Documentación
    └── chirpstack-digitalocean-deployment-guide.md  # Guía detallada
```

## 🚀 Instalación Rápida (Automática)

### Paso 1: Preparar el Servidor

1. **Crear droplet Ubuntu 24.04 LTS en DigitalOcean (mínimo 2GB RAM)**
2. **Configurar dominio (opcional pero recomendado):**
   - En DigitalOcean: **Networking** → **Domains** → **Add Domain**
   - Ingresa tu dominio y selecciona el droplet
   - Cambiar nameservers en tu registrador a los de DigitalOcean
3. **Conectar vía SSH como root:**
   ```bash
   ssh root@143.244.144.51
   ```
   
   > **💡 Si reconstruiste el droplet**, borra las claves SSH anteriores:
   > ```bash
   > ssh-keygen -R 143.244.144.51
   > ```

### Paso 2: Descargar e Instalar

```bash
# Clonar repositorio
git clone https://github.com/viefmoon/chirpstack_agricos.git
cd chirpstack_agricos

# Hacer script principal ejecutable
chmod +x install.sh

# Verificar estructura
tree -L 2
```

### Paso 3: Ejecutar Instalación

#### Opción A: Instalación Automática Completa (Recomendado)
```bash
# Instalación completa con HTTPS automático
sudo ./install.sh
```

#### Opción B: Instalación Manual (Paso a Paso)
```bash
# 1. Instalar dependencias (Docker, Nginx, etc.)
sudo ./scripts/install-dependencies.sh

# 2. Configurar ChirpStack
sudo ./scripts/configure-chirpstack.sh

# 3. Configurar seguridad (opcional pero recomendado)
sudo ./scripts/setup-security.sh

# 4. Configurar servicio Supabase (opcional)
sudo ./scripts/setup-supabase-service.sh
```

## 🔧 Instalación Manual

Si prefieres seguir el proceso paso a paso, consulta la guía completa en `chirpstack-digitalocean-deployment-guide.md`.

## 📋 Descripción de Scripts

### Instalador Principal

#### install.sh
**Qué hace:**
- Orchestador principal que ejecuta todos los scripts en orden
- Verifica estructura del repositorio
- Maneja configuración automática de región y dominio
- Genera resumen completo de instalación

**Uso:**
```bash
sudo ./install.sh
```

### Scripts de Instalación

#### 1. scripts/install-dependencies.sh

**Qué hace:**
- Actualiza el sistema Ubuntu
- Instala Docker y Docker Compose
- Instala herramientas básicas (nginx, ufw, certbot, etc.)
- Crea usuario `chirpstack`
- Configura firewall básico
- Optimiza configuración del sistema

**Uso:**
```bash
sudo ./scripts/install-dependencies.sh
```

#### 2. scripts/configure-chirpstack.sh

**Qué hace:**
- Clona el repositorio Docker de ChirpStack
- Configura variables de entorno automáticamente
- Genera contraseñas seguras para PostgreSQL
- Configura Docker Compose para producción
- Inicia todos los servicios
- Configura Nginx como reverse proxy
- Crea scripts de utilidad

**Uso:**
```bash
sudo ./scripts/configure-chirpstack.sh
```

**Resultado:**
- ChirpStack accesible en `https://network.sense.lat`
- Usuario: `admin` / Contraseña: `admin`

#### 3. scripts/setup-security.sh

**Qué hace:**
- Instala y configura fail2ban
- Configura reglas iptables avanzadas
- Configura HTTPS con Let's Encrypt (si tienes dominio)
- Implementa headers de seguridad en Nginx
- Configura monitoreo de seguridad automático
- Configura backups automáticos

**Uso:**
```bash
sudo ./scripts/setup-security.sh
```

Durante la ejecución te preguntará si tienes un dominio configurado para habilitar HTTPS.

#### 4. scripts/setup-supabase-service.sh

**Qué hace:**
- Instala Node.js LTS automáticamente
- Crea usuario del sistema para el servicio
- Configura servicio systemd con reinicio automático
- Crea scripts de utilidad para manejo del servicio
- Configura permisos de seguridad

**Uso:**
```bash
sudo ./scripts/setup-supabase-service.sh
```

#### 5. scripts/backup-chirpstack.sh

**Qué hace:**
- Crea backups completos de ChirpStack
- Incluye base de datos, configuraciones y certificados SSL
- Permite restauración completa del sistema
- Limpieza automática de backups antiguos

**Uso:**
```bash
# Backup completo
sudo ./scripts/backup-chirpstack.sh

# Solo base de datos
sudo ./scripts/backup-chirpstack.sh --database

# Solo configuraciones
sudo ./scripts/backup-chirpstack.sh --config

# Listar backups
sudo ./scripts/backup-chirpstack.sh --list

# Restaurar backup
sudo ./scripts/backup-chirpstack.sh --restore backup_file.tar.gz

# Limpiar backups antiguos
sudo ./scripts/backup-chirpstack.sh --cleanup
```

### Servicios Adicionales

#### services/supabase/
**Contiene:**
- `chirpstack-supabase-service.js` - Servicio Node.js para insertar datos en Supabase
- `package.json` - Dependencias npm (mqtt, @supabase/supabase-js, dotenv)  
- `.env.example` - Plantilla de configuración de entorno

## 🔍 Acceso Post-Instalación

1. **Abrir navegador:** `https://network.sense.lat`
2. **Login:** `admin` / `admin`  
3. **¡IMPORTANTE!** Cambiar contraseña inmediatamente

## 🔗 Servicio ChirpStack-Supabase (Opcional)

El servicio permite almacenar automáticamente las mediciones de sensores LoRaWAN en Supabase.

### Configuración Rápida

```bash
# 1. Configurar credenciales de Supabase (interactivo)
sudo /opt/chirpstack-supabase-service/configure-env.sh

# 2. Iniciar el servicio
sudo systemctl start chirpstack-supabase

# 3. Verificar que esté funcionando
sudo systemctl status chirpstack-supabase
```

### Comandos del Servicio

```bash
# Iniciar servicio
sudo systemctl start chirpstack-supabase

# Detener servicio  
sudo systemctl stop chirpstack-supabase

# Reiniciar servicio
sudo systemctl restart chirpstack-supabase

# Ver estado
sudo systemctl status chirpstack-supabase

# Ver logs en tiempo real
sudo journalctl -u chirpstack-supabase -f
```

### Configuración Manual

Editar archivo de configuración:
```bash
sudo nano /opt/chirpstack-supabase-service/.env
```

Variables requeridas:
```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key-aqui
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_TOPIC=application/#
```

### Estructura de Base de Datos

El servicio crea automáticamente registros en estas tablas:

- **`stations`** - Estaciones de medición
- **`devices`** - Dispositivos LoRaWAN  
- **`sensors`** - Sensores individuales
- **`sensor_types`** - Tipos de sensores (TEMP, HUM, PH, etc.)
- **`readings`** - Lecturas de sensores
- **`voltage_readings`** - Lecturas de voltaje de dispositivos

### Sensores Soportados

El servicio reconoce automáticamente estos sensores:

#### Sensores Simples:
- **N100K/N10K** - Temperatura
- **HDS10** - Humedad
- **RTD/DS18B20** - Temperatura  
- **PH** - pH
- **COND** - Conductividad
- **SOILH** - Humedad del suelo
- **VEML7700** - Luminosidad

#### Sensores Múltiples:
- **SHT30/SHT40** - Temperatura + Humedad
- **BME280/BME680** - Temperatura + Humedad + Presión (+ Gas)
- **CO2** - CO2 + Temperatura + Humedad
- **ENV4** - Humedad + Temperatura + Presión + Luminosidad

## 📊 Monitoreo y Mantenimiento

### Scripts de Utilidad Creados

```bash
# Iniciar ChirpStack
/opt/chirpstack-docker/start-chirpstack.sh

# Detener ChirpStack  
/opt/chirpstack-docker/stop-chirpstack.sh

# Ver logs en tiempo real
/opt/chirpstack-docker/logs-chirpstack.sh

# Ver estado del sistema
/opt/chirpstack-docker/status-chirpstack.sh

# Monitoreo de seguridad
/opt/security-monitor.sh
```

### Tareas Automáticas Configuradas

- **Backup diario:** 02:00 AM
- **Reporte de seguridad:** 06:00 AM  
- **Renovación SSL:** 03:00 AM (si aplica)
- **Limpieza de logs:** Rotación diaria

## 🔧 Configuración Avanzada

### Cambiar Región LoRaWAN

**⚠️ CRÍTICO:** La región debe coincidir con tu ubicación geográfica y gateway.

#### Regiones Disponibles (ID de configuración):
- **us915_0:** Estados Unidos, Canadá, México, Brasil (canales 0-7)
- **us915_1:** Estados Unidos, Canadá, México, Brasil (canales 8-15)  
- **eu868:** Europa, África, Rusia  
- **as923:** Asia-Pacífico (Japón, Singapur, etc.)
- **au915_0:** Australia, Nueva Zelanda (canales 0-7)
- **cn470_10:** China
- **in865:** India

#### Cambiar Región Antes de Instalar:
```bash
# Editar install.sh antes de ejecutar
nano install.sh

# Cambiar línea:
LORAWAN_REGION="eu868"  # Cambiar por tu región
```

#### Cambiar Región Después de Instalar:
```bash
# Editar archivo de configuración
nano /opt/chirpstack-docker/.env

# Cambiar línea:  
CHIRPSTACK_REGION=eu868  # Cambiar por tu región

# Editar configuración principal
nano /opt/chirpstack-docker/configuration/chirpstack/chirpstack.toml

# Cambiar línea:
enabled_regions=["eu868"]  # Tu región

# Reiniciar servicios
cd /opt/chirpstack-docker
docker-compose restart
```

#### Verificar Configuración:
```bash
# Ver logs para confirmar región cargada
docker-compose logs chirpstack | grep -i region
```

### Configurar `network.sense.lat`

1. **En el panel de DigitalOcean:**
   - Ve a **Networking** → **Domains**
   - Busca `sense.lat` (si no existe, agrégalo primero)
   - Clic **Add Record**
   - **Tipo:** A, **Hostname:** network, **Directs to:** tu droplet

2. **Ejecutar script de seguridad:**
   ```bash
   sudo ./setup-security.sh
   # Ingresa: network.sense.lat
   ```

**Resultado:** ChirpStack accesible en `https://network.sense.lat`

### Integrar con Gateway Externo

Los gateways pueden conectarse usando:
- **UDP Packet Forwarder:** Puerto 1700/UDP
- **MQTT:** Puerto 1883
- **Basics Station:** Websocket en puerto 3001

## 🚨 Troubleshooting

### Problema: No se puede acceder a la interfaz web

```bash
# Verificar servicios
docker-compose ps
systemctl status nginx

# Verificar logs
docker-compose logs chirpstack
tail -f /var/log/nginx/error.log
```

### Problema: Gateway no se conecta

```bash
# Verificar gateway bridge
docker-compose logs chirpstack-gateway-bridge

# Verificar puerto UDP
ufw status | grep 1700
netstat -ulnp | grep 1700

# IMPORTANTE: Verificar que la región coincida
docker-compose logs chirpstack | grep -i region
```

**Causa común:** Región mal configurada
- Gateway configurado para EU868 pero ChirpStack en US915
- Solución: Cambiar región en `/opt/chirpstack-docker/.env`

### Problema: Servicios no funcionan

```bash
# Reiniciar servicios
cd /opt/chirpstack-docker
docker-compose restart

# Ver logs si hay problemas
docker-compose logs chirpstack
```

## 📝 Requisitos del Sistema

### Mínimos
- **OS:** Ubuntu 24.04 LTS x64
- **RAM:** 2GB
- **Almacenamiento:** 20GB SSD
- **CPU:** 1 vCPU
- **Ancho de banda:** 1TB

### Recomendados (Producción)
- **OS:** Ubuntu 24.04 LTS x64
- **RAM:** 4GB
- **Almacenamiento:** 80GB SSD  
- **CPU:** 2 vCPUs
- **Ancho de banda:** Ilimitado

### Beneficios de Ubuntu 24.04 LTS
- **5 años de soporte** (hasta 2029)
- **Mejoras de seguridad** con kernel 6.8
- **Mejor rendimiento** de contenedores
- **Actualizaciones de seguridad** automáticas

## 🔐 Consideraciones de Seguridad

### Configuraciones Aplicadas
- Fail2ban para protección contra ataques de fuerza bruta
- Firewall UFW configurado
- Headers de seguridad en Nginx
- HTTPS con Let's Encrypt (si tienes dominio)
- Reglas iptables avanzadas
- Monitoreo de seguridad automático

### Recomendaciones Adicionales
- Cambiar contraseña de admin inmediatamente
- Configurar claves SSH en lugar de contraseñas
- Monitorear logs regularmente
- Mantener sistema actualizado
- Hacer backups regulares

## 🆘 Soporte

### Archivos de Log Importantes
- ChirpStack: `docker-compose logs chirpstack`
- Nginx: `/var/log/nginx/chirpstack.error.log`
- Sistema: `/var/log/syslog`
- Seguridad: `/var/log/chirpstack/security-report.log`

### Recursos Útiles
- [Documentación oficial ChirpStack](https://www.chirpstack.io/docs/)
- [Foro de la comunidad](https://forum.chirpstack.io/)
- [GitHub ChirpStack](https://github.com/chirpstack/chirpstack)

## 📄 Licencia

Esta guía y scripts están disponibles bajo licencia MIT. Úsalos libremente para tus proyectos.

---

**¡Importante!** Recuerda cambiar la contraseña por defecto (`admin`/`admin`) inmediatamente después de la instalación.