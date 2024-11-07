#!/usr/bin/env bash
# Manejo de hooks para el sistema de provisión
#
# Este script proporciona funciones para gestionar la ejecución de hooks
# (scripts pre y post provisión) en el sistema. Los hooks permiten ejecutar
# acciones personalizadas antes y después del proceso principal de provisión.
#
# Estructura de directorios esperada:
#   hooks/
#   ├── pre/        # Scripts ejecutados antes de la provisión
#   │   ├── 01-check-system.sh
#   │   ├── 02-backup.sh
#   │   └── ...
#   └── post/       # Scripts ejecutados después de la provisión
#       ├── 01-cleanup.sh
#       ├── 02-verify.sh
#       └── ...
#
# Ejemplo de uso:
#   source ./hooks.sh
#
#   # Ejecutar pre-hooks
#   if ! run_pre_hooks; then
#       echo "Pre-hooks fallaron"
#       exit 1
#   fi
#
#   # Ejecutar post-hooks
#   run_post_hooks  # Continúa incluso si hay errores

# Obtener el directorio base de provisión
# Esto define la ubicación base donde se encuentran los hooks
HOOKS_BASE="${PROVISION_DIR}/hooks"

# Función para validar un hook antes de ejecutarlo
# Uso: validate_hook <ruta_hook>
# Retorna:
#   0 si el hook es válido
#   1 si hay algún error
# Ejemplo:
#   if validate_hook "/path/to/hook.sh"; then
#       echo "Hook válido"
#   fi
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
# Uso: execute_hook <ruta_hook>
# Retorna:
#   0 si el hook se ejecuta exitosamente
#   1 si hay algún error
# Ejemplo:
#   execute_hook "/hooks/pre/01-check-system.sh"
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
# Uso: execute_hooks_in_dir <directorio> [continuar_en_error]
# Parámetros:
#   directorio: Ruta al directorio de hooks
#   continuar_en_error: true/false (default: false)
# Ejemplo:
#   execute_hooks_in_dir "/hooks/pre" false
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
# Uso: run_pre_hooks
# Retorna:
#   0 si todos los pre-hooks se ejecutan exitosamente
#   1 si algún pre-hook falla
# Ejemplo:
#   if ! run_pre_hooks; then
#       echo "Fallo en pre-hooks"
#       exit 1
#   fi
run_pre_hooks() {
    log_header "Ejecutando pre-hooks"
    execute_hooks_in_dir "${HOOKS_BASE}/pre" false
}

# Función para ejecutar post-hooks
# Uso: run_post_hooks
# Nota: Continúa ejecutando incluso si hay errores
# Ejemplo:
#   run_post_hooks || true
run_post_hooks() {
    log_header "Ejecutando post-hooks"
    execute_hooks_in_dir "${HOOKS_BASE}/post" true
}

# Ejemplo completo de uso del script
: '
#!/bin/bash
source ./hooks.sh

# 1. Ejecutar pre-hooks (detener si fallan)
log_info "Iniciando fase de pre-hooks..."
if ! run_pre_hooks; then
    log_error "Pre-hooks fallaron, abortando provisión"
    exit 1
fi

# 2. Realizar tareas principales de provisión
log_info "Ejecutando tareas principales..."
if ! perform_main_tasks; then
    log_error "Falló la provisión principal"
    # Aún así ejecutamos post-hooks para limpieza
fi

# 3. Ejecutar post-hooks (continuar aunque fallen)
log_info "Iniciando fase de post-hooks..."
run_post_hooks

# Ejemplo de hook individual
if ! execute_hook "${HOOKS_BASE}/pre/01-check-system.sh"; then
    log_error "Falló la verificación del sistema"
    exit 1
fi
'

# Exportar funciones para uso en otros scripts
export -f run_pre_hooks
export -f run_post_hooks
export -f execute_hook
export -f execute_hooks_in_dir