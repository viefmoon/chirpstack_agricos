# Guía Completa: Despliegue de ChirpStack v4 en DigitalOcean

Esta guía te llevará paso a paso para deployar una infraestructura completa de ChirpStack v4 en un droplet de DigitalOcean desde cero.

> **Optimizado para Ubuntu 24.04 LTS:** Esta guía aprovecha las mejoras de seguridad, rendimiento y compatibilidad de Ubuntu 24.04 LTS, combinadas con ChirpStack v4 que unifica el Network Server y Application Server en un solo componente.

## ⚡ Instalación Rápida

Si quieres ir directo al grano:

```bash
# Conectar al servidor
ssh root@143.244.144.51

# Descargar e instalar
git clone https://github.com/viefmoon/chirpstack_agricos.git
cd chirpstack_agricos
chmod +x *.sh
sudo ./quick-install.sh

# CRÍTICO: Cambiar contraseña admin
# - Ir a: http://143.244.144.51:8080
# - Login: admin/admin → Avatar → Change password

# Configurar DNS: network.sense.lat → 143.244.144.51
# Acceder: https://network.sense.lat
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

### 4. Crear usuario para ChirpStack

```bash
adduser chirpstack
usermod -aG sudo chirpstack
```

## Instalación de Dependencias

### 1. Instalar Docker y Docker Compose

```bash
# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Agregar usuario al grupo docker
usermod -aG docker chirpstack

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 2. Instalar herramientas adicionales

```bash
apt install -y \
    curl \
    wget \
    git \
    htop \
    nano \
    ufw \
    certbot \
    nginx
```

## Instalación de ChirpStack v4

### 1. Descargar scripts de configuración

```bash
# Crear directorio de trabajo y descargar scripts
mkdir -p /opt/chirpstack-setup
cd /opt/chirpstack-setup
git clone https://github.com/viefmoon/chirpstack_agricos.git .
chmod +x *.sh

# Ejecutar instalación automática
./quick-install.sh
```

O si prefieres instalación manual paso a paso:

```bash
# 1. Instalar dependencias
./install-dependencies.sh

# 2. Configurar ChirpStack
./configure-chirpstack.sh

# 3. Configurar seguridad y HTTPS
./setup-security.sh
```

### 2. Configurar variables de entorno

```bash
# Copiar archivo de configuración de ejemplo
cp .env.example .env

# Editar configuración
nano .env
```

> **⚠️ IMPORTANTE - Configuración de Región LoRaWAN:**
> 
> La región determina las **frecuencias y parámetros de radio** que usará tu red LoRaWAN. **Debe coincidir con tu ubicación geográfica y gateway**. Una configuración incorrecta impedirá que los dispositivos se conecten.
>
> **Regiones comunes:**
> - **US915:** Estados Unidos, Canadá, México, Brasil
> - **EU868:** Europa, África, Rusia
> - **AS923:** Asia-Pacífico (Japón, Singapur, etc.)
> - **AU915:** Australia, Nueva Zelanda
> - **CN470:** China
> - **IN865:** India

**Contenido del archivo `.env`:**

```env
# PostgreSQL
POSTGRES_PASSWORD=chirpstack_ns

# Redis (mantener por defecto)
REDIS_PASSWORD=

# ChirpStack
# Cambiar por una clave secreta fuerte
CHIRPSTACK_API_SECRET=generaste-una-clave-secreta-muy-fuerte-aqui

# Región LoRaWAN - IMPORTANTE: Seleccionar según tu ubicación
# Regiones disponibles:
# - EU868 (Europa)
# - US915 (Estados Unidos, Canadá, México) 
# - AS923 (Asia-Pacífico)
# - AU915 (Australia)
# - CN470 (China)
# - IN865 (India)
CHIRPSTACK_REGION=US915

# Interfaz web
CHIRPSTACK_WEB_BIND=0.0.0.0:8080
```

### 3. Modificar docker-compose.yml para producción

```bash
nano docker-compose.yml
```

**Modificaciones importantes:**

```yaml
version: "3.8"

services:
  chirpstack:
    image: chirpstack/chirpstack:4
    command: -c /etc/chirpstack
    restart: unless-stopped
    volumes:
      - ./configuration/chirpstack:/etc/chirpstack
      - ./lorawan-devices:/opt/lorawan-devices
    depends_on:
      - postgres
      - redis
    environment:
      - MQTT_BROKER_HOST=mosquitto
      - REDIS_HOST=redis
      - POSTGRESQL_HOST=postgres
    ports:
      - 8080:8080
    networks:
      - chirpstack

  chirpstack-gateway-bridge:
    image: chirpstack/chirpstack-gateway-bridge:4
    restart: unless-stopped
    ports:
      - 1700:1700/udp
    volumes:
      - ./configuration/chirpstack-gateway-bridge:/etc/chirpstack-gateway-bridge
    networks:
      - chirpstack
    depends_on:
      - mosquitto

  mosquitto:
    image: eclipse-mosquitto:2
    restart: unless-stopped
    ports:
      - 1883:1883
    volumes:
      - ./configuration/mosquitto:/mosquitto/config/
    networks:
      - chirpstack

  postgres:
    image: postgres:14-alpine
    restart: unless-stopped
    volumes:
      - ./configuration/postgresql/initdb:/docker-entrypoint-initdb.d
      - postgresqldata:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=chirpstack_ns
    networks:
      - chirpstack

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redisdata:/data
    networks:
      - chirpstack

volumes:
  postgresqldata:
  redisdata:

networks:
  chirpstack:
```

### 4. Iniciar servicios

```bash
# Cambiar al usuario chirpstack
su - chirpstack
cd /opt/chirpstack-docker

# Iniciar servicios
docker-compose up -d

# Verificar que todos los contenedores estén corriendo
docker-compose ps
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

### Comandos útiles

```bash
# Ver logs en tiempo real
docker-compose logs -f chirpstack

# Reiniciar servicios
docker-compose restart

# Actualizar ChirpStack
docker-compose pull
docker-compose up -d

# Backup de base de datos
docker-compose exec postgres pg_dump -U chirpstack chirpstack > backup.sql

# Verificar puertos abiertos
netstat -tlnp | grep -E '(8080|1700|1883)'
```

### Troubleshooting común

#### 1. No se puede acceder a la interfaz web

```bash
# Verificar que Nginx esté corriendo
systemctl status nginx

# Verificar que ChirpStack esté corriendo
docker-compose ps

# Verificar logs
docker-compose logs chirpstack
```

#### 2. Gateway no se conecta

```bash
# Verificar logs del gateway bridge
docker-compose logs chirpstack-gateway-bridge

# Verificar que el puerto UDP 1700 esté abierto
ufw status | grep 1700
```

#### 3. Problemas de base de datos

```bash
# Verificar PostgreSQL
docker-compose logs postgres

# Conectar directamente a la base de datos
docker-compose exec postgres psql -U chirpstack
```

### Monitoreo

#### 1. Script de monitoreo básico

Crear `/opt/monitor-chirpstack.sh`:

```bash
#!/bin/bash
echo "=== ChirpStack Health Check ==="
echo "Date: $(date)"
echo ""

echo "Docker containers:"
docker-compose -f /opt/chirpstack-docker/docker-compose.yml ps

echo ""
echo "System resources:"
df -h /
free -h

echo ""
echo "Network ports:"
netstat -tlnp | grep -E '(8080|1700|1883)'
```

#### 2. Configurar cron para monitoreo

```bash
crontab -e

# Agregar línea para ejecutar cada 5 minutos
*/5 * * * * /opt/monitor-chirpstack.sh >> /var/log/chirpstack-monitor.log 2>&1
```

## Scripts de Automatización

Los siguientes scripts están incluidos en esta guía:

- `install-dependencies.sh` - Instalación automática de dependencias
- `configure-chirpstack.sh` - Configuración automática de ChirpStack
- `setup-security.sh` - Configuración de seguridad y firewall
- `backup-chirpstack.sh` - Script de backup automático

## Conclusión

¡Felicidades! Has deployado exitosamente ChirpStack en DigitalOcean. Tu servidor LoRaWAN está listo para:

- Registrar gateways LoRaWAN
- Gestionar dispositivos LoRa
- Crear aplicaciones IoT
- Monitorear tu red LoRaWAN

### Próximos pasos recomendados:

1. Configurar tu primer gateway
2. Registrar dispositivos de prueba
3. Configurar integraciones (HTTP, MQTT, etc.)
4. Implementar monitoreo avanzado
5. Configurar backups automáticos

### Recursos adiciales:

- [Documentación oficial ChirpStack](https://www.chirpstack.io/docs/)
- [Repositorio GitHub](https://github.com/chirpstack/chirpstack)
- [Foro de la comunidad](https://forum.chirpstack.io/)

---

**Nota:** Esta guía está diseñada para instalaciones de producción. Para desarrollo, considera usar la configuración Docker más simple.