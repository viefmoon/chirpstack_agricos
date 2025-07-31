#!/bin/bash

# ChirpStack Connection Diagnostics Script
# Helps diagnose PostgreSQL connection issues

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

CHIRPSTACK_DIR="/opt/chirpstack-docker"

echo -e "${BLUE}ChirpStack Connection Diagnostics${NC}"
echo "=================================="
echo ""

# Verificar que estamos en el directorio correcto
if [[ ! -d "$CHIRPSTACK_DIR" ]]; then
    error "Directorio ChirpStack no encontrado: $CHIRPSTACK_DIR"
    exit 1
fi

cd "$CHIRPSTACK_DIR"

# 1. Verificar estado de contenedores
log "1. Verificando estado de contenedores..."
docker-compose ps
echo ""

# 2. Verificar configuración de PostgreSQL
log "2. Verificando configuración de PostgreSQL..."
echo "Credenciales en .env:"
grep "POSTGRES" .env || warning "No se encontraron credenciales POSTGRES en .env"
echo ""

# 3. Verificar logs de PostgreSQL
log "3. Logs recientes de PostgreSQL..."
docker-compose logs --tail=20 postgres
echo ""

# 4. Verificar logs de ChirpStack
log "4. Logs recientes de ChirpStack..."
docker-compose logs --tail=20 chirpstack
echo ""

# 5. Probar conexión a PostgreSQL desde dentro del contenedor
log "5. Probando conexión a base de datos..."
if docker-compose exec -T postgres pg_isready -U chirpstack -d chirpstack > /dev/null 2>&1; then
    info "✓ PostgreSQL está aceptando conexiones"
    
    # Probar conexión completa
    if docker-compose exec -T postgres psql -U chirpstack -d chirpstack -c "SELECT version();" > /dev/null 2>&1; then
        info "✓ Conexión a base de datos exitosa"
    else
        error "✗ No se puede conectar a la base de datos"
    fi
else
    error "✗ PostgreSQL no está aceptando conexiones"
fi
echo ""

# 6. Verificar tablas de ChirpStack
log "6. Verificando tablas de ChirpStack..."
TABLES=$(docker-compose exec -T postgres psql -U chirpstack -d chirpstack -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | xargs || echo "0")
if [[ "$TABLES" -gt "0" ]]; then
    info "✓ Base de datos tiene $TABLES tablas"
else
    warning "⚠ Base de datos parece estar vacía o no inicializada"
fi
echo ""

# 7. Verificar puertos
log "7. Verificando puertos..."
if command -v netstat > /dev/null; then
    netstat -tlnp | grep -E "(8080|1700|1883|5432)" || warning "Algunos puertos pueden no estar disponibles"
else
    warning "netstat no disponible, instalando..."
    apt update && apt install -y net-tools
    netstat -tlnp | grep -E "(8080|1700|1883|5432)" || warning "Algunos puertos pueden no estar disponibles"
fi
echo ""

# 8. Verificar conectividad web
log "8. Verificando interfaz web..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080" | grep -q "200\|302"; then
    info "✓ Interfaz web responde"
else
    warning "⚠ Interfaz web no responde en puerto 8080"
fi
echo ""

# 9. Recomendaciones
log "9. Recomendaciones de solución..."
echo ""
if ! docker-compose ps | grep -q "Up.*chirpstack"; then
    echo "🔧 ChirpStack no está corriendo:"
    echo "   docker-compose restart chirpstack"
    echo ""
fi

if ! docker-compose ps | grep -q "Up.*postgres"; then
    echo "🔧 PostgreSQL no está corriendo:"
    echo "   docker-compose restart postgres"
    echo ""
fi

echo "📋 Comandos útiles:"
echo "   - Reiniciar todo: docker-compose restart"
echo "   - Ver logs: docker-compose logs -f"
echo "   - Recrear servicios: docker-compose down && docker-compose up -d"
echo "   - Limpiar volúmenes: docker-compose down -v && docker-compose up -d"
echo ""

echo -e "${GREEN}Diagnóstico completado${NC}"