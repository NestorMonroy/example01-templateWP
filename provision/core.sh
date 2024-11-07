#!/usr/bin/env bash

# Cargar helpers y configuración
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

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
    # Mostrar información inicial
    log_header "Iniciando Provisión"
    log_info "Fecha: $(date)"
    log_info "Sistema: $(get_system_info)"

    # Verificar requisitos básicos
    check_system_requirements 512 1
    check_internet_connection
    check_disk_space 1000 "/data"

    # Verificar dependencias
    check_provision_dependencies

    # Ejecutar pre-hooks
    run_provision_pre_hooks || {
        log_error "Los pre-hooks fallaron"
        return 1
    }

    # Realizar tareas principales de provisión
    log_header "Tareas Principales de Provisión"

    local scripts=(
        "setup-php.sh"
        "setup-mysql.sh"
        "setup-wordpress.sh"
    )

    for script in "${scripts[@]}"; do
        local script_path="${PROVISION_DIR}/scripts/${script}"
        if [ -f "$script_path" ]; then
            log_info "Ejecutando: $script"
            if ! bash "$script_path"; then
                log_error "Script falló: $script"
                return 1
            fi
        else
            log_error "Script no encontrado: $script"
            return 1
        fi
    done

    # Ejecutar post-hooks
    run_provision_post_hooks

    log_success "Provisión completada exitosamente"
    return 0
}

# Ejecutar provisión
main_provision