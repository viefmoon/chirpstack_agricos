#!/bin/bash

# ChirpStack Supabase Service - Script de Configuración
# Instala y configura el servicio Node.js para insertar mediciones en Supabase

set -e

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

# Variables
SERVICE_DIR="/opt/chirpstack-supabase-service"
SERVICE_USER="chirpstack-service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "Iniciando configuración del servicio ChirpStack-Supabase..."

# Instalar Node.js si no está instalado
if ! command -v node &> /dev/null; then
    log "Instalando Node.js..."
    
    # Instalar NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
    
    # Verificar instalación
    if node --version && npm --version; then
        info "✓ Node.js $(node --version) y npm $(npm --version) instalados correctamente"
    else
        error "No se pudo instalar Node.js correctamente"
        exit 1
    fi
else
    info "✓ Node.js ya está instalado: $(node --version)"
fi

# Crear usuario para el servicio si no existe
if ! id "$SERVICE_USER" &>/dev/null; then
    log "Creando usuario $SERVICE_USER..."
    adduser --system --group --no-create-home --disabled-login $SERVICE_USER
    info "✓ Usuario $SERVICE_USER creado"
else
    info "✓ Usuario $SERVICE_USER ya existe"
fi

# Crear directorio del servicio
log "Configurando directorio del servicio..."
mkdir -p "$SERVICE_DIR"
chown -R $SERVICE_USER:$SERVICE_USER "$SERVICE_DIR"

# Copiar archivos del servicio
log "Copiando archivos del servicio..."
SERVICES_DIR="$SCRIPT_DIR/../services/supabase"
cp "$SERVICES_DIR/chirpstack-supabase-service.js" "$SERVICE_DIR/"
cp "$SERVICES_DIR/package.json" "$SERVICE_DIR/"
cp "$SERVICES_DIR/.env.example" "$SERVICE_DIR/"

# Cambiar a directorio del servicio e instalar dependencias
cd "$SERVICE_DIR"

# Instalar dependencias de Node.js
log "Instalando dependencias de Node.js..."
npm install --production

# Configurar permisos
chown -R $SERVICE_USER:$SERVICE_USER "$SERVICE_DIR"
chmod +x "$SERVICE_DIR/chirpstack-supabase-service.js"

# Crear archivo de configuración de entorno si no existe
if [[ ! -f "$SERVICE_DIR/.env" ]]; then
    log "Creando archivo de configuración .env..."
    cat > "$SERVICE_DIR/.env" << EOF
# Configuración de Supabase
# IMPORTANTE: Configura estas variables antes de iniciar el servicio
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key-aqui

# Configuración MQTT (ChirpStack)
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_TOPIC=application/#

# Configuración opcional
NODE_ENV=production
EOF
    
    chown $SERVICE_USER:$SERVICE_USER "$SERVICE_DIR/.env"
    chmod 600 "$SERVICE_DIR/.env"  # Solo el usuario del servicio puede leer
    
    warning "⚠️  IMPORTANTE: Configura las credenciales de Supabase en $SERVICE_DIR/.env"
fi

# Crear servicio systemd
log "Creando servicio systemd..."
cat > /etc/systemd/system/chirpstack-supabase.service << EOF
[Unit]
Description=ChirpStack Supabase Integration Service
Documentation=https://github.com/viefmoon/chirpstack_agricos
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$SERVICE_DIR
ExecStart=/usr/bin/node chirpstack-supabase-service.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=chirpstack-supabase

# Variables de entorno
Environment=NODE_ENV=production

# Límites de recursos
LimitNOFILE=65536

# Seguridad
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$SERVICE_DIR
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd y habilitar el servicio
systemctl daemon-reload
systemctl enable chirpstack-supabase.service

# Crear scripts de utilidad
log "Creando scripts de utilidad..."

# Script para iniciar el servicio
cat > "$SERVICE_DIR/start-service.sh" << 'EOF'
#!/bin/bash
echo "Iniciando servicio ChirpStack-Supabase..."
sudo systemctl start chirpstack-supabase
sudo systemctl status chirpstack-supabase
EOF

# Script para detener el servicio
cat > "$SERVICE_DIR/stop-service.sh" << 'EOF'
#!/bin/bash
echo "Deteniendo servicio ChirpStack-Supabase..."
sudo systemctl stop chirpstack-supabase
sudo systemctl status chirpstack-supabase
EOF

# Script para ver logs
cat > "$SERVICE_DIR/logs-service.sh" << 'EOF'
#!/bin/bash
echo "Logs del servicio ChirpStack-Supabase (Ctrl+C para salir):"
sudo journalctl -u chirpstack-supabase -f
EOF

# Script para verificar estado
cat > "$SERVICE_DIR/status-service.sh" << 'EOF'
#!/bin/bash
echo "=== Estado del servicio ==="
sudo systemctl status chirpstack-supabase
echo ""
echo "=== Últimos logs ==="
sudo journalctl -u chirpstack-supabase --no-pager -n 20
EOF

# Hacer scripts ejecutables
chmod +x "$SERVICE_DIR"/*.sh

# Crear script de configuración interactiva
cat > "$SERVICE_DIR/configure-env.sh" << 'EOF'
#!/bin/bash

# Script interactivo para configurar variables de entorno

echo "=== Configuración del Servicio ChirpStack-Supabase ==="
echo ""

ENV_FILE="/opt/chirpstack-supabase-service/.env"

echo "Configurando credenciales de Supabase..."
read -p "URL de Supabase (ej: https://tu-proyecto.supabase.co): " SUPABASE_URL
read -p "Service Role Key de Supabase: " SUPABASE_SERVICE_ROLE_KEY

echo ""
echo "Configuración MQTT (por defecto usar localhost para ChirpStack local):"
read -p "MQTT Host [localhost]: " MQTT_HOST
MQTT_HOST=${MQTT_HOST:-localhost}

read -p "MQTT Port [1883]: " MQTT_PORT
MQTT_PORT=${MQTT_PORT:-1883}

read -p "MQTT Topic [application/#]: " MQTT_TOPIC
MQTT_TOPIC=${MQTT_TOPIC:-"application/#"}

# Crear archivo .env
cat > "$ENV_FILE" << ENVEOF
# Configuración de Supabase
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY

# Configuración MQTT (ChirpStack)
MQTT_HOST=$MQTT_HOST
MQTT_PORT=$MQTT_PORT
MQTT_TOPIC=$MQTT_TOPIC

# Configuración opcional
NODE_ENV=production
ENVEOF

# Configurar permisos
sudo chown chirpstack-service:chirpstack-service "$ENV_FILE"
sudo chmod 600 "$ENV_FILE"

echo ""
echo "✅ Configuración guardada en $ENV_FILE"
echo ""
echo "Para iniciar el servicio:"
echo "  sudo systemctl start chirpstack-supabase"
echo ""
echo "Para ver los logs:"
echo "  sudo journalctl -u chirpstack-supabase -f"
EOF

chmod +x "$SERVICE_DIR/configure-env.sh"

# Crear documentación README
cat > "$SERVICE_DIR/README_SERVICE.md" << 'EOF'
# ChirpStack - Supabase Integration Service

Este servicio conecta ChirpStack con Supabase para almacenar mediciones de sensores LoRaWAN.

## Configuración

1. **Configurar credenciales de Supabase:**
   ```bash
   sudo /opt/chirpstack-supabase-service/configure-env.sh
   ```

2. **Iniciar el servicio:**
   ```bash
   sudo systemctl start chirpstack-supabase
   ```

3. **Verificar que esté funcionando:**
   ```bash
   sudo systemctl status chirpstack-supabase
   ```

## Comandos Útiles

- **Iniciar servicio:** `sudo systemctl start chirpstack-supabase`
- **Detener servicio:** `sudo systemctl stop chirpstack-supabase`
- **Reiniciar servicio:** `sudo systemctl restart chirpstack-supabase`
- **Ver estado:** `sudo systemctl status chirpstack-supabase`
- **Ver logs:** `sudo journalctl -u chirpstack-supabase -f`

## Scripts de Utilidad

- `start-service.sh` - Iniciar servicio
- `stop-service.sh` - Detener servicio  
- `logs-service.sh` - Ver logs en tiempo real
- `status-service.sh` - Ver estado y últimos logs
- `configure-env.sh` - Configurar variables de entorno

## Estructura de Base de Datos Esperada

El servicio espera las siguientes tablas en Supabase:

- `stations` - Estaciones de medición
- `devices` - Dispositivos LoRaWAN
- `sensors` - Sensores individuales
- `sensor_types` - Tipos de sensores
- `readings` - Lecturas de sensores
- `voltage_readings` - Lecturas de voltaje de dispositivos

## Logs

Los logs del servicio se almacenan en el journal del sistema:
```bash
sudo journalctl -u chirpstack-supabase -f
```
EOF

log "¡Configuración del servicio completada exitosamente!"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  SERVICIO CHIRPSTACK-SUPABASE LISTO${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Directorio del servicio:${NC} $SERVICE_DIR"
echo -e "${BLUE}Usuario del servicio:${NC} $SERVICE_USER"
echo -e "${BLUE}Archivo de configuración:${NC} $SERVICE_DIR/.env"
echo ""
echo -e "${YELLOW}Siguiente paso OBLIGATORIO:${NC}"
echo -e "${YELLOW}1. Configurar credenciales de Supabase:${NC}"
echo "   sudo $SERVICE_DIR/configure-env.sh"
echo ""
echo -e "${YELLOW}2. Iniciar el servicio:${NC}"
echo "   sudo systemctl start chirpstack-supabase"
echo ""
echo -e "${BLUE}Comandos útiles:${NC}"
echo "   • Ver estado: sudo systemctl status chirpstack-supabase"
echo "   • Ver logs: sudo journalctl -u chirpstack-supabase -f"
echo "   • Reiniciar: sudo systemctl restart chirpstack-supabase"
echo ""
echo -e "${RED}⚠️  IMPORTANTE: El servicio NO iniciará hasta configurar Supabase${NC}"
echo ""

exit 0