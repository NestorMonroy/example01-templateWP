#!/bin/bash

# Verificar que estamos en el contexto correcto
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Cargar helpers necesarios
load_helpers "system.sh" "logging.sh" "error.sh"

# Función principal del hook
check_system_requirements() {
    log_header "Verificación de Requisitos del Sistema"

    # Verificar si se está ejecutando como root
    if ! check_root; then
        handle_error "Este script debe ejecutarse como root"
        return 1
    }

    # Obtener y registrar información del sistema
    log_info "Sistema operativo: $(get_os_info)"

    # Verificar recursos
    local total_memory=$(get_total_memory)
    local disk_space=$(get_disk_space)
    local cpu_cores=$(get_cpu_cores)

    # Registrar información detallada
    log_info "Recursos del sistema:"
    log_info "- Memoria total: ${total_memory}MB (mínimo: ${MIN_MEMORY_MB}MB)"
    log_info "- Espacio en disco: ${disk_space}MB (mínimo: ${MIN_DISK_SPACE_MB}MB)"
    log_info "- Núcleos CPU: ${cpu_cores} (mínimo: ${MIN_CPU_CORES})"

    # Validar memoria
    if [ "$total_memory" -lt "$MIN_MEMORY_MB" ]; then
        handle_error "Memoria insuficiente: ${total_memory}MB < ${MIN_MEMORY_MB}MB"
        return 1
    }

    # Validar espacio en disco
    if [ "$disk_space" -lt "$MIN_DISK_SPACE_MB" ]; then
        handle_error "Espacio en disco insuficiente: ${disk_space}MB < ${MIN_DISK_SPACE_MB}MB"
        return 1
    }

    # Validar CPU
    if [ "$cpu_cores" -lt "$MIN_CPU_CORES" ]; then
        handle_error "Núcleos CPU insuficientes: ${cpu_cores} < ${MIN_CPU_CORES}"
        return 1
    }

    # Verificar rendimiento actual
    local cpu_usage=$(get_cpu_usage)
    local memory_usage=$(get_memory_usage)

    log_info "Estado actual del sistema:"
    log_info "- Uso de CPU: ${cpu_usage}%"
    log_info "- Uso de memoria: ${memory_usage}%"

    # Advertencias de rendimiento
    if [ "$(echo "$cpu_usage > 80" | bc -l)" -eq 1 ]; then
        log_warning "Alta carga de CPU detectada (${cpu_usage}%)"
    fi

    if [ "$(echo "$memory_usage > 90" | bc -l)" -eq 1 ]; then
        log_warning "Alto uso de memoria detectado (${memory_usage}%)"
    fi

    # Verificar espacio para backup
    local backup_space=$(df -BM --output=avail "$(dirname "$BACKUP_PATH")" | tail -n 1 | tr -d 'M')
    if [ "$backup_space" -lt "$MIN_DISK_SPACE_MB" ]; then
        log_warning "Espacio insuficiente en directorio de backup: ${backup_space}MB"
        log_warning "Los backups podrían fallar durante la provisión"
    }

    log_success "Verificación del sistema completada exitosamente"
    return 0
}

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Validar que estamos en el contexto correcto
    validate_provision_env || {
        echo "Error: Entorno de provisión no inicializado"
        exit 1
    }

    # Ejecutar la verificación
    check_system_requirements
fi