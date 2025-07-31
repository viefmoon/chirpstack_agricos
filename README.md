# ChirpStack v4 en DigitalOcean - Guía de Despliegue Automático

Esta es una guía completa para deployar ChirpStack v4 en un droplet de DigitalOcean desde cero, incluyendo scripts de automatización para simplificar el proceso.

> **ChirpStack v4 + Ubuntu 24.04 LTS:** Combinación optimizada que unifica el Network Server y Application Server en un solo componente, aprovechando las últimas mejoras de seguridad y rendimiento de Ubuntu 24.04.

## ⚡ Instalación Súper Rápida

```bash
# 1. Conectar al servidor
ssh root@143.244.144.51

# 2. Descargar y ejecutar
git clone https://github.com/viefmoon/chirpstack_agricos.git
cd chirpstack_agricos
chmod +x *.sh
sudo ./quick-install.sh

# 3. CAMBIAR CONTRASEÑA (CRÍTICO):
#    - Ir a: http://143.244.144.51:8080
#    - Login: admin/admin
#    - Avatar → Change password

# 4. Configurar DNS: network.sense.lat → 143.244.144.51
# 5. Acceder: https://network.sense.lat
```

## 📁 Archivos Incluidos

- **`chirpstack-digitalocean-deployment-guide.md`** - Guía detallada paso a paso
- **`install-dependencies.sh`** - Script de instalación automática de dependencias
- **`configure-chirpstack.sh`** - Script de configuración automática de ChirpStack
- **`setup-security.sh`** - Script de configuración de seguridad y HTTPS
- **`backup-chirpstack.sh`** - Script completo de backup y restauración
- **`quick-install.sh`** - Instalación automática completa

## 🚀 Instalación Rápida (Automática)

### Paso 1: Preparar el Servidor

1. **Crear droplet Ubuntu 24.04 LTS en DigitalOcean (mínimo 2GB RAM)**
2. **Configurar dominio (opcional pero recomendado):**
   - En DigitalOcean: **Networking** → **Domains** → **Add Domain**
   - Ingresa tu dominio y selecciona el droplet
   - Cambiar nameservers en tu registrador a los de DigitalOcean
3. **Conectar vía SSH como root:**
   ```bash
   ssh root@143.244.144.51
   ```

### Paso 2: Descargar Scripts

```bash
# Crear directorio de trabajo
mkdir -p /opt/chirpstack-setup
cd /opt/chirpstack-setup

# Clonar repositorio con todos los scripts
git clone https://github.com/viefmoon/chirpstack_agricos.git .

# Hacer scripts ejecutables
chmod +x *.sh

# Verificar archivos descargados
ls -la *.sh
```

### Paso 3: Ejecutar Instalación

#### Opción A: Instalación Automática (Recomendado)
```bash
# Instalación completa en un solo comando
sudo ./quick-install.sh
```

#### Opción B: Instalación Manual (Paso a Paso)
```bash
# 1. Instalar dependencias (Docker, Nginx, etc.)
sudo ./install-dependencies.sh

# 2. Configurar ChirpStack
sudo ./configure-chirpstack.sh

# 3. Configurar seguridad (opcional pero recomendado)
sudo ./setup-security.sh
```

## 🔧 Instalación Manual

Si prefieres seguir el proceso paso a paso, consulta la guía completa en `chirpstack-digitalocean-deployment-guide.md`.

## 📋 Descripción de Scripts

### 1. install-dependencies.sh

**Qué hace:**
- Actualiza el sistema Ubuntu
- Instala Docker y Docker Compose
- Instala herramientas básicas (nginx, ufw, certbot, etc.)
- Crea usuario `chirpstack`
- Configura firewall básico
- Optimiza configuración del sistema

**Uso:**
```bash
sudo ./install-dependencies.sh
```

### 2. configure-chirpstack.sh

**Qué hace:**
- Clona el repositorio Docker de ChirpStack
- Configura variables de entorno automáticamente
- Genera contraseñas seguras para PostgreSQL
- Configura Docker Compose para producción
- Inicia todos los servicios
- Configura Nginx como reverse proxy
- Crea scripts de utilidad

**Uso:**
```bash
sudo ./configure-chirpstack.sh
```

**Resultado:**
- ChirpStack accesible en `http://143.244.144.51:8080`
- Usuario: `admin` / Contraseña: `admin`

### 3. setup-security.sh

**Qué hace:**
- Instala y configura fail2ban
- Configura reglas iptables avanzadas
- Configura HTTPS con Let's Encrypt (si tienes dominio)
- Implementa headers de seguridad en Nginx
- Configura monitoreo de seguridad automático
- Configura backups automáticos

**Uso:**
```bash
sudo ./setup-security.sh
```

Durante la ejecución te preguntará si tienes un dominio configurado para habilitar HTTPS.

### 4. backup-chirpstack.sh

**Qué hace:**
- Crea backups completos de ChirpStack
- Incluye base de datos, configuraciones y certificados SSL
- Permite restauración completa del sistema
- Limpieza automática de backups antiguos

**Uso:**
```bash
# Si no tienes los scripts, descargar:
# git clone https://github.com/viefmoon/chirpstack_agricos.git
# cd chirpstack_agricos

# Backup completo
sudo ./backup-chirpstack.sh

# Solo base de datos
sudo ./backup-chirpstack.sh --database

# Solo configuraciones
sudo ./backup-chirpstack.sh --config

# Listar backups
sudo ./backup-chirpstack.sh --list

# Restaurar backup
sudo ./backup-chirpstack.sh --restore backup_file.tar.gz

# Limpiar backups antiguos
sudo ./backup-chirpstack.sh --cleanup
```

## 🔍 Verificación Post-Instalación

### 1. Verificar Servicios

```bash
# Verificar contenedores Docker
cd /opt/chirpstack-docker
docker-compose ps

# Verificar logs
docker-compose logs chirpstack
```

### 2. Acceder a la Interfaz Web

1. Abrir navegador: `http://YOUR_IP:8080` (o tu dominio si configuraste HTTPS)
2. Login: `admin` / `admin`
3. **¡IMPORTANTE!** Cambiar contraseña inmediatamente

### 3. Verificar Puertos

```bash
# Verificar puertos abiertos
netstat -tlnp | grep -E '(8080|1700|1883)'
```

## 📊 Monitoreo y Mantenimiento

### Scripts de Utilidad Creados

```bash
# Iniciar ChirpStack
/opt/chirpstack-docker/start-chirpstack.sh

# Detener ChirpStack  
/opt/chirpstack-docker/stop-chirpstack.sh

# Ver logs en tiempo real
/opt/chirpstack-docker/logs-chirpstack.sh

# Ver estado del sistema
/opt/chirpstack-docker/status-chirpstack.sh

# Monitoreo de seguridad
/opt/security-monitor.sh
```

### Tareas Automáticas Configuradas

- **Backup diario:** 02:00 AM
- **Reporte de seguridad:** 06:00 AM  
- **Renovación SSL:** 03:00 AM (si aplica)
- **Limpieza de logs:** Rotación diaria

## 🔧 Configuración Avanzada

### Cambiar Región LoRaWAN

**⚠️ CRÍTICO:** La región debe coincidir con tu ubicación geográfica y gateway.

#### Regiones Disponibles:
- **US915:** Estados Unidos, Canadá, México, Brasil
- **EU868:** Europa, África, Rusia  
- **AS923:** Asia-Pacífico (Japón, Singapur, etc.)
- **AU915:** Australia, Nueva Zelanda
- **CN470:** China
- **IN865:** India

#### Cambiar Región:
```bash
# Editar archivo de configuración
nano /opt/chirpstack-docker/.env

# Cambiar línea:
CHIRPSTACK_REGION=EU868  # Cambiar por tu región

# Reiniciar servicios
cd /opt/chirpstack-docker
docker-compose restart
```

#### Verificar Configuración:
```bash
# Ver logs para confirmar región cargada
docker-compose logs chirpstack | grep -i region
```

### Configurar `network.sense.lat`

1. **En el panel de DigitalOcean:**
   - Ve a **Networking** → **Domains**
   - Busca `sense.lat` (si no existe, agrégalo primero)
   - Clic **Add Record**
   - **Tipo:** A, **Hostname:** network, **Directs to:** tu droplet

2. **Ejecutar script de seguridad:**
   ```bash
   sudo ./setup-security.sh
   # Ingresa: network.sense.lat
   ```

**Resultado:** ChirpStack accesible en `https://network.sense.lat`

### Integrar con Gateway Externo

Los gateways pueden conectarse usando:
- **UDP Packet Forwarder:** Puerto 1700/UDP
- **MQTT:** Puerto 1883
- **Basics Station:** Websocket en puerto 3001

## 🚨 Troubleshooting

### Problema: No se puede acceder a la interfaz web

```bash
# Verificar servicios
docker-compose ps
systemctl status nginx

# Verificar logs
docker-compose logs chirpstack
tail -f /var/log/nginx/error.log
```

### Problema: Gateway no se conecta

```bash
# Verificar gateway bridge
docker-compose logs chirpstack-gateway-bridge

# Verificar puerto UDP
ufw status | grep 1700
netstat -ulnp | grep 1700

# IMPORTANTE: Verificar que la región coincida
docker-compose logs chirpstack | grep -i region
```

**Causa común:** Región mal configurada
- Gateway configurado para EU868 pero ChirpStack en US915
- Solución: Cambiar región en `/opt/chirpstack-docker/.env`

### Problema: Base de datos no funciona

```bash
# Verificar PostgreSQL
docker-compose logs postgres

# Conectar a la base de datos
docker-compose exec postgres psql -U postgres chirpstack
```

## 📝 Requisitos del Sistema

### Mínimos
- **OS:** Ubuntu 24.04 LTS x64
- **RAM:** 2GB
- **Almacenamiento:** 20GB SSD
- **CPU:** 1 vCPU
- **Ancho de banda:** 1TB

### Recomendados (Producción)
- **OS:** Ubuntu 24.04 LTS x64
- **RAM:** 4GB
- **Almacenamiento:** 80GB SSD  
- **CPU:** 2 vCPUs
- **Ancho de banda:** Ilimitado

### Beneficios de Ubuntu 24.04 LTS
- **5 años de soporte** (hasta 2029)
- **Mejoras de seguridad** con kernel 6.8
- **Mejor rendimiento** de contenedores
- **Actualizaciones de seguridad** automáticas

## 🔐 Consideraciones de Seguridad

### Configuraciones Aplicadas
- Fail2ban para protección contra ataques de fuerza bruta
- Firewall UFW configurado
- Headers de seguridad en Nginx
- HTTPS con Let's Encrypt (si tienes dominio)
- Reglas iptables avanzadas
- Monitoreo de seguridad automático

### Recomendaciones Adicionales
- Cambiar contraseña de admin inmediatamente
- Configurar claves SSH en lugar de contraseñas
- Monitorear logs regularmente
- Mantener sistema actualizado
- Hacer backups regulares

## 🆘 Soporte

### Archivos de Log Importantes
- ChirpStack: `docker-compose logs chirpstack`
- Nginx: `/var/log/nginx/chirpstack.error.log`
- Sistema: `/var/log/syslog`
- Seguridad: `/var/log/chirpstack/security-report.log`

### Recursos Útiles
- [Documentación oficial ChirpStack](https://www.chirpstack.io/docs/)
- [Foro de la comunidad](https://forum.chirpstack.io/)
- [GitHub ChirpStack](https://github.com/chirpstack/chirpstack)

## 📄 Licencia

Esta guía y scripts están disponibles bajo licencia MIT. Úsalos libremente para tus proyectos.

---

**¡Importante!** Recuerda cambiar la contraseña por defecto (`admin`/`admin`) inmediatamente después de la instalación.