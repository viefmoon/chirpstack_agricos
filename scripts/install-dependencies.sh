#!/bin/bash

# ChirpStack DigitalOcean - Script de Instalación de Dependencias
# Autor: Guía ChirpStack Deployment
# Versión: 1.0

set -e  # Salir si algún comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root (use sudo)"
   exit 1
fi

log "Iniciando instalación de dependencias para ChirpStack..."

# Actualizar sistema
log "Actualizando sistema..."
apt update && apt upgrade -y

# Configurar zona horaria (puedes cambiar según tu ubicación)
log "Configurando zona horaria..."
timedatectl set-timezone America/Mexico_City

# Crear directorio de keyrings si no existe
mkdir -p /etc/apt/keyrings

# Instalar herramientas básicas
log "Instalando herramientas básicas..."
apt install -y \
    curl \
    wget \
    git \
    htop \
    nano \
    vim \
    ufw \
    certbot \
    python3-certbot-nginx \
    nginx \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Instalar requisitos de ChirpStack según guía oficial
log "Instalando requisitos de ChirpStack..."
apt install -y \
    mosquitto \
    mosquitto-clients \
    redis-server \
    redis-tools \
    postgresql \
    gpg

# Iniciar y habilitar servicios
log "Iniciando servicios..."
systemctl start mosquitto
systemctl enable mosquitto
systemctl start redis-server  
systemctl enable redis-server
systemctl start postgresql
systemctl enable postgresql

# Configurar repositorio ChirpStack
log "Configurando repositorio ChirpStack..."
sudo mkdir -p /etc/apt/keyrings/
sudo sh -c 'wget -q -O - https://artifacts.chirpstack.io/packages/chirpstack.key | gpg --dearmor > /etc/apt/keyrings/chirpstack.gpg'
echo "deb [signed-by=/etc/apt/keyrings/chirpstack.gpg] https://artifacts.chirpstack.io/packages/4.x/deb stable main" | sudo tee /etc/apt/sources.list.d/chirpstack.list

# Actualizar cache de paquetes
apt update

# Configurar PostgreSQL para ChirpStack
log "Configurando base de datos PostgreSQL..."
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

log "Base de datos PostgreSQL configurada correctamente"

# Crear directorios necesarios
log "Creando directorios..."
mkdir -p /opt/chirpstack-config
mkdir -p /var/log/chirpstack
mkdir -p /opt/backups

# Configurar firewall básico
log "Configurando firewall UFW..."
ufw --force enable

# Permitir SSH (importante para no perder acceso)
ufw allow ssh

# Permitir HTTP y HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Permitir puertos específicos de ChirpStack
ufw allow 8080/tcp   # Web interface
ufw allow 1700/udp   # Gateway bridge UDP
ufw allow 1883/tcp   # MQTT

log "Firewall configurado correctamente"

# Optimizar configuración del sistema
log "Optimizando configuración del sistema..."

# Aumentar límites de archivos abiertos
cat >> /etc/security/limits.conf << EOF
chirpstack soft nofile 65536
chirpstack hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

# Configurar parámetros del kernel para mejor rendimiento de red
cat >> /etc/sysctl.conf << EOF
# ChirpStack network optimizations
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.udp_mem = 102400 873800 16777216
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
EOF

# Aplicar cambios del kernel
sysctl -p

# Crear directorio de logs
log "Configurando sistema de logs..."
mkdir -p /var/log/chirpstack
chown chirpstack:chirpstack /var/log/chirpstack

# Configurar logrotate para ChirpStack
cat > /etc/logrotate.d/chirpstack << EOF
/var/log/chirpstack/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    copytruncate
    notifempty
    su chirpstack chirpstack
}
EOF

# Verificar instalación básica
log "Verificando instalación..."
mosquitto --help > /dev/null && log "✓ Mosquitto instalado"
redis-cli --version > /dev/null && log "✓ Redis instalado"  
sudo -u postgres psql -c "SELECT version();" > /dev/null && log "✓ PostgreSQL instalado"

log "¡Instalación de dependencias completada exitosamente!"
info "Mosquitto, Redis, PostgreSQL y repositorio ChirpStack configurados correctamente"

exit 0