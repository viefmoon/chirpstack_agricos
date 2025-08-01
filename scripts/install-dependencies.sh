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

# Instalar Docker
log "Instalando Docker..."
if ! command -v docker &> /dev/null; then
    # Limpiar cualquier configuración anterior de Docker
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.asc
    rm -f /etc/apt/keyrings/docker-archive-keyring.gpg
    
    # Usar el script oficial de Docker (más confiable)
    log "Descargando script oficial de Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    
    # Verificar que se descargó correctamente
    if [[ ! -f "get-docker.sh" ]]; then
        error "No se pudo descargar el script de Docker"
        exit 1
    fi
    
    # Ejecutar script oficial de Docker
    log "Ejecutando instalación oficial de Docker..."
    sh get-docker.sh
    
    # Limpiar script temporal
    rm -f get-docker.sh
    
    # Iniciar y habilitar Docker
    systemctl start docker
    systemctl enable docker
    
    log "Docker instalado correctamente"
else
    info "Docker ya está instalado"
fi

# Instalar Docker Compose (versión standalone)
log "Instalando Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Crear symlink para compatibilidad
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log "Docker Compose instalado correctamente (versión: ${DOCKER_COMPOSE_VERSION})"
else
    info "Docker Compose ya está instalado"
fi

# Crear usuario chirpstack si no existe
log "Configurando usuario chirpstack..."
if ! id "chirpstack" &>/dev/null; then
    adduser --disabled-password --gecos "" chirpstack
    usermod -aG sudo chirpstack
    usermod -aG docker chirpstack
    log "Usuario chirpstack creado y agregado a grupos sudo y docker"
else
    # Asegurar que el usuario esté en los grupos correctos
    usermod -aG sudo chirpstack
    usermod -aG docker chirpstack
    info "Usuario chirpstack ya existe, agregado a grupos necesarios"
fi

# Crear directorio para ChirpStack
log "Creando directorio para ChirpStack..."
mkdir -p /opt/chirpstack-docker
chown -R chirpstack:chirpstack /opt

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
docker --version && docker-compose --version

log "¡Instalación de dependencias completada exitosamente!"
info "Docker, Nginx y usuario chirpstack configurados correctamente"

exit 0