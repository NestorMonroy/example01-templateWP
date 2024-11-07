#!/usr/bin/env bash
# Manejo de hooks para el sistema de provisión

# Obtener el directorio base de provisión
HOOKS_BASE="${PROVISION_DIR}/hooks"

# Función para validar un hook antes de ejecutarlo
validate_hook() {
    local hook_path="$1"

    # Verificar que el archivo existe y es ejecutable
    if [[ ! -f "$hook_path" ]]; then
        log_error "Hook no encontrado: $hook_path"
        return 1
    fi

    if [[ ! -x "$hook_path" ]]; then
        log_error "Hook no es ejecutable: $hook_path"
        return 1
    }

    return 0
}

# Función para ejecutar un hook individual
execute_hook() {
    local hook_path="$1"
    local hook_name=$(basename "$hook_path")

    log_info "Ejecutando hook: $hook_name"

    if ! validate_hook "$hook_path"; then
        return 1
    fi

    if ! bash "$hook_path"; then
        log_error "Hook falló: $hook_name"
        return 1
    fi

    log_success "Hook completado: $hook_name"
    return 0
}

# Función para ejecutar todos los hooks en un directorio
execute_hooks_in_dir() {
    local dir="$1"
    local continue_on_error="${2:-false}"

    if [[ ! -d "$dir" ]]; then
        log_warning "Directorio de hooks no encontrado: $dir"
        return 0
    fi

    # Ejecutar hooks en orden alfabético
    local hooks=("$dir"/*.sh)
    if [ -n "$(ls -A $dir/*.sh 2>/dev/null)" ]; then
        for hook in "${hooks[@]}"; do
            if ! execute_hook "$hook"; then
                if [[ "$continue_on_error" != "true" ]]; then
                    return 1
                fi
            fi
        done
    fi

    return 0
}

# Función para ejecutar pre-hooks
run_pre_hooks() {
    log_header "Ejecutando pre-hooks"
    execute_hooks_in_dir "${HOOKS_BASE}/pre" false
}

# Función para ejecutar post-hooks
run_post_hooks() {
    log_header "Ejecutando post-hooks"
    execute_hooks_in_dir "${HOOKS_BASE}/post" true
}

# Exportar funciones para uso en otros scripts
export -f run_pre_hooks
export -f run_post_hooks
export -f execute_hook
export -f execute_hooks_in_dir