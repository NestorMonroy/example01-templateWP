#!/usr/bin/env bash
# Funciones relacionadas con el sistema operativo y servicios

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables del sistema
export DEBIAN_FRONTEND=noninteractive
export SYSTEM_MEMORY=$(free -m | awk '/^Mem:/{print $2}')
export CPU_CORES=$(nproc)
export OS_NAME=$(lsb_release -si)
export OS_VERSION=$(lsb_release -sr)
export OS_CODENAME=$(lsb_release -sc)

# Función para ejecutar como no root
noroot() {
    sudo -EH -u "vagrant" "$@"
}

# Verificar si se está ejecutando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Verificar requisitos mínimos del sistema
check_system_requirements() {
    local min_memory="${1:-512}" # MB
    local min_cores="${2:-1}"

    log_info "Verificando requisitos del sistema..."

    if [ "$SYSTEM_MEMORY" -lt "$min_memory" ]; then
        log_error "Memoria insuficiente: ${SYSTEM_MEMORY}MB (mínimo: ${min_memory}MB)"
        return 1
    fi

    if [ "$CPU_CORES" -lt "$min_cores" ]; then
        log_error "Núcleos CPU insuficientes: ${CPU_CORES} (mínimo: ${min_cores})"
        return 1
    fi

    log_success "Requisitos del sistema cumplidos"
    return 0
}

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

    if process_is_running "$process_name"; then
        log_info "Matando proceso: $process_name con señal $signal"
        pkill "-$signal" -f "$process_name"
        return $?
    fi
    return 0
}

# Gestión de puertos
port_is_open() {
    local port="$1"
    local protocol="${2:-tcp}"
    netstat -tuln | grep -q ":$port "
}

wait_for_port() {
    local port="$1"
    local timeout="${2:-30}"
    local description="${3:-port $port}"

    log_info "Esperando que $description esté disponible..."

    local counter=0
    while ! port_is_open "$port"; do
        counter=$((counter + 1))
        if [ "$counter" -ge "$timeout" ]; then
            log_error "Timeout esperando por $description"
            return 1
        fi
        sleep 1
    done

    log_success "$description está disponible"
    return 0
}

# Información del sistema
get_system_info() {
    local info=""
    info+="Sistema Operativo: $OS_NAME $OS_VERSION ($OS_CODENAME)\n"
    info+="Memoria Total: $SYSTEM_MEMORY MB\n"
    info+="CPU Cores: $CPU_CORES\n"
    info+="Kernel: $(uname -r)\n"
    info+="Hostname: $(hostname)\n"
    info+="IP Address: $(hostname -I | cut -d' ' -f1)\n"
    echo -e "$info"
}

# Gestión de tiempo de sistema
set_timezone() {
    local timezone="${1:-UTC}"
    if [ -f "/usr/share/zoneinfo/$timezone" ]; then
        log_info "Configurando zona horaria a $timezone"
        ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
        dpkg-reconfigure -f noninteractive tzdata
        log_success "Zona horaria configurada a $timezone"
        return 0
    else
        log_error "Zona horaria $timezone no válida"
        return 1
    fi
}

# Gestión de límites del sistema
set_system_limits() {
    local limit_file="/etc/security/limits.conf"
    local nofile_soft="${1:-65535}"
    local nofile_hard="${2:-65535}"

    log_info "Configurando límites del sistema..."

    # Hacer backup del archivo original
    if [ ! -f "${limit_file}.orig" ]; then
        cp "$limit_file" "${limit_file}.orig"
    fi

    # Configurar límites
    cat >> "$limit_file" << EOF
* soft nofile $nofile_soft
* hard nofile $nofile_hard
EOF

    log_success "Límites del sistema configurados"
    return 0
}

# Gestión de memoria virtual
set_swap() {
    local size="${1:-1024}" # MB
    local swapfile="/swapfile"

    if [ -f "$swapfile" ]; then
        log_warning "Archivo swap ya existe"
        return 0
    fi

    log_info "Creando archivo swap de ${size}MB..."

    # Crear archivo swap
    dd if=/dev/zero of="$swapfile" bs=1M count="$size"
    chmod 600 "$swapfile"
    mkswap "$swapfile"
    swapon "$swapfile"

    # Hacer permanente
    echo "$swapfile none swap sw 0 0" >> /etc/fstab

    log_success "Swap configurado correctamente"
    return 0
}

# Verificar que estamos como root al cargar el módulo
check_root