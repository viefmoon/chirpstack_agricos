# Guía Completa: Despliegue Nativo de ChirpStack v4 en DigitalOcean

Esta guía te llevará paso a paso para deployar una infraestructura completa de ChirpStack v4 de forma nativa en un droplet de DigitalOcean desde cero, siguiendo la guía oficial de ChirpStack.

> **Instalación Nativa con Ubuntu 24.04 LTS:** Esta guía sigue la documentación oficial de ChirpStack aprovechando las mejoras de seguridad, rendimiento y compatibilidad de Ubuntu 24.04 LTS, combinadas con ChirpStack v4 que unifica el Network Server y Application Server en un solo componente.

## ⚡ Instalación Rápida

Si quieres ir directo al grano:

```bash
# Si reconstruiste el droplet, borra las claves SSH:
ssh-keygen -R 143.244.144.51

# Conectar al servidor
ssh root@143.244.144.51

# Descargar e instalar (completo con HTTPS automático)
git clone https://github.com/viefmoon/chirpstack_agricos.git
cd chirpstack_agricos
chmod +x *.sh
sudo ./install.sh

# CRÍTICO: Cambiar contraseña admin
# - Ir a: https://network.sense.lat
# - Login: admin/admin → Avatar → Change password

# DNS ya configurado: network.sense.lat → 143.244.144.51
# Acceso final: https://network.sense.lat
```

## Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Configuración del Droplet DigitalOcean](#configuración-del-droplet-digitalocean)
3. [Preparación del Servidor](#preparación-del-servidor)
4. [Instalación de Dependencias](#instalación-de-dependencias)
5. [Instalación de ChirpStack v4](#instalación-de-chirpstack-v4)
6. [Configuración de Seguridad](#configuración-de-seguridad)
7. [Verificación y Testing](#verificación-y-testing)
8. [Mantenimiento y Troubleshooting](#mantenimiento-y-troubleshooting)

## Requisitos Previos

- Cuenta de DigitalOcean
- Conocimientos básicos de Linux/Ubuntu
- Cliente SSH (PuTTY, Terminal, etc.)
- Dominio opcional para HTTPS

## Configuración del Droplet DigitalOcean

### 1. Crear el Droplet

1. **Accede a tu panel de DigitalOcean**
2. **Crear nuevo Droplet:**
   - **Imagen:** Ubuntu 24.04 LTS x64
   - **Tipo:** Basic
   - **CPU:** 2 vCPUs, 4GB RAM, 80GB SSD (mínimo recomendado)
   - **Región:** Selecciona la más cercana a tu ubicación
   - **Autenticación:** SSH Key (recomendado) o contraseña
   - **Hostname:** `chirpstack-server`

3. **Configurar red:**
   - Habilitar IPv6 (opcional)
   - Habilitar monitoreo (recomendado)

### 2. Configuración inicial de red

Tu droplet ChirpStack tiene la IP pública: **`143.244.144.51`**

### 3. Configuración de DNS para `network.sense.lat`

Para configurar ChirpStack en `network.sense.lat` usando DigitalOcean DNS:

1. **Verificar que `sense.lat` esté en DigitalOcean DNS:**
   - Ve a **Networking** → **Domains**
   - Si no ves `sense.lat`, agrégalo con **Add Domain**
   - Asegúrate de que los nameservers estén configurados en tu registrador

2. **Agregar subdominio para ChirpStack:**
   - En la página de `sense.lat`, clic **Add Record**
   - **Tipo:** `A`
   - **Hostname:** `network`
   - **Will direct to:** Selecciona tu droplet ChirpStack
   - **TTL:** 3600 (1 hour)
   - Clic **Create Record**

3. **Resultado:** ChirpStack será accesible en `https://network.sense.lat`

## 📋 Pasos Específicos para Configurar `network.sense.lat`

### Opción A: Si `sense.lat` ya está en DigitalOcean DNS

1. **Ir a DigitalOcean:**
   - Panel → **Networking** → **Domains**
   - Clic en `sense.lat`

2. **Agregar registro A:**
   - Clic **Add Record**
   - **Type:** A
   - **Hostname:** `network`
   - **Will direct to:** Selecciona tu droplet ChirpStack
   - **TTL:** 3600
   - Clic **Create Record**

3. **Verificar:** En 5-10 minutos `network.sense.lat` apuntará a tu servidor

### Opción B: Si `sense.lat` NO está en DigitalOcean DNS

1. **Agregar dominio completo:**
   - Panel → **Networking** → **Domains**
   - Clic **Add Domain**
   - Ingresa: `sense.lat`
   - Selecciona tu droplet ChirpStack
   - Clic **Add Domain**

2. **Configurar nameservers en tu registrador:**
   - Ve al panel donde compraste `sense.lat`
   - Cambia nameservers a:
     - `ns1.digitalocean.com`
     - `ns2.digitalocean.com`
     - `ns3.digitalocean.com`

3. **Agregar subdominio network:**
   - Volver a DigitalOcean → **Domains** → `sense.lat`
   - Clic **Add Record**
   - **Type:** A, **Hostname:** `network`, **Directs to:** tu droplet

4. **Esperar propagación:** 1-24 horas para nameservers, 5-10 minutos para registro A

## Preparación del Servidor

### 1. Conexión SSH

```bash
# Si reconstruiste el droplet:
ssh-keygen -R 143.244.144.51

ssh root@143.244.144.51
```

### 2. Actualizar el sistema

```bash
apt update && apt upgrade -y
```

### 3. Configurar zona horaria

```bash
timedatectl set-timezone America/Mexico_City  # Ajusta según tu ubicación
```

## Instalación de Dependencias (Nativa)

### 1. Instalar requisitos de ChirpStack según guía oficial

```bash
# Instalar servicios base
apt install -y \
    mosquitto \
    mosquitto-clients \
    redis-server \
    redis-tools \
    postgresql \
    gpg

# Iniciar y habilitar servicios
systemctl start mosquitto
systemctl enable mosquitto
systemctl start redis-server  
systemctl enable redis-server
systemctl start postgresql
systemctl enable postgresql
```

### 2. Configurar PostgreSQL

```bash
# Configurar base de datos
sudo -u postgres psql << 'EOF'
-- create role for authentication
CREATE ROLE chirpstack WITH LOGIN PASSWORD 'chirpstack';

-- create database
CREATE DATABASE chirpstack WITH OWNER chirpstack;

-- change to chirpstack database
\c chirpstack

-- create pg_trgm extension
CREATE EXTENSION pg_trgm;

-- exit psql
\q
EOF
```

### 3. Configurar repositorio ChirpStack

```bash
# Configurar clave GPG
sudo mkdir -p /etc/apt/keyrings/
sudo sh -c 'wget -q -O - https://artifacts.chirpstack.io/packages/chirpstack.key | gpg --dearmor > /etc/apt/keyrings/chirpstack.gpg'

# Agregar repositorio
echo "deb [signed-by=/etc/apt/keyrings/chirpstack.gpg] https://artifacts.chirpstack.io/packages/4.x/deb stable main" | sudo tee /etc/apt/sources.list.d/chirpstack.list

# Actualizar cache de paquetes
apt update
```

### 4. Instalar herramientas adicionales

```bash
apt install -y \
    curl \
    wget \
    git \
    htop \
    nano \
    ufw \
    certbot \
    python3-certbot-nginx \
    nginx
```

## Instalación Nativa de ChirpStack v4

### 1. Instalar ChirpStack Gateway Bridge

```bash
# Instalar desde repositorio oficial
apt install -y chirpstack-gateway-bridge
```

### 2. Configurar ChirpStack Gateway Bridge para US915

```bash
# Configurar para región US915
cat > /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml << EOF
[general]
log_level=4

[backend.semtech_udp]
bind="0.0.0.0:1700"

[integration.mqtt]
server="tcp://localhost:1883"
client_id_template="chirpstack-gateway-bridge-{{ .GatewayID }}"

# US915 region configuration
event_topic_template="us915_0/gateway/{{ .GatewayID }}/event/{{ .EventType }}"
state_topic_template="us915_0/gateway/{{ .GatewayID }}/state/{{ .StateType }}"
command_topic_template="us915_0/gateway/{{ .GatewayID }}/command/#"

[integration.mqtt.stats]
enabled=true
interval="30s"
EOF
```

### 3. Instalar ChirpStack

```bash
# Instalar desde repositorio oficial
apt install -y chirpstack
```

### 4. Configurar ChirpStack para US915

```bash
# Configurar para región US915
cat > /etc/chirpstack/chirpstack.toml << EOF
[postgresql]
dsn="postgres://chirpstack:chirpstack@localhost/chirpstack?sslmode=disable"

[redis]
servers=["redis://localhost:6379"]

[network]
net_id="000000"
enabled_regions=["us915_0"]

[api]
bind="0.0.0.0:8080"
secret="$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)"

[gateway.backend.mqtt]
server="tcp://localhost:1883"
client_id_template="chirpstack-gateway-{{ .GatewayID }}"

[integration.mqtt]
server="tcp://localhost:1883"
client_id_template="chirpstack-application-{{ .ApplicationID }}"

[join_server]
bind="0.0.0.0:8003"
EOF
```

### 5. Iniciar servicios ChirpStack

```bash
# Iniciar y habilitar servicios
systemctl start chirpstack-gateway-bridge
systemctl enable chirpstack-gateway-bridge

systemctl start chirpstack
systemctl enable chirpstack
### 6. Usar scripts de instalación automática

```bash
# Descargar scripts de instalación
git clone https://github.com/viefmoon/chirpstack_agricos.git
cd chirpstack_agricos
chmod +x *.sh

# Ejecutar instalación automática completa
sudo ./install.sh
```

O si prefieres instalación manual paso a paso:

```bash
# 1. Instalar dependencias nativas
sudo ./scripts/install-dependencies.sh

# 2. Configurar ChirpStack nativo
sudo ./scripts/configure-chirpstack.sh

# 3. Configurar seguridad y HTTPS
sudo ./scripts/setup-security.sh
```

> **⚠️ IMPORTANTE - Configuración de Región LoRaWAN:**
> 
> La región determina las **frecuencias y parámetros de radio** que usará tu red LoRaWAN. **Debe coincidir con tu ubicación geográfica y gateway**. Una configuración incorrecta impedirá que los dispositivos se conecten.
>
> **Regiones comunes:**
> - **US915_0:** Estados Unidos, Canadá, México, Brasil (canales 0-7)
> - **EU868:** Europa, África, Rusia
> - **AS923:** Asia-Pacífico (Japón, Singapur, etc.)
> - **AU915_0:** Australia, Nueva Zelanda (canales 0-7)
> - **CN470_10:** China
> - **IN865:** India

Los scripts configuran automáticamente la región **US915_0** para Estados Unidos/México. Las configuraciones se almacenan en:

- **ChirpStack:** `/etc/chirpstack/chirpstack.toml`
- **Gateway Bridge:** `/etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml`

### 7. Verificar instalación nativa

```bash
# Verificar estado de todos los servicios
systemctl status chirpstack
systemctl status chirpstack-gateway-bridge
systemctl status mosquitto
systemctl status redis-server
systemctl status postgresql

# O usar script de utilidad (si usaste instalación automática)
/opt/chirpstack-status.sh
```

### 8. Verificar conectividad

```bash
# Verificar puertos abiertos
netstat -tlnp | grep -E '(8080|1700|1883)'

# Probar interfaz web
curl -I http://localhost:8080

# Ver logs en tiempo real (Ctrl+C para salir)
journalctl -f -u chirpstack -u chirpstack-gateway-bridge
```


## Configuración de Seguridad

### 1. Configurar Firewall (UFW)

```bash
# Habilitar UFW
ufw enable

# Permitir SSH
ufw allow ssh

# Permitir HTTP y HTTPS
ufw allow 80
ufw allow 443

# Permitir puertos específicos de ChirpStack
ufw allow 8080  # Web interface
ufw allow 1700/udp  # Gateway bridge
ufw allow 1883  # MQTT

# Verificar estado
ufw status
```

### 2. Configurar Nginx como Reverse Proxy

```bash
nano /etc/nginx/sites-available/chirpstack
```

**Contenido del archivo:**

```nginx
server {
    listen 80;
    server_name your-domain.com;  # Cambiar por tu dominio

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

```bash
# Habilitar sitio
ln -s /etc/nginx/sites-available/chirpstack /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# Verificar configuración
nginx -t

# Recargar Nginx
systemctl reload nginx
```

### 3. Configurar HTTPS con Let's Encrypt

```bash
# Obtener certificado SSL
certbot --nginx -d your-domain.com

# Verificar renovación automática
certbot renew --dry-run
```

## Verificación y Testing

### 1. Verificar servicios

```bash
# Verificar contenedores Docker
docker-compose ps

# Verificar logs generales
docker-compose logs chirpstack
docker-compose logs chirpstack-gateway-bridge

# IMPORTANTE: Verificar que la región esté cargada correctamente
docker-compose logs chirpstack | grep -i region
```

**Salida esperada para región:**
```
chirpstack_1  | INFO chirpstack::config: region configuration loaded, region=us915_0
```

Si no ves la región correcta, edita `/opt/chirpstack-docker/.env` y reinicia con `docker-compose restart`.

### 2. Acceso a la interfaz web

1. Abrir navegador y ir a: `http://143.244.144.51:8080` o `https://network.sense.lat`
2. **Credenciales por defecto:**
   - Usuario: `admin`
   - Contraseña: `admin`

### 3. Cambiar contraseña por defecto

1. Acceder al panel web
2. Ir to **Settings** → **Account**
3. Cambiar contraseña del usuario admin

### 4. Configurar primera aplicación

1. **Crear Tenant:**
   - Ir a **Tenants** → **Add tenant**
   - Nombre: `Mi Organización`

2. **Crear Application:**
   - Seleccionar tenant creado
   - Ir a **Applications** → **Add application**
   - Nombre: `Mi Primera App`

3. **Registrar Gateway:**
   - Ir a **Gateways** → **Add gateway**
   - Gateway ID: MAC de tu gateway
   - Configurar según tu hardware

## Mantenimiento y Troubleshooting

### Comandos útiles (Instalación Nativa)

```bash
# Ver logs en tiempo real
journalctl -f -u chirpstack -u chirpstack-gateway-bridge

# Reiniciar servicios
systemctl restart chirpstack
systemctl restart chirpstack-gateway-bridge
systemctl restart mosquitto

# O usar script de utilidad
/opt/chirpstack-restart.sh

# Actualizar ChirpStack
apt update && apt upgrade chirpstack chirpstack-gateway-bridge

# Backup de base de datos
pg_dump -U chirpstack -h localhost chirpstack > backup.sql

# Verificar puertos abiertos
netstat -tlnp | grep -E '(8080|1700|1883)'

# Estado completo del sistema
/opt/chirpstack-status.sh
```

### Troubleshooting común (Instalación Nativa)

#### 1. No se puede acceder a la interfaz web

```bash
# Verificar que Nginx esté corriendo
systemctl status nginx

# Verificar que ChirpStack esté corriendo
systemctl status chirpstack

# Verificar logs
journalctl -u chirpstack -n 50
journalctl -u nginx -n 20
```

#### 2. Gateway no se conecta 

```bash
# Verificar logs del gateway bridge
journalctl -u chirpstack-gateway-bridge -f

# Verificar Mosquitto MQTT
systemctl status mosquitto
journalctl -u mosquitto -n 20

# Verificar que el puerto UDP 1700 esté abierto
ufw status | grep 1700
netstat -ulnp | grep 1700
```

#### 3. Problemas de base de datos

```bash
# Verificar PostgreSQL
systemctl status postgresql
journalctl -u postgresql -n 20

# Conectar directamente a la base de datos
sudo -u postgres psql chirpstack

# Verificar conexión desde ChirpStack
psql -U chirpstack -h localhost -d chirpstack
```

### Monitoreo (Instalación Nativa)

#### 1. Scripts de monitoreo incluidos

Los scripts de instalación automática crean utilidades de monitoreo:

```bash
# Estado completo de servicios
/opt/chirpstack-status.sh

# Ver logs en tiempo real
/opt/chirpstack-logs.sh

# Reiniciar todos los servicios
/opt/chirpstack-restart.sh
```

#### 2. Monitoreo manual de servicios

```bash
# Estado de servicios críticos
systemctl status chirpstack chirpstack-gateway-bridge mosquitto postgresql redis-server

# Uso de recursos
htop
df -h
free -h

# Conexiones de red
netstat -tlnp | grep -E '(8080|1700|1883)'
ss -tlnp | grep -E '(8080|1700|1883)'
```

#### 3. Configurar monitoreo automático

```bash
# Crear script personalizado de monitoreo
cat > /opt/monitor-chirpstack-native.sh << 'EOF'
#!/bin/bash
echo "=== ChirpStack Native Health Check ==="
echo "Date: $(date)"
echo ""

echo "Service Status:"
systemctl is-active chirpstack chirpstack-gateway-bridge mosquitto postgresql redis-server

echo ""
echo "System resources:"
df -h / | tail -1
free -h | grep Mem

echo ""
echo "Network ports:"
netstat -tlnp | grep -E '(8080|1700|1883)'
EOF

chmod +x /opt/monitor-chirpstack-native.sh

# Configurar cron para monitoreo
crontab -e

# Agregar línea para ejecutar cada 5 minutos
*/5 * * * * /opt/monitor-chirpstack-native.sh >> /var/log/chirpstack-monitor.log 2>&1
```

## Scripts de Automatización (Instalación Nativa)

Los siguientes scripts están incluidos para instalación nativa:

### Scripts principales:
- `install.sh` - **Instalador completo automático**
- `complete-clean-install.sh` - Limpieza completa para reinstalación 

### Scripts modulares:
- `scripts/install-dependencies.sh` - Instalación de PostgreSQL, Redis, Mosquitto
- `scripts/configure-chirpstack.sh` - Configuración nativa de ChirpStack v4
- `scripts/setup-security.sh` - Configuración de seguridad y HTTPS
- `scripts/setup-supabase-service.sh` - Servicio opcional Supabase

### Scripts de utilidad (creados automáticamente):
- `/opt/chirpstack-status.sh` - Estado de todos los servicios
- `/opt/chirpstack-logs.sh` - Ver logs en tiempo real
- `/opt/chirpstack-restart.sh` - Reiniciar todos los servicios

## Conclusión

¡Felicidades! Has deployado exitosamente **ChirpStack v4 nativo** en DigitalOcean siguiendo la guía oficial. Tu servidor LoRaWAN está listo para:

- ✅ **Gateway detectado correctamente** (sin problemas MQTT)
- ✅ **Gestión de dispositivos LoRa** con región US915_0 
- ✅ **Aplicaciones IoT** con integración MQTT nativa
- ✅ **Monitoreo con systemd** (más estable que Docker)
- ✅ **Rendimiento optimizado** (sin overhead de Docker)

### Próximos pasos recomendados:

1. **🔒 Cambiar contraseña admin** en http://143.244.144.51:8080
2. **🔧 Configurar HTTPS** con `sudo ./scripts/setup-security.sh`
3. **📡 Configurar tu primer gateway** (región US915_0)
4. **📱 Registrar dispositivos de prueba**
5. **🔗 Configurar integraciones** (HTTP, MQTT, Supabase)
6. **📊 Implementar monitoreo** con scripts incluidos

### Comandos útiles para recordar:

```bash
# Estado completo
/opt/chirpstack-status.sh

# Ver logs 
/opt/chirpstack-logs.sh

# Reiniciar servicios
/opt/chirpstack-restart.sh

# Configurar HTTPS
sudo ./scripts/setup-security.sh
```

### Recursos adicionales:

- [Documentación oficial ChirpStack](https://www.chirpstack.io/docs/)
- [Guía oficial de instalación nativa](https://www.chirpstack.io/docs/chirpstack/installation/debian-ubuntu/)
- [Repositorio GitHub](https://github.com/chirpstack/chirpstack)
- [Foro de la comunidad](https://forum.chirpstack.io/)

---

**✅ Instalación Nativa Completa:** Esta guía implementa la instalación nativa recomendada por ChirpStack, proporcionando mejor rendimiento, estabilidad y facilidad de mantenimiento que las alternativas con Docker.