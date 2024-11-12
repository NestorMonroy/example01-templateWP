#!/usr/bin/env bash
# Pre-hook: Verificación de Disponibilidad de Puertos
#
# Propósitos principales:
# - Verificar disponibilidad de puertos críticos (80, 443, 3306, 9000)
# - Identificar y documentar servicios que puedan causar conflictos
# - Verificar configuraciones de firewall relacionadas
# - Realizar pruebas de conectividad y latencia
# - Sugerir configuraciones alternativas si es necesario
#
# Dependencias:
# - environment.sh: Gestión del entorno y variables de configuración
# - network.sh: Funciones de verificación de red y conectividad
# - services.sh: Gestión de servicios y verificación de puertos
# - error.sh: Manejo consistente de errores
# - logging.sh: Sistema de logging unificado
# - system.sh: Verificaciones del sistema
#

# Secuencia de verificación:
# 1. Validación del entorno
# 2. Verificación de servicios en ejecución
# 3. Verificación de disponibilidad de puertos
# 4. Verificación de reglas de firewall
# 5. Pruebas de conectividad


# Función para validar el entorno de verificación de puertos
validate_port_check_env() {
    log_info "PASO 1: Validación del Entorno para Verificación de Puertos"
    log_info "----------------------------------------------------"

    # 1. Verificar que estamos como root
    log_info "1.1 Verificando permisos de root..."
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    }
    log_success "- Permisos de root verificados"

    # 2. Validar inicialización del entorno de provisión
    log_info "1.2 Verificando inicialización del entorno..."
    if ! validate_provision_env; then
        error_handle "Entorno de provisión no inicializado" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    }
    log_success "- Entorno de provisión validado"

    # 3. Verificar variables requeridas
    log_info "1.3 Verificando variables de configuración..."
    local required_vars=(
        "PROVISION_DIR"
        "LOGS_DIR"
        "REQUIRED_PORTS"
    )

    local missing_vars=0
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Variable requerida no definida: $var"
            ((missing_vars++))
        fi
    done

    if [ $missing_vars -gt 0 ]; then
        error_handle "Faltan variables de configuración requeridas" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    }
    log_success "- Variables de configuración verificadas"

    # 4. Verificar comandos necesarios
    log_info "1.4 Verificando comandos requeridos..."
    local required_commands=(
        "netstat"
        "lsof"
        "nc"
        "ss"
    )

    local missing_commands=0
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Comando requerido no encontrado: $cmd"
            ((missing_commands++))
        fi
    done

    if [ $missing_commands -gt 0 ]; then
        error_handle "Faltan comandos necesarios para la verificación de puertos" ${ERROR_CODES["DEPENDENCY_ERROR"]}
        return 1
    }
    log_success "- Comandos requeridos verificados"

    # 5. Verificar acceso a archivos y directorios necesarios
    log_info "1.5 Verificando acceso a archivos y directorios..."
    local required_paths=(
        "/proc/net"
        "/etc/services"
        "$LOGS_DIR"
    )

    local access_errors=0
    for path in "${required_paths[@]}"; do
        if [ ! -e "$path" ]; then
            log_error "Path requerido no existe: $path"
            ((access_errors++))
        elif [ ! -r "$path" ]; then
            log_error "Sin permisos de lectura en: $path"
            ((access_errors++))
        fi
    done

    if [ $access_errors -gt 0 ]; then
        error_handle "Problemas de acceso a archivos necesarios" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    }
    log_success "- Acceso a archivos y directorios verificado"

    # 6. Verificar capacidades de red
    log_info "1.6 Verificando capacidades de red..."
    if ! ip link show lo >/dev/null 2>&1; then
        error_handle "Interface de loopback no disponible" ${ERROR_CODES["NETWORK_ERROR"]}
        return 1
    }
    log_success "- Capacidades de red verificadas"

    # Resultado final
    log_success "Validación del entorno completada exitosamente"
    return 0
}

# Función para verificar servicios que podrían causar conflictos
check_service_conflicts() {
    log_info "PASO 2: Verificación de Servicios Conflictivos"
    log_info "----------------------------------------"

    # Mapeo de servicios conocidos que pueden causar conflictos
    declare -A CONFLICTING_SERVICES=(
        ["apache2"]="80,443"
        ["httpd"]="80,443"
        ["nginx"]="80,443"
        ["mysql"]="3306"
        ["mariadb"]="3306"
        ["postgresql"]="5432"
        ["php-fpm"]="9000"
        ["memcached"]="11211"
        ["redis-server"]="6379"
        ["dovecot"]="143,993"
        ["postfix"]="25,587"
    )

    local conflicts_found=0
    local services_checked=0

    # 1. Verificar servicios activos
    log_info "2.1 Verificando servicios activos..."

    for service in "${!CONFLICTING_SERVICES[@]}"; do
        ((services_checked++))

        # Verificar si el servicio existe y está activo
        if service_exists "$service" && service_is_running "$service"; then
            local ports="${CONFLICTING_SERVICES[$service]}"
            log_warning "Servicio potencialmente conflictivo encontrado: $service"
            log_info "- Puertos asociados: $ports"

            # Verificar cada puerto asociado al servicio
            IFS=',' read -ra PORT_LIST <<< "$ports"
            for port in "${PORT_LIST[@]}"; do
                if is_port_active "$port"; then
                    local port_info
                    port_info=$(get_port_info "$port")
                    log_warning "- Puerto $port está en uso:"
                    echo "$port_info" | while IFS='=' read -r key value; do
                        log_info "  $key: $value"
                    done
                    ((conflicts_found++))
                fi
            done
        fi
    done

    # 2. Verificar servicios habilitados en el arranque
    log_info "2.2 Verificando servicios habilitados en el arranque..."

    local enabled_conflicts=0
    for service in "${!CONFLICTING_SERVICES[@]}"; do
        if service_exists "$service" && service_is_enabled "$service"; then
            log_warning "Servicio configurado para iniciar en el arranque: $service"
            ((enabled_conflicts++))
        fi
    done

    # 3. Verificar dependencias de servicios
    log_info "2.3 Verificando dependencias de servicios..."

    local dependency_conflicts=0
    for service in "${!CONFLICTING_SERVICES[@]}"; do
        if service_exists "$service"; then
            if check_service_dependencies "$service" 2>/dev/null; then
                local deps
                # Obtener dependencias usando systemctl (forma segura)
                deps=$(systemctl list-dependencies "$service" --plain --no-legend 2>/dev/null | grep '\.service' || echo "")
                if [ -n "$deps" ]; then
                    log_info "Dependencias encontradas para $service:"
                    echo "$deps" | while read -r dep; do
                        log_info "- $dep"
                    done
                    ((dependency_conflicts++))
                fi
            fi
        fi
    done

    # 4. Generar reporte de conflictos
    {
        echo "=== Reporte de Verificación de Servicios ==="
        echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Servicios verificados: $services_checked"
        echo "Conflictos encontrados: $conflicts_found"
        echo "Servicios habilitados en arranque: $enabled_conflicts"
        echo "Servicios con dependencias: $dependency_conflicts"
        echo
        echo "=== Detalles de Conflictos ==="
        for service in "${!CONFLICTING_SERVICES[@]}"; do
            if service_exists "$service" && service_is_running "$service"; then
                echo "Servicio: $service"
                echo "Puertos: ${CONFLICTING_SERVICES[$service]}"
                echo "Estado: $(systemctl status "$service" 2>/dev/null | grep "Active:" || echo "Estado desconocido")"
                echo
            fi
        done
    } >> "${LOGS_DIR}/service_conflicts.log"

    # 5. Mostrar recomendaciones
    if [ $conflicts_found -gt 0 ]; then
        log_warning "Se encontraron $conflicts_found conflictos potenciales"
        log_info "Recomendaciones:"
        log_info "- Considere detener los servicios conflictivos:"
        for service in "${!CONFLICTING_SERVICES[@]}"; do
            if service_is_running "$service"; then
                log_info "  systemctl stop $service"
            fi
        done
        log_info "- O modificar los puertos utilizados en la configuración"
        log_info "- Reporte completo guardado en: ${LOGS_DIR}/service_conflicts.log"
        return 1
    else
        log_success "No se encontraron conflictos de servicios"
        return 0
    fi
}

# Función para verificar la configuración del firewall
verify_firewall_configuration() {
    log_info "PASO 3: Verificación de Reglas de Firewall"
    log_info "---------------------------------------"

    # 1. Detectar tipo de firewall
    local firewall_type=""
    local firewall_errors=0
    local firewall_warnings=0

    # 1.1 Detectar firewall instalado
    log_info "3.1 Detectando tipo de firewall..."
    if command -v ufw >/dev/null; then
        firewall_type="ufw"
        log_info "- UFW (Uncomplicated Firewall) detectado"
    elif command -v firewalld >/dev/null; then
        firewall_type="firewalld"
        log_info "- FirewallD detectado"
    elif command -v iptables >/dev/null; then
        firewall_type="iptables"
        log_info "- IPTables detectado"
    else
        log_warning "No se detectó ningún firewall instalado"
        firewall_type="none"
    fi

    # 2. Verificar estado del firewall
    log_info "3.2 Verificando estado del firewall..."
    local firewall_status=""
    case "$firewall_type" in
        "ufw")
            if ufw status | grep -q "Status: active"; then
                firewall_status="active"
                log_info "- UFW está activo"
            else
                firewall_status="inactive"
                log_warning "- UFW está instalado pero inactivo"
                ((firewall_warnings++))
            fi
            ;;
        "firewalld")
            if systemctl is-active firewalld >/dev/null 2>&1; then
                firewall_status="active"
                log_info "- FirewallD está activo"
            else
                firewall_status="inactive"
                log_warning "- FirewallD está instalado pero inactivo"
                ((firewall_warnings++))
            fi
            ;;
        "iptables")
            if iptables -L >/dev/null 2>&1; then
                firewall_status="active"
                log_info "- IPTables está funcionando"
            else
                firewall_status="inactive"
                log_warning "- IPTables no está accesible"
                ((firewall_warnings++))
            fi
            ;;
        "none")
            firewall_status="none"
            log_warning "- No hay firewall configurado"
            ((firewall_warnings++))
            ;;
    esac

    # 3. Verificar reglas para puertos requeridos
    log_info "3.3 Verificando reglas para puertos requeridos..."
    local ports_checked=0
    local ports_missing=0

    for port in "${!REQUIRED_PORTS[@]}"; do
        local service_name="${REQUIRED_PORTS[$port]}"
        ((ports_checked++))
        log_info "- Verificando reglas para $service_name (puerto $port)..."

        local rule_exists=false
        case "$firewall_type" in
            "ufw")
                if ufw status | grep -qE "^$port/tcp.*ALLOW"; then
                    rule_exists=true
                fi
                ;;
            "firewalld")
                if firewall-cmd --list-ports | grep -q "$port/tcp"; then
                    rule_exists=true
                fi
                ;;
            "iptables")
                if iptables -L -n | grep -qE "tcp dpt:$port.*ACCEPT"; then
                    rule_exists=true
                fi
                ;;
        esac

        if [ "$rule_exists" = true ]; then
            log_success "  Puerto $port permitido en firewall"
        else
            log_warning "  No se encontró regla para el puerto $port"
            ((ports_missing++))
        fi
    done

    # 4. Verificar políticas por defecto
    log_info "3.4 Verificando políticas por defecto..."
    local default_policy=""
    case "$firewall_type" in
        "ufw")
            default_policy=$(ufw status verbose | grep "Default:" || echo "unknown")
            ;;
        "firewalld")
            default_policy=$(firewall-cmd --get-default-zone || echo "unknown")
            ;;
        "iptables")
            default_policy=$(iptables -L | grep "Chain INPUT" | awk '{print $4}' || echo "unknown")
            ;;
    esac
    log_info "- Política por defecto: $default_policy"

    # 5. Generar reporte
    {
        echo "=== Reporte de Verificación de Firewall ==="
        echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Tipo de Firewall: $firewall_type"
        echo "Estado: $firewall_status"
        echo "Política por defecto: $default_policy"
        echo "Puertos verificados: $ports_checked"
        echo "Puertos sin reglas: $ports_missing"
        echo "Advertencias: $firewall_warnings"
        echo "Errores: $firewall_errors"
        echo
        echo "=== Reglas Actuales ==="
        case "$firewall_type" in
            "ufw")
                ufw status verbose
                ;;
            "firewalld")
                firewall-cmd --list-all
                ;;
            "iptables")
                iptables -L -n
                ;;
        esac
    } >> "${LOGS_DIR}/firewall_check.log"

    # 6. Generar recomendaciones
    if [ $ports_missing -gt 0 ]; then
        log_info "3.5 Generando recomendaciones de configuración..."
        echo "=== Recomendaciones ===" >> "${LOGS_DIR}/firewall_check.log"

        case "$firewall_type" in
            "ufw")
                for port in "${!REQUIRED_PORTS[@]}"; do
                    local service_name="${REQUIRED_PORTS[$port]}"
                    echo "sudo ufw allow $port/tcp # $service_name" >> "${LOGS_DIR}/firewall_check.log"
                done
                ;;
            "firewalld")
                for port in "${!REQUIRED_PORTS[@]}"; do
                    local service_name="${REQUIRED_PORTS[$port]}"
                    echo "sudo firewall-cmd --permanent --add-port=$port/tcp # $service_name" >> "${LOGS_DIR}/firewall_check.log"
                done
                echo "sudo firewall-cmd --reload" >> "${LOGS_DIR}/firewall_check.log"
                ;;
            "iptables")
                for port in "${!REQUIRED_PORTS[@]}"; do
                    local service_name="${REQUIRED_PORTS[$port]}"
                    echo "sudo iptables -A INPUT -p tcp --dport $port -j ACCEPT # $service_name" >> "${LOGS_DIR}/firewall_check.log"
                done
                ;;
        esac
    fi

    # 7. Retornar resultado
    if [ $firewall_errors -gt 0 ]; then
        log_error "Se encontraron errores en la configuración del firewall"
        return 1
    elif [ $firewall_warnings -gt 0 ] || [ $ports_missing -gt 0 ]; then
        log_warning "Se encontraron advertencias en la configuración del firewall"
        log_info "Revise el reporte en ${LOGS_DIR}/firewall_check.log"
        return 0
    else
        log_success "Configuración de firewall verificada correctamente"
        return 0
    fi
}

# Función para realizar pruebas exhaustivas de conectividad
test_port_connectivity() {
    log_info "PASO 4: Pruebas de Conectividad de Puertos"
    log_info "----------------------------------------"

    local failed_tests=0
    local total_tests=0
    local start_time=$(date +%s)

    # 1. Preparar entorno para las pruebas
    log_info "4.1 Preparando entorno de pruebas..."
    local test_file="${LOGS_DIR}/port_connectivity_results.log"
    {
        echo "=== Pruebas de Conectividad de Puertos ==="
        echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Host: $(hostname)"
        echo "IP: $(hostname -I | awk '{print $1}')"
        echo
    } > "$test_file"

    # 2. Pruebas por cada puerto requerido
    log_info "4.2 Iniciando pruebas de conectividad..."

    for port in "${!REQUIRED_PORTS[@]}"; do
        local service_name="${REQUIRED_PORTS[$port]}"
        ((total_tests++))

        log_info "- Probando $service_name (puerto $port)..."
        echo "=== Puerto $port ($service_name) ===" >> "$test_file"

        # 2.1 Prueba básica de disponibilidad
        local is_available=true
        if is_port_active "$port"; then
            is_available=false
            log_warning "  Puerto $port está en uso"
            get_port_info "$port" >> "$test_file"
        fi

        # 2.2 Pruebas de conectividad local
        local connectivity_results=()
        local test_methods=(
            "netstat"
            "socket"
            "tcp_ping"
        )

        for method in "${test_methods[@]}"; do
            local test_result
            case "$method" in
                "netstat")
                    # Prueba usando netstat
                    if netstat -tuln | grep -q ":${port}[[:space:]]"; then
                        test_result="Puerto visible en netstat"
                        connectivity_results+=("$method: OCUPADO")
                    else
                        test_result="Puerto no visible en netstat"
                        connectivity_results+=("$method: DISPONIBLE")
                    fi
                    ;;
                "socket")
                    # Prueba usando redirección de bash
                    if timeout 1 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
                        test_result="Conexión TCP exitosa"
                        connectivity_results+=("$method: OCUPADO")
                    else
                        test_result="Conexión TCP fallida"
                        connectivity_results+=("$method: DISPONIBLE")
                    fi
                    ;;
                "tcp_ping")
                    # Prueba de latencia TCP
                    local start_ping=$(date +%s%N)
                    if timeout 1 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
                        local end_ping=$(date +%s%N)
                        local latency=$(( (end_ping - start_ping) / 1000000 ))
                        test_result="Latencia: ${latency}ms"
                    else
                        test_result="No responde"
                    fi
                    connectivity_results+=("$method: $test_result")
                    ;;
            esac
            echo "Método $method: $test_result" >> "$test_file"
        done

        # 2.3 Verificar consistencia de resultados
        local inconsistent=false
        local prev_result="${connectivity_results[0]#*: }"
        for result in "${connectivity_results[@]:1}"; do
            local current_result="${result#*: }"
            if [ "$current_result" != "$prev_result" ]; then
                inconsistent=true
                break
            fi
        done

        if $inconsistent; then
            log_warning "  Resultados inconsistentes en pruebas de puerto $port"
            echo "ADVERTENCIA: Resultados inconsistentes detectados" >> "$test_file"
            ((failed_tests++))
        fi

        # 2.4 Verificar latencia si el puerto está en uso
        if ! $is_available; then
            local latency_samples=()
            local samples=3
            local timeout_value=1

            log_info "  Midiendo latencia..."
            for ((i=1; i<=samples; i++)); do
                local start_time=$(date +%s%N)
                if timeout $timeout_value bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
                    local end_time=$(date +%s%N)
                    local latency=$(( (end_time - start_time) / 1000000 ))
                    latency_samples+=($latency)
                else
                    latency_samples+=(-1)
                fi
            done

            # Calcular promedio de latencia
            local total_latency=0
            local valid_samples=0
            for latency in "${latency_samples[@]}"; do
                if [ $latency -ge 0 ]; then
                    total_latency=$((total_latency + latency))
                    ((valid_samples++))
                fi
            done

            if [ $valid_samples -gt 0 ]; then
                local avg_latency=$((total_latency / valid_samples))
                echo "Latencia promedio: ${avg_latency}ms" >> "$test_file"
                if [ $avg_latency -gt 100 ]; then
                    log_warning "  Alta latencia detectada: ${avg_latency}ms"
                    ((failed_tests++))
                fi
            else
                echo "No se pudo medir la latencia" >> "$test_file"
                log_warning "  No se pudo medir la latencia"
                ((failed_tests++))
            fi
        fi

        echo >> "$test_file"
    done

    # 3. Resumen de resultados
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    {
        echo "=== Resumen de Pruebas ==="
        echo "Duración total: ${duration}s"
        echo "Pruebas realizadas: $total_tests"
        echo "Pruebas fallidas: $failed_tests"
        echo "Estado general: $([ $failed_tests -eq 0 ] && echo "EXITOSO" || echo "CON ERRORES")"
    } >> "$test_file"

    # 4. Retornar resultado
    if [ $failed_tests -gt 0 ]; then
        log_warning "Se encontraron $failed_tests pruebas fallidas"
        log_info "Consulte el reporte detallado en: $test_file"
        return 1
    else
        log_success "Todas las pruebas de conectividad completadas exitosamente"
        return 0
    fi
}

# Función principal del script
main() {
    log_header "Pre-Hook: Verificación de Disponibilidad de Puertos"
    log_info "================================================"

    # 1. Establecer el paso actual de provisión
    export PROVISION_STEP="port_availability"

    # 2. Definir pasos de verificación
    declare -A verification_steps=(
        ["validate_port_check_env"]="Validación del Entorno"
        ["check_service_conflicts"]="Verificación de Servicios Conflictivos"
        ["verify_firewall_configuration"]="Verificación de Firewall"
        ["test_port_connectivity"]="Pruebas de Conectividad"
    )

    # 3. Variables para seguimiento
    local total_steps=${#verification_steps[@]}
    local current_step=0
    local failed_steps=0
    local start_time=$(date +%s)
    local summary_file="${LOGS_DIR}/port_verification_summary.log"

    # 4. Iniciar registro de resumen
    {
        echo "=== Resumen de Verificación de Puertos ==="
        echo "Fecha de inicio: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Puertos requeridos:"
        for port in "${!REQUIRED_PORTS[@]}"; do
            echo "- Puerto $port: ${REQUIRED_PORTS[$port]}"
        done
        echo
    } > "$summary_file"

    # 5. Ejecutar cada paso de verificación
    for step_func in "${!verification_steps[@]}"; do
        ((current_step++))
        local step_name="${verification_steps[$step_func]}"
        local step_start_time=$(date +%s)

        # 5.1 Mostrar progreso
        log_info ""
        log_info "Paso $current_step de $total_steps: $step_name"
        log_info "----------------------------------------"

        # 5.2 Ejecutar paso
        if ! $step_func; then
            ((failed_steps++))
            {
                echo "=== Paso $current_step: $step_name ==="
                echo "Estado: FALLIDO"
                echo "Tiempo: $(($(date +%s) - step_start_time)) segundos"
                echo
            } >> "$summary_file"

            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                error_handle "Falló el paso: $step_name" ${ERROR_CODES["GENERAL_ERROR"]}
                {
                    echo "Verificación interrumpida por error en paso: $step_name"
                    echo "Tiempo total: $(($(date +%s) - start_time)) segundos"
                    echo "Estado final: ERROR CRÍTICO"
                } >> "$summary_file"
                return 1
            else
                log_warning "Continuando a pesar del error (PROVISION_CONTINUE_ON_ERROR=true)"
            fi
        else
            {
                echo "=== Paso $current_step: $step_name ==="
                echo "Estado: EXITOSO"
                echo "Tiempo: $(($(date +%s) - step_start_time)) segundos"
                echo
            } >> "$summary_file"
        fi

        # 5.3 Actualizar estado
        save_provision_state "port_verification_step_${current_step}"

        # 5.4 Mostrar progreso
        log_progress "$current_step" "$total_steps" "$step_name"
    done

    # 6. Generar resumen final
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    {
        echo "=== Resumen Final ==="
        echo "Fecha de finalización: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Duración total: ${total_duration} segundos"
        echo "Pasos totales: $total_steps"
        echo "Pasos fallidos: $failed_steps"
        echo
        echo "=== Estado de Puertos ==="
        for port in "${!REQUIRED_PORTS[@]}"; do
            local service_name="${REQUIRED_PORTS[$port]}"
            local port_info=$(get_port_info "$port")
            echo "Puerto $port ($service_name):"
            echo "$port_info"
            echo
        done

        if [ $failed_steps -gt 0 ]; then
            echo "=== Recomendaciones ==="
            echo "1. Revisar logs específicos en ${LOGS_DIR}/"
            echo "2. Verificar servicios conflictivos"
            echo "3. Comprobar reglas de firewall"
            echo "4. Validar configuración de red"
        fi
    } >> "$summary_file"

    # 7. Mostrar resultado final
    log_info ""
    if [ $failed_steps -eq 0 ]; then
        log_success "Verificación de puertos completada exitosamente"
        log_info "Tiempo total: ${total_duration} segundos"
        log_info "Resumen disponible en: $summary_file"
        return 0
    else
        log_warning "Verificación completada con advertencias ($failed_steps fallos)"
        log_info "Tiempo total: ${total_duration} segundos"
        log_info "Revise el resumen en: $summary_file"
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

    # 3. Ejecutar verificación
    main
    exit_code=$?

    # 4. Mostrar mensaje final
    if [ $exit_code -eq 0 ]; then
        log_success "Verificación de puertos completada exitosamente"
    else
        log_error "Verificación de puertos falló"
        if [ "$PROVISION_CONTINUE_ON_ERROR" == "true" ]; then
            log_warning "Continuando a pesar de los errores..."
            exit_code=0
        fi
    fi

    exit $exit_code
fi