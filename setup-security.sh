#!/bin/bash

# ChirpStack DigitalOcean - Script de Configuración de Seguridad
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

PUBLIC_IP="143.244.144.51"

log "Iniciando configuración de seguridad para ChirpStack..."

# Configurar dominio automáticamente si se pasa como variable de entorno
if [[ -n "$AUTO_DOMAIN" ]]; then
    DOMAIN="$AUTO_DOMAIN"
    HTTPS_ENABLED="$AUTO_HTTPS"
    info "Usando configuración automática: $DOMAIN"
else
    # Preguntar por el dominio solo si no se configuró automáticamente
    echo ""
    echo -e "${BLUE}¿Tienes un dominio configurado para este servidor?${NC}"
    echo "Si tienes un dominio (ej: network.sense.lat), podremos configurar HTTPS"
    echo "Si no tienes dominio, solo configuraremos seguridad básica"
    echo ""
    read -p "Ingresa tu dominio (o presiona Enter para solo IP): " DOMAIN

    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$PUBLIC_IP"
        HTTPS_ENABLED=false
        info "Usando IP pública: $PUBLIC_IP"
    else
        HTTPS_ENABLED=true
        info "Usando dominio: $DOMAIN"
    fi
fi

# Configurar fail2ban para protección contra ataques de fuerza bruta
log "Instalando y configurando fail2ban..."
apt install -y fail2ban

# Configurar fail2ban para SSH
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-noscript]
enabled = true
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
filter = nginx-noproxy
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

systemctl enable fail2ban
systemctl start fail2ban

# Configurar límites de conexión más estrictos
log "Configurando límites de conexión..."
cat >> /etc/security/limits.conf << EOF
# Límites de conexión para ChirpStack
* soft nofile 65536
* hard nofile 65536
chirpstack soft nproc 4096
chirpstack hard nproc 8192
EOF

# Configurar iptables adicionales para protección DDoS básica
log "Configurando reglas de firewall avanzadas..."

# Crear script de reglas iptables personalizadas
cat > /etc/iptables-chirpstack.sh << 'EOF'
#!/bin/bash
# Reglas iptables avanzadas para ChirpStack

# Limpiar reglas existentes
# iptables -F
# iptables -X
# iptables -t nat -F
# iptables -t nat -X

# Protección contra ataques SYN flood
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# Protección contra ping flood
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# Protección específica para puertos ChirpStack
# Limitar conexiones por IP al puerto 8080 (Web interface)
iptables -A INPUT -p tcp --dport 8080 -m connlimit --connlimit-above 10 -j DROP

# Limitar conexiones por IP al puerto 1883 (MQTT)
iptables -A INPUT -p tcp --dport 1883 -m connlimit --connlimit-above 20 -j DROP

echo "Reglas iptables aplicadas"
EOF

chmod +x /etc/iptables-chirpstack.sh

# Aplicar las reglas
/etc/iptables-chirpstack.sh

# Configurar arranque automático de reglas iptables
cat > /etc/systemd/system/iptables-chirpstack.service << EOF
[Unit]
Description=ChirpStack iptables rules
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/iptables-chirpstack.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable iptables-chirpstack.service

# Configurar monitoreo básico con logrotate mejorado
log "Configurando monitoreo y logs..."
cat > /etc/logrotate.d/chirpstack-security << EOF
/var/log/chirpstack/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    copytruncate
    notifempty
    su chirpstack chirpstack
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}

/var/log/nginx/chirpstack.*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    copytruncate
    notifempty
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF

# Si hay dominio, configurar HTTPS con Let's Encrypt
if [[ "$HTTPS_ENABLED" == true ]]; then
    log "Configurando HTTPS con Let's Encrypt para $DOMAIN..."
    
    # Verificar que el dominio apunte al servidor
    DOMAIN_IP=$(dig +short $DOMAIN)
    if [[ "$DOMAIN_IP" != "$PUBLIC_IP" ]]; then
        warning "El dominio $DOMAIN no parece apuntar a este servidor ($PUBLIC_IP)"
        warning "IP del dominio: $DOMAIN_IP"
        warning "Continuando de todos modos..."
    fi
    
    # Actualizar configuración de Nginx para el dominio
    cat > /etc/nginx/sites-available/chirpstack << EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Redirección para Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redireccionar todo el tráfico HTTP a HTTPS (se activará después del certificado)
    # return 301 https://\$server_name\$request_uri;

    # Configuración temporal para obtener certificado
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
    }
}
EOF

    nginx -t && systemctl reload nginx
    
    # Crear directorio para challenges de Let's Encrypt
    mkdir -p /var/www/html/.well-known
    
    log "Obteniendo certificado SSL de Let's Encrypt..."
    if certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --redirect; then
        log "Certificado SSL configurado exitosamente"
        
        # Configurar renovación automática
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | crontab -
        
        # Actualizar configuración con headers de seguridad mejorados
        cat > /etc/nginx/sites-available/chirpstack << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem;

    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss: ws:;" always;

    # Client settings
    client_max_body_size 10M;

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
        
        nginx -t && systemctl reload nginx
    else
        error "No se pudo obtener el certificado SSL"
        warning "Continuando con HTTP..."
    fi
else
    log "Configurando Nginx para acceso solo por IP..."
fi

# Crear script de monitoreo de seguridad
log "Creando script de monitoreo de seguridad..."
cat > /opt/security-monitor.sh << 'EOF'
#!/bin/bash

# Script de monitoreo de seguridad para ChirpStack

echo "=== ChirpStack Security Report - $(date) ==="
echo ""

echo "1. Fail2ban Status:"
fail2ban-client status
echo ""

echo "2. Active connections to ChirpStack ports:"
netstat -tlnp | grep -E '(8080|1700|1883)' | head -20
echo ""

echo "3. Recent authentication failures:"
journalctl --since "1 hour ago" | grep -i "authentication failure" | tail -10
echo ""

echo "4. System resource usage:"
df -h / | tail -1
free -h | grep Mem
echo ""

echo "5. ChirpStack container status:"
cd /opt/chirpstack-docker && docker-compose ps
echo ""

echo "6. Recent Nginx errors:"
tail -10 /var/log/nginx/chirpstack.error.log 2>/dev/null || echo "No errors found"
echo ""

echo "7. SSL Certificate status (if applicable):"
if [[ -d "/etc/letsencrypt/live" ]]; then
    certbot certificates 2>/dev/null || echo "No SSL certificates found"
else
    echo "No SSL certificates configured"
fi
echo ""

echo "=== End of Security Report ==="
EOF

chmod +x /opt/security-monitor.sh

# Crear tarea cron para monitoreo automático
log "Configurando monitoreo automático..."
(crontab -l 2>/dev/null; echo "0 6 * * * /opt/security-monitor.sh >> /var/log/chirpstack/security-report.log 2>&1") | crontab -

# Configurar backup automático de configuraciones críticas
log "Configurando backup automático de configuraciones..."
mkdir -p /opt/backups
cat > /opt/backup-config.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Crear directorio de backup con fecha
mkdir -p "$BACKUP_DIR/$DATE"

# Backup de configuraciones importantes
cp -r /opt/chirpstack-docker "$BACKUP_DIR/$DATE/"
cp -r /etc/nginx/sites-available "$BACKUP_DIR/$DATE/"
cp /etc/fail2ban/jail.local "$BACKUP_DIR/$DATE/" 2>/dev/null || true

# Backup de la base de datos ChirpStack
cd /opt/chirpstack-docker
docker-compose exec -T postgres pg_dump -U postgres chirpstack > "$BACKUP_DIR/$DATE/chirpstack_db_backup.sql" 2>/dev/null || echo "Database backup failed"

# Comprimir backup
cd "$BACKUP_DIR"
tar -czf "chirpstack_backup_$DATE.tar.gz" "$DATE"
rm -rf "$DATE"

# Mantener solo los últimos 7 backups
find "$BACKUP_DIR" -name "chirpstack_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/chirpstack_backup_$DATE.tar.gz"
EOF

chmod +x /opt/backup-config.sh

# Programar backup diario
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/backup-config.sh >> /var/log/chirpstack/backup.log 2>&1") | crontab -

# Configurar directorio de logs si no existe
mkdir -p /var/log/chirpstack
chown chirpstack:chirpstack /var/log/chirpstack

# Crear resumen de seguridad
log "Creando resumen de configuración de seguridad..."
cat > /opt/SECURITY_CONFIG.txt << EOF
ChirpStack Security Configuration Summary
=========================================

Date: $(date)
Server: $DOMAIN ($PUBLIC_IP)

Security Measures Configured:
✓ Fail2ban installed and configured
✓ Advanced iptables rules applied
✓ Nginx security headers configured
✓ Log rotation configured
✓ Automated security monitoring
✓ Automated configuration backups
$(if [[ "$HTTPS_ENABLED" == true ]]; then echo "✓ HTTPS/SSL configured with Let's Encrypt"; else echo "⚠ HTTPS not configured (no domain provided)"; fi)

Important Files:
- Security monitoring: /opt/security-monitor.sh
- Configuration backup: /opt/backup-config.sh
- Fail2ban config: /etc/fail2ban/jail.local
- Iptables rules: /etc/iptables-chirpstack.sh
- Nginx config: /etc/nginx/sites-available/chirpstack

Scheduled Tasks:
- Daily security report: 06:00 AM
- Daily configuration backup: 02:00 AM
$(if [[ "$HTTPS_ENABLED" == true ]]; then echo "- SSL certificate renewal: 03:00 AM"; fi)

Access Information:
- Web Interface: $(if [[ "$HTTPS_ENABLED" == true ]]; then echo "https://$DOMAIN"; else echo "http://$DOMAIN:8080"; fi)
- Default Login: admin / admin
- IMPORTANT: Change default password immediately!

Security Recommendations:
1. Change default admin password immediately
2. Create additional user accounts as needed  
3. Monitor security reports in /var/log/chirpstack/security-report.log
4. Review fail2ban logs regularly: journalctl -u fail2ban
5. Test backup restoration procedures
6. Monitor SSL certificate expiration (if applicable)

Commands:
- Run security check: /opt/security-monitor.sh
- Create manual backup: /opt/backup-config.sh
- Check fail2ban status: fail2ban-client status
- View recent blocked IPs: fail2ban-client status sshd

EOF

log "¡Configuración de seguridad completada exitosamente!"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  SEGURIDAD CONFIGURADA EXITOSAMENTE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [[ "$HTTPS_ENABLED" == true ]]; then
    echo -e "${BLUE}Acceso seguro configurado:${NC}"
    echo -e "URL: ${GREEN}https://$DOMAIN${NC}"
else
    echo -e "${BLUE}Acceso configurado:${NC}"
    echo -e "URL: ${YELLOW}http://$PUBLIC_IP:8080${NC}"
    echo -e "${YELLOW}Recomendación: Configura un dominio y ejecuta este script nuevamente para HTTPS${NC}"
fi

echo ""
echo -e "${BLUE}Medidas de seguridad implementadas:${NC}"
echo "✓ Fail2ban para protección contra ataques de fuerza bruta"
echo "✓ Reglas iptables avanzadas contra DDoS"
echo "✓ Headers de seguridad en Nginx"
echo "✓ Monitoreo automático de seguridad"
echo "✓ Backup automático de configuraciones"
if [[ "$HTTPS_ENABLED" == true ]]; then
    echo "✓ HTTPS con certificado Let's Encrypt"
fi

echo ""
echo -e "${RED}¡IMPORTANTE!${NC}"
echo -e "${RED}1. Cambia la contraseña por defecto (admin/admin) inmediatamente${NC}"
echo -e "${RED}2. Revisa el resumen de seguridad en: /opt/SECURITY_CONFIG.txt${NC}"

echo ""
echo -e "${BLUE}Comandos de monitoreo:${NC}"
echo "- Reporte de seguridad: /opt/security-monitor.sh"
echo "- Estado de fail2ban: fail2ban-client status"
echo "- Backup manual: /opt/backup-config.sh"

echo ""

exit 0