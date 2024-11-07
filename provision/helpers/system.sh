#!/usr/bin/env bash
# Funciones básicas relacionadas con el sistema operativo
#
# Este script proporciona funciones para verificar y obtener información
# del sistema operativo, recursos del sistema y requisitos mínimos.
#
# Ejemplo de uso general:
#   source ./system.sh
#
#   # Verificar requisitos mínimos
#   check_system_requirements 1024 2
#
#   # Mostrar información del sistema
#   show_system_info
#
#   # Verificar ambiente
#   check_environment_requirements 10 2048 2

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables del sistema
# Estas variables se calculan una vez al cargar el script
export DEBIAN_FRONTEND=noninteractive                          # Evita prompts interactivos
export SYSTEM_MEMORY=$(free -m | awk '/^Mem:/{print $2}')     # Memoria total en MB
export CPU_CORES=$(nproc)                                     # Número de cores CPU
export OS_NAME=$(lsb_release -si)                            # Nombre del SO
export OS_VERSION=$(lsb_release -sr)                         # Versión del SO
export OS_CODENAME=$(lsb_release -sc)                        # Nombre código del SO
export DISK_SPACE=$(df -h / | awk 'NR==2 {print $4}')       # Espacio libre en disco

# Función para ejecutar comandos como usuario no root
# Uso: noroot <comando>
# Ejemplo:
#   noroot composer install
noroot() {
    sudo -EH -u "vagrant" "$@"
}

# Verificar si se está ejecutando como root
# Uso: check_root
# Ejemplo:
#   check_root || exit 1
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Verificar requisitos mínimos del sistema
# Uso: check_system_requirements [min_memory_mb] [min_cores]
# Ejemplo:
#   check_system_requirements 1024 2
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
# Uso: os_info=$(get_os_info)
# Ejemplo:
#   echo "Sistema operativo: $(get_os_info)"
get_os_info() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo "$NAME $VERSION"
    else
        uname -s
    fi
}

# Funciones para obtener recursos del sistema
# Uso: memoria=$(get_total_memory)
#      espacio=$(get_disk_space)
#      cores=$(get_cpu_cores)
get_total_memory() {
    echo "$SYSTEM_MEMORY"
}

get_disk_space() {
    echo "$DISK_SPACE"
}

get_cpu_cores() {
    echo "$CPU_CORES"
}

# Mostrar información completa del sistema
# Uso: show_system_info
# Ejemplo:
#   show_system_info > system_info.log
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
# Uso: check_environment_requirements [min_disk_gb] [min_memory_mb] [min_cores]
# Ejemplo:
#   check_environment_requirements 10 2048 2
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
# Uso: check_os_version <os_requerido> <version_requerida>
# Ejemplo:
#   check_os_version "Ubuntu" "20.04"
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

# Obtener métricas del sistema
# Uso:
#   cpu=$(get_cpu_usage)
#   memoria=$(get_memory_usage)
#   temp=$(get_system_temperature)
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    echo "$cpu_usage"
}

get_memory_usage() {
    local memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    printf "%.2f" "$memory_usage"
}

get_system_temperature() {
    if [ -x "$(command -v sensors)" ]; then
        sensors | grep "CPU Temperature" | awk '{print $3}'
    else
        echo "N/A"
    fi
}

# Ejemplo de uso completo del script
: '
# Verificar permisos y requisitos básicos
check_root
check_system_requirements 2048 2

# Mostrar información del sistema
show_system_info

# Verificar ambiente específico
check_environment_requirements 20 4096 4

# Verificar versión específica de SO
check_os_version "Ubuntu" "20.04"

# Monitorear recursos
while true; do
    echo "CPU Usage: $(get_cpu_usage)%"
    echo "Memory Usage: $(get_memory_usage)%"
    echo "Temperature: $(get_system_temperature)"
    sleep 5
done
'

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