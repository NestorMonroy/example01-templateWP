#!/usr/bin/env bash
# Gestión del entorno de provisión

# Importar dependencias necesarias
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables de entorno
CURRENT_LOG_FILE=""
PROVISION_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEMP_DIR="/tmp/provision_${PROVISION_TIMESTAMP}"

# Definir directorios requeridos
REQUIRED_DIRS=(
    "${LOGS_DIR}"
    "${PROJECT_DIR}/tmp"
    "${PROJECT_DIR}/backups"
    "${PROVISION_DIR}/tmp"
    "$TEMP_DIR"
)

# Función para inicializar el entorno de provisión
init_provision_env() {
    log_header "Inicializando entorno de provisión"

    # Configurar archivo de log
    CURRENT_LOG_FILE="${LOGS_DIR}/provision_${PROVISION_TIMESTAMP}.log"
    export CURRENT_LOG_FILE

    # Configurar logging
    set_log_file "$CURRENT_LOG_FILE"
    set_log_level "INFO"

    # Crear directorios necesarios
    create_required_directories

    # Crear archivo de estado
    echo "${PROVISION_TIMESTAMP}" > "${PROVISION_DIR}/tmp/last_provision"

    log_success "Entorno inicializado correctamente"
    log_info "Log file: $CURRENT_LOG_FILE"
    log_info "Timestamp: $PROVISION_TIMESTAMP"
}

# Función para crear directorios necesarios
create_required_directories() {
    log_info "Creando directorios necesarios..."

    local dir
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            log_info "Creando directorio: $dir"
            if ! mkdir -p "$dir"; then
                log_error "No se pudo crear el directorio: $dir"
                return 1
            fi
            chmod 755 "$dir"
        fi
    done

    log_success "Directorios creados correctamente"
}

# Función para limpiar archivos temporales
clean_temp_files() {
    log_info "Limpiando archivos temporales..."

    # Lista de directorios a limpiar
    local temp_dirs=(
        "${PROJECT_DIR}/tmp/*"
        "${PROVISION_DIR}/tmp/*"
        "$TEMP_DIR"
        "/tmp/provision_*"
    )

    local dir
    for dir in "${temp_dirs[@]}"; do
        if ls $dir 1> /dev/null 2>&1; then
            log_info "Limpiando: $dir"
            rm -rf $dir
        fi
    done

    log_success "Limpieza de archivos temporales completada"
}

# Función para obtener el timestamp de la última provisión
get_last_provision_time() {
    local last_provision_file="${PROVISION_DIR}/tmp/last_provision"
    if [ -f "$last_provision_file" ]; then
        cat "$last_provision_file"
    else
        echo "Never"
    fi
}

# Función para guardar el estado de la provisión
save_provision_state() {
    local state="$1"
    local state_file="${PROVISION_DIR}/tmp/provision_state"

    echo "$state" > "$state_file"
    log_info "Estado de provisión guardado: $state"
}

# Función para obtener el estado de la provisión
get_provision_state() {
    local state_file="${PROVISION_DIR}/tmp/provision_state"
    if [ -f "$state_file" ]; then
        cat "$state_file"
    else
        echo "unknown"
    fi
}

# Función para limpiar el entorno
cleanup_provision_env() {
    local exit_code=$?
    log_header "Limpiando entorno"

    # Limpiar archivos temporales
    clean_temp_files

    # Guardar estado final
    if [ $exit_code -eq 0 ]; then
        save_provision_state "completed"
        log_success "Provisión completada exitosamente"
    else
        save_provision_state "failed"
        log_error "Provisión terminó con errores (código: $exit_code)"
    fi

    # Registrar tiempo de finalización
    local end_time=$(date +%Y%m%d_%H%M%S)
    echo "$end_time" > "${PROVISION_DIR}/tmp/last_completion"

    log_info "Log guardado en: $CURRENT_LOG_FILE"
    log_info "Tiempo de finalización: $end_time"
}

# Función para crear un backup del entorno
backup_environment() {
    local backup_dir="${PROJECT_DIR}/backups/env_${PROVISION_TIMESTAMP}"
    local dirs_to_backup=(
        "${PROJECT_DIR}/config"
        "${PROVISION_DIR}/config"
    )

    log_info "Creando backup del entorno..."

    mkdir -p "$backup_dir"

    for dir in "${dirs_to_backup[@]}"; do
        if [ -d "$dir" ]; then
            local dirname=$(basename "$dir")
            log_info "Respaldando: $dirname"
            cp -r "$dir" "${backup_dir}/${dirname}"
        fi
    done

    log_success "Backup creado en: $backup_dir"
}

# Función para restaurar un backup
restore_environment() {
    local backup_timestamp="$1"
    local backup_dir="${PROJECT_DIR}/backups/env_${backup_timestamp}"

    if [ ! -d "$backup_dir" ]; then
        log_error "Backup no encontrado: $backup_timestamp"
        return 1
    fi

    log_info "Restaurando backup: $backup_timestamp"

    local dir
    for dir in "$backup_dir"/*; do
        local dirname=$(basename "$dir")
        local target_dir
        case "$dirname" in
            "config")
                target_dir="${PROJECT_DIR}/config"
                ;;
            *)
                target_dir="${PROVISION_DIR}/${dirname}"
                ;;
        esac

        log_info "Restaurando: $dirname"
        rm -rf "$target_dir"
        cp -r "$dir" "$target_dir"
    done

    log_success "Entorno restaurado desde backup: $backup_timestamp"
}

# Exportar funciones y variables
export CURRENT_LOG_FILE
export PROVISION_TIMESTAMP
export -f init_provision_env
export -f cleanup_provision_env
export -f create_required_directories
export -f clean_temp_files
export -f get_last_provision_time
export -f save_provision_state
export -f get_provision_state
export -f backup_environment
export -f restore_environment