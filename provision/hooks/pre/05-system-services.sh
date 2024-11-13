#!/usr/bin/env bash
# Pre-hook: Verificación de Servicios del Sistema
#
# Este hook verifica el estado de servicios críticos del sistema,
# asegurando que todos los componentes necesarios estén funcionando
# correctamente antes de continuar con la provisión.
#
# Depende de los siguientes helpers:
# - services.sh: Para gestión y verificación de servicios
# - system.sh: Para información y verificación del sistema
# - error.sh: Para manejo consistente de errores
# - logging.sh: Para logging uniforme
# - config.sh: Para variables de configuración
#
# Pasos de verificación:
# 1. Validación del ambiente de ejecución
# 2. Verificación de systemd y sistema init
# 3. Verificación de servicios críticos
# 4. Verificación de servicios opcionales
# 5. Verificación de logs y estado general

# 1. Validación inicial del entorno de provisión
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Obtener el directorio base de provisión
HOOKS_BASE="${PROVISION_DIR}/hooks"

# Importar helpers necesarios usando la función de hooks.sh
load_helpers "services.sh" "system.sh" "error.sh" "logging.sh" "config.sh" "environment.sh"

# Verificar que somos root
check_root || {
    error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
    exit 1
}

# 1. Función para validar el ambiente de ejecución
validate_services_env() {
    log_info "PASO 1: Validación del Ambiente de Ejecución"
    log_info "----------------------------------------"

    # 1.1 Validar inicialización del entorno
    log_info "Verificando inicialización del entorno..."
    if ! validate_provision_env; then
        error_handle "Entorno de provisión no inicializado" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    }

    # 1.2 Verificar existencia de directorios necesarios
    log_info "Verificando directorios necesarios..."
    local required_dirs=(
        "${LOGS_DIR}"              # Directorio de logs
        "${PROVISION_DIR}/tmp"     # Temporales de provisión
    )

    for dir in "${required_dirs[@]}"; do
        if ! ensure_directory "$dir" 755 "root" "root"; then
            error_handle "No se pudo crear/verificar directorio: $dir" ${ERROR_CODES["GENERAL_ERROR"]}
            return 1
        fi
    done

    # 1.3 Verificar permisos de logs
    log_info "Verificando permisos de logs..."
    if ! check_write_permission "$LOGS_DIR"; then
        error_handle "Sin permisos de escritura en $LOGS_DIR" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    }

    # 1.4 Verificar sistema operativo
    log_info "Verificando sistema operativo..."
    local os_info
    os_info=$(get_os_info)
    log_info "Sistema detectado: $os_info"

    # 1.5 Verificar recursos disponibles
    log_info "Verificando recursos del sistema..."
    if ! check_system_requirements "$MIN_MEMORY_MB" "$MIN_CPU_CORES"; then
        error_handle "El sistema no cumple con los requisitos mínimos" ${ERROR_CODES["GENERAL_ERROR"]}
        return 1
    }

    log_success "Validación del ambiente completada"
    return 0
}

# 2. Función para verificación de systemd y sistema init
verify_system_init() {
    log_info "PASO 2: Verificación de systemd y Sistema Init"
    log_info "-----------------------------------------"

    # 2.1 Verificar sistema init usando nueva función
    log_info "Verificando sistema init..."
    if ! system_check_init; then
        error_handle "El sistema no está usando systemd como init" ${ERROR_CODES["DEPENDENCY_ERROR"]}
        return 1
    }

    # 2.2 Verificar estado completo de systemd
    log_info "Realizando verificación completa de systemd..."
    if ! system_verify_systemd; then
        log_error "Se encontraron problemas con systemd"

        # 2.2.1 Obtener unidades fallidas
        local failed_units
        failed_units=$(service_get_failed_units true)
        if [ -n "$failed_units" ]; then
            log_error "Unidades fallidas encontradas:"
            echo "$failed_units" | while read -r line; do
                log_error "  $line"
            done
        fi

        # 2.2.2 Intentar recuperación básica
        log_warning "Intentando recuperación básica..."

        # Recargar configuración de systemd
        if ! systemctl daemon-reload; then
            log_error "No se pudo recargar la configuración de systemd"
        fi

        # Reiniciar unidades fallidas
        local unit
        while read -r unit; do
            if [ -n "$unit" ]; then
                log_info "Intentando reiniciar unidad: $unit"
                if ! service_control "restart" "$unit" "Unidad fallida"; then
                    log_error "No se pudo reiniciar $unit"
                fi
            fi
        done < <(service_get_failed_units)

        # Verificar nuevamente después de intentos de recuperación
        if ! system_verify_systemd; then
            error_handle "systemd continúa en estado degradado después de intentos de recuperación" ${ERROR_CODES["DEPENDENCY_ERROR"]}
            return 1
        fi
    fi

    # 2.3 Verificar servicios esenciales de systemd
    log_info "Verificando servicios esenciales de systemd..."
    local essential_units=(
        "systemd-journald"
        "systemd-logind"
        "systemd-udevd"
    )

    local failed_essential=0
    for unit in "${essential_units[@]}"; do
        log_info "Verificando $unit..."

        # 2.3.1 Verificar estado usando service_get_status
        local status
        status=$(service_get_status "$unit")
        if [ $? -ne 0 ]; then
            log_error "Servicio esencial $unit en estado problemático"
            log_error "Estado actual:"
            echo "$status"
            ((failed_essential++))
        fi

        # 2.3.2 Verificar carga del servicio
        local service_load
        service_load=$(service_get_load "$unit")
        if [ -n "$service_load" ]; then
            log_info "Carga de $unit: $service_load"
        fi
    done

    if [ $failed_essential -gt 0 ]; then
        error_handle "Hay $failed_essential servicios esenciales con problemas" ${ERROR_CODES["DEPENDENCY_ERROR"]}
        return 1
    fi

    # 2.4 Verificar logs del sistema
    log_info "Verificando logs del sistema..."
    local system_logs=(
        "systemd"
        "kernel"
    )

    for log in "${system_logs[@]}"; do
        log_info "Verificando logs de $log..."
        if ! service_check_logs "$log" 50 "err"; then
            log_warning "Se encontraron errores en logs de $log"
        fi
    done

    # 2.5 Registrar estado en archivo de reporte
    {
        echo "=== Reporte de Verificación de Sistema Init ==="
        echo "Fecha: $(date)"
        echo "Sistema Init: $(ps --no-headers -o comm 1)"
        echo "Estado systemd: $(systemctl is-system-running)"
        echo "Servicios esenciales verificados: ${#essential_units[@]}"
        echo "Servicios esenciales con problemas: $failed_essential"
        echo "Logs verificados: ${#system_logs[@]}"
        echo ""
        echo "Estado detallado de servicios esenciales:"
        for unit in "${essential_units[@]}"; do
            echo "--- $unit ---"
            service_get_status "$unit"
            echo ""
        done
    } > "${LOGS_DIR}/system_init_check.log"

    log_success "Verificación de systemd completada"
    return 0
}

# 3. Función para verificación de servicios críticos
verify_critical_services() {
    log_info "PASO 3: Verificación de Servicios Críticos"
    log_info "----------------------------------------"

    # 3.1 Definir servicios críticos desde config.sh o usar valores por defecto
    local -A critical_services
    if [ ${#CRITICAL_SERVICES[@]} -eq 0 ]; then
        declare -A critical_services=(
            ["sshd"]="SSH Server:network"
            ["cron"]="Cron Service:system"
            ["rsyslog"]="System Logger:system"
            ["networking"]="Networking:network"
            ["mysql"]="MySQL Server:database"
        )
    else
        critical_services=("${CRITICAL_SERVICES[@]}")
    fi

    # 3.2 Preparar directorio para logs detallados
    local service_logs_dir="${LOGS_DIR}/services"
    ensure_directory "$service_logs_dir"

    # 3.3 Inicializar contadores y arrays para el reporte
    local total_services=${#critical_services[@]}
    local failed_services=0
    local recovered_services=0
    local service_states=()

    log_info "Verificando $total_services servicios críticos..."

    # 3.4 Verificar cada servicio crítico
    for service_info in "${!critical_services[@]}"; do
        IFS=':' read -r service_name service_desc service_type <<< "${critical_services[$service_info]}"

        log_info "Verificando $service_desc ($service_name)..."
        local service_log_file="${service_logs_dir}/${service_name}.log"
        local recovery_attempted=false
        local service_status="OK"

        # 3.4.1 Verificación inicial
        {
            echo "=== Verificación de Servicio: $service_name ==="
            echo "Descripción: $service_desc"
            echo "Tipo: $service_type"
            echo "Fecha: $(date)"
            echo ""

            # 3.4.2 Verificar existencia del servicio
            if ! service_exists "$service_name"; then
                echo "ERROR: Servicio no encontrado"
                service_status="NO_EXISTE"
                ((failed_services++))
                service_states+=("✗ $service_desc (No instalado)")
                continue
            }

            # 3.4.3 Obtener estado detallado
            echo "--- Estado Detallado ---"
            service_get_status "$service_name"
            echo ""

            # 3.4.4 Verificar estado de ejecución
            if ! service_is_running "$service_name"; then
                echo "ADVERTENCIA: Servicio no está en ejecución"
                service_status="DETENIDO"

                # Intento de recuperación
                log_warning "$service_desc no está en ejecución, intentando iniciar..."
                if error_retry_command "service_control start $service_name" "$service_desc" 3 5; then
                    log_success "Servicio $service_desc recuperado exitosamente"
                    ((recovered_services++))
                    service_status="RECUPERADO"
                    recovery_attempted=true
                else
                    log_error "No se pudo recuperar el servicio $service_desc"
                    ((failed_services++))
                    service_states+=("✗ $service_desc (No se pudo iniciar)")
                    continue
                fi
            }

            # 3.4.5 Verificar carga y recursos
            echo "--- Métricas del Servicio ---"
            local service_load
            service_load=$(service_get_load "$service_name")
            echo "Carga: $service_load"

            # 3.4.6 Verificar logs del servicio
            echo "--- Últimos Errores en Logs ---"
            service_check_logs "$service_name" 50 "err"

            # 3.4.7 Verificar dependencias
            echo "--- Verificación de Dependencias ---"
            if ! check_service_dependencies "$service_name"; then
                echo "ADVERTENCIA: Problemas con dependencias detectados"
                service_status="DEP_ERROR"
            fi

            # 3.4.8 Verificar inicio automático
            if ! service_is_enabled "$service_name"; then
                echo "ADVERTENCIA: Servicio no está habilitado para inicio automático"
                log_warning "Habilitando inicio automático para $service_desc..."
                if service_control "enable" "$service_name" "$service_desc"; then
                    echo "Inicio automático habilitado exitosamente"
                else
                    echo "ERROR: No se pudo habilitar el inicio automático"
                    service_status="AUTO_START_ERROR"
                fi
            }

            # 3.4.9 Resultado final del servicio
            echo ""
            echo "Estado final: $service_status"
            echo "Recuperación intentada: $recovery_attempted"

        } > "$service_log_file"

        # 3.4.10 Actualizar estado para el reporte
        case "$service_status" in
            "OK")
                service_states+=("✓ $service_desc (Funcionando correctamente)")
                ;;
            "RECUPERADO")
                service_states+=("⟲ $service_desc (Recuperado)")
                ;;
            *)
                if [ "$failed_services" -eq 0 ]; then
                    service_states+=("! $service_desc ($service_status)")
                fi
                ;;
        esac

        # 3.4.11 Mostrar progreso
        local progress=$((100 * (failed_services + recovered_services + 1) / total_services))
        log_progress "$progress" "100" "Verificando servicios críticos"
    done

    # 3.5 Generar reporte final
    {
        echo "=== Reporte de Verificación de Servicios Críticos ==="
        echo "Fecha: $(date)"
        echo "Total servicios verificados: $total_services"
        echo "Servicios fallidos: $failed_services"
        echo "Servicios recuperados: $recovered_services"
        echo ""
        echo "Estado por servicio:"
        printf '%s\n' "${service_states[@]}"
        echo ""
        echo "Logs detallados disponibles en: $service_logs_dir"
    } > "${LOGS_DIR}/critical_services_report.log"

    # 3.6 Evaluar resultado final
    if [ $failed_services -gt 0 ]; then
        log_error "Hay $failed_services servicios críticos con problemas"
        if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
            error_handle "Verificación de servicios críticos falló" ${ERROR_CODES["DEPENDENCY_ERROR"]}
            return 1
        fi
        log_warning "Continuando a pesar de los errores (PROVISION_CONTINUE_ON_ERROR=true)"
    else
        log_success "Verificación de servicios críticos completada"
        if [ $recovered_services -gt 0 ]; then
            log_info "Se recuperaron $recovered_services servicios durante la verificación"
        fi
    fi

    return 0
}

# 4. Función para verificación de servicios opcionales
verify_optional_services() {
    log_info "PASO 4: Verificación de Servicios Opcionales"
    log_info "------------------------------------------"

    # 4.1 Definir servicios opcionales desde config.sh o usar valores por defecto
    local -A optional_services
    if [ ${#OPTIONAL_SERVICES[@]} -eq 0 ]; then
        declare -A optional_services=(
            ["udev"]="Device Manager:system"
            ["dbus"]="System Message Bus:system"
            ["apparmor"]="Security Module:security"
            ["irqbalance"]="IRQ Balancer:system"
            ["acpid"]="Power Management:system"
        )
    else
        optional_services=("${OPTIONAL_SERVICES[@]}")
    fi

    # 4.2 Preparar directorio para logs y reportes
    local optional_logs_dir="${LOGS_DIR}/optional_services"
    ensure_directory "$optional_logs_dir"

    # 4.3 Inicializar contadores y arrays
    local total_services=${#optional_services[@]}
    local verified_count=0
    local warning_count=0
    local service_details=()

    log_info "Verificando $total_services servicios opcionales..."

    # 4.4 Verificar cada servicio opcional
    for service_info in "${!optional_services[@]}"; do
        IFS=':' read -r service_name service_desc service_type <<< "${optional_services[$service_info]}"
        local service_log="${optional_logs_dir}/${service_name}.log"
        local service_state="DESCONOCIDO"

        log_info "Verificando $service_desc ($service_name)..."

        # 4.4.1 Documentar verificación
        {
            echo "=== Verificación de Servicio Opcional: $service_name ==="
            echo "Descripción: $service_desc"
            echo "Tipo: $service_type"
            echo "Fecha: $(date)"
            echo ""

            # 4.4.2 Verificar existencia
            if service_exists "$service_name"; then
                echo "Servicio encontrado en el sistema"

                # 4.4.3 Verificar estado
                if service_is_running "$service_name"; then
                    service_state="ACTIVO"

                    # 4.4.4 Obtener información detallada
                    echo "--- Estado Detallado ---"
                    service_get_status "$service_name"

                    # 4.4.5 Verificar carga
                    echo "--- Métricas de Recursos ---"
                    local service_load
                    service_load=$(service_get_load "$service_name")
                    echo "Carga: $service_load"

                    # 4.4.6 Verificar inicio automático
                    if ! service_is_enabled "$service_name"; then
                        echo "NOTA: Servicio no está configurado para inicio automático"
                        service_state="ACTIVO_NO_AUTO"
                    fi

                    # 4.4.7 Verificar logs recientes
                    echo "--- Últimos Mensajes de Log ---"
                    service_check_logs "$service_name" 20 "warning"

                else
                    service_state="INACTIVO"
                    echo "Servicio encontrado pero no está en ejecución"

                    # 4.4.8 Si está configurado para auto-inicio pero no está corriendo
                    if service_is_enabled "$service_name"; then
                        echo "ADVERTENCIA: Servicio configurado para inicio automático pero no está ejecutándose"
                        service_state="INACTIVO_AUTO"
                    fi
                fi

            else
                service_state="NO_INSTALADO"
                echo "Servicio no encontrado en el sistema"
            fi

            # 4.4.9 Registrar estado final
            echo ""
            echo "Estado final: $service_state"
            echo "Timestamp: $(date +%Y-%m-%d_%H:%M:%S)"

        } > "$service_log"

        # 4.4.10 Actualizar contadores y estado
        ((verified_count++))
        case "$service_state" in
            "ACTIVO")
                service_details+=("✓ $service_desc")
                ;;
            "ACTIVO_NO_AUTO")
                service_details+=("! $service_desc (Sin auto-inicio)")
                ((warning_count++))
                ;;
            "INACTIVO"|"INACTIVO_AUTO")
                service_details+=("⚠ $service_desc ($service_state)")
                ((warning_count++))
                ;;
            "NO_INSTALADO")
                service_details+=("- $service_desc (No instalado)")
                ;;
            *)
                service_details+=("? $service_desc (Estado desconocido)")
                ((warning_count++))
                ;;
        esac

        # 4.4.11 Mostrar progreso
        local progress=$((verified_count * 100 / total_services))
        log_progress "$progress" "100" "Verificando servicios opcionales"
    done

    # 4.5 Generar reporte consolidado
    {
        echo "=== Reporte de Verificación de Servicios Opcionales ==="
        echo "Fecha: $(date)"
        echo "Total servicios verificados: $total_services"
        echo "Advertencias encontradas: $warning_count"
        echo ""
        echo "Detalle por servicio:"
        printf '%s\n' "${service_details[@]}"
        echo ""
        echo "Notas:"
        echo "✓ : Servicio funcionando correctamente"
        echo "! : Servicio funcionando con advertencias"
        echo "⚠ : Servicio con problemas"
        echo "- : Servicio no instalado"
        echo "? : Estado desconocido"
        echo ""
        echo "Logs detallados disponibles en: $optional_logs_dir"
    } > "${LOGS_DIR}/optional_services_report.log"

    # 4.6 Evaluar resultado
    if [ $warning_count -gt 0 ]; then
        log_warning "Se encontraron $warning_count advertencias en servicios opcionales"
        # No fallamos el script porque son servicios opcionales
    else
        log_success "Verificación de servicios opcionales completada sin advertencias"
    fi

    # 4.7 Guardar estado para referencia
    save_provision_state "optional_services_verified"

    return 0
}

# 5. Función para verificación de logs y estado general
verify_system_health() {
    log_info "PASO 5: Verificación de Logs y Estado General"
    log_info "----------------------------------------"

    # 5.1 Preparar directorio para reportes
    local health_check_dir="${LOGS_DIR}/system_health"
    ensure_directory "$health_check_dir"

    # Variables para tracking de problemas
    local issues_found=0
    local warnings_found=0

    # 5.2 Verificar estado de logs del sistema
    log_info "Verificando logs del sistema..."
    {
        echo "=== Verificación de Logs del Sistema ==="
        echo "Fecha: $(date)"
        echo ""

        # 5.2.1 Verificar espacio en /var/log
        local log_space
        log_space=$(get_directory_size_mb "/var/log")
        echo "Espacio usado en /var/log: ${log_space}MB"

        # 5.2.2 Verificar permisos del directorio de logs
        if ! check_write_permission "/var/log"; then
            echo "ADVERTENCIA: Problemas de permisos en /var/log"
            ((warnings_found++))
        fi

        # 5.2.3 Verificar journal
        echo "--- Estado del Journal ---"
        if ! journalctl --verify >/dev/null 2>&1; then
            echo "ERROR: Se encontraron problemas en el journal"
            ((issues_found++))
        else
            echo "Journal verificado correctamente"
        fi

        # 5.2.4 Verificar rotación de logs
        echo "--- Configuración de Logrotate ---"
        if [ -f "/etc/logrotate.conf" ]; then
            cat "/etc/logrotate.conf" | grep -v "^#" | grep -v "^$"
        else
            echo "ADVERTENCIA: No se encontró configuración de logrotate"
            ((warnings_found++))
        fi

    } > "${health_check_dir}/logs_check.log"

    # 5.3 Verificar recursos del sistema
    log_info "Verificando recursos del sistema..."
    {
        echo "=== Estado de Recursos del Sistema ==="
        echo "Fecha: $(date)"
        echo ""

        # 5.3.1 CPU
        echo "--- CPU ---"
        echo "Cores: $(get_cpu_cores)"
        echo "Modelo: $(get_cpu_model)"
        echo "Velocidad: $(get_cpu_speed) MHz"
        echo "Carga promedio: $(get_load_average)"

        # 5.3.2 Memoria
        echo "--- Memoria ---"
        echo "Total: $(get_total_memory) MB"
        echo "Disponible: $(get_available_memory) MB"

        if [ "$(get_available_memory)" -lt "$MIN_MEMORY_MB" ]; then
            echo "ADVERTENCIA: Memoria disponible por debajo del mínimo requerido"
            ((warnings_found++))
        fi

        # 5.3.3 CPU Throttling
        echo "--- Estado de CPU ---"
        if check_cpu_throttling; then
            echo "ADVERTENCIA: Se detectó CPU throttling"
            ((warnings_found++))
        else
            echo "No se detectó CPU throttling"
        fi

    } > "${health_check_dir}/resources_check.log"

    # 5.4 Verificar estado de procesos del sistema
    log_info "Verificando procesos del sistema..."
    {
        echo "=== Estado de Procesos del Sistema ==="
        echo "Fecha: $(date)"
        echo ""

        # 5.4.1 Procesos zombies
        echo "--- Procesos Zombie ---"
        local zombie_count
        zombie_count=$(ps aux | grep -w Z | wc -l)
        if [ "$zombie_count" -gt 0 ]; then
            echo "ADVERTENCIA: Se encontraron $zombie_count procesos zombie"
            ps aux | grep -w Z
            ((warnings_found++))
        else
            echo "No se encontraron procesos zombie"
        fi

        # 5.4.2 Procesos con alto consumo
        echo "--- Procesos con Alto Consumo ---"
        echo "Top 5 CPU:"
        ps aux --sort=-%cpu | head -6
        echo ""
        echo "Top 5 Memoria:"
        ps aux --sort=-%mem | head -6

    } > "${health_check_dir}/processes_check.log"

    # 5.5 Verificar sistemas de archivos
    log_info "Verificando sistemas de archivos..."
    {
        echo "=== Estado de Sistemas de Archivos ==="
        echo "Fecha: $(date)"
        echo ""

        # 5.5.1 Espacio en disco
        echo "--- Uso de Disco ---"
        df -h

        # 5.5.2 Inodos
        echo "--- Uso de Inodos ---"
        df -i

        # 5.5.3 Puntos de montaje críticos
        local -A mount_points=(
            ["/"]="root"
            ["/var"]="var"
            ["/tmp"]="tmp"
        )

        echo "--- Verificación de Puntos de Montaje ---"
        for mount in "${!mount_points[@]}"; do
            local desc="${mount_points[$mount]}"
            if ! mountpoint -q "$mount"; then
                echo "ADVERTENCIA: $desc ($mount) no está montado"
                ((warnings_found++))
            fi
        done

    } > "${health_check_dir}/filesystem_check.log"

    # 5.6 Generar reporte consolidado
    {
        echo "=== Reporte de Estado General del Sistema ==="
        echo "Fecha: $(date)"
        echo "Sistema: $(get_os_info)"
        echo ""
        echo "Resumen de verificaciones:"
        echo "- Problemas críticos encontrados: $issues_found"
        echo "- Advertencias encontradas: $warnings_found"
        echo ""
        echo "Detalles disponibles en:"
        echo "- Logs: ${health_check_dir}/logs_check.log"
        echo "- Recursos: ${health_check_dir}/resources_check.log"
        echo "- Procesos: ${health_check_dir}/processes_check.log"
        echo "- Sistema de archivos: ${health_check_dir}/filesystem_check.log"

        if [ $issues_found -gt 0 ] || [ $warnings_found -gt 0 ]; then
            echo ""
            echo "Se requiere atención en los siguientes aspectos:"
            [ $issues_found -gt 0 ] && echo "* Problemas críticos detectados"
            [ $warnings_found -gt 0 ] && echo "* Advertencias que requieren revisión"
        fi

    } > "${LOGS_DIR}/system_health_report.log"

    # 5.7 Evaluar resultado final
    if [ $issues_found -gt 0 ]; then
        log_error "Se encontraron $issues_found problemas críticos"
        if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
            error_handle "Verificación de estado del sistema falló" ${ERROR_CODES["GENERAL_ERROR"]}
            return 1
        fi
    fi

    if [ $warnings_found -gt 0 ]; then
        log_warning "Se encontraron $warnings_found advertencias"
    fi

    # 5.8 Guardar estado
    save_provision_state "system_health_verified"

    log_success "Verificación de estado del sistema completada"
    return 0
}

# Función principal
main() {
    log_header "Pre-Hook: Verificación de Servicios del Sistema"
    log_info "============================================="

    # 1. Establecer el paso actual de provisión
    export PROVISION_STEP="system_services"

    # 2. Definir pasos de verificación
    local -A verification_steps=(
        ["validate_services_env"]="Validación del Ambiente"
        ["verify_system_init"]="Verificación de Sistema Init"
        ["verify_critical_services"]="Verificación de Servicios Críticos"
        ["verify_optional_services"]="Verificación de Servicios Opcionales"
        ["verify_system_health"]="Verificación de Estado del Sistema"
    )

    # 3. Inicializar contadores
    local total_steps=${#verification_steps[@]}
    local current_step=0
    local failed_steps=0

    # 4. Registrar inicio del proceso
    log_info "Iniciando verificación de servicios"
    log_info "- Total de pasos: $total_steps"
    log_info "- Timestamp: $(date +%Y%m%d_%H%M%S)"
    log_info "- Directorio de logs: $LOGS_DIR"

    # 5. Ejecutar cada paso
    for step_func in "${!verification_steps[@]}"; do
        ((current_step++))
        local step_name="${verification_steps[$step_func]}"

        # 5.1 Mostrar progreso
        log_info ""
        log_info "Paso $current_step de $total_steps: $step_name"
        log_info "----------------------------------------"

        # 5.2 Ejecutar paso con manejo de errores
        if ! error_retry_command "$step_func" "$step_name" 2 5; then
            ((failed_steps++))

            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                error_handle "Falló el paso: $step_name" ${ERROR_CODES["GENERAL_ERROR"]}
                cleanup_failed_verification
                return 1
            else
                log_warning "Falló el paso pero continuando por PROVISION_CONTINUE_ON_ERROR=true"
            fi
        fi

        # 5.3 Actualizar estado
        save_provision_state "services_check_${current_step}_completed"

        # 5.4 Mostrar progreso
        local percent=$((current_step * 100 / total_steps))
        log_progress "$current_step" "$total_steps" "$step_name completado"
    done

    # 6. Generar reporte final consolidado
    generate_final_report

    # 7. Verificación final
    if [ $failed_steps -eq 0 ]; then
        log_success "Verificación de servicios completada exitosamente"
        save_provision_state "services_check_completed"
        return 0
    else
        log_error "Verificación completada con $failed_steps errores"
        save_provision_state "services_check_failed"
        return 1
    fi
}

# Función para generar reporte final
generate_final_report() {
    local report_file="${LOGS_DIR}/services_verification_report.log"

    {
        echo "=== Reporte Final de Verificación de Servicios ==="
        echo "Fecha: $(date)"
        echo "Host: $(hostname)"
        echo "Sistema Operativo: $(get_os_info)"
        echo ""

        echo "=== Resumen de Verificaciones ==="
        for step_func in "${!verification_steps[@]}"; do
            local step_name="${verification_steps[$step_func]}"
            local step_state

            if [ -f "${PROVISION_DIR}/tmp/services_check_${step_func}" ]; then
                step_state="✓ Completado"
            else
                step_state="✗ Fallido"
            fi

            echo "$step_name: $step_state"
        done

        echo ""
        echo "=== Estado del Sistema ==="
        echo "Uptime: $(uptime -p)"
        echo "Carga del Sistema: $(get_load_average)"
        echo "Memoria Disponible: $(get_available_memory)MB"

        echo ""
        echo "=== Logs Detallados ==="
        echo "Los logs detallados están disponibles en:"
        find "$LOGS_DIR" -type f -name "*.log" | while read -r log_file; do
            echo "- $(basename "$log_file")"
        done

    } > "$report_file"

    log_info "Reporte final generado en: $report_file"
}

# Función para limpieza en caso de fallo
cleanup_failed_verification() {
    log_info "Limpiando después de verificación fallida..."

    # Limpiar archivos temporales
    clean_temp_files

    # Asegurar que los servicios críticos estén funcionando
    for service in "${CRITICAL_SERVICES[@]}"; do
        if ! service_is_running "$service"; then
            log_warning "Intentando reiniciar servicio crítico: $service"
            service_control "restart" "$service" "Recuperación"
        fi
    done
}

# Configurar manejador de errores específico
trap 'error_handle "Error en verificación de servicios" $? $LINENO' ERR

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Verificar que somos root
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        exit 1
    fi

    # Configurar manejo de errores
    set -e
    trap 'error_handle "Error en línea $LINENO" $? $LINENO' ERR

    # Ejecutar script
    main
    exit_code=$?

    # Limpiar si es necesario
    if [ $exit_code -ne 0 ] && [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
        cleanup_failed_verification
    fi

    exit $exit_code
fi