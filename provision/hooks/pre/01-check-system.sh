#!/usr/bin/env bash
# Pre-hook: Verificación básica del sistema
#
# Pasos de verificación:
# 1. Validación del contexto de ejecución
# 2. Verificación de memoria
# 3. Verificación de espacio en disco
# 4. Verificación de CPU
# 5. Verificación de permisos de usuario
#
# Cada paso incluye:
# - Recolección de datos
# - Validación contra requisitos mínimos
# - Registro de resultados
# - Manejo de errores

# 1. Validación del contexto de ejecución
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Cargar helpers necesarios
load_helpers "system.sh" "logging.sh" "error.sh" "filesystem.sh"

# 2. Función para verificar memoria
check_memory() {
    log_info "PASO 1: Verificación de Memoria"
    log_info "------------------------"

    # 2.1 Recolectar datos de memoria
    local total_memory=$(get_total_memory)
    local available_memory=$(get_available_memory)
    local memory_usage_percent=$(( (total_memory - available_memory) * 100 / total_memory ))

    # 2.2 Registrar información
    log_info "Datos de memoria:"
    log_info "- Total: ${total_memory}MB"
    log_info "- Disponible: ${available_memory}MB"
    log_info "- Uso actual: ${memory_usage_percent}%"

    # 2.3 Validar contra requisitos
    if [ "$total_memory" -lt "$MIN_MEMORY_MB" ]; then
        log_error "Memoria insuficiente: ${total_memory}MB (mínimo: ${MIN_MEMORY_MB}MB)"
        return 1
    fi

    # 2.4 Verificar uso actual
    if [ "$memory_usage_percent" -gt 90 ]; then
        log_warning "Alto uso de memoria: ${memory_usage_percent}%"
    fi

    log_success "Verificación de memoria exitosa"
    return 0
}

# 3. Función para verificar espacio en disco
check_disk_space() {
    log_info "PASO 2: Verificación de Espacio en Disco"
    log_info "--------------------------------"

    # 3.1 Definir directorios críticos a verificar
    local critical_paths=(
        "$PROJECT_DIR:Directorio del proyecto"
        "$WORDPRESS_PATH:Directorio de WordPress"
        "$BACKUP_PATH:Directorio de respaldos"
        "$TEMP_DIR:Directorio temporal"
    )

    # 3.2 Verificar cada directorio
    for path_info in "${critical_paths[@]}"; do
        # Separar ruta y descripción
        IFS=':' read -r path description <<< "$path_info"
        local dir=$(dirname "$path")

        log_info "Verificando $description ($dir):"

        # 3.3 Recolectar datos del disco
        local available_space=$(get_free_space_mb "$dir")
        local total_space=$(get_total_space_mb "$dir")
        local usage_percent=$(( (total_space - available_space) * 100 / total_space ))

        # 3.4 Registrar información detallada
        log_info "  - Espacio total: ${total_space}MB"
        log_info "  - Espacio disponible: ${available_space}MB"
        log_info "  - Porcentaje usado: ${usage_percent}%"

        # 3.5 Validar espacio disponible
        if [ "$available_space" -lt "$MIN_DISK_SPACE_MB" ]; then
            log_error "   Espacio insuficiente en $description"
            log_error "   Disponible: ${available_space}MB"
            log_error "   Mínimo requerido: ${MIN_DISK_SPACE_MB}MB"
            return 1
        fi

        # 3.6 Verificar uso crítico
        if [ "$usage_percent" -gt 90 ]; then
            log_warning " Uso crítico de disco en $description: ${usage_percent}%"
        elif [ "$usage_percent" -gt 80 ]; then
            log_warning " Alto uso de disco en $description: ${usage_percent}%"
        fi

        # 3.7 Verificar permisos de escritura
        if ! check_write_permission "$dir"; then
            log_error "Sin permisos de escritura en $description"
            return 1
        fi

        log_success "Verificación exitosa para $description"
    done

    # 3.8 Verificación adicional para directorio de backups
    local backup_available=$(get_free_space_mb "$(dirname "$BACKUP_PATH")")
    local wp_size=$(get_directory_size_mb "$WORDPRESS_PATH")

    if [ "$backup_available" -lt "$wp_size" ]; then
        log_warning "   Espacio insuficiente para un backup completo"
        log_warning "   Espacio disponible: ${backup_available}MB"
        log_warning "   Tamaño de WordPress: ${wp_size}MB"
    fi

    log_success "Verificación de espacio en disco completada exitosamente"
    return 0
}


# 4. Función para verificar CPU
check_cpu() {
    log_info "PASO 3: Verificación de CPU"
    log_info "------------------------"

    # 4.1 Recolectar información de CPU
    local cpu_cores=$(get_cpu_cores)
    local cpu_usage=$(get_cpu_usage)
    local load_average=$(get_load_average)
    local cpu_model=$(get_cpu_model)
    local cpu_mhz=$(get_cpu_speed)

    # 4.2 Registrar información detallada
    log_info "Información de CPU:"
    log_info "- Modelo: $cpu_model"
    log_info "- Velocidad: $cpu_mhz MHz"
    log_info "- Núcleos disponibles: $cpu_cores"
    log_info "- Uso actual: $cpu_usage%"
    log_info "- Carga promedio: $load_average"

    # 4.3 Verificar número de núcleos
    if [ "$cpu_cores" -lt "$MIN_CPU_CORES" ]; then
        log_error "Núcleos CPU insuficientes"
        log_error "- Actual: $cpu_cores"
        log_error "- Mínimo requerido: $MIN_CPU_CORES"
        return 1
    fi

    # 4.4 Verificar carga actual
    if [ "$(echo "$cpu_usage > 80" | bc -l)" -eq 1 ]; then
        log_warning "Alta carga de CPU detectada: $cpu_usage%"
        log_warning "La instalación podría verse afectada"
    fi

    # 4.5 Verificar carga promedio
    local max_load=$(echo "$cpu_cores * 2" | bc)
    if [ "$(echo "$load_average > $max_load" | bc -l)" -eq 1 ]; then
        log_warning "Carga del sistema elevada"
        log_warning "- Carga actual: $load_average"
        log_warning "- Carga máxima recomendada: $max_load"
    fi

    # 4.6 Verificar throttling de CPU
    check_cpu_throttling
    local throttling_status=$?

    case $throttling_status in
        0)
            log_warning "Se detectó throttling de CPU"
            log_warning "El rendimiento podría verse afectado"
            ;;
        1)
            log_info "Estado térmico del CPU: Normal"
            ;;
        2)
            # Aunque check_cpu_throttling ya generó warnings específicos,
            # podemos agregar un mensaje general en el contexto de la verificación
            log_warning "No se pudo verificar el estado térmico del CPU"
            ;;
        *)
            # Por si acaso hay algún código de retorno inesperado
            log_error "Error desconocido al verificar el estado térmico del CPU"
            ;;
    esac
}

# 5. Función para verificar permisos de usuario
check_user_permissions() {
    log_info "PASO 4: Verificación de Permisos de Usuario"
    log_info "---------------------------------------"

    # 5.1 Verificar usuario root
    local current_user=$(whoami)
    local current_uid=$(id -u)

    log_info "Información de usuario:"
    log_info "- Usuario actual: $current_user"
    log_info "- UID: $current_uid"

    if [ "$current_uid" -ne 0 ]; then
        log_error "El script debe ejecutarse como root"
        log_error "- Usuario actual: $current_user"
        log_error "- UID actual: $current_uid"
        return 1
    }

    # 5.2 Verificar permisos en directorios críticos
    local dir_permissions=(
        "$PROJECT_DIR:755:www-data:www-data:Directorio del proyecto"
        "$WORDPRESS_PATH:755:www-data:www-data:Directorio WordPress"
        "$BACKUP_PATH:700:root:root:Directorio de respaldos"
        "$LOGS_DIR:755:root:root:Directorio de logs"
        "$TEMP_DIR:755:root:root:Directorio temporal"
    )

    # 5.3 Verificar cada directorio
    for dir_info in "${dir_permissions[@]}"; do
        IFS=':' read -r dir perms owner group description <<< "$dir_info"

        log_info "Verificando $description ($dir):"

        # 5.3.1 Verificar existencia del directorio
        if [ ! -d "$dir" ]; then
            log_info "- Creando directorio..."
            if ! mkdir -p "$dir"; then
                log_error "No se pudo crear el directorio"
                return 1
            fi
        }

        # 5.3.2 Verificar y establecer propietario
        local current_owner=$(stat -c '%U' "$dir")
        if [ "$current_owner" != "$owner" ]; then
            log_info "- Estableciendo propietario a $owner..."
            if ! chown "$owner" "$dir"; then
                log_error "No se pudo cambiar el propietario"
                return 1
            fi
        fi

        # 5.3.3 Verificar y establecer grupo
        local current_group=$(stat -c '%G' "$dir")
        if [ "$current_group" != "$group" ]; then
            log_info "- Estableciendo grupo a $group..."
            if ! chgrp "$group" "$dir"; then
                log_error "No se pudo cambiar el grupo"
                return 1
            fi
        fi

        # 5.3.4 Verificar y establecer permisos
        local current_perms=$(stat -c '%a' "$dir")
        if [ "$current_perms" != "$perms" ]; then
            log_info "- Estableciendo permisos a $perms..."
            if ! chmod "$perms" "$dir"; then
                log_error "No se pudo cambiar los permisos"
                return 1
            fi
        fi

        # 5.3.5 Verificar permisos de escritura
        if ! check_write_permission "$dir"; then
            log_error "Sin acceso de escritura en $description"
            return 1
        fi

        log_success "Permisos correctos en $description"
    done

    # 5.4 Verificar usuario www-data
    if ! id -u www-data >/dev/null 2>&1; then
        log_error "Usuario www-data no existe en el sistema"
        return 1
    fi

    # 5.5 Verificar permisos de archivos específicos
    if [ -f "$WORDPRESS_PATH/wp-config.php" ]; then
        local wp_config_perms=$(stat -c '%a' "$WORDPRESS_PATH/wp-config.php")
        if [ "$wp_config_perms" != "600" ]; then
            log_warning "Permisos de wp-config.php deberían ser 600"
            log_warning "Permisos actuales: $wp_config_perms"
        fi
    fi

    log_success "Verificación de permisos completada exitosamente"
    return 0
}

# Función auxiliar para verificar grupo www-data
check_www_data_group() {
    if ! getent group www-data >/dev/null; then
        return 1
    fi
    return 0
}

# Función auxiliar para verificar permisos efectivos
check_effective_permissions() {
    local dir="$1"
    local user="$2"
    local required_perm="$3"

    sudo -u "$user" test "$required_perm" "$dir" 2>/dev/null
    return $?
}

# Función principal del hook
check_system_requirements() {
    log_header "Verificación de Requisitos del Sistema"
    log_info "====================================="

    # 1. Validar que estamos en el contexto correcto
    if ! validate_provision_env; then
        log_error "Error: Entorno de provisión no inicializado"
        return 1
    }

    # 2. Establecer el paso actual de provisión
    export PROVISION_STEP="system_requirements"

    # 3. Registrar información del sistema
    log_info "Iniciando verificación del sistema"
    log_info "- Sistema Operativo: $(get_os_info)"
    log_info "- Fecha y Hora: $(date)"
    log_info "- Script: ${BASH_SOURCE[0]}"

    # 4. Definir verificaciones y sus descripciones
    local -A checks=(
        ["check_memory"]="Verificación de Memoria"
        ["check_disk_space"]="Verificación de Espacio en Disco"
        ["check_cpu"]="Verificación de CPU"
        ["check_user_permissions"]="Verificación de Permisos"
    )

    # 5. Contador para resultados
    local total_checks=${#checks[@]}
    local passed_checks=0
    local failed_checks=0

    # 6. Ejecutar cada verificación
    for check in "${!checks[@]}"; do
        log_info ""
        log_info "Ejecutando: ${checks[$check]}"
        log_info "-----------------------------------"

        if $check; then
            ((passed_checks++))
            log_success "Completado: ${checks[$check]}"
        else
            ((failed_checks++))
            log_error "Falló: ${checks[$check]}"

            # Verificar si debemos continuar o abortar
            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                log_error "Abortando verificación del sistema"
                return 1
            fi
        fi
    done

    # 7. Mostrar resumen final
    log_info ""
    log_info "Resumen de Verificaciones"
    log_info "========================"
    log_info "Total de verificaciones: $total_checks"
    log_info "Verificaciones exitosas: $passed_checks"
    log_info "Verificaciones fallidas: $failed_checks"

    # 8. Determinar resultado final
    if [ $failed_checks -eq 0 ]; then
        log_success "Todas las verificaciones completadas exitosamente"
        return 0
    else
        if [ "$PROVISION_CONTINUE_ON_ERROR" = "true" ]; then
            log_warning "Verificación completada con advertencias"
            return 0
        else
            log_error "Verificación fallida"
            return 1
        fi
    fi
}

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Configurar manejo de errores
    set -e
    trap 'handle_error $? ${LINENO}' ERR

    # Ejecutar verificaciones
    check_system_requirements
fi