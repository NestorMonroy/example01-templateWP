#!/usr/bin/env bash
# Cargar helpers
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Definir directorios base
export PROVISION_DIR="/data/wordpress/provision"
export PROJECT_DIR="/data/wordpress"
export LOGS_DIR="${PROVISION_DIR}/logs"
export TEMP_DIR="/tmp/provision"

# Definir configuraciones de la aplicación
export PHP_VERSION="8.1"
export MYSQL_VERSION="8.0"
export WP_VERSION="latest"

# Definir requisitos del sistema
export MIN_MEMORY_MB=512
export MIN_CPU_CORES=1
export MIN_DISK_SPACE_MB=1000

# Variables para control de ejecución
export CURRENT_LOG_FILE=""
export PROVISION_STEP=""
export IS_INITIALIZED=false

# Variables de wordpress
export WORDPRESS_PATH="/var/www/wordpress"
export BACKUP_PATH="/var/backups/wordpress"
export MIN_DISK_GB=5
export REQUIRED_PORTS=(80 443 3306)
export REQUIRED_PACKAGES=(php mysql-server nginx)

# Actualizaciones necesarias para el sistema de backup
# Rutas de backup
export BACKUP_BASE_DIR="${PROJECT_DIR}/backups"
export BACKUP_TEMP_DIR="${TEMP_DIR}/backup"
export BACKUP_RETENTION_DAYS=30
export MAX_BACKUP_SIZE_MB=5120  # 5GB máximo por backup
export MIN_BACKUP_SPACE_MB=6144 # Requiere 6GB libres para backup

# Variables de control de backup
export BACKUP_COMPRESSION=true
export BACKUP_VERIFY=true
export BACKUP_INCLUDE_PLUGINS=true
export BACKUP_INCLUDE_THEMES=true
export BACKUP_INCLUDE_UPLOADS=true
export BACKUP_INCLUDE_DB=true

# Patrones de exclusión para backup (archivos que no se respaldarán)
export BACKUP_EXCLUDE_PATTERNS=(
    "*.log"
    "*.tmp"
    "*.cache"
    "*/cache/*"
    "*/logs/*"
    "*/backup*/*"
    "*/node_modules/*"
    "*/vendor/*"
)

# Configuraciones específicas para backup de base de datos
export DB_BACKUP_SINGLE_TRANSACTION=true
export DB_BACKUP_COMPRESS=true
export DB_BACKUP_ROUTINES=true
export DB_BACKUP_EVENTS=true
export DB_BACKUP_TRIGGERS=true

# Configuraciones de repositorios
# PPAs requeridos
export REQUIRED_PPAS=(
    "ppa:ondrej/php"      # Para PHP
    "ppa:ondrej/nginx"    # Para Nginx actualizado
)

# Repositorios externos
declare -A EXTERNAL_REPOS=(
    ["mysql"]="deb [signed-by=/etc/apt/trusted.gpg.d/mysql.gpg] http://repo.mysql.com/apt/ubuntu/ $(lsb_release -sc) mysql-${MYSQL_VERSION}"
)

# URLs de llaves GPG
declare -A GPG_KEYS=(
    ["mysql"]="https://dev.mysql.com/doc/refman/${MYSQL_VERSION}/en/checking-gpg-signature.html"
)

# Configuración de sources.list
export SOURCES_BACKUP_DIR="${PROJECT_DIR}/backups/sources"
export SOURCES_LIST="/etc/apt/sources.list"

# Definiciones de paquetes requeridos
# Paquetes base del sistema
export SYSTEM_PACKAGES=(
    "apt-transport-https"
    "ca-certificates"
    "software-properties-common"
    "curl"
    "wget"
    "git"
    "unzip"
    "tar"
    "gnupg"
)

# Paquetes para servidor web y PHP
export WEB_PACKAGES=(
    "nginx"
    "php${PHP_VERSION}-fpm"
    "php${PHP_VERSION}-cli"
    "php${PHP_VERSION}-common"
    "php${PHP_VERSION}-mysql"
    "php${PHP_VERSION}-xml"
    "php${PHP_VERSION}-curl"
    "php${PHP_VERSION}-gd"
    "php${PHP_VERSION}-mbstring"
    "php${PHP_VERSION}-zip"
    "php${PHP_VERSION}-json"
)

# Paquetes para base de datos
export DB_PACKAGES=(
    "mysql-server"
    "mysql-client"
)

# Versiones requeridas
export PACKAGE_VERSIONS=(
    "nginx:latest"
    "php:${PHP_VERSION}"
    "mysql:${MYSQL_VERSION}"
)

# Directorios para logs y temporales de paquetes
export PACKAGES_LOG_DIR="${LOGS_DIR}/packages"
export PACKAGES_TEMP_DIR="${TEMP_DIR}/packages"

# Opciones de instalación
export PACKAGES_VERIFY_AFTER_INSTALL=true
export PACKAGES_AUTO_REMOVE=true

# Configuraciones de servicios
declare -A PHP_CONFIGURATIONS=(
    ["memory_limit"]="256M"
    ["max_execution_time"]="300"
    ["post_max_size"]="64M"
    ["upload_max_filesize"]="64M"
    ["max_input_vars"]="3000"
    ["date.timezone"]="UTC"
)

declare -A MYSQL_CONFIGURATIONS=(
    ["max_allowed_packet"]="64M"
    ["innodb_buffer_pool_size"]="256M"
    ["key_buffer_size"]="128M"
    ["max_connections"]="150"
)

declare -A NGINX_CONFIGURATIONS=(
    ["worker_connections"]="2048"
    ["client_max_body_size"]="64M"
    ["keepalive_timeout"]="65"
    ["fastcgi_read_timeout"]="300"
)

# Lista de servicios a gestionar
export MANAGED_SERVICES=(
    "php${PHP_VERSION}-fpm"
    "mysql"
    "nginx"
)

# Rutas de sockets y puertos para verificación
declare -A SERVICE_SOCKETS=(
    ["php-fpm"]="/run/php/php${PHP_VERSION}-fpm.sock"
    ["mysql"]="/var/run/mysqld/mysqld.sock"
)

declare -A SERVICE_PORTS=(
    ["nginx"]="80"
    ["nginx-ssl"]="443"
    ["mysql"]="3306"
    ["php-fpm"]="9000"
)

# Patrones de configuración por servicio
declare -A SERVICE_CONFIG_PATTERNS=(
    # PHP
    ["php_memory_limit"]="^memory_limit\s*=\s*${PHP_CONFIGURATIONS[memory_limit]}"
    ["php_max_execution_time"]="^max_execution_time\s*=\s*${PHP_CONFIGURATIONS[max_execution_time]}"
    ["php_post_max_size"]="^post_max_size\s*=\s*${PHP_CONFIGURATIONS[post_max_size]}"
    ["php_upload_max_filesize"]="^upload_max_filesize\s*=\s*${PHP_CONFIGURATIONS[upload_max_filesize]}"

    # MySQL
    ["mysql_max_connections"]="^max_connections\s*=\s*${MYSQL_CONFIGURATIONS[max_connections]}"
    ["mysql_key_buffer_size"]="^key_buffer_size\s*=\s*${MYSQL_CONFIGURATIONS[key_buffer_size]}"

    # Nginx
    ["nginx_worker_connections"]="worker_connections\s+${NGINX_CONFIGURATIONS[worker_connections]}"
    ["nginx_client_max_body"]="client_max_body_size\s+${NGINX_CONFIGURATIONS[client_max_body_size]}"
)

# Archivos de configuración por servicio
declare -A SERVICE_CONFIG_FILES=(
    ["php"]="/etc/php/${PHP_VERSION}/fpm/php.ini"
    ["php-fpm"]="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
    ["mysql"]="/etc/mysql/mysql.conf.d/mysqld.cnf"
    ["nginx"]="/etc/nginx/nginx.conf"
)

# Estados esperados de servicios
declare -A SERVICE_STATES=(
    ["php${PHP_VERSION}-fpm"]="running"
    ["mysql"]="running"
    ["nginx"]="running"
)

# Timeouts para verificaciones (en segundos)
declare -A SERVICE_TIMEOUTS=(
    ["socket"]=5
    ["port"]=3
    ["service"]=10
)

# Dependencias de servicios
declare -A SERVICE_DEPENDENCIES=(
    ["nginx"]="php${PHP_VERSION}-fpm"
    ["php${PHP_VERSION}-fpm"]=""
    ["mysql"]=""
)

# Directorios para backups de configuración
export SERVICE_BACKUP_DIR="${PROJECT_DIR}/backups/services"
export SERVICE_CONFIG_BACKUP_DIR="${SERVICE_BACKUP_DIR}/configs"

# Variables para control de verificación
export VERIFY_PORTS=true
export VERIFY_SOCKETS=true
export VERIFY_CONFIGS=true
export VERIFY_DEPENDENCIES=true
export VERIFY_AUTO_START=true

# Número máximo de reintentos para verificaciones


# Función para inicializar el entorno
init_provision_env() {
    # Evitar inicialización múltiple
    if [ "$IS_INITIALIZED" = true ]; then
        return 0
    fi

    # Crear directorios necesarios
    for dir in "$LOGS_DIR" "$TEMP_DIR"; do
        ensure_directory "$dir" 755
    done

    # Configurar timestamp y archivo de log
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    export CURRENT_LOG_FILE="${LOGS_DIR}/provision_${timestamp}.log"

    # Crear enlace simbólico al último log
    ln -sf "$CURRENT_LOG_FILE" "${LOGS_DIR}/provision_latest.log"

    # Configurar logging
    set_log_file "$CURRENT_LOG_FILE"
    set_log_level "INFO"

    # Registrar inicio de sesión
    log_header "Configuración del Entorno de Provisión"
    log_info "Inicializando entorno de provisión"
    log_info "Archivo de log: $CURRENT_LOG_FILE"
    log_info "Directorio de proyecto: $PROJECT_DIR"
    log_info "Versiones objetivo:"
    log_info "- PHP: $PHP_VERSION"
    log_info "- MySQL: $MYSQL_VERSION"
    log_info "- WordPress: $WP_VERSION"

    export IS_INITIALIZED=true
}

# Función para limpiar el entorno
cleanup_provision_env() {
    local exit_code=$?

    # Evitar limpieza múltiple
    if [ "${PROVISION_STEP}" = "cleanup" ]; then
        return $exit_code
    fi
    export PROVISION_STEP="cleanup"

    log_header "Limpieza Final"

    # Limpiar archivos temporales
    if [ -d "$TEMP_DIR" ]; then
        log_info "Limpiando directorio temporal: $TEMP_DIR"
        safe_remove "$TEMP_DIR"
    fi

    # Limpiar paquetes
    log_info "Limpiando caché de paquetes"
    apt_clean

    # Registrar resultado final
    if [ $exit_code -eq 0 ]; then
        log_success "Provisión completada exitosamente"
    else
        log_error "Provisión terminó con errores (código: $exit_code)"
    fi

    log_info "Log guardado en: $CURRENT_LOG_FILE"
    return $exit_code
}

# Función para manejar errores
handle_provision_error() {
    local error_code=$?
    local line_number=$1
    local script_name
    script_name=$(basename "${BASH_SOURCE[1]}")

    log_error "Error en $script_name línea $line_number (código: $error_code)"

    if [ "$PROVISION_STEP" != "cleanup" ]; then
        cleanup_provision_env
    fi

    exit $error_code
}

# Función para validar el entorno
validate_provision_env() {
    if [ "$IS_INITIALIZED" != true ]; then
        log_error "El entorno no está inicializado"
        return 1
    fi

    if [ -z "$CURRENT_LOG_FILE" ]; then
        log_error "Archivo de log no configurado"
        return 1
    fi

    return 0
}

# Registrar manejadores
trap 'handle_provision_error ${LINENO}' ERR
trap 'cleanup_provision_env' EXIT

# Exportar funciones para uso en otros scripts
#export -f init_provision_env
#export -f cleanup_provision_env
#export -f validate_provision_env
#export -f handle_provision_error

# No inicializar automáticamente - permitir que core.sh lo haga explícitamente
# init_provision_env