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

# Variables de configuración
CHIRPSTACK_DIR="/opt/chirpstack-docker"
PUBLIC_IP="143.244.144.51"
POSTGRES_PASSWORD="chirpstack"  # Usar contraseña estándar de ChirpStack
CHIRPSTACK_API_SECRET=$(generate_password)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHIRPSTACK_REGION="us915_0"  # Región por defecto

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

# Descargar archivos de configuración de regiones oficiales
log "Descargando configuraciones de regiones oficiales..."
mkdir -p configuration/chirpstack

# Descargar configuraciones de las regiones más comunes
for region in us915_0 eu868 as923 au915_0; do
    if [[ ! -f "configuration/chirpstack/region_${region}.toml" ]]; then
        log "Descargando configuración para región $region..."
        curl -fsSL "https://raw.githubusercontent.com/chirpstack/chirpstack/master/chirpstack/configuration/region_${region}.toml" \
             -o "configuration/chirpstack/region_${region}.toml" || warning "No se pudo descargar región $region"
    fi
done

# Descargar configuración principal si no existe
if [[ ! -f "configuration/chirpstack/chirpstack.toml" ]]; then
    log "Descargando configuración principal..."
    curl -fsSL "https://raw.githubusercontent.com/chirpstack/chirpstack/master/chirpstack/configuration/chirpstack.toml" \
         -o "configuration/chirpstack/chirpstack.toml" || warning "No se pudo descargar configuración principal"
fi

# Configurar la región específica en el archivo principal
log "Configurando región $CHIRPSTACK_REGION en chirpstack.toml..."
if [[ -f "configuration/chirpstack/chirpstack.toml" ]]; then
    # Crear backup del archivo original
    cp "configuration/chirpstack/chirpstack.toml" "configuration/chirpstack/chirpstack.toml.backup"
    
    # Configurar solo la región especificada como habilitada
    cat > "configuration/chirpstack/chirpstack.toml" << EOF
# ChirpStack configuration for production deployment
# Generated automatically by configure-chirpstack.sh

[postgresql]
dsn="postgres://chirpstack:chirpstack@postgres/chirpstack?sslmode=disable"

[redis]
servers=["redis://redis:6379"]

[network]
net_id="000000"
EOF

# Configurar regiones según el parámetro
if [[ "$CHIRPSTACK_REGION" == "multi" ]]; then
    echo 'enabled_regions=["eu868", "us915_0", "us915_1", "as923", "au915_0", "cn470_10", "in865"]' >> "configuration/chirpstack/chirpstack.toml"
    info "✓ Configuración multi-región habilitada: EU868, US915, AS923, AU915, CN470, IN865"
else
    echo "enabled_regions=[\"$CHIRPSTACK_REGION\"]" >> "configuration/chirpstack/chirpstack.toml"
    info "✓ Región específica configurada: $CHIRPSTACK_REGION"
fi

cat >> "configuration/chirpstack/chirpstack.toml" << EOF

[api]
bind="0.0.0.0:8080"
secret="$CHIRPSTACK_API_SECRET"

[gateway.backend.mqtt]
server="tcp://mosquitto:1883"
client_id_template="chirpstack-gateway-{{ .GatewayID }}"

[integration.mqtt]
server="tcp://mosquitto:1883"
client_id_template="chirpstack-application-{{ .ApplicationID }}"

[join_server]
bind="0.0.0.0:8003"

EOF

    log "Configuración personalizada aplicada para región $CHIRPSTACK_REGION"
else
    warning "No se pudo configurar el archivo chirpstack.toml"
fi

# Crear archivo de configuración .env usando la contraseña estándar
log "Creando archivo de configuración .env..."
cat > .env << EOF
# PostgreSQL Configuration
POSTGRES_PASSWORD=chirpstack

# Redis Configuration
REDIS_PASSWORD=

# ChirpStack API Secret
CHIRPSTACK_API_SECRET=$CHIRPSTACK_API_SECRET

# Región LoRaWAN - CRÍTICO: Debe coincidir con tu ubicación y gateway
# Regiones disponibles (ID de configuración):
# - us915_0: Estados Unidos, Canadá, México, Brasil (canales 0-7)
# - eu868: Europa, África, Rusia
# - as923: Asia-Pacífico (Japón, Singapur, etc.)
# - au915_0: Australia, Nueva Zelanda (canales 0-7)
# - cn470_10: China
# - in865: India
# 
# NOTA: El ID debe coincidir exactamente con el archivo region_XXX.toml
CHIRPSTACK_REGION=us915_0

EOF

# Crear configuración personalizada de Docker Compose para producción
log "Creando configuración Docker Compose para producción..."
cat > docker-compose.yml << 'EOF'
# Docker Compose file for ChirpStack v4

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
      - POSTGRES_PASSWORD=chirpstack
      - POSTGRES_USER=chirpstack
      - POSTGRES_DB=chirpstack
    networks:
      - chirpstack
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U chirpstack"]
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
    server_name network.sense.lat;

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


# Asegurar que no hay servicios corriendo y reiniciar limpio
log "Reiniciando servicios ChirpStack con configuración actualizada..."
cd "$CHIRPSTACK_DIR"

# Detener cualquier servicio existente y limpiar volúmenes problemáticos
docker-compose down -v || true

# Iniciar servicios con la nueva configuración
log "Iniciando servicios ChirpStack..."
docker-compose up -d

# Esperar a que los servicios estén listos
log "Esperando a que los servicios estén listos..."
sleep 30

# Verificar estado de los servicios
log "Verificando estado de los servicios..."
su - chirpstack -c "cd $CHIRPSTACK_DIR && docker-compose ps"


# Crear archivo de información de la instalación
log "Creando archivo de información de la instalación..."
cat > /opt/chirpstack-docker/INSTALLATION_INFO.txt << EOF
ChirpStack Installation Information
===================================

Installation Date: $(date)
Server IP: $PUBLIC_IP
Installation Directory: $CHIRPSTACK_DIR

Database Configuration:
- PostgreSQL Password: chirpstack (default)
- ChirpStack API Secret: $CHIRPSTACK_API_SECRET

Web Interface:
- URL: http://143.244.144.51:8080
- URL with domain: https://network.sense.lat (after DNS setup)
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
echo -e "URL: ${YELLOW}http://143.244.144.51:8080${NC}"
echo -e "URL con dominio: ${YELLOW}https://network.sense.lat${NC} (después de configurar DNS)"
echo -e "Usuario: ${YELLOW}admin${NC}"
echo -e "Contraseña: ${YELLOW}admin${NC}"
echo ""
echo -e "${RED}🚨 PASO CRÍTICO INMEDIATO:${NC}"
echo -e "${RED}CAMBIAR CONTRASEÑA DE ADMIN (OBLIGATORIO)${NC}"
echo ""
echo -e "${YELLOW}Cómo cambiar contraseña:${NC}"
echo "1. Ir a: http://143.244.144.51:8080"
echo "2. Login: admin / admin"
echo "3. Clic en avatar (esquina superior derecha)"
echo "4. Ir a 'Change password'"
echo "5. Crear contraseña segura"
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
echo -e "${RED}⚠️  NO uses en producción con contraseña 'admin'${NC}"
echo ""

exit 0