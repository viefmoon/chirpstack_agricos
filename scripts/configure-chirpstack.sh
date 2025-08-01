#!/bin/bash

# ChirpStack Native Installation - Script de Configuración
# Siguiendo la guía oficial de ChirpStack
# Versión: 2.0

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

# Variables de configuración
PUBLIC_IP="143.244.144.51"
CHIRPSTACK_REGION="us915_1"  # Región US915 canales 8-15 (canal 2)

log "Iniciando configuración nativa de ChirpStack..."
log "IP Pública: $PUBLIC_IP"
log "Región LoRaWAN: $CHIRPSTACK_REGION"

# Instalar ChirpStack Gateway Bridge
log "Instalando ChirpStack Gateway Bridge..."
apt install -y chirpstack-gateway-bridge

# Configurar ChirpStack Gateway Bridge para US915
log "Configurando ChirpStack Gateway Bridge para región US915..."
cat > /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml << EOF
[general]
log_level=4

[backend.semtech_udp]
bind="0.0.0.0:1700"

[integration.mqtt]
server="tcp://localhost:1883"
client_id_template="chirpstack-gateway-bridge-{{ .GatewayID }}"

# US915 region configuration
event_topic_template="us915_1/gateway/{{ .GatewayID }}/event/{{ .EventType }}"
state_topic_template="us915_1/gateway/{{ .GatewayID }}/state/{{ .StateType }}"
command_topic_template="us915_1/gateway/{{ .GatewayID }}/command/#"

[integration.mqtt.auth]
type="generic"

[integration.mqtt.stats]
enabled=true
interval="30s"
EOF

# Instalar ChirpStack
log "Instalando ChirpStack..."
apt install -y chirpstack

# Configurar ChirpStack para US915
log "Configurando ChirpStack para región US915..."
cat > /etc/chirpstack/chirpstack.toml << EOF
# ChirpStack configuration for native installation
# Generated automatically by configure-chirpstack-native.sh

[postgresql]
dsn="postgres://chirpstack:chirpstack@localhost/chirpstack?sslmode=disable"

[redis]
servers=["redis://localhost:6379"]

[network]
net_id="000000"
enabled_regions=["us915_1"]

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

# Iniciar y habilitar servicios ChirpStack
log "Iniciando servicios ChirpStack..."
systemctl start chirpstack-gateway-bridge
systemctl enable chirpstack-gateway-bridge

systemctl start chirpstack
systemctl enable chirpstack

# Esperar a que los servicios estén listos
log "Esperando a que los servicios estén listos..."
sleep 10

# Verificar estado de los servicios
log "Verificando estado de los servicios..."
systemctl status chirpstack-gateway-bridge --no-pager -l || warning "Gateway Bridge no está funcionando correctamente"
systemctl status chirpstack --no-pager -l || warning "ChirpStack no está funcionando correctamente"
systemctl status mosquitto --no-pager -l || warning "Mosquitto no está funcionando correctamente"
systemctl status redis-server --no-pager -l || warning "Redis no está funcionando correctamente"
systemctl status postgresql --no-pager -l || warning "PostgreSQL no está funcionando correctamente"

# Configurar Nginx como reverse proxy
log "Configurando Nginx como reverse proxy..."
cat > /etc/nginx/sites-available/chirpstack << EOF
server {
    listen 80;
    server_name network.sense.lat $PUBLIC_IP;

    # Aumentar tamaño máximo de subida
    client_max_body_size 10M;

    # Headers de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Logs específicos para ChirpStack
    access_log /var/log/nginx/chirpstack.access.log;
    error_log /var/log/nginx/chirpstack.error.log;
}
EOF

# Habilitar sitio Nginx
if [[ -f "/etc/nginx/sites-enabled/default" ]]; then
    rm /etc/nginx/sites-enabled/default
fi

ln -sf /etc/nginx/sites-available/chirpstack /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Crear scripts de utilidad
log "Creando scripts de utilidad..."
cat > /opt/chirpstack-status.sh << 'EOF'
#!/bin/bash
echo "=== ChirpStack Services Status ==="
echo ""
echo "ChirpStack Gateway Bridge:"
systemctl status chirpstack-gateway-bridge --no-pager -l
echo ""
echo "ChirpStack:"
systemctl status chirpstack --no-pager -l
echo ""
echo "Mosquitto MQTT Broker:"
systemctl status mosquitto --no-pager -l
echo ""
echo "Redis:"
systemctl status redis-server --no-pager -l
echo ""
echo "PostgreSQL:"
systemctl status postgresql --no-pager -l
echo ""
echo "=== Network Ports ==="
netstat -tlnp | grep -E '(8080|1700|1883)'
EOF

cat > /opt/chirpstack-logs.sh << 'EOF'
#!/bin/bash
echo "=== ChirpStack Logs ==="
echo ""
echo "Press Ctrl+C to exit log viewing"
echo ""
journalctl -f -u chirpstack -u chirpstack-gateway-bridge -u mosquitto
EOF

cat > /opt/chirpstack-restart.sh << 'EOF'
#!/bin/bash
echo "Restarting all ChirpStack services..."
systemctl restart mosquitto
systemctl restart redis-server
systemctl restart chirpstack-gateway-bridge
systemctl restart chirpstack
systemctl restart nginx
echo "All services restarted."
echo ""
echo "Checking status..."
systemctl status chirpstack --no-pager -l
EOF

# Hacer scripts ejecutables
chmod +x /opt/chirpstack-*.sh

# Crear archivo de información de la instalación
log "Creando archivo de información de la instalación..."
cat > /opt/CHIRPSTACK_NATIVE_INSTALL.txt << EOF
ChirpStack Native Installation Information
==========================================

Installation Date: $(date)
Installation Method: Native packages (following official guide)
Server IP: $PUBLIC_IP
LoRaWAN Region: $CHIRPSTACK_REGION

Access Information:
Web Interface: http://$PUBLIC_IP:8080
Default Username: admin
Default Password: admin

IMPORTANT: Change the default password immediately!

Configuration Files:
- ChirpStack: /etc/chirpstack/chirpstack.toml
- Gateway Bridge: /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml
- Nginx: /etc/nginx/sites-available/chirpstack

Services:
- ChirpStack: systemctl status chirpstack
- Gateway Bridge: systemctl status chirpstack-gateway-bridge
- MQTT Broker: systemctl status mosquitto
- Redis: systemctl status redis-server
- PostgreSQL: systemctl status postgresql

Useful Commands:
- Check status: /opt/chirpstack-status.sh
- View logs: /opt/chirpstack-logs.sh
- Restart services: /opt/chirpstack-restart.sh

Service Logs:
- ChirpStack: journalctl -u chirpstack -f
- Gateway Bridge: journalctl -u chirpstack-gateway-bridge -f
- MQTT: journalctl -u mosquitto -f

Network Ports:
- ChirpStack Web Interface: 8080
- MQTT Broker: 1883
- Gateway Bridge UDP: 1700
- HTTP/HTTPS: 80/443

Next Steps:
1. Access http://$PUBLIC_IP:8080
2. Login with admin/admin
3. Change default password
4. Configure your first gateway
5. Set up your first application
6. Register your first device

Troubleshooting:
- Check all services: /opt/chirpstack-status.sh
- View live logs: /opt/chirpstack-logs.sh
- Restart all: /opt/chirpstack-restart.sh
EOF

log "¡Configuración nativa de ChirpStack completada exitosamente!"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  CHIRPSTACK NATIVE INSTALADO EXITOSAMENTE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Información de acceso:${NC}"
echo -e "URL: ${YELLOW}http://$PUBLIC_IP:8080${NC}"
echo -e "Usuario: ${YELLOW}admin${NC}"
echo -e "Contraseña: ${YELLOW}admin${NC}"
echo ""
echo -e "${RED}🚨 PASO CRÍTICO INMEDIATO:${NC}"
echo -e "${RED}CAMBIAR CONTRASEÑA DE ADMIN (OBLIGATORIO)${NC}"
echo ""
echo -e "${BLUE}Comandos útiles:${NC}"
echo "- Estado de servicios: /opt/chirpstack-status.sh"
echo "- Ver logs en vivo: /opt/chirpstack-logs.sh"
echo "- Reiniciar servicios: /opt/chirpstack-restart.sh"
echo ""
echo -e "${BLUE}Información completa guardada en:${NC}"
echo "/opt/CHIRPSTACK_NATIVE_INSTALL.txt"
echo ""
echo -e "${YELLOW}Siguiente paso recomendado:${NC}"
echo "sudo ./setup-security.sh (para configurar HTTPS)"
echo ""

exit 0