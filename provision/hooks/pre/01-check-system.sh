#!/usr/bin/env bash
# Pre-hook: Verificación básica del sistema
#
# Este hook realiza una verificación exhaustiva del sistema incluyendo:
# - Recursos del sistema (memoria, CPU, disco)
# - Estado actual del sistema (uso de CPU, memoria)
# - Espacio para backups
# - Permisos y contexto de ejecución

# Verificar contexto de ejecución
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Cargar helpers necesarios
load_helpers "system.sh" "logging.sh" "error.sh"

# Función para verificar rendimiento actual
check_system_performance() {
    local cpu_usage=$(get_cpu_usage)
    local memory_usage=$(get_memory_usage)

    log_info "Estado actual del sistema:"
    log_info "- Uso de CPU: ${cpu_usage}%"
    log_info "- Uso de memoria: ${memory_usage}%"

    # Advertencias de rendimiento
    if [ "$(echo "$cpu_usage > 80" | bc -l)" -eq 1 ]; then
        log_warning "Alta carga de CPU detectada (${cpu_usage}%)"
        return 1
    fi

    if [ "$(echo "$memory_usage > 90" | bc -l)" -eq 1 ]; then
        log_warning "Alto uso de memoria detectado (${memory_usage}%)"
        return 1
    fi

    return 0
}

# Función para verificar espacio de backup
check_backup_space() {
    log_info "Verificando espacio para backups..."

    local backup_space=$(df -BM --output=avail "$(dirname "$BACKUP_PATH")" | tail -n 1 | tr -d 'M')
    if [ "$backup_space" -lt "$MIN_DISK_SPACE_MB" ]; then
        log_warning "Espacio insuficiente en directorio de backup: ${backup_space}MB"
        log_warning "Los backups podrían fallar durante la provisión"
        return 1
    fi

    log_success "Espacio para backups OK: ${backup_space}MB"
    return 0
}

# Función principal del hook
check_system_requirements() {
    export PROVISION_STEP="Verificación del Sistema"
    log_header "Verificación de Requisitos del Sistema"

    # 1. Verificar contexto de ejecución
    validate_provision_env || {
        log_error "Entorno de provisión no inicializado"
        return 1
    }

    # 2. Verificar ejecución como root
    if ! check_root; then
        log_error "Este script debe ejecutarse como root"
        return 1
    }

    # 3. Registrar información del sistema
    log_info "Sistema operativo: $(get_os_info)"

    # 4. Verificar recursos del sistema
    local total_memory=$(get_total_memory)
    local disk_space=$(get_disk_space)
    local cpu_cores=$(get_cpu_cores)

    log_info "Recursos del sistema:"
    log_info "- Memoria total: ${total_memory}MB (mínimo: ${MIN_MEMORY_MB}MB)"
    log_info "- Espacio en disco: ${disk_space}MB (mínimo: ${MIN_DISK_SPACE_MB}MB)"
    log_info "- Núcleos CPU: ${cpu_cores} (mínimo: ${MIN_CPU_CORES})"

    # 5. Validar recursos
    local checks=(
        "Memoria:$total_memory:$MIN_MEMORY_MB"
        "Disco:$disk_space:$MIN_DISK_SPACE_MB"
        "CPU:$cpu_cores:$MIN_CPU_CORES"
    )

    for check in "${checks[@]}"; do
        IFS=: read -r resource value minimum <<< "$check"
        if [ "$value" -lt "$minimum" ]; then
            log_error "$resource insuficiente: $value < $minimum"
            return 1
        fi
        log_success "$resource OK: $value"
    done

    # 6. Verificar rendimiento actual
    if ! check_system_performance; then
        log_warning "Sistema bajo carga alta - la provisión podría verse afectada"
    fi

    # 7. Verificar espacio para backup
    if ! check_backup_space; then
        log_warning "Problemas con espacio de backup - considere liberar espacio"
    fi

    # 8. Verificar directorios críticos
    log_info "Verificando directorios críticos..."
    local critical_dirs=(
        "$PROJECT_DIR"
        "$PROVISION_DIR"
        "$LOGS_DIR"
        "$TEMP_DIR"
        "$(dirname "$WORDPRESS_PATH")"
        "$(dirname "$BACKUP_PATH")"
    )

    for dir in "${critical_dirs[@]}"; do
        if ! ensure_directory "$dir" 755; then
            log_error "No se pudo asegurar el directorio: $dir"
            return 1
        fi
        log_success "Directorio OK: $dir"
    done

    log_success "Verificación del sistema completada exitosamente"
    return 0
}

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ejecutar la verificación
    check_system_requirements
fi