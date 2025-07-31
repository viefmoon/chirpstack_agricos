#!/bin/bash

# ChirpStack DigitalOcean - Script de Backup Completo
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

# Configuración
CHIRPSTACK_DIR="/opt/chirpstack-docker"
BACKUP_BASE_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/chirpstack_backup_$DATE"
LOG_FILE="/var/log/chirpstack/backup.log"

# Crear directorio de logs si no existe
mkdir -p /var/log/chirpstack

# Función para mostrar ayuda
show_help() {
    echo "ChirpStack Backup Script"
    echo ""
    echo "Uso: $0 [OPCIONES]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help          Mostrar esta ayuda"
    echo "  -f, --full          Backup completo (incluyendo volúmenes Docker)"
    echo "  -d, --database      Solo backup de base de datos"
    echo "  -c, --config        Solo backup de configuraciones"
    echo "  -r, --restore FILE  Restaurar desde backup"
    echo "  --list             Listar backups disponibles"
    echo "  --cleanup          Limpiar backups antiguos (>30 días)"
    echo ""
    echo "Ejemplos:"
    echo "  $0                  # Backup completo por defecto"
    echo "  $0 -d              # Solo backup de base de datos"
    echo "  $0 -r backup.tar.gz # Restaurar desde backup"
    echo ""
}

# Función para crear backup de base de datos
backup_database() {
    log "Creando backup de base de datos PostgreSQL..."
    
    if [[ ! -d "$CHIRPSTACK_DIR" ]]; then
        error "Directorio ChirpStack no encontrado: $CHIRPSTACK_DIR"
        return 1
    fi
    
    cd "$CHIRPSTACK_DIR"
    
    # Verificar que PostgreSQL esté corriendo
    if ! docker-compose ps postgres | grep -q "Up"; then
        error "PostgreSQL no está corriendo"
        return 1
    fi
    
    # Crear backup de la base de datos
    docker-compose exec -T postgres pg_dump -U postgres chirpstack > "$BACKUP_DIR/chirpstack_database.sql" || {
        error "Error al crear backup de base de datos"
        return 1
    }
    
    # Backup de usuarios y roles
    docker-compose exec -T postgres pg_dumpall -U postgres --roles-only > "$BACKUP_DIR/chirpstack_roles.sql" || {
        warning "No se pudo hacer backup de roles"
    }
    
    log "Backup de base de datos completado"
}

# Función para crear backup de configuraciones
backup_config() {
    log "Creando backup de configuraciones..."
    
    # ChirpStack configurations
    if [[ -d "$CHIRPSTACK_DIR" ]]; then
        cp -r "$CHIRPSTACK_DIR" "$BACKUP_DIR/chirpstack-docker" || {
            error "Error al copiar configuraciones de ChirpStack"
            return 1
        }
        
        # Excluir volúmenes de datos grandes si no es backup completo
        if [[ "$BACKUP_TYPE" != "full" ]]; then
            rm -rf "$BACKUP_DIR/chirpstack-docker/volumes" 2>/dev/null || true
        fi
    fi
    
    # Nginx configurations
    if [[ -d "/etc/nginx/sites-available" ]]; then
        mkdir -p "$BACKUP_DIR/nginx"
        cp -r /etc/nginx/sites-available "$BACKUP_DIR/nginx/" || {
            warning "Error al copiar configuraciones de Nginx"
        }
        cp /etc/nginx/nginx.conf "$BACKUP_DIR/nginx/" 2>/dev/null || true
    fi
    
    # SSL certificates
    if [[ -d "/etc/letsencrypt" ]]; then
        mkdir -p "$BACKUP_DIR/ssl"
        cp -r /etc/letsencrypt "$BACKUP_DIR/ssl/" || {
            warning "Error al copiar certificados SSL"
        }
    fi
    
    # Fail2ban configuration
    if [[ -f "/etc/fail2ban/jail.local" ]]; then
        mkdir -p "$BACKUP_DIR/security"
        cp /etc/fail2ban/jail.local "$BACKUP_DIR/security/" || true
    fi
    
    # Custom scripts
    if [[ -f "/etc/iptables-chirpstack.sh" ]]; then
        cp /etc/iptables-chirpstack.sh "$BACKUP_DIR/security/" || true
    fi
    
    # System crontab
    crontab -l > "$BACKUP_DIR/crontab.txt" 2>/dev/null || echo "No crontab found" > "$BACKUP_DIR/crontab.txt"
    
    log "Backup de configuraciones completado"
}

# Función para crear backup completo
backup_full() {
    log "Creando backup completo..."
    
    backup_config
    backup_database
    
    # Backup de volúmenes Docker
    log "Creando backup de volúmenes Docker..."
    cd "$CHIRPSTACK_DIR"
    
    # Detener servicios temporalmente para backup consistente
    if docker-compose ps | grep -q "Up"; then
        log "Deteniendo servicios temporalmente..."
        docker-compose stop
        SERVICES_WERE_RUNNING=true
    fi
    
    # Backup de volúmenes
    mkdir -p "$BACKUP_DIR/volumes"
    
    # PostgreSQL data
    if docker volume ls | grep -q "postgresqldata"; then
        docker run --rm -v chirpstack-docker_postgresqldata:/data -v "$BACKUP_DIR/volumes":/backup ubuntu tar czf /backup/postgresql_data.tar.gz -C /data . || {
            warning "Error al hacer backup del volumen PostgreSQL"
        }
    fi
    
    # Redis data
    if docker volume ls | grep -q "redisdata"; then
        docker run --rm -v chirpstack-docker_redisdata:/data -v "$BACKUP_DIR/volumes":/backup ubuntu tar czf /backup/redis_data.tar.gz -C /data . || {
            warning "Error al hacer backup del volumen Redis"
        }
    fi
    
    # Reiniciar servicios si estaban corriendo
    if [[ "$SERVICES_WERE_RUNNING" == true ]]; then
        log "Reiniciando servicios..."
        docker-compose up -d
        sleep 10
        log "Servicios reiniciados"
    fi
    
    log "Backup completo terminado"
}

# Función para listar backups
list_backups() {
    log "Backups disponibles en $BACKUP_BASE_DIR:"
    echo ""
    
    if [[ -d "$BACKUP_BASE_DIR" ]]; then
        ls -la "$BACKUP_BASE_DIR"/*.tar.gz 2>/dev/null | while read -r line; do
            filename=$(echo "$line" | awk '{print $9}')
            size=$(echo "$line" | awk '{print $5}')
            date=$(echo "$line" | awk '{print $6, $7, $8}')
            echo "  $(basename "$filename") - $size bytes - $date"
        done
    else
        info "No hay backups disponibles"
    fi
    echo ""
}

# Función para limpiar backups antiguos
cleanup_backups() {
    log "Limpiando backups antiguos (>30 días)..."
    
    if [[ -d "$BACKUP_BASE_DIR" ]]; then
        find "$BACKUP_BASE_DIR" -name "chirpstack_backup_*.tar.gz" -mtime +30 -delete
        find "$BACKUP_BASE_DIR" -name "chirpstack_backup_*" -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true
        log "Limpieza completada"
    else
        info "No hay directorio de backups para limpiar"
    fi
}

# Función para restaurar backup
restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Archivo de backup no encontrado: $backup_file"
        return 1
    fi
    
    log "Restaurando desde: $backup_file"
    
    # Crear directorio temporal para extracción
    local temp_dir="/tmp/chirpstack_restore_$(date +%s)"
    mkdir -p "$temp_dir"
    
    # Extraer backup
    log "Extrayendo backup..."
    tar -xzf "$backup_file" -C "$temp_dir" || {
        error "Error al extraer backup"
        rm -rf "$temp_dir"
        return 1
    }
    
    # Encontrar el directorio de backup extraído
    local extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "chirpstack_backup_*" | head -1)
    
    if [[ -z "$extracted_dir" ]]; then
        error "Estructura de backup inválida"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log "Detener servicios ChirpStack..."
    cd "$CHIRPSTACK_DIR" && docker-compose down || true
    
    # Restaurar configuraciones
    if [[ -d "$extracted_dir/chirpstack-docker" ]]; then
        log "Restaurando configuraciones ChirpStack..."
        cp -r "$extracted_dir/chirpstack-docker"/* "$CHIRPSTACK_DIR/" || {
            error "Error al restaurar configuraciones ChirpStack"
        }
    fi
    
    # Restaurar configuraciones Nginx
    if [[ -d "$extracted_dir/nginx" ]]; then
        log "Restaurando configuraciones Nginx..."
        cp -r "$extracted_dir/nginx/sites-available"/* /etc/nginx/sites-available/ || true
        cp "$extracted_dir/nginx/nginx.conf" /etc/nginx/ 2>/dev/null || true
        nginx -t && systemctl reload nginx || warning "Error al recargar Nginx"
    fi
    
    # Restaurar certificados SSL
    if [[ -d "$extracted_dir/ssl/letsencrypt" ]]; then
        log "Restaurando certificados SSL..."
        cp -r "$extracted_dir/ssl/letsencrypt"/* /etc/letsencrypt/ || true
    fi
    
    # Restaurar configuraciones de seguridad
    if [[ -d "$extracted_dir/security" ]]; then
        log "Restaurando configuraciones de seguridad..."
        cp "$extracted_dir/security/jail.local" /etc/fail2ban/ 2>/dev/null || true
        cp "$extracted_dir/security/iptables-chirpstack.sh" /etc/ 2>/dev/null || true
        systemctl restart fail2ban || true
    fi
    
    # Iniciar servicios
    log "Iniciando servicios ChirpStack..."
    cd "$CHIRPSTACK_DIR" && docker-compose up -d
    
    # Restaurar base de datos si existe
    if [[ -f "$extracted_dir/chirpstack_database.sql" ]]; then
        log "Esperando a que PostgreSQL esté listo..."
        sleep 30
        
        log "Restaurando base de datos..."
        cat "$extracted_dir/chirpstack_database.sql" | docker-compose exec -T postgres psql -U postgres chirpstack || {
            warning "Error al restaurar base de datos"
        }
    fi
    
    # Restaurar volúmenes si existen
    if [[ -d "$extracted_dir/volumes" ]]; then
        log "Restaurando volúmenes Docker..."
        
        # Detener servicios para restaurar volúmenes
        docker-compose down
        
        # Restaurar PostgreSQL
        if [[ -f "$extracted_dir/volumes/postgresql_data.tar.gz" ]]; then
            docker run --rm -v chirpstack-docker_postgresqldata:/data -v "$extracted_dir/volumes":/backup ubuntu tar xzf /backup/postgresql_data.tar.gz -C /data || true
        fi
        
        # Restaurar Redis
        if [[ -f "$extracted_dir/volumes/redis_data.tar.gz" ]]; then
            docker run --rm -v chirpstack-docker_redisdata:/data -v "$extracted_dir/volumes":/backup ubuntu tar xzf /backup/redis_data.tar.gz -C /data || true
        fi
        
        # Reiniciar servicios
        docker-compose up -d
    fi
    
    # Limpiar directorio temporal
    rm -rf "$temp_dir"
    
    log "Restauración completada"
    log "Verifica que todos los servicios estén funcionando correctamente"
}

# Función principal de backup
create_backup() {
    log "Iniciando proceso de backup..."
    
    # Crear directorio base de backups
    mkdir -p "$BACKUP_BASE_DIR"
    
    # Crear directorio específico para este backup
    mkdir -p "$BACKUP_DIR"
    
    # Crear archivo de información del backup
    cat > "$BACKUP_DIR/backup_info.txt" << EOF
ChirpStack Backup Information
============================
Date: $(date)
Backup Type: $BACKUP_TYPE
Server: $(hostname)
ChirpStack Version: $(cd "$CHIRPSTACK_DIR" && docker-compose exec chirpstack chirpstack --version 2>/dev/null || echo "Unknown")

Backup Contents:
$(if [[ "$BACKUP_TYPE" == "full" ]]; then echo "- Complete configuration and data"; fi)
$(if [[ "$BACKUP_TYPE" == "database" ]]; then echo "- Database only"; fi)
$(if [[ "$BACKUP_TYPE" == "config" ]]; then echo "- Configuration files only"; fi)
- ChirpStack configuration files
- Nginx configuration
- SSL certificates (if present)
- Security configurations
- System crontab

Restore Instructions:
1. Stop ChirpStack services
2. Run: $0 -r $(basename "$BACKUP_DIR").tar.gz
3. Verify services are running correctly
EOF
    
    # Ejecutar backup según el tipo
    case $BACKUP_TYPE in
        "full")
            backup_full
            ;;
        "database")
            backup_database
            ;;
        "config")
            backup_config
            ;;
        *)
            backup_full  # Por defecto
            ;;
    esac
    
    # Comprimir backup
    log "Comprimiendo backup..."
    cd "$BACKUP_BASE_DIR"
    tar -czf "$(basename "$BACKUP_DIR").tar.gz" "$(basename "$BACKUP_DIR")" || {
        error "Error al comprimir backup"
        return 1
    }
    
    # Limpiar directorio sin comprimir
    rm -rf "$BACKUP_DIR"
    
    # Mostrar información del backup
    local backup_file="$BACKUP_BASE_DIR/$(basename "$BACKUP_DIR").tar.gz"
    local backup_size=$(du -h "$backup_file" | cut -f1)
    
    log "Backup completado exitosamente"
    info "Archivo: $backup_file"
    info "Tamaño: $backup_size"
    
    # Limpiar backups antiguos automáticamente
    cleanup_backups
}

# Parsear argumentos
BACKUP_TYPE="full"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--full)
            BACKUP_TYPE="full"
            shift
            ;;
        -d|--database)
            BACKUP_TYPE="database"
            shift
            ;;
        -c|--config)
            BACKUP_TYPE="config"
            shift
            ;;
        -r|--restore)
            if [[ -n "$2" ]]; then
                restore_backup "$2"
                exit $?
            else
                error "Especifica el archivo de backup para restaurar"
                exit 1
            fi
            ;;
        --list)
            list_backups
            exit 0
            ;;
        --cleanup)
            cleanup_backups
            exit 0
            ;;
        *)
            error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Verificar que ChirpStack esté instalado
if [[ ! -d "$CHIRPSTACK_DIR" ]]; then
    error "ChirpStack no parece estar instalado en $CHIRPSTACK_DIR"
    exit 1
fi

# Ejecutar backup
{
    create_backup
} 2>&1 | tee -a "$LOG_FILE"