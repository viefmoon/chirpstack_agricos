#!/bin/bash

# ChirpStack v4 Native Installation - Instalador Principal
# Repositorio: https://github.com/viefmoon/chirpstack_agricos
# Versión: 2.0 (Native)

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

# Obtener directorio actual del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Banner
echo -e "${GREEN}"
cat << 'EOF'
 ┌─────────────────────────────────────────────────────────────┐
 │                                                             │
 │    ChirpStack v4 Native + Ubuntu 24.04 - Instalador v2.0  │
 │                 Instalación Nativa Automática              │
 │                                                             │
 └─────────────────────────────────────────────────────────────┘
EOF
echo -e "${NC}"

log "Iniciando instalación nativa automática de ChirpStack v4..."

# Información del servidor
PUBLIC_IP="143.244.144.51"
HOSTNAME=$(hostname)

info "Servidor: $HOSTNAME"
info "IP Pública: $PUBLIC_IP"
info "Directorio de scripts: $SCRIPTS_DIR"

# Verificar que los scripts estén disponibles
if [[ ! -f "$SCRIPTS_DIR/install-dependencies.sh" ]] || [[ ! -f "$SCRIPTS_DIR/configure-chirpstack.sh" ]] || [[ ! -f "$SCRIPTS_DIR/setup-security.sh" ]]; then
    error "Scripts no encontrados en $SCRIPTS_DIR"
    error "Estructura esperada:"
    error "├── install.sh (este archivo)"
    error "├── scripts/"
    error "│   ├── install-dependencies.sh"
    error "│   ├── configure-chirpstack.sh"
    error "│   ├── setup-security.sh"
    error "│   └── setup-supabase-service.sh"
    error "└── services/"
    error "    └── supabase/"
    exit 1
fi

log "Scripts encontrados correctamente"

# Configuración automática
DOMAIN="network.sense.lat"
HTTPS_ENABLED=true

# Configuración de región US915 (Estados Unidos, México, Canadá)
LORAWAN_REGION="us915_1"

info "Configuración de región US915 (canales 8-15)"
info "Ideal para Estados Unidos, México, Canadá, Brasil"

# Hacer scripts ejecutables
chmod +x "$SCRIPTS_DIR"/*.sh

echo ""
echo -e "${YELLOW}Configuración automática:${NC}"
echo "- Servidor: $HOSTNAME ($PUBLIC_IP)"
echo "- Dominio: $DOMAIN"
echo "- Regiones LoRaWAN: Todas habilitadas (multi-región)"
echo "- HTTPS: Habilitado"
echo ""
log "Instalación iniciada automáticamente..."
sleep 2

# PASO 1: Instalar dependencias
log "PASO 1/4: Instalando dependencias del sistema..."
echo ""
"$SCRIPTS_DIR/install-dependencies.sh"

if [[ $? -ne 0 ]]; then
    error "Error en la instalación de dependencias"
    exit 1
fi

# PASO 2: Configurar ChirpStack (instalación nativa)
log "PASO 2/4: Configurando ChirpStack nativo..."
echo ""

"$SCRIPTS_DIR/configure-chirpstack.sh"

if [[ $? -ne 0 ]]; then
    error "Error en la configuración de ChirpStack"
    exit 1
fi

# PASO 3: Configurar seguridad y HTTPS
log "PASO 3/4: Configurando seguridad y HTTPS..."
echo ""

# Configurar seguridad automáticamente sin preguntas
export AUTO_DOMAIN="$DOMAIN"
export AUTO_HTTPS="$HTTPS_ENABLED"
"$SCRIPTS_DIR/setup-security.sh"

if [[ $? -eq 0 ]]; then
    info "✓ Seguridad y HTTPS configurados correctamente"
    info "✓ Certificados SSL obtenidos para $DOMAIN"
else
    warning "⚠ Hubo algunos problemas con HTTPS, pero ChirpStack funciona en HTTP"
    warning "⚠ Puedes configurar HTTPS manualmente más tarde"
fi

# PASO 4: Configurar servicio Supabase (opcional)
log "PASO 4/4: Configurando servicio ChirpStack-Supabase..."
echo ""

if [[ -f "$SCRIPTS_DIR/setup-supabase-service.sh" ]]; then
    "$SCRIPTS_DIR/setup-supabase-service.sh"
    
    if [[ $? -eq 0 ]]; then
        info "✓ Servicio ChirpStack-Supabase configurado correctamente"
    else
        warning "⚠ Hubo problemas configurando el servicio Supabase, pero ChirpStack funciona sin él"
    fi
else
    warning "Script setup-supabase-service.sh no encontrado, omitiendo configuración del servicio"
fi

# Esperar a que los servicios estén listos
log "Esperando a que los servicios estén listos..."
sleep 20

# Crear archivo de resumen
cat > /opt/INSTALLATION_SUMMARY.txt << EOF
ChirpStack Installation Summary
===============================

Installation Date: $(date)
Installation Method: ChirpStack v2.0 Installer
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
Backup Scripts: $SCRIPTS_DIR/

Useful Commands:
- Start services: /opt/chirpstack-docker/start-chirpstack.sh
- Stop services: /opt/chirpstack-docker/stop-chirpstack.sh
- View logs: /opt/chirpstack-docker/logs-chirpstack.sh
- Check status: /opt/chirpstack-docker/status-chirpstack.sh
- Security monitor: /opt/security-monitor.sh
- Create backup: $SCRIPTS_DIR/backup-chirpstack.sh

Services Status:
- ChirpStack Web Interface: Port 8080
- MQTT Broker: Port 1883
- Gateway Bridge: Port 1700/UDP
- PostgreSQL: Internal Docker network
- Redis: Internal Docker network

ChirpStack-Supabase Service (Optional):
- Configure: /opt/chirpstack-supabase-service/configure-env.sh
- Start: systemctl start chirpstack-supabase
- Status: systemctl status chirpstack-supabase
- Logs: journalctl -u chirpstack-supabase -f

Next Steps:
1. Access the web interface
2. Change default admin password
3. Configure Supabase service (optional)
4. Configure your first gateway
5. Set up your first application
6. Register your first device

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
    echo -e "${GREEN}✓ HTTPS configurado automáticamente${NC}"
else
    echo -e "${BLUE}🌐 Acceso Web:${NC} ${GREEN}http://143.244.144.51:8080${NC}"
fi

echo -e "${BLUE}👤 Usuario:${NC} ${YELLOW}admin${NC}"
echo -e "${BLUE}🔑 Contraseña:${NC} ${YELLOW}admin${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANTE: Cambia la contraseña por defecto inmediatamente${NC}"
echo ""
echo -e "${BLUE}📊 Estado de Servicios:${NC}"
/opt/chirpstack-status.sh
echo ""
echo -e "${BLUE}🔧 Comandos Útiles:${NC}"
echo "   • Ver logs: ${YELLOW}/opt/chirpstack-logs.sh${NC}"
echo "   • Estado: ${YELLOW}/opt/chirpstack-status.sh${NC}"
echo "   • Reiniciar: ${YELLOW}/opt/chirpstack-restart.sh${NC}"
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
echo "3. Configurar Supabase (OPCIONAL):"
echo "   sudo /opt/chirpstack-supabase-service/configure-env.sh"
echo "4. Configurar tu primer gateway"
echo "5. Crear tu primera aplicación" 
echo "6. Programar backups regulares"
echo ""
echo -e "${BLUE}🔗 Servicio ChirpStack-Supabase:${NC}"
echo "   • Configurar: /opt/chirpstack-supabase-service/configure-env.sh"
echo "   • Iniciar: systemctl start chirpstack-supabase"
echo "   • Ver logs: journalctl -u chirpstack-supabase -f"
echo ""
echo -e "${RED}⚠️  NO uses ChirpStack en producción con contraseña 'admin'${NC}"
echo ""

exit 0