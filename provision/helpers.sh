#!/usr/bin/env bash
# Punto de entrada único para todas las funciones helper

# Definir la ruta base de los helpers
HELPER_DIR="$(dirname "${BASH_SOURCE[0]}")/helpers"

# Verificar que estamos ejecutando como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

# Cargar módulos en orden
declare -a MODULES=(
    "colors.sh"
    "logging.sh"
    "system.sh"
    "network.sh"
    "packages.sh"
    "filesystem.sh"
)

# Función para cargar un módulo
load_module() {
    local module="$1"
    local module_path="${HELPER_DIR}/${module}"

    if [ ! -f "$module_path" ]; then
        echo "Error: Módulo no encontrado: $module"
        exit 1
    }

    source "$module_path"
}

# Cargar todos los módulos
for module in "${MODULES[@]}"; do
    load_module "$module"
done

# Configuración global
export PROVISION_DIR="/data/wordpress/provision"
export PROJECT_DIR="/data/wordpress"
export LOGS_DIR="${PROVISION_DIR}/logs"

# Asegurar directorio de logs
ensure_directory "$LOGS_DIR" 755

# Función para inicializar el entorno de provisión
init_provision_env() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="${LOGS_DIR}/provision_${timestamp}.log"

    # Configurar logging
    set_log_file "$log_file"
    set_log_level "INFO"

    # Mostrar información inicial
    log_header "Iniciando Provisión"
    log_info "Fecha: $(date)"
    log_info "Sistema: $(get_system_info)"

    # Verificar requisitos básicos
    check_system_requirements 512 1
    check_internet_connection
    check_disk_space 1000 "/data"
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

    # Registro final
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

# Función para verificar dependencias
check_provision_dependencies() {
    local dependencies=(
        "wget"
        "curl"
        "git"
        "tar"
        "gzip"
        "mysql"
    )

    log_info "Verificando dependencias..."
    install_packages "${dependencies[@]}"
}

# Función para ejecutar pre-hooks
run_provision_pre_hooks() {
    local hooks_dir="${PROVISION_DIR}/hooks/pre"

    if [ -d "$hooks_dir" ]; then
        log_info "Ejecutando pre-hooks..."

        for hook in "$hooks_dir"/*.sh; do
            if [ -f "$hook" ]; then
                log_info "Ejecutando hook: $(basename "$hook")"
                if ! bash "$hook"; then
                    log_error "Hook falló: $(basename "$hook")"
                    return 1
                fi
            fi
        done
    fi
}

# Función para ejecutar post-hooks
run_provision_post_hooks() {
    local hooks_dir="${PROVISION_DIR}/hooks/post"

    if [ -d "$hooks_dir" ]; then
        log_info "Ejecutando post-hooks..."

        for hook in "$hooks_dir"/*.sh; do
            if [ -f "$hook" ]; then
                log_info "Ejecutando hook: $(basename "$hook")"
                if ! bash "$hook"; then
                    log_warning "Hook falló: $(basename "$hook")"
                fi
            fi
        done
    fi
}

# Función principal de provisión
main_provision() {
    # Inicializar entorno
    init_provision_env

    # Verificar dependencias
    check_provision_dependencies

    # Ejecutar pre-hooks
    run_provision_pre_hooks

    # Realizar tareas principales de provisión
    log_header "Tareas Principales de Provisión"

    # Aquí irían las llamadas a tus scripts específicos de provisión
    # Por ejemplo:
    # source "${PROVISION_DIR}/scripts/setup-php.sh"
    # source "${PROVISION_DIR}/scripts/setup-mysql.sh"
    # source "${PROVISION_DIR}/scripts/setup-wordpress.sh"

    # Ejecutar post-hooks
    run_provision_post_hooks

    # Limpieza final
    cleanup_provision_env
}

# Exponer funciones útiles para los scripts de provisión
export -f init_provision_env
export -f cleanup_provision_env
export -f handle_provision_error
export -f check_provision_dependencies
export -f run_provision_pre_hooks
export -f run_provision_post_hooks
export -f main_provision

# Si este script se ejecuta directamente (no es sourceado)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_provision
fi