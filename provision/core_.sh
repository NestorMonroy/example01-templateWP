#!/usr/bin/env bash
# Script principal de provisión

# Cargar helpers
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Verificar que estamos ejecutando como root
if [[ $EUID -ne 0 ]]; then
    log_error "Este script debe ejecutarse como root"
    exit 1
fi

# Función para inicializar el entorno
init_environment() {
    log_header "Iniciando Provisión"
    
    # Crear directorios necesarios
    ensure_directory "$LOGS_DIR"
    
    # Verificar requisitos básicos
    check_system_requirements 512 1
    check_internet_connection
    check_disk_space 1000 "/data"
}

# Función para instalar dependencias base
install_base_dependencies() {
    log_header "Instalando Dependencias Base"
    
    install_packages wget curl git zip unzip
}

# Función principal de provisión
main() {
    # Inicializar entorno
    init_environment
    
    # Instalar dependencias base
    install_base_dependencies
    
    # Ejecutar scripts de provisión
    log_header "Ejecutando Scripts de Provisión"
    
    local scripts_dir="${PROVISION_DIR}/scripts"
    local scripts=(
        "setup-php.sh"
        "setup-mysql.sh"
        "setup-wordpress.sh"
    )
    
    for script in "${scripts[@]}"; do
        log_info "Ejecutando: $script"
        if [ -f "${scripts_dir}/${script}" ]; then
            bash "${scripts_dir}/${script}"
        else
            log_error "Script no encontrado: ${script}"
            exit 1
        fi
    done
    
    log_success "Provisión completada exitosamente"
}

# Manejar errores
trap 'log_error "Error en línea $LINENO"; exit 1' ERR

# Ejecutar provisión
main