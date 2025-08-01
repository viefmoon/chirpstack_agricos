#!/bin/bash

# ChirpStack Complete Clean Installation (Native)
# Este script limpia completamente la instalación nativa de ChirpStack

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
 │       ChirpStack Complete Clean Installation (Native)       │
 │                                                             │
 └─────────────────────────────────────────────────────────────┘
EOF
echo -e "${NC}"

log "Iniciando limpieza completa de instalación nativa..."

# 1. Detener servicios ChirpStack
log "Deteniendo servicios ChirpStack..."
systemctl stop chirpstack 2>/dev/null || true
systemctl stop chirpstack-gateway-bridge 2>/dev/null || true
systemctl disable chirpstack 2>/dev/null || true
systemctl disable chirpstack-gateway-bridge 2>/dev/null || true

# 2. Remover paquetes ChirpStack
log "Removiendo paquetes ChirpStack..."
apt remove --purge -y chirpstack chirpstack-gateway-bridge 2>/dev/null || true

# 3. Limpiar configuraciones
log "Limpiando configuraciones..."
rm -rf /etc/chirpstack
rm -rf /etc/chirpstack-gateway-bridge

# 4. Limpiar base de datos PostgreSQL
log "Limpiando base de datos..."
sudo -u postgres psql << 'EOF' 2>/dev/null || true
DROP DATABASE IF EXISTS chirpstack;
DROP ROLE IF EXISTS chirpstack;
\q
EOF

# 5. Limpiar directorios de datos
log "Limpiando directorios..."
rm -rf /opt/chirpstack-config
rm -rf /opt/chirpstack-docker
rm -rf /opt/chirpstack-setup
rm -rf /opt/chirpstack-supabase-service
rm -rf /opt/backups/chirpstack

# 6. Limpiar scripts de utilidad
log "Limpiando scripts..."
rm -f /opt/chirpstack-*.sh
rm -f /opt/CHIRPSTACK_NATIVE_INSTALL.txt
rm -f /opt/INSTALLATION_SUMMARY.txt
rm -f /opt/security-monitor.sh

# 7. Limpiar configuraciones de Nginx
log "Limpiando configuraciones de Nginx..."
rm -f /etc/nginx/sites-enabled/chirpstack
rm -f /etc/nginx/sites-available/chirpstack

# 8. Limpiar servicios systemd
log "Limpiando servicios systemd..."
systemctl stop chirpstack-supabase 2>/dev/null || true
systemctl disable chirpstack-supabase 2>/dev/null || true
rm -f /etc/systemd/system/chirpstack-supabase.service
systemctl daemon-reload

# 9. Limpiar archivos de log
log "Limpiando archivos de log..."
rm -rf /var/log/chirpstack/
rm -f /var/log/nginx/chirpstack*.log

# 10. Limpiar certificados SSL si existen
log "Limpiando certificados SSL..."
certbot delete --cert-name network.sense.lat --non-interactive 2>/dev/null || true

# 11. Limpiar repositorio ChirpStack
log "Limpiando repositorio ChirpStack..."
rm -f /etc/apt/sources.list.d/chirpstack.list
rm -f /etc/apt/keyrings/chirpstack.gpg

# 12. Actualizar cache de paquetes
log "Actualizando cache de paquetes..."
apt update

# 13. Reiniciar servicios de red
log "Reiniciando servicios de red..."
systemctl restart nginx || true

log "Limpieza completa terminada"
log "Ahora puedes ejecutar: sudo ./install.sh"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                  ¡LIMPIEZA COMPLETADA!                          ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Servicios que permanecen (necesarios para nueva instalación):${NC}"
echo "✓ PostgreSQL - Base de datos limpia"
echo "✓ Redis - Cache limpio"
echo "✓ Mosquitto - Broker MQTT"
echo "✓ Nginx - Servidor web"
echo ""
echo -e "${YELLOW}Próximo paso:${NC}"
echo -e "${BLUE}sudo ./install.sh${NC}"
echo ""