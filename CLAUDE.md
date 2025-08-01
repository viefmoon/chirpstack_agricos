# CLAUDE.md - Información del Proyecto

## Descripción del Proyecto

**ChirpStack Agrícola v2.0 (Native)** - Sistema completo de instalación nativa automática de ChirpStack v4 en DigitalOcean siguiendo la guía oficial, con integración opcional de Supabase para aplicaciones IoT agrícolas.

## Estructura del Proyecto

```
chirpstack_agricos/
├── install.sh                               # Script principal de instalación automática
├── README.md                                # Documentación principal
├── CLAUDE.md                                # Este archivo
├── scripts/                                 # Scripts de instalación modular
│   ├── install-dependencies.sh              # Instalación de dependencias del sistema
│   ├── configure-chirpstack.sh              # Configuración nativa de ChirpStack v4
│   ├── setup-security.sh                    # Configuración de seguridad (HTTPS, firewall)
│   ├── setup-supabase-service.sh            # Instalación del servicio Supabase
│   └── backup-chirpstack.sh                 # Sistema de backup automático
├── services/                                # Servicios adicionales
│   └── supabase/                            # Integración con Supabase
│       ├── chirpstack-supabase-service.js   # Servicio Node.js para insertar datos
│       ├── package.json                     # Dependencias npm
│       └── .env.example                     # Plantilla de configuración
└── docs/                                    # Documentación detallada
    └── chirpstack-digitalocean-deployment-guide.md  # Guía completa de despliegue
```

## Tecnologías Utilizadas

### Backend/Infraestructura
- **ChirpStack v4**: Servidor LoRaWAN unificado (Network + Application Server)
- **Ubuntu 24.04 LTS**: Sistema operativo base
- **Docker & Docker Compose**: Containerización de servicios
- **PostgreSQL 14**: Base de datos principal
- **Redis 7**: Cache y sesiones
- **Mosquitto**: Broker MQTT
- **Nginx**: Reverse proxy y servidor web
- **Let's Encrypt**: Certificados SSL/TLS

### Servicios Adicionales
- **Node.js LTS**: Runtime para servicio Supabase
- **Supabase**: Backend-as-a-Service para almacenamiento de datos
- **systemd**: Gestión del servicio Supabase

### Seguridad
- **UFW (Uncomplicated Firewall)**: Firewall básico
- **fail2ban**: Protección contra ataques de fuerza bruta
- **iptables**: Reglas avanzadas de firewall
- **Certbot**: Gestión automática de certificados SSL

## Configuraciones del Servidor

### Servidor de Producción
- **Servidor**: Digital Ocean Droplet
- **IP Pública**: 143.244.144.51
- **Dominio**: network.sense.lat
- **Región LoRaWAN**: US915 (canales 8-15)

### Puertos de Red
- **8080**: Interfaz web ChirpStack
- **1700/UDP**: Gateway Bridge (Semtech UDP)
- **1883**: MQTT Broker
- **80/443**: HTTP/HTTPS (Nginx)
- **22**: SSH

### Credenciales por Defecto
- **Usuario**: admin
- **Contraseña**: admin
- ⚠️ **CRÍTICO**: Cambiar inmediatamente después de la instalación

## Comandos Importantes

### Conexión SSH
```bash
# Conectar al servidor
ssh root@143.244.144.51

# Si reconstruiste el droplet, borra las claves SSH anteriores
ssh-keygen -R 143.244.144.51
```

### Instalación
```bash
# Instalación automática completa con HTTPS
sudo ./install.sh

# Instalación manual paso a paso
sudo ./scripts/install-dependencies.sh
sudo ./scripts/configure-chirpstack.sh
sudo ./scripts/setup-security.sh
sudo ./scripts/setup-supabase-service.sh
```

### Gestión de Servicios ChirpStack (Nativo)
```bash
# Estado de todos los servicios
/opt/chirpstack-status.sh

# Ver logs en tiempo real
/opt/chirpstack-logs.sh

# Reiniciar todos los servicios
/opt/chirpstack-restart.sh

# Comandos systemd directos
systemctl status chirpstack
systemctl status chirpstack-gateway-bridge
systemctl status mosquitto
systemctl restart chirpstack
journalctl -u chirpstack -f
```

### Gestión del Servicio Supabase
```bash
# Configurar credenciales (interactivo)
sudo /opt/chirpstack-supabase-service/configure-env.sh

# Gestión del servicio
sudo systemctl start chirpstack-supabase
sudo systemctl stop chirpstack-supabase
sudo systemctl restart chirpstack-supabase
sudo systemctl status chirpstack-supabase

# Ver logs
sudo journalctl -u chirpstack-supabase -f
```

### Backup y Restauración
```bash
# Backup completo
sudo ./scripts/backup-chirpstack.sh

# Solo base de datos
sudo ./scripts/backup-chirpstack.sh --database

# Restaurar backup
sudo ./scripts/backup-chirpstack.sh --restore backup_file.tar.gz

# Listar backups
sudo ./scripts/backup-chirpstack.sh --list
```

### Monitoreo
```bash
# Monitoreo de seguridad
/opt/security-monitor.sh

# Verificar región LoRaWAN
docker-compose logs chirpstack | grep -i region

# Estado de puertos
netstat -tlnp | grep -E '(8080|1700|1883)'

# Estado del firewall
ufw status
```

## Archivos de Configuración Importantes

### ChirpStack (Nativo)
- `/etc/chirpstack/chirpstack.toml` - Configuración principal
- `/etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml` - Configuración Gateway Bridge
- `/opt/CHIRPSTACK_NATIVE_INSTALL.txt` - Información de instalación

### Nginx
- `/etc/nginx/sites-available/chirpstack` - Configuración del virtual host
- `/etc/nginx/nginx.conf` - Configuración principal de Nginx

### Supabase Service
- `/opt/chirpstack-supabase-service/.env` - Credenciales de Supabase
- `/opt/chirpstack-supabase-service/chirpstack-supabase-service.js` - Código del servicio

### Seguridad
- `/etc/ufw/user.rules` - Reglas de firewall
- `/etc/fail2ban/jail.local` - Configuración de fail2ban

## Ubicaciones de Archivos de Sistema

### Logs
- `/var/log/nginx/chirpstack.access.log` - Logs de acceso web
- `/var/log/nginx/chirpstack.error.log` - Logs de errores web
- `/var/log/chirpstack/security-report.log` - Reportes de seguridad
- `journalctl -u chirpstack -f` - Logs de ChirpStack en tiempo real
- `journalctl -u chirpstack-gateway-bridge -f` - Logs de Gateway Bridge

### Backups
- `/opt/backups/chirpstack/` - Backups automáticos
- `/opt/INSTALLATION_SUMMARY.txt` - Resumen de instalación

### Certificados SSL
- `/etc/letsencrypt/live/network.sense.lat/` - Certificados SSL

## Tipos de Sensores Soportados

### Sensores Individuales
- **N100K/N10K**: Temperatura
- **HDS10**: Humedad
- **RTD/DS18B20**: Temperatura
- **PH**: pH
- **COND**: Conductividad
- **SOILH**: Humedad del suelo
- **VEML7700**: Luminosidad

### Sensores Múltiples
- **SHT30/SHT40**: Temperatura + Humedad
- **BME280/BME680**: Temperatura + Humedad + Presión (+ Gas)
- **CO2**: CO2 + Temperatura + Humedad
- **ENV4**: Humedad + Temperatura + Presión + Luminosidad

## Regiones LoRaWAN Disponibles

- **us915_0**: Estados Unidos, Canadá, México, Brasil (canales 0-7)
- **us915_1**: Estados Unidos, Canadá, México, Brasil (canales 8-15) - CONFIGURADO
- **eu868**: Europa, África, Rusia
- **as923**: Asia-Pacífico (Japón, Singapur, etc.)
- **au915_0**: Australia, Nueva Zelanda (canales 0-7)
- **cn470_10**: China
- **in865**: India

## Troubleshooting Común

### Problema de conexión SSH después de rebuild
```bash
# Error común después de reconstruir droplet:
# WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!

# Solución - Borrar claves SSH anteriores:
ssh-keygen -R 143.244.144.51

# Alternativa manual:
# Windows: Editar C:\Users\TuUsuario\.ssh\known_hosts
# Linux/macOS: Editar ~/.ssh/known_hosts
# Buscar y eliminar la línea que contiene 143.244.144.51
```

### Interfaz web no accesible
```bash
# Verificar servicios
systemctl status nginx
docker-compose ps

# Ver logs
docker-compose logs chirpstack
tail -f /var/log/nginx/error.log
```

### Gateway no se conecta
```bash
# Verificar gateway bridge
docker-compose logs chirpstack-gateway-bridge

# Verificar puerto UDP
netstat -ulnp | grep 1700

# Verificar región
docker-compose logs chirpstack | grep -i region
```

### Problemas con servicios
```bash
# Reiniciar todos los servicios
/opt/chirpstack-restart.sh

# Ver estado detallado
/opt/chirpstack-status.sh

# Ver logs específicos
journalctl -u chirpstack -f
journalctl -u chirpstack-gateway-bridge -f
```

## Características de Seguridad

- **fail2ban**: Protección contra ataques de fuerza bruta
- **UFW Firewall**: Solo puertos necesarios abiertos
- **HTTPS**: Certificados SSL automáticos con Let's Encrypt
- **Headers de seguridad**: HSTS, CSP, X-Frame-Options
- **Monitoreo automático**: Reportes de seguridad diarios
- **Backups automáticos**: Respaldo diario a las 02:00 AM

## Tareas Automatizadas (cron)

- **02:00 AM**: Backup automático completo
- **03:00 AM**: Renovación de certificados SSL
- **06:00 AM**: Reporte de seguridad
- **Diaria**: Rotación de logs

## Próximos Pasos Después de la Instalación

1. **Cambiar contraseña admin** (CRÍTICO)
2. **Configurar DNS** para network.sense.lat
3. **Configurar servicio Supabase** (opcional)
4. **Registrar primer gateway**
5. **Crear primera aplicación**
6. **Programar backups regulares**
7. **Configurar monitoreo**

## Recursos de Soporte

- **Documentación oficial**: https://www.chirpstack.io/docs/
- **Foro de comunidad**: https://forum.chirpstack.io/
- **GitHub**: https://github.com/chirpstack/chirpstack
- **Guía local**: docs/chirpstack-digitalocean-deployment-guide.md

## Notas de Desarrollo

Este proyecto está optimizado para:
- **Instalaciones de producción** en DigitalOcean
- **Aplicaciones agrícolas** IoT con sensores LoRaWAN
- **Integración con Supabase** para almacenamiento de datos
- **Mantenimiento automatizado** con scripts de utilidad
- **Seguridad robusta** para entornos productivos

⚠️ **Importante**: Siempre cambiar las credenciales por defecto antes de usar en producción.