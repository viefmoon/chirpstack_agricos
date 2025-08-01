#!/bin/bash

# ChirpStack Complete Clean Installation
# Este script limpia completamente y reinstala ChirpStack

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo -e "${GREEN}"
cat << 'EOF'
 ┌─────────────────────────────────────────────────────────────┐
 │                                                             │
 │          ChirpStack Complete Clean Installation             │
 │                                                             │
 └─────────────────────────────────────────────────────────────┘
EOF
echo -e "${NC}"

log "Iniciando limpieza completa..."

# 1. Detener y eliminar todos los contenedores Docker
log "Deteniendo y eliminando contenedores Docker..."
if command -v docker-compose >/dev/null 2>&1; then
    cd /opt/chirpstack-docker 2>/dev/null && docker-compose down -v || true
fi

# Eliminar contenedores relacionados con ChirpStack
docker ps -a | grep -E "(chirpstack|mosquitto|postgres|redis)" | awk '{print $1}' | xargs -r docker rm -f || true

# Eliminar volúmenes
docker volume ls | grep -E "(chirpstack|postgres|redis)" | awk '{print $2}' | xargs -r docker volume rm || true

# 2. Limpiar directorios de instalación
log "Eliminando directorios de instalación..."
rm -rf /opt/chirpstack-docker
rm -rf /opt/chirpstack-setup
rm -rf /opt/chirpstack-supabase-service
rm -rf /opt/backups/chirpstack

# 3. Limpiar configuraciones de Nginx
log "Limpiando configuraciones de Nginx..."
rm -f /etc/nginx/sites-enabled/chirpstack
rm -f /etc/nginx/sites-available/chirpstack

# 4. Limpiar servicios systemd
log "Limpiando servicios systemd..."
systemctl stop chirpstack-supabase 2>/dev/null || true
systemctl disable chirpstack-supabase 2>/dev/null || true
rm -f /etc/systemd/system/chirpstack-supabase.service
systemctl daemon-reload

# 5. Limpiar archivos de log y temporales
log "Limpiando archivos de log y temporales..."
rm -f /var/log/chirpstack*.log
rm -f /opt/INSTALLATION_SUMMARY.txt
rm -f /opt/security-monitor.sh

# 6. Limpiar certificados SSL si existen
log "Limpiando certificados SSL..."
certbot delete --cert-name network.sense.lat --non-interactive 2>/dev/null || true

# 7. Reiniciar servicios de red
log "Reiniciando servicios de red..."
systemctl restart nginx || true

log "Limpieza completa terminada"
log "Ahora puedes ejecutar: sudo ./install.sh"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                  ¡LIMPIEZA COMPLETADA!                          ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Próximo paso:${NC}"
echo -e "${BLUE}sudo ./install.sh${NC}"
echo ""