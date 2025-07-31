#!/bin/bash

# ChirpStack DigitalOcean - Instalación Rápida
# Autor: Guía ChirpStack Deployment
# Versión: 1.0
# Este script descarga e instala ChirpStack completamente automático

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

# Banner
echo -e "${GREEN}"
cat << 'EOF'
 ┌─────────────────────────────────────────────────────────────┐
 │                                                             │
 │       ChirpStack v4 + Ubuntu 24.04 - Instalador           │
 │                    Instalación Automática                  │
 │                                                             │
 └─────────────────────────────────────────────────────────────┘
EOF
echo -e "${NC}"

log "Iniciando instalación automática de ChirpStack..."

# Información del servidor
PUBLIC_IP="143.244.144.51"
HOSTNAME=$(hostname)

info "Servidor: $HOSTNAME"
info "IP Pública: $PUBLIC_IP"

# Preguntar configuración básica
echo ""
echo -e "${BLUE}Configuración inicial:${NC}"
echo ""

# Configurar dominio automáticamente
DOMAIN="network.sense.lat"
HTTPS_ENABLED=true
info "Usando dominio configurado: $DOMAIN"
log "Si necesitas cambiar el dominio, edita este script"

# Configurar región LoRaWAN automáticamente
LORAWAN_REGION="US915"
info "Región LoRaWAN configurada: $LORAWAN_REGION"
log "Para cambiar región, edita este script o el archivo .env después"

# Mostrar configuración automática
echo ""
echo -e "${YELLOW}Configuración automática:${NC}"
echo "- Servidor: $HOSTNAME ($PUBLIC_IP)"
echo "- Dominio: $DOMAIN"
echo "- Región LoRaWAN: $LORAWAN_REGION"
echo "- HTTPS: Habilitado"
echo ""
log "Instalación iniciada automáticamente..."
sleep 2

# Crear directorio de trabajo
WORK_DIR="/opt/chirpstack-setup"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Verificar que los scripts estén disponibles
if [[ ! -f "./install-dependencies.sh" ]] || [[ ! -f "./configure-chirpstack.sh" ]] || [[ ! -f "./setup-security.sh" ]]; then
    error "Scripts no encontrados. Asegúrate de ejecutar desde el directorio del repositorio:"
    error "git clone https://github.com/viefmoon/chirpstack_agricos.git"
    error "cd chirpstack_agricos"
    error "chmod +x *.sh"
    error "sudo ./quick-install.sh"
    exit 1
fi

log "Scripts encontrados correctamente"

# Hacer scripts ejecutables
chmod +x *.sh

# PASO 1: Instalar dependencias
log "PASO 1/3: Instalando dependencias del sistema..."
echo ""
./install-dependencies.sh

if [[ $? -ne 0 ]]; then
    error "Error en la instalación de dependencias"
    exit 1
fi

# PASO 2: Configurar ChirpStack
log "PASO 2/3: Configurando ChirpStack..."
echo ""

# Personalizar configuración antes de ejecutar
if [[ -f "configure-chirpstack.sh" ]]; then
    # Modificar región en el script si es necesario
    sed -i "s/CHIRPSTACK_REGION=US915/CHIRPSTACK_REGION=$LORAWAN_REGION/" configure-chirpstack.sh
fi

./configure-chirpstack.sh

if [[ $? -ne 0 ]]; then
    error "Error en la configuración de ChirpStack"
    exit 1
fi

# PASO 3: Configurar seguridad
log "PASO 3/3: Configurando seguridad..."
echo ""

# Configurar seguridad automáticamente sin preguntas
export AUTO_DOMAIN="$DOMAIN"
export AUTO_HTTPS="$HTTPS_ENABLED"
./setup-security.sh

if [[ $? -ne 0 ]]; then
    warning "Hubo algunos problemas con la configuración de seguridad, pero ChirpStack debería funcionar"
fi

# Esperar a que todos los servicios estén listos
log "Esperando a que todos los servicios estén completamente listos..."
sleep 30

# Verificar instalación
log "Verificando instalación..."

# Verificar servicios Docker
cd /opt/chirpstack-docker
if docker-compose ps | grep -q "Up"; then
    info "✓ Servicios Docker están corriendo"
else
    warning "⚠ Algunos servicios Docker pueden no estar corriendo"
fi

# Verificar puertos
if netstat -tlnp | grep -q ":8080"; then
    info "✓ Puerto 8080 (Web interface) está abierto"
else
    warning "⚠ Puerto 8080 no está disponible"
fi

if netstat -ulnp | grep -q ":1700"; then
    info "✓ Puerto 1700 (Gateway Bridge) está abierto"
else
    warning "⚠ Puerto 1700 no está disponible"
fi

# Verificar acceso web
if curl -s "http://localhost:8080" > /dev/null; then
    info "✓ Interfaz web responde correctamente"
else
    warning "⚠ Interfaz web no responde"
fi

# Crear archivo de resumen
cat > /opt/INSTALLATION_SUMMARY.txt << EOF
ChirpStack Installation Summary
===============================

Installation Date: $(date)
Installation Method: Quick Install Script
Server: $HOSTNAME
Public IP: $PUBLIC_IP
Domain: $DOMAIN
LoRaWAN Region: $LORAWAN_REGION
HTTPS Enabled: $HTTPS_ENABLED

Access Information:
$(if [[ "$HTTPS_ENABLED" == true ]]; then echo "Web Interface: https://$DOMAIN"; else echo "Web Interface: http://$PUBLIC_IP:8080"; fi)
Default Username: admin
Default Password: admin

IMPORTANT: Change the default password immediately!

Installation Location: /opt/chirpstack-docker
Configuration Files: /opt/chirpstack-docker/.env
Backup Scripts: /opt/chirpstack-setup/

Useful Commands:
- Start services: /opt/chirpstack-docker/start-chirpstack.sh
- Stop services: /opt/chirpstack-docker/stop-chirpstack.sh
- View logs: /opt/chirpstack-docker/logs-chirpstack.sh
- Check status: /opt/chirpstack-docker/status-chirpstack.sh
- Security monitor: /opt/security-monitor.sh
- Create backup: /opt/chirpstack-setup/backup-chirpstack.sh

Services Status:
- ChirpStack Web Interface: Port 8080
- MQTT Broker: Port 1883
- Gateway Bridge: Port 1700/UDP
- PostgreSQL: Internal Docker network
- Redis: Internal Docker network

Next Steps:
1. Access the web interface
2. Change default admin password
3. Configure your first gateway
4. Set up your first application
5. Register your first device

Troubleshooting:
- If web interface is not accessible, check: systemctl status nginx
- If services are not running, check: cd /opt/chirpstack-docker && docker-compose ps
- View all logs: cd /opt/chirpstack-docker && docker-compose logs

Support Resources:
- ChirpStack Documentation: https://www.chirpstack.io/docs/
- Community Forum: https://forum.chirpstack.io/
- GitHub: https://github.com/chirpstack/chirpstack
EOF

# Mostrar resumen final
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                   ¡INSTALACIÓN COMPLETADA!                      ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""

if [[ "$HTTPS_ENABLED" == true ]]; then
    echo -e "${BLUE}🌐 Acceso Web Seguro:${NC} ${GREEN}https://network.sense.lat${NC}"
else
    echo -e "${BLUE}🌐 Acceso Web:${NC} ${GREEN}http://143.244.144.51:8080${NC}"
fi

echo -e "${BLUE}👤 Usuario:${NC} ${YELLOW}admin${NC}"
echo -e "${BLUE}🔑 Contraseña:${NC} ${YELLOW}admin${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANTE: Cambia la contraseña por defecto inmediatamente${NC}"
echo ""
echo -e "${BLUE}📊 Estado de Servicios:${NC}"
cd /opt/chirpstack-docker && docker-compose ps
echo ""
echo -e "${BLUE}🔧 Comandos Útiles:${NC}"
echo "   • Ver logs: ${YELLOW}/opt/chirpstack-docker/logs-chirpstack.sh${NC}"
echo "   • Estado: ${YELLOW}/opt/chirpstack-docker/status-chirpstack.sh${NC}"
echo "   • Backup: ${YELLOW}/opt/chirpstack-setup/backup-chirpstack.sh${NC}"
echo ""
echo -e "${BLUE}📄 Resumen completo guardado en:${NC} /opt/INSTALLATION_SUMMARY.txt"
echo ""
echo -e "${GREEN}🎉 ChirpStack está listo para usar. ¡Disfruta tu red LoRaWAN!${NC}"
echo ""

# Mostrar pasos críticos inmediatos
echo -e "${RED}🚨 PASOS CRÍTICOS INMEDIATOS:${NC}"
echo ""
echo -e "${YELLOW}1. CAMBIAR CONTRASEÑA DE ADMIN (OBLIGATORIO):${NC}"
if [[ "$HTTPS_ENABLED" == true ]]; then
    echo "   • Ir a: https://network.sense.lat"
else
    echo "   • Ir a: http://143.244.144.51:8080"
fi
echo "   • Login: admin / admin"
echo "   • Clic en tu avatar (esquina superior derecha)"
echo "   • Ir a 'Change password'"
echo "   • Crear contraseña segura"
echo ""
echo -e "${YELLOW}2. CONFIGURAR DNS (si no lo hiciste):${NC}"
echo "   • DigitalOcean → Networking → Domains → sense.lat"
echo "   • Add Record: Type A, Hostname 'network', IP 143.244.144.51"
echo ""
echo -e "${YELLOW}📋 Próximos pasos (después de lo anterior):${NC}"
echo "3. Configurar tu primer gateway"
echo "4. Crear tu primera aplicación" 
echo "5. Programar backups regulares"
echo ""
echo -e "${RED}⚠️  NO uses ChirpStack en producción con contraseña 'admin'${NC}"
echo ""

exit 0