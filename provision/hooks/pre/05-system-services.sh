#!/usr/bin/env bash
# Pre-hook: Verificación de Servicios del Sistema
#
# Este hook verifica el estado de los servicios críticos del sistema,
# asegurando que todos los componentes necesarios estén funcionando
# correctamente antes de continuar con la provisión.
#
# Nota: Este script debe ser ejecutado como root

# 1. Validación inicial del entorno de provisión
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# 2. Importar helpers necesarios
# Nota: Orden específico para manejar dependencias
for helper in colors logging error system services filesystem environment config; do
    source "${PROVISION_DIR}/helpers/${helper}.sh" || {
        echo "Error: No se pudo cargar ${helper}.sh"
        exit 1
    }
done

# 3. Verificar que somos root (usando función existente)
check_root || {
    error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
    exit 1
}

# 4. Cargar configuraciones de servicios desde config.sh si existen
if [ -z "${CRITICAL_SERVICES[*]}" ]; then
    declare -A CRITICAL_SERVICES=(
        ["systemd"]="Sistema base"
        ["systemd-journald"]="Sistema de logging"
        ["systemd-networkd"]="Networking"
        ["systemd-resolved"]="Resolución DNS"
        ["ssh"]="SSH Server"
        ["cron"]="Tareas programadas"
        ["rsyslog"]="System Logger"
    )
fi

if [ -z "${OPTIONAL_SERVICES[*]}" ]; then
    declare -A OPTIONAL_SERVICES=(
        ["udev"]="Device Manager"
        ["dbus"]="Message Bus"
        ["apparmor"]="Security"
        ["irqbalance"]="IRQ Balancer"
    )
fi

# 5. Funciones de verificación
verify_systemd_init() {
    log_info "Verificando systemd como sistema init..."

    # Verificar proceso init usando system.sh
    local sys_info
    sys_info=$(get_os_info)
    log_info "Sistema operativo: $sys_info"

    if [ "$(ps --no-headers -o comm 1)" != "systemd" ]; then
        error_handle "systemd no es el sistema init" ${ERROR_CODES["DEPENDENCY_ERROR"]}
        return 1
    fi

    # Obtener y mostrar versión de systemd
    local systemd_version
    systemd_version=$(systemctl --version | head -n1 | awk '{print $2}')
    log_info "Versión de systemd: $systemd_version"

    # Verificar estado del sistema
    local system_state
    system_state=$(systemctl is-system-running)
    log_info "Estado del sistema: $system_state"

    # Verificar recursos del sistema usando system.sh
    log_info "Recursos del sistema:"
    log_info "- CPU Load: $(get_load_average)"
    log_info "- Memoria disponible: $(get_available_memory)MB"

    # Verificar unidades fallidas
    local failed_units
    failed_units=$(systemctl --failed --no-legend)
    if [ -n "$failed_units" ]; then
        log_warning "Unidades fallidas encontradas:"
        echo "$failed_units" | while read -r line; do
            log_warning "  $line"
        done
        # Guardar estado para el reporte
        save_provision_state "failed_units_detected"
        return 1
    fi

    log_success "Verificación de systemd completada"
    return 0
}

verify_critical_services() {
    log_info "Verificando servicios críticos..."
    local failed_count=0
    local temp_log
    temp_log=$(create_temp_file "services_check")

    for service_name in "${!CRITICAL_SERVICES[@]}"; do
        local service_desc="${CRITICAL_SERVICES[$service_name]}"
        log_info "Verificando $service_desc ($service_name)..."

        # Usar error_retry_command para intentos múltiples
        if ! error_retry_command "service_exists $service_name" "$service_desc" 3 2; then
            log_error "$service_desc no está instalado"
            ((failed_count++))
            continue
        fi

        if ! service_is_running "$service_name"; then
            log_warning "$service_desc no está en ejecución, intentando iniciar..."
            if ! error_retry_command "service_control start $service_name" "Iniciar $service_desc" 3 5; then
                log_error "No se pudo iniciar $service_desc"
                ((failed_count++))
                continue
            fi
        fi

        if ! service_is_enabled "$service_name"; then
            log_warning "$service_desc no está habilitado, habilitando..."
            service_control "enable" "$service_name" "$service_desc"
        fi

        # Verificar dependencias y almacenar resultado
        if ! check_service_dependencies "$service_name" > "$temp_log" 2>&1; then
            log_error "Dependencias faltantes para $service_desc"
            log_error "$(cat "$temp_log")"
            ((failed_count++))
            continue
        fi

        # Verificar espacio en log
        if ! check_disk_space "/var/log" 100; then
            log_warning "Espacio insuficiente en /var/log para $service_name"
        fi

        log_success "$service_desc verificado correctamente"
    done

    # Limpiar archivo temporal usando función segura
    safe_remove "$temp_log"

    if [ $failed_count -gt 0 ]; then
        error_handle "Fallaron $failed_count servicios críticos" ${ERROR_CODES["DEPENDENCY_ERROR"]}
        return 1
    fi

    return 0
}

# 6. Función para verificar servicios opcionales
verify_optional_services() {
    log_info "Verificando servicios opcionales..."
    local warning_count=0
    local service_states=()

    # Crear directorio temporal para logs
    local temp_dir
    temp_dir=$(create_temp_dir "optional_services")

    for service_name in "${!OPTIONAL_SERVICES[@]}"; do
        local service_desc="${OPTIONAL_SERVICES[$service_name]}"
        local service_log="${temp_dir}/${service_name}.log"

        log_info "Verificando $service_desc ($service_name)..."

        # Verificar existencia del servicio
        if service_exists "$service_name"; then
            # Verificar estado del servicio usando funciones de services.sh
            if service_is_running "$service_name"; then
                # Obtener información adicional del servicio usando system.sh
                local memory_usage
                memory_usage=$(get_memory_usage "$service_name")

                service_states+=("✓ $service_desc (Memoria: ${memory_usage}%)")
                log_success "$service_desc está activo"

                # Verificar si está habilitado para inicio automático
                if ! service_is_enabled "$service_name"; then
                    log_warning "$service_desc no está habilitado para inicio automático"
                    ((warning_count++))
                fi
            else
                service_states+=("⚠ $service_desc (Inactivo)")
                log_warning "$service_desc no está en ejecución"
                ((warning_count++))
            fi
        else
            service_states+=("- $service_desc (No instalado)")
            log_info "$service_desc no está instalado"
        fi
    done

    # Generar reporte de estado
    {
        echo "=== Estado de Servicios Opcionales ==="
        echo "Fecha: $(date)"
        echo "Total servicios verificados: ${#OPTIONAL_SERVICES[@]}"
        echo "Advertencias encontradas: $warning_count"
        echo ""
        printf '%s\n' "${service_states[@]}"
    } > "${PROVISION_DIR}/logs/optional_services_status.log"

    # Limpiar directorio temporal
    safe_remove "$temp_dir"

    if [ $warning_count -gt 0 ]; then
        log_warning "Se encontraron $warning_count advertencias en servicios opcionales"
    else
        log_success "Todos los servicios opcionales verificados"
    fi

    return 0
}

# 7. Función para verificar estado general del sistema
verify_system_state() {
    log_info "Verificando estado general del sistema..."
    local issues_found=0

    # 7.1 Verificar carga del sistema usando system.sh
    local load_avg
    load_avg=$(get_load_average)
    local cpu_cores
    cpu_cores=$(get_cpu_cores)

    log_info "Carga del sistema: $load_avg (cores: $cpu_cores)"
    if (( $(echo "$load_avg > $cpu_cores" | bc -l) )); then
        log_warning "Carga del sistema superior al número de cores"
        ((issues_found++))
    }

    # 7.2 Verificar uso de memoria usando system.sh
    local mem_usage
    mem_usage=$(get_memory_usage)
    local mem_available
    mem_available=$(get_available_memory)

    log_info "Uso de memoria: ${mem_usage}% (Disponible: ${mem_available}MB)"
    if [ "$mem_usage" -gt 90 ]; then
        log_warning "Uso de memoria crítico"
        ((issues_found++))
    fi

    # 7.3 Verificar CPU throttling usando system.sh
    if check_cpu_throttling; then
        log_warning "Se detectó CPU throttling"
        ((issues_found++))
    fi

    # 7.4 Verificar espacio en disco usando filesystem.sh
    local disk_space
    disk_space=$(get_disk_space)
    log_info "Espacio en disco: $disk_space"

    # Verificar espacio en directorios críticos
    local -A critical_dirs=(
        ["/var/log"]="100"    # 100MB mínimo
        ["/var/run"]="50"     # 50MB mínimo
        ["/tmp"]="200"        # 200MB mínimo
        ["$PROVISION_DIR"]="500" # 500MB mínimo
    )

    for dir in "${!critical_dirs[@]}"; do
        local min_space="${critical_dirs[$dir]}"
        if ! check_disk_space "$dir" "$min_space"; then
            log_warning "Espacio insuficiente en $dir (mínimo requerido: ${min_space}MB)"
            ((issues_found++))
        fi
    done

    # 7.5 Verificar estado de servicios systemd
    local system_state
    system_state=$(systemctl is-system-running)
    log_info "Estado del sistema systemd: $system_state"

    case "$system_state" in
        "degraded")
            log_warning "Sistema en estado degradado"
            systemctl --failed
            ((issues_found++))
            ;;
        "maintenance")
            log_error "Sistema en modo mantenimiento"
            ((issues_found++))
            ;;
        "stopping")
            log_error "Sistema deteniéndose"
            ((issues_found++))
            ;;
    esac

    # 7.6 Generar reporte del estado del sistema
    {
        echo "=== Estado General del Sistema ==="
        echo "Fecha: $(date)"
        echo "Sistema Operativo: $(get_os_info)"
        echo "Kernel: $(uname -r)"
        echo "Uptime: $(uptime -p)"
        echo ""
        echo "=== Recursos ==="
        echo "CPU Cores: $cpu_cores"
        echo "Carga del Sistema: $load_avg"
        echo "Memoria Usada: $mem_usage%"
        echo "Memoria Disponible: $mem_available MB"
        echo "Estado systemd: $system_state"
        echo ""
        echo "=== Espacio en Disco ==="
        df -h
        echo ""
        echo "=== Resumen ==="
        echo "Problemas encontrados: $issues_found"
    } > "${PROVISION_DIR}/logs/system_state.log"

    if [ $issues_found -gt 0 ]; then
        log_warning "Se encontraron $issues_found problemas en el estado del sistema"
        return 1
    fi

    log_success "Estado del sistema verificado correctamente"
    return 0
}

# 8. Función principal
main() {
    log_header "Pre-Hook: Verificación de Servicios del Sistema"

    # Establecer el paso actual de provisión
    export PROVISION_STEP="system_services_check"

    # Definir pasos de verificación
    local -A verification_steps=(
        ["verify_systemd_init"]="Verificación de systemd"
        ["verify_critical_services"]="Verificación de Servicios Críticos"
        ["verify_optional_services"]="Verificación de Servicios Opcionales"
        ["verify_system_state"]="Verificación del Estado del Sistema"
    )

    # Variables de control
    local total_steps=${#verification_steps[@]}
    local current_step=0
    local failed_steps=0

    # Ejecutar verificaciones
    for step_func in "${!verification_steps[@]}"; do
        ((current_step++))
        local step_name="${verification_steps[$step_func]}"

        log_info ""
        log_info "Paso $current_step de $total_steps: $step_name"
        log_info "----------------------------------------"

        # Ejecutar paso y manejar errores
        if ! error_retry_command "$step_func" "$step_name" 2 5; then
            ((failed_steps++))
            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                error_handle "Falló el paso: $step_name" ${ERROR_CODES["GENERAL_ERROR"]}
                return 1
            fi
        fi

        # Actualizar estado de provisión
        save_provision_state "system_services_${current_step}_complete"

        # Mostrar progreso
        log_progress "$current_step" "$total_steps" "$step_name"
    done

    # Resultado final
    if [ "$failed_steps" -eq 0 ]; then
        log_success "Verificación de servicios completada exitosamente"
        return 0
    else
        log_error "Verificación completada con $failed_steps errores"
        return 1
    fi
}

# Ejecutar script solo si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Verificar permisos de root
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        exit 1
    fi

    # Configurar manejo de errores
    set -e
    trap 'error_handle "Error en línea $LINENO" $? $LINENO' ERR

    # Ejecutar script principal
    main
    exit $?
fi