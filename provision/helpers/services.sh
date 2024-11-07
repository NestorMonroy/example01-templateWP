#!/usr/bin/env bash
# Gestión de servicios, procesos y puertos

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Gestión de servicios
service_exists() {
    local service_name="$1"
    systemctl list-unit-files | grep -q "^$service_name\.service"
}

service_is_running() {
    local service_name="$1"
    systemctl is-active --quiet "$service_name"
}

service_is_enabled() {
    local service_name="$1"
    systemctl is-enabled --quiet "$service_name"
}

service_control() {
    local action="$1"
    local service="$2"
    local description="${3:-$service}"

    log_info "Service $action: $description"

    if ! service_exists "$service"; then
        log_error "Servicio $service no encontrado"
        return 1
    fi

    case "$action" in
        start)
            systemctl start "$service"
            ;;
        stop)
            systemctl stop "$service"
            ;;
        restart)
            systemctl restart "$service"
            ;;
        reload)
            systemctl reload "$service"
            ;;
        enable)
            systemctl enable "$service"
            ;;
        disable)
            systemctl disable "$service"
            ;;
        status)
            systemctl status "$service"
            ;;
        *)
            log_error "Acción desconocida: $action"
            return 1
            ;;
    esac

    if [ $? -ne 0 ]; then
        log_error "Error al $action servicio $description"
        return 1
    fi

    log_success "$description $action completado"
    return 0
}

# Gestión de procesos
process_is_running() {
    local process_name="$1"
    pgrep -f "$process_name" >/dev/null
}

kill_process() {
    local process_name="$1"
    local signal="${2:-TERM}"
    local timeout="${3:-10}"

    if process_is_running "$process_name"; then
        log_info "Terminando proceso: $process_name con señal $signal"

        # Intentar terminar el proceso
        pkill "-$signal" -f "$process_name"

        # Esperar a que termine
        local counter=0
        while process_is_running "$process_name" && [ $counter -lt $timeout ]; do
            sleep 1
            counter=$((counter + 1))
        done

        # Si aún está corriendo después del timeout, usar SIGKILL
        if process_is_running "$process_name"; then
            log_warning "Forzando terminación con SIGKILL"
            pkill -9 -f "$process_name"
            sleep 1
        fi

        if process_is_running "$process_name"; then
            log_error "No se pudo terminar el proceso: $process_name"
            return 1
        fi

        log_success "Proceso terminado: $process_name"
        return 0
    fi

    log_info "Proceso no encontrado: $process_name"
    return 0
}

# Gestión de puertos
port_is_open() {
    local port="$1"
    local protocol="${2:-tcp}"

    case "$protocol" in
        tcp)
            netstat -tuln | grep -q ":${port} "
            ;;
        udp)
            netstat -uln | grep -q ":${port} "
            ;;
        *)
            log_error "Protocolo no soportado: $protocol"
            return 1
            ;;
    esac
}

is_port_in_use() {
    local port="$1"
    local protocol="${2:-tcp}"

    if port_is_open "$port" "$protocol"; then
        log_warning "Puerto $port ($protocol) está en uso"
        return 0
    else
        log_info "Puerto $port ($protocol) está disponible"
        return 1
    fi
}

find_next_available_port() {
    local start_port="$1"
    local end_port="${2:-65535}"
    local protocol="${3:-tcp}"

    log_info "Buscando puerto disponible desde $start_port hasta $end_port..."

    for port in $(seq "$start_port" "$end_port"); do
        if ! is_port_in_use "$port" "$protocol"; then
            log_success "Puerto disponible encontrado: $port"
            echo "$port"
            return 0
        fi
    done

    log_error "No se encontraron puertos disponibles entre $start_port y $end_port"
    return 1
}

wait_for_port() {
    local port="$1"
    local host="${2:-localhost}"
    local timeout="${3:-30}"
    local protocol="${4:-tcp}"
    local description="${5:-$host:$port}"

    log_info "Esperando que $description esté disponible..."

    local counter=0
    while ! port_is_open "$port" "$protocol"; do
        counter=$((counter + 1))
        if [ "$counter" -ge "$timeout" ]; then
            log_error "Timeout esperando por $description"
            return 1
        fi
        sleep 1
        echo -n "."
    done
    echo ""

    log_success "$description está disponible"
    return 0
}

# Función para verificar dependencias de servicios
check_service_dependencies() {
    local service="$1"
    local deps

    deps=$(systemctl list-dependencies "$service" --no-pager | grep "^●" | cut -d" " -f2)

    for dep in $deps; do
        if ! service_is_running "$dep"; then
            log_error "Dependencia no está corriendo: $dep"
            return 1
        fi
    done

    return 0
}

# Exportar funciones
#export -f service_exists
#export -f service_is_running
#export -f service_is_enabled
#export -f service_control
#export -f process_is_running
#export -f kill_process
#export -f port_is_open
#export -f is_port_in_use
#export -f find_next_available_port
#export -f wait_for_port
#export -f check_service_dependencies