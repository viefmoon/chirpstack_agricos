#!/bin/bash

# ChirpStack DigitalOcean - Script de Configuración Automática
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

# Función para generar contraseña segura
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Función para obtener IP pública
get_public_ip() {
    curl -s http://checkip.amazonaws.com/ || curl -s http://icanhazip.com/ || echo "127.0.0.1"
}

# Variables de configuración
CHIRPSTACK_DIR="/opt/chirpstack-docker"
PUBLIC_IP=$(get_public_ip)
POSTGRES_PASSWORD=$(generate_password)
CHIRPSTACK_API_SECRET=$(generate_password)

log "Iniciando configuración de ChirpStack..."
log "IP Pública detectada: $PUBLIC_IP"

# Crear directorio si no existe
if [[ ! -d "$CHIRPSTACK_DIR" ]]; then
    log "Creando directorio $CHIRPSTACK_DIR..."
    mkdir -p "$CHIRPSTACK_DIR"
    chown -R chirpstack:chirpstack "$CHIRPSTACK_DIR"
fi

cd "$CHIRPSTACK_DIR"

# Clonar repositorio ChirpStack Docker si no existe
if [[ ! -f "docker-compose.yml" ]]; then
    log "Clonando repositorio ChirpStack Docker..."
    git clone https://github.com/chirpstack/chirpstack-docker.git temp_repo
    mv temp_repo/* .
    mv temp_repo/.* . 2>/dev/null || true
    rmdir temp_repo
    chown -R chirpstack:chirpstack .
else
    info "Repositorio ChirpStack ya existe, actualizando..."
    git pull origin master || warning "No se pudo actualizar el repositorio"
fi

# Crear archivo de configuración .env
log "Creando archivo de configuración .env..."
cat > .env << EOF
# PostgreSQL Configuration
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Redis Configuration (usar contraseña vacía por simplicidad)
REDIS_PASSWORD=

# ChirpStack Configuration
CHIRPSTACK_API_SECRET=$CHIRPSTACK_API_SECRET

# Región LoRaWAN - cambiar según tu ubicación
# Opciones: EU868, US915, AS923_1, AS923_2, AS923_3, AS923_4, AU915, CN470, CN779, EU433, IN865, KR920, RU864
CHIRPSTACK_REGION=US915

# Network Server Configuration
CHIRPSTACK_NETWORK_SERVER_BIND=0.0.0.0:8000

# Application Server Configuration  
CHIRPSTACK_APPLICATION_SERVER_BIND=0.0.0.0:8080

# Web Interface
CHIRPSTACK_WEB_BIND=0.0.0.0:8080

# External hostname/IP (cambiar por tu dominio si tienes uno)
CHIRPSTACK_EXTERNAL_HOST=$PUBLIC_IP

# MQTT Broker
MQTT_BROKER_HOST=mosquitto
MQTT_BROKER_PORT=1883

# Gateway Bridge
GATEWAY_BRIDGE_MQTT_TOPIC_PREFIX=gateway/

EOF

# Crear configuración personalizada de Docker Compose para producción
log "Creando configuración Docker Compose para producción..."
cat > docker-compose.yml << 'EOF'
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
      - "8080:8080"
    networks:
      - chirpstack
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3

  chirpstack-gateway-bridge:
    image: chirpstack/chirpstack-gateway-bridge:4
    restart: unless-stopped
    ports:
      - "1700:1700/udp"
    volumes:
      - ./configuration/chirpstack-gateway-bridge:/etc/chirpstack-gateway-bridge
    networks:
      - chirpstack
    depends_on:
      - mosquitto
    healthcheck:
      test: ["CMD", "pgrep", "chirpstack-gateway-bridge"]
      interval: 30s
      timeout: 10s
      retries: 3

  mosquitto:
    image: eclipse-mosquitto:2
    restart: unless-stopped
    ports:
      - "1883:1883"
    volumes:
      - ./configuration/mosquitto:/mosquitto/config/
    networks:
      - chirpstack
    healthcheck:
      test: ["CMD", "mosquitto_pub", "-h", "localhost", "-t", "test", "-m", "health-check"]
      interval: 30s
      timeout: 10s
      retries: 3

  postgres:
    image: postgres:14-alpine
    restart: unless-stopped
    volumes:
      - ./configuration/postgresql/initdb:/docker-entrypoint-initdb.d
      - postgresqldata:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    networks:
      - chirpstack
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redisdata:/data
    networks:
      - chirpstack
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgresqldata:
  redisdata:

networks:
  chirpstack:
    driver: bridge
EOF

# Asegurar permisos correctos
chown -R chirpstack:chirpstack "$CHIRPSTACK_DIR"

# Configurar Nginx como reverse proxy
log "Configurando Nginx como reverse proxy..."
cat > /etc/nginx/sites-available/chirpstack << EOF
server {
    listen 80;
    server_name $PUBLIC_IP;  # Cambiar por tu dominio cuando lo configures

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

# Crear script de inicio/monitoreo
log "Creando scripts de utilidad..."
cat > /opt/chirpstack-docker/start-chirpstack.sh << 'EOF'
#!/bin/bash
cd /opt/chirpstack-docker
docker-compose up -d
echo "ChirpStack iniciado. Verificando servicios..."
sleep 10
docker-compose ps
EOF

cat > /opt/chirpstack-docker/stop-chirpstack.sh << 'EOF'
#!/bin/bash
cd /opt/chirpstack-docker
docker-compose down
echo "ChirpStack detenido."
EOF

cat > /opt/chirpstack-docker/logs-chirpstack.sh << 'EOF'
#!/bin/bash
cd /opt/chirpstack-docker
docker-compose logs -f
EOF

cat > /opt/chirpstack-docker/status-chirpstack.sh << 'EOF'
#!/bin/bash
cd /opt/chirpstack-docker
echo "=== Estado de contenedores ==="
docker-compose ps
echo ""
echo "=== Uso de recursos ==="
docker stats --no-stream
echo ""
echo "=== Puertos abiertos ==="
netstat -tlnp | grep -E '(8080|1700|1883)'
EOF

# Hacer scripts ejecutables
chmod +x /opt/chirpstack-docker/*.sh
chown chirpstack:chirpstack /opt/chirpstack-docker/*.sh

# Iniciar servicios como usuario chirpstack
log "Iniciando servicios ChirpStack..."
cd "$CHIRPSTACK_DIR"
su - chirpstack -c "cd $CHIRPSTACK_DIR && docker-compose up -d"

# Esperar a que los servicios estén listos
log "Esperando a que los servicios estén listos..."
sleep 30

# Verificar estado de los servicios
log "Verificando estado de los servicios..."
su - chirpstack -c "cd $CHIRPSTACK_DIR && docker-compose ps"

# Importar dispositivos LoRaWAN si es posible
log "Intentando importar dispositivos LoRaWAN..."
if [[ -f "Makefile" ]]; then
    su - chirpstack -c "cd $CHIRPSTACK_DIR && make import-lorawan-devices" || warning "No se pudieron importar dispositivos LoRaWAN"
fi

# Crear archivo de información de la instalación
log "Creando archivo de información de la instalación..."
cat > /opt/chirpstack-docker/INSTALLATION_INFO.txt << EOF
ChirpStack Installation Information
===================================

Installation Date: $(date)
Server IP: $PUBLIC_IP
Installation Directory: $CHIRPSTACK_DIR

Database Configuration:
- PostgreSQL Password: $POSTGRES_PASSWORD
- ChirpStack API Secret: $CHIRPSTACK_API_SECRET

Web Interface:
- URL: http://$PUBLIC_IP:8080
- Default Username: admin
- Default Password: admin

IMPORTANT: Change the default admin password immediately!

Services:
- ChirpStack Web Interface: Port 8080
- MQTT Broker: Port 1883  
- Gateway Bridge: Port 1700/UDP

Useful Commands:
- Start services: /opt/chirpstack-docker/start-chirpstack.sh
- Stop services: /opt/chirpstack-docker/stop-chirpstack.sh
- View logs: /opt/chirpstack-docker/logs-chirpstack.sh
- Check status: /opt/chirpstack-docker/status-chirpstack.sh

Nginx Configuration:
- Config file: /etc/nginx/sites-available/chirpstack
- Reverse proxy configured for port 80

Next Steps:
1. Access http://$PUBLIC_IP:8080
2. Login with admin/admin
3. Change default password
4. Configure your first gateway and application

EOF

chown chirpstack:chirpstack /opt/chirpstack-docker/INSTALLATION_INFO.txt

log "¡Configuración de ChirpStack completada exitosamente!"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  CHIRPSTACK CONFIGURADO EXITOSAMENTE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Información de acceso:${NC}"
echo -e "URL: ${YELLOW}http://$PUBLIC_IP:8080${NC}"
echo -e "Usuario: ${YELLOW}admin${NC}"
echo -e "Contraseña: ${YELLOW}admin${NC}"
echo ""
echo -e "${RED}¡IMPORTANTE!${NC}"
echo -e "${RED}Cambia la contraseña por defecto inmediatamente${NC}"
echo ""
echo -e "${BLUE}Comandos útiles:${NC}"
echo "- Iniciar servicios: /opt/chirpstack-docker/start-chirpstack.sh"
echo "- Detener servicios: /opt/chirpstack-docker/stop-chirpstack.sh"
echo "- Ver logs: /opt/chirpstack-docker/logs-chirpstack.sh"
echo "- Ver estado: /opt/chirpstack-docker/status-chirpstack.sh"
echo ""
echo -e "${BLUE}Información guardada en:${NC}"
echo "/opt/chirpstack-docker/INSTALLATION_INFO.txt"
echo ""
echo -e "${YELLOW}Siguiente paso recomendado:${NC}"  
echo "sudo ./setup-security.sh (para configurar HTTPS)"
echo ""

exit 0