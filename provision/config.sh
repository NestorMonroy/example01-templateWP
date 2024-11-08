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
export MIN_MEMORY_MB=512
export MIN_DISK_GB=5
export MIN_CPU_CORES=1
export REQUIRED_PORTS=(80 443 3306)
export REQUIRED_PACKAGES=(php mysql-server nginx)



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