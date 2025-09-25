#!/bin/bash

# Script de actualización del servicio ChirpStack-Supabase vía SSH
# Copia el archivo local al servidor remoto y reinicia el servicio

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuración del servidor
SERVER_IP="143.244.144.51"
SERVER_USER="root"
SERVICE_NAME="chirpstack-supabase"
SERVICE_DIR="/opt/chirpstack-supabase-service"

# Archivos locales
LOCAL_SERVICE_FILE="services/supabase/chirpstack-supabase-service.js"
LOCAL_PACKAGE_FILE="services/supabase/package.json"

# Función de ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Script para actualizar el servicio ChirpStack-Supabase vía SSH"
    echo ""
    echo "Opciones:"
    echo "  -h, --help       Mostrar esta ayuda"
    echo "  -n, --no-backup  No crear backup antes de actualizar"
    echo "  -r, --no-restart No reiniciar el servicio después de actualizar"
    echo "  -p, --package    También actualizar package.json"
    echo "  -s, --status     Solo mostrar el estado del servicio"
    echo ""
    echo "Ejemplos:"
    echo "  $0                    # Actualizar con backup y reinicio"
    echo "  $0 --no-backup        # Actualizar sin backup"
    echo "  $0 --package          # Actualizar servicio y dependencias"
    echo "  $0 --status           # Ver estado actual"
}

# Variables de control
CREATE_BACKUP=true
RESTART_SERVICE=true
UPDATE_PACKAGE=false
SHOW_STATUS_ONLY=false

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--no-backup)
            CREATE_BACKUP=false
            shift
            ;;
        -r|--no-restart)
            RESTART_SERVICE=false
            shift
            ;;
        -p|--package)
            UPDATE_PACKAGE=true
            shift
            ;;
        -s|--status)
            SHOW_STATUS_ONLY=true
            shift
            ;;
        *)
            echo -e "${RED}Opción desconocida: $1${NC}"
            echo "Use --help para ver las opciones disponibles"
            exit 1
            ;;
    esac
done

# Si solo queremos ver el estado
if [ "$SHOW_STATUS_ONLY" = true ]; then
    echo -e "${CYAN}Estado del servicio ChirpStack-Supabase:${NC}"
    ssh ${SERVER_USER}@${SERVER_IP} "systemctl status ${SERVICE_NAME} --no-pager"
    exit 0
fi

# Verificar que el archivo local existe
if [ ! -f "$LOCAL_SERVICE_FILE" ]; then
    echo -e "${RED}Error: No se encuentra el archivo local${NC}"
    echo "  $LOCAL_SERVICE_FILE"
    echo ""
    echo "Asegúrate de ejecutar este script desde el directorio raíz del proyecto"
    exit 1
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  ACTUALIZACIÓN DEL SERVICIO VÍA SSH${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${BLUE}Servidor:${NC} ${SERVER_USER}@${SERVER_IP}"
echo -e "${BLUE}Servicio:${NC} ${SERVICE_NAME}"
echo -e "${BLUE}Directorio:${NC} ${SERVICE_DIR}"
echo ""

# Verificar conexión SSH
echo -n "Verificando conexión SSH... "
if ssh -o ConnectTimeout=5 ${SERVER_USER}@${SERVER_IP} "echo 'ok'" &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo ""
    echo -e "${RED}No se pudo conectar al servidor${NC}"
    echo ""
    echo "Posibles soluciones:"
    echo "  1. Verificar que el servidor esté encendido"
    echo "  2. Verificar tu conexión a internet"
    echo "  3. Si el servidor fue reconstruido, ejecuta:"
    echo -e "${YELLOW}     ssh-keygen -R ${SERVER_IP}${NC}"
    exit 1
fi

# Crear backup si está habilitado
if [ "$CREATE_BACKUP" = true ]; then
    echo -n "Creando backup... "
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

    ssh ${SERVER_USER}@${SERVER_IP} "cd ${SERVICE_DIR} && \
        mkdir -p backups && \
        cp chirpstack-supabase-service.js backups/service.backup_${BACKUP_DATE}.js" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} (backup_${BACKUP_DATE})"
    else
        echo -e "${YELLOW}⚠${NC} (no se pudo crear backup, continuando...)"
    fi
fi

# Copiar archivo principal
echo -n "Copiando archivo del servicio... "
if scp -q ${LOCAL_SERVICE_FILE} ${SERVER_USER}@${SERVER_IP}:${SERVICE_DIR}/chirpstack-supabase-service.js; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}Error al copiar el archivo${NC}"
    exit 1
fi

# Actualizar package.json si se solicitó
if [ "$UPDATE_PACKAGE" = true ]; then
    if [ -f "$LOCAL_PACKAGE_FILE" ]; then
        echo -n "Copiando package.json... "
        if scp -q ${LOCAL_PACKAGE_FILE} ${SERVER_USER}@${SERVER_IP}:${SERVICE_DIR}/package.json; then
            echo -e "${GREEN}✓${NC}"

            echo -n "Instalando dependencias... "
            if ssh ${SERVER_USER}@${SERVER_IP} "cd ${SERVICE_DIR} && npm install --production" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}⚠${NC} (verificar manualmente)"
            fi
        else
            echo -e "${YELLOW}⚠${NC} (no se pudo copiar)"
        fi
    fi
fi

# Verificar sintaxis
echo -n "Verificando sintaxis... "
if ssh ${SERVER_USER}@${SERVER_IP} "cd ${SERVICE_DIR} && node -c chirpstack-supabase-service.js" 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}Error de sintaxis en el archivo${NC}"

    if [ "$CREATE_BACKUP" = true ]; then
        echo "Restaurando backup..."
        ssh ${SERVER_USER}@${SERVER_IP} "cd ${SERVICE_DIR} && \
            cp backups/service.backup_${BACKUP_DATE}.js chirpstack-supabase-service.js"
    fi
    exit 1
fi

# Reiniciar servicio si está habilitado
if [ "$RESTART_SERVICE" = true ]; then
    echo -n "Reiniciando servicio... "
    if ssh ${SERVER_USER}@${SERVER_IP} "systemctl restart ${SERVICE_NAME}" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"

        # Esperar un momento
        sleep 2

        # Verificar estado
        echo ""
        echo "Estado del servicio:"
        ssh ${SERVER_USER}@${SERVER_IP} "systemctl is-active ${SERVICE_NAME}" | {
            read status
            if [ "$status" = "active" ]; then
                echo -e "  ${GREEN}● Activo${NC}"
            else
                echo -e "  ${RED}● $status${NC}"
            fi
        }
    else
        echo -e "${YELLOW}⚠${NC}"
        echo "  El servicio no se pudo reiniciar automáticamente"
    fi
else
    echo -e "${YELLOW}Servicio no reiniciado${NC} (usa --no-restart)"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ ACTUALIZACIÓN COMPLETADA${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Mostrar comandos útiles
echo -e "${CYAN}Comandos útiles:${NC}"
echo ""
echo "Ver logs en tiempo real:"
echo -e "  ${YELLOW}ssh ${SERVER_USER}@${SERVER_IP} 'journalctl -u ${SERVICE_NAME} -f'${NC}"
echo ""
echo "Reiniciar manualmente:"
echo -e "  ${YELLOW}ssh ${SERVER_USER}@${SERVER_IP} 'systemctl restart ${SERVICE_NAME}'${NC}"
echo ""
echo "Ver estado detallado:"
echo -e "  ${YELLOW}ssh ${SERVER_USER}@${SERVER_IP} 'systemctl status ${SERVICE_NAME}'${NC}"
echo ""

if [ "$CREATE_BACKUP" = true ]; then
    echo "Restaurar backup si es necesario:"
    echo -e "  ${YELLOW}ssh ${SERVER_USER}@${SERVER_IP} 'cd ${SERVICE_DIR}/backups && ls -la'${NC}"
fi

exit 0