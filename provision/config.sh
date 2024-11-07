#!/usr/bin/env bash
# Configuración global del proyecto

# Definir directorios base
export PROVISION_DIR="/data/wordpress/provision"
export PROJECT_DIR="/data/wordpress"
export LOGS_DIR="${PROVISION_DIR}/logs"

# Asegurar directorio de logs
ensure_directory "$LOGS_DIR" 755

# Función para inicializar el entorno
init_provision_env() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="${LOGS_DIR}/provision_${timestamp}.log"

    # Configurar logging
    set_log_file "$log_file"
    set_log_level "INFO"
}

# Función para limpiar el entorno
cleanup_provision_env() {
    local exit_code=$?

    log_header "Limpieza Final"

    # Limpiar archivos temporales
    if [ -d "/tmp/provision" ]; then
        safe_remove "/tmp/provision"
    fi

    # Limpiar paquetes
    apt_clean

    if [ $exit_code -eq 0 ]; then
        log_success "Provisión completada exitosamente"
    else
        log_error "Provisión terminó con errores (código: $exit_code)"
    fi

    log_info "Log guardado en: $CURRENT_LOG_FILE"
}

# Función para manejar errores
handle_provision_error() {
    local error_code=$?
    local line_number=$1

    log_error "Error en línea $line_number (código: $error_code)"
    cleanup_provision_env
    exit $error_code
}

# Registrar manejador de errores
trap 'handle_provision_error ${LINENO}' ERR

# Inicializar el entorno cuando se carga el script
init_provision_env