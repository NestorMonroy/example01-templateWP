#!/usr/bin/env bash
# Funciones básicas relacionadas con el sistema operativo

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
export DISK_SPACE=$(df -h / | awk 'NR==2 {print $4}')

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

# Obtener información del sistema operativo
get_os_info() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo "$NAME $VERSION"
    else
        uname -s
    fi
}

# Obtener memoria total
get_total_memory() {
    echo "$SYSTEM_MEMORY"
}

# Obtener espacio en disco
get_disk_space() {
    echo "$DISK_SPACE"
}

# Obtener número de cores CPU
get_cpu_cores() {
    echo "$CPU_CORES"
}

# Mostrar información completa del sistema
show_system_info() {
    log_header "Información del Sistema"

    log_info "Sistema Operativo: $(get_os_info)"
    log_info "Versión: $OS_VERSION ($OS_CODENAME)"
    log_info "Kernel: $(uname -r)"
    log_info "Arquitectura: $(uname -m)"
    log_info "Memoria Total: $(get_total_memory) MB"
    log_info "CPU Cores: $(get_cpu_cores)"
    log_info "Espacio en Disco: $(get_disk_space)"
    log_info "Hostname: $(hostname)"
    log_info "IP Principal: $(hostname -I | awk '{print $1}')"
}

# Verificar requisitos del ambiente
check_environment_requirements() {
    local min_disk="${1:-5}" # GB
    local min_memory="${2:-1024}" # MB
    local min_cores="${3:-1}"

    log_info "Verificando requisitos del ambiente..."

    # Verificar espacio en disco
    local disk_gb=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')
    if [ "$disk_gb" -lt "$min_disk" ]; then
        log_error "Espacio en disco insuficiente: ${disk_gb}GB (mínimo: ${min_disk}GB)"
        return 1
    fi

    # Verificar memoria
    if [ "$SYSTEM_MEMORY" -lt "$min_memory" ]; then
        log_error "Memoria RAM insuficiente: ${SYSTEM_MEMORY}MB (mínimo: ${min_memory}MB)"
        return 1
    fi

    # Verificar CPU cores
    if [ "$CPU_CORES" -lt "$min_cores" ]; then
        log_error "Núcleos CPU insuficientes: ${CPU_CORES} (mínimo: ${min_cores})"
        return 1
    fi

    # Verificar conectividad
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "No hay conexión a internet"
        return 1
    fi

    log_success "Todos los requisitos del ambiente cumplidos"
    return 0
}

# Verificar versión del sistema operativo
check_os_version() {
    local required_os="$1"
    local required_version="$2"

    if [ "$OS_NAME" != "$required_os" ]; then
        log_error "Sistema operativo incorrecto: $OS_NAME (requerido: $required_os)"
        return 1
    fi

    if [ "$OS_VERSION" != "$required_version" ]; then
        log_error "Versión incorrecta: $OS_VERSION (requerida: $required_version)"
        return 1
    fi

    log_success "Versión del sistema operativo correcta"
    return 0
}

# Obtener uso de CPU
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    echo "$cpu_usage"
}

# Obtener uso de memoria
get_memory_usage() {
    local memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    printf "%.2f" "$memory_usage"
}

# Obtener temperatura del sistema (si está disponible)
get_system_temperature() {
    if [ -x "$(command -v sensors)" ]; then
        sensors | grep "CPU Temperature" | awk '{print $3}'
    else
        echo "N/A"
    fi
}

# Verificar que estamos como root al cargar el módulo
check_root

# Exportar funciones
#export -f noroot
#export -f check_root
#export -f check_system_requirements
#export -f get_os_info
#export -f get_total_memory
#export -f get_disk_space
#export -f get_cpu_cores
#export -f show_system_info
#export -f check_environment_requirements
#export -f check_os_version
#export -f get_cpu_usage
#export -f get_memory_usage
#export -f get_system_temperature