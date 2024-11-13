#!/usr/bin/env bash
# Gestión del entorno de provisión
#
# Este script proporciona funciones para gestionar el entorno de provisión,
# incluyendo inicialización, limpieza, backups y restauración.
#
# Ejemplo de uso general:
#   source ./environment.sh
#
#   # Inicializar y configurar limpieza
#   init_provision_env
#   trap cleanup_provision_env EXIT
#
#   # Crear backup y realizar cambios
#   backup_environment
#   save_provision_state "in_progress"

# Importar dependencias necesarias
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables de entorno
# Archivo de log actual para la provisión
CURRENT_LOG_FILE=""

# Timestamp único para esta ejecución
PROVISION_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Directorio temporal para esta provisión
TEMP_DIR="/tmp/provision_${PROVISION_TIMESTAMP}"

# Definir directorios requeridos
# Lista de directorios que deben existir para la provisión
REQUIRED_DIRS=(
    "${LOGS_DIR}"              # Directorio de logs
    "${PROJECT_DIR}/tmp"       # Temporales del proyecto
    "${PROJECT_DIR}/backups"   # Backups del proyecto
    "${PROVISION_DIR}/tmp"     # Temporales de provisión
    "$TEMP_DIR"               # Directorio temporal actual
)

# Función para inicializar el entorno de provisión
# Uso: init_provision_env
# Ejemplo:
#   init_provision_env
#   if [ $? -eq 0 ]; then
#       echo "Entorno inicializado correctamente"
#   fi
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
# Uso: create_required_directories
# Ejemplo:
#   create_required_directories || exit 1
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
# Uso: clean_temp_files
# Ejemplo:
#   clean_temp_files
#   echo "Limpieza completada con código: $?"
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
# Uso: last_time=$(get_last_provision_time)
# Ejemplo:
#   echo "Última provisión: $(get_last_provision_time)"
get_last_provision_time() {
    local last_provision_file="${PROVISION_DIR}/tmp/last_provision"
    if [ -f "$last_provision_file" ]; then
        cat "$last_provision_file"
    else
        echo "Never"
    fi
}

# Función para guardar el estado de la provisión
# Uso: save_provision_state <estado>
# Ejemplo:
#   save_provision_state "in_progress"
#   save_provision_state "completed"
save_provision_state() {
    local state="$1"
    local state_file="${PROVISION_DIR}/tmp/provision_state"

    echo "$state" > "$state_file"
    log_info "Estado de provisión guardado: $state"
}

# Función para obtener el estado de la provisión
# Uso: state=$(get_provision_state)
# Ejemplo:
#   if [ "$(get_provision_state)" = "completed" ]; then
#       echo "Provisión completada"
#   fi
get_provision_state() {
    local state_file="${PROVISION_DIR}/tmp/provision_state"
    if [ -f "$state_file" ]; then
        cat "$state_file"
    else
        echo "unknown"
    fi
}

# Función para limpiar el entorno
# Uso: cleanup_provision_env
# Ejemplo:
#   trap cleanup_provision_env EXIT
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
# Uso: backup_environment
# Ejemplo:
#   backup_environment
#   echo "Backup creado en: $PROVISION_TIMESTAMP"
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

# Verificación completa del ambiente
# Uso: verify_complete_environment <tipo_ambiente>
# Ejemplo: verify_complete_environment "production"
verify_complete_environment() {
    local env_type="$1"
    local failed=0

    # Verificar variables requeridas
    if ! verify_environment_variables "required" "${REQUIRED_ENV_VARS[$env_type]}"; then
        ((failed++))
    fi

    # Verificar directorios requeridos
    if ! verify_directories "${REQUIRED_DIRECTORIES[$env_type]}"; then
        ((failed++))
    fi

    return $failed
}

# Función para restaurar un backup
# Uso: restore_environment <timestamp>
# Ejemplo:
#   restore_environment "20240107_123045"
#   if [ $? -eq 0 ]; then
#       echo "Restauración exitosa"
#   fi
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

# Ejemplo completo de uso del script
: '
#!/bin/bash
source ./environment.sh

# Inicializar entorno
init_provision_env

# Registrar limpieza al salir
trap cleanup_provision_env EXIT

# Crear backup inicial
backup_environment

# Comenzar provisión
save_provision_state "in_progress"

# Si algo falla, restaurar desde backup
if ! perform_changes; then
    restore_environment "$PROVISION_TIMESTAMP"
    exit 1
fi

# Limpiar archivos temporales
clean_temp_files
'

# Exportar funciones y variables
#export CURRENT_LOG_FILE
#export PROVISION_TIMESTAMP
#export -f init_provision_env
#export -f cleanup_provision_env
#export -f create_required_directories
#export -f clean_temp_files
#export -f get_last_provision_time
#export -f save_provision_state
#export -f get_provision_state
#export -f backup_environment
#export -f restore_environment