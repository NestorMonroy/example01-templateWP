#!/usr/bin/env bash
# Pre-hook: Configuración del Entorno
#
# Este hook realiza la configuración inicial del entorno antes de la provisión,
# incluyendo verificación de requisitos, configuración del sistema y preparación
# del ambiente de ejecución.
#
# Depende de los siguientes helpers:
# - environment.sh: Para gestión del entorno
# - system.sh: Para verificación de recursos
# - filesystem.sh: Para operaciones de archivos
# - error.sh: Para manejo de errores
# - logging.sh: Para registro de eventos
# - sysconfig.sh: Para configuración del sistema

# 1. Validación del contexto de ejecución
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Obtener el directorio base de provisión
HOOKS_BASE="${PROVISION_DIR}/hooks"

# Importar helpers necesarios usando la función de hooks.sh
load_helpers "environment.sh" "filesystem.sh" "system.sh" "error.sh" "logging.sh" "sysconfig.sh"

# 1. Función para validar el entorno de provisión
validate_provision_environment() {
    log_info "PASO 1: Validación del Entorno de Provisión"
    log_info "----------------------------------------"

    # 1.1 Verificar que estamos como root (usando system.sh)
    log_info "Verificando permisos de ejecución..."
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    }

    # 1.2 Verificar ambiente inicializado
    log_info "Verificando estado del ambiente..."
    if ! verify_complete_environment "BASE"; then
        error_handle "Ambiente base no inicializado correctamente" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    fi

    # 1.3 Verificar requisitos del sistema
    log_info "Verificando requisitos del sistema..."
    if ! verify_system_condition "resource" "memory" "${SYSTEM_REQUIREMENTS[MEMORY_MIN]}" "MB"; then
        error_handle "Memoria insuficiente" ${ERROR_CODES["GENERAL_ERROR"]}
        return 1
    fi

    if ! verify_system_condition "resource" "cpu" "${SYSTEM_REQUIREMENTS[CPU_CORES_MIN]}"; then
        error_handle "CPU insuficiente" ${ERROR_CODES["GENERAL_ERROR"]}
        return 1
    fi

    if ! verify_system_condition "version" "os" "Ubuntu" "${SYSTEM_REQUIREMENTS[OS_VERSION]}"; then
        error_handle "Versión de sistema operativo no soportada" ${ERROR_CODES["GENERAL_ERROR"]}
        return 1
    }

    log_success "Validación del entorno completada exitosamente"
    return 0
}

# 2. Función para configurar sistema base
configure_base_system() {
    log_info "PASO 2: Configuración del Sistema Base"
    log_info "------------------------------------"

    # 2.1 Configurar límites del sistema
    log_info "Configurando límites del sistema..."
    if ! set_system_limits 65535 65535; then
        log_warning "No se pudieron configurar límites del sistema"
    fi

    # 2.2 Configurar kernel
    log_info "Configurando parámetros del kernel..."
    local -A kernel_params=(
        ["fs.file-max"]="65535"
        ["vm.swappiness"]="10"
        ["net.core.somaxconn"]="65535"
    )

    for param in "${!kernel_params[@]}"; do
        if ! set_kernel_parameter "$param" "${kernel_params[$param]}"; then
            log_warning "No se pudo configurar parámetro: $param"
        fi
    done

    # 2.3 Configurar timezone y locale
    log_info "Configurando timezone y locale..."
    if ! set_timezone "UTC"; then
        log_warning "No se pudo configurar timezone"
    fi

    if ! set_locale "en_US.UTF-8"; then
        log_warning "No se pudo configurar locale"
    fi

    # 2.4 Configurar swap si es necesario
    local min_memory=$((SYSTEM_REQUIREMENTS[MEMORY_MIN]))
    if [ "$(get_total_memory)" -lt "$min_memory" ]; then
        log_info "Configurando swap adicional..."
        if ! set_swap 2048; then
            log_warning "No se pudo configurar swap adicional"
        fi
    fi

    log_success "Configuración del sistema base completada"
    return 0
}

# 3. Función para preparar directorios de aplicación
prepare_app_directories() {
    log_info "PASO 3: Preparación de Directorios"
    log_info "---------------------------------"

    # 3.1 Crear directorios de aplicación
    log_info "Creando directorios de aplicación..."
    local dirs=(${REQUIRED_DIRECTORIES[APP]})
    local failed=0

    for dir in "${dirs[@]}"; do
        log_info "Configurando directorio: $dir"

        # Obtener permisos configurados o usar valores por defecto
        local perms="${DIRECTORY_PERMISSIONS[$dir]}"
        if [ -n "$perms" ]; then
            IFS=':' read -r mode owner group <<< "$perms"
        else
            mode="755"
            owner="root"
            group="root"
        fi

        if ! ensure_directory "$dir" "$mode" "$owner" "$group"; then
            log_error "Error configurando directorio: $dir"
            ((failed++))
        fi
    done

    # 3.2 Verificar permisos y propiedad
    log_info "Verificando permisos y propiedad..."
    for dir in "${dirs[@]}"; do
        if ! check_write_permission "$dir"; then
            log_warning "Permisos de escritura no verificados en: $dir"
            ((failed++))
        fi
    done

    if [ $failed -gt 0 ]; then
        log_warning "Algunos directorios no se configuraron correctamente ($failed errores)"
        return 1
    fi

    log_success "Preparación de directorios completada"
    return 0
}

# 4. Función para configurar ambiente de ejecución
configure_runtime_environment() {
    log_info "PASO 4: Configuración del Ambiente de Ejecución"
    log_info "--------------------------------------------"

    # 4.1 Configurar variables de ambiente según el tipo
    log_info "Configurando variables de ambiente..."
    local env_type="${APP_ENV:-production}"

    if ! verify_environment_variables "valued" "${REQUIRED_ENV_VARS[$env_type]}"; then
        log_warning "No se pudieron configurar todas las variables de ambiente"
    fi

    # 4.2 Verificar estado del ambiente
    log_info "Verificando estado del ambiente..."
    local checks=(${ENVIRONMENT_CHECKS[$env_type]})
    if ! verify_environment_state "$env_type" "${checks[@]}"; then
        log_warning "El ambiente no está en el estado esperado"
    fi

    # 4.3 Verificar conectividad
    log_info "Verificando conectividad..."
    local network_checks=(${NETWORK_CHECKS[connectivity]})
    for host in "${network_checks[@]}"; do
        if ! ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            log_warning "No hay conectividad con: $host"
        fi
    done

    log_success "Configuración del ambiente de ejecución completada"
    return 0
}

# Función principal del hook
main() {
    log_header "Pre-Hook: Configuración del Entorno"
    log_info "===================================="

    # 1. Establecer el paso actual de provisión
    export PROVISION_STEP="environment_setup"

    # 2. Definir pasos de configuración
    local -A setup_steps=(
        ["validate_provision_environment"]="Validación del Entorno"
        ["configure_base_system"]="Configuración del Sistema"
        ["prepare_app_directories"]="Preparación de Directorios"
        ["configure_runtime_environment"]="Configuración del Ambiente"
    )

    # 3. Inicializar contadores
    local total_steps=${#setup_steps[@]}
    local current_step=0
    local failed_steps=0

    # 4. Ejecutar cada paso
    for step_func in "${!setup_steps[@]}"; do
        ((current_step++))
        local step_name="${setup_steps[$step_func]}"

        # 4.1 Mostrar progreso
        log_info ""
        log_info "Paso $current_step de $total_steps: $step_name"
        log_info "----------------------------------------"

        # 4.2 Ejecutar paso
        if ! $step_func; then
            ((failed_steps++))
            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                error_handle "Falló el paso: $step_name" ${ERROR_CODES["GENERAL_ERROR"]}
                return 1
            else
                log_warning "Falló el paso pero continuando por PROVISION_CONTINUE_ON_ERROR=true"
            fi
        fi

        # 4.3 Actualizar estado
        save_provision_state "environment_step_${current_step}_completed"

        # 4.4 Mostrar progreso
        local percent=$((current_step * 100 / total_steps))
        log_progress "$current_step" "$total_steps" "$step_name completado"
    done

    # 5. Verificación final
    log_info ""
    log_info "Realizando verificación final..."

    if [ "$failed_steps" -eq 0 ]; then
        log_success "Configuración del entorno completada exitosamente"
        return 0
    else
        log_warning "Configuración completada con advertencias ($failed_steps fallos)"
        return 1
    fi
}

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 1. Verificar que somos root
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        exit 1
    fi

    # 2. Configurar manejo de errores
    set -e
    trap 'error_handle "Error en línea $LINENO" $? $LINENO' ERR

    # 3. Ejecutar script
    main
    exit $?
fi