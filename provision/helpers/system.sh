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
# Obtener memoria disponible en MB
# Uso: memoria_disponible=$(get_available_memory)
# Ejemplo:
#   echo "Memoria disponible: $(get_available_memory) MB"
get_available_memory() {
    free -m | awk '/^Mem:/ {print $7}'
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
# Modificar la función existente get_cpu_usage para mayor precisión
get_cpu_usage() {
    local cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1)
    echo $((100 - cpu_idle))
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

# Obtener modelo de CPU
# Uso: modelo=$(get_cpu_model)
# Ejemplo:
#   echo "Modelo de CPU: $(get_cpu_model)"
get_cpu_model() {
    grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//'
}

# Obtener velocidad de CPU en MHz
# Uso: velocidad=$(get_cpu_speed)
# Ejemplo:
#   echo "Velocidad de CPU: $(get_cpu_speed) MHz"
get_cpu_speed() {
    grep "cpu MHz" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//' | cut -d. -f1
}

# Verifica el estado de throttling del CPU mediante sensores térmicos
# Retorna diferentes códigos según el resultado.
# Esta función comprueba si el CPU está experimentando throttling debido a altas temperaturas
# monitoreando los sensores térmicos del sistema.
#
# Uso: check_cpu_throttling
#      Códigos de retorno:
#      0 - Se detectó throttling (temperatura > 80°C)
#      1 - No hay throttling (temperatura normal)
#      2 - No se puede verificar (sensores no disponibles o error de lectura)
#
# Ejemplo:
#   check_cpu_throttling
#   case $? in
#       0) echo "¡Advertencia! CPU en throttling" ;;
#       1) echo "Temperatura CPU normal" ;;
#       2) echo "No se puede verificar temperatura" ;;
#   esac
check_cpu_throttling() {
    # 1. Verifica si existen los sensores
    if [ ! -d "/sys/class/thermal/thermal_zone0" ]; then
        log_warning "No se detectaron sensores térmicos en el sistema"
        return 2  # Código especial: no hay sensores
    fi

    # 2. Verifica si se puede acceder al archivo de temperatura
    local temp_file="/sys/class/thermal/thermal_zone0/temp"
    if [ ! -f "$temp_file" ] || [ ! -r "$temp_file" ]; then
        log_warning "No se puede acceder al sensor de temperatura"
        return 2
    fi

    # 3. Intenta leer la temperatura
    local temp=$(cat "$temp_file" 2>/dev/null)
    if [ -z "$temp" ]; then
        log_warning "No se pudo leer la temperatura del CPU"
        return 1
    fi

    # 4. Procesa y verifica la temperatura
    temp=$((temp/1000))
    if [ "$temp" -gt 80 ]; then
        log_warning "Temperatura CPU elevada: ${temp}°C"
        return 0  # Hay throttling
    fi

    return 1  # No hay throttling
}

# Obtener carga promedio del sistema
# Uso: carga=$(get_load_average)
# Ejemplo:
#   echo "Carga del sistema: $(get_load_average)"
get_load_average() {
    cut -d ' ' -f1 /proc/loadavg
}

# Función para verificar sistema init
# Uso: system_check_init
# Retorna:
#   0 - Si systemd es el init system
#   1 - Si hay otro init system
#   2 - Si no se puede determinar
# Ejemplo:
#   if system_check_init; then
#       echo "systemd es el init system"
#   fi
system_check_init() {
    log_info "Verificando sistema init..."

    # Verificar proceso PID 1
    local init_process
    init_process=$(ps --no-headers -o comm 1)
    if [ -z "$init_process" ]; then
        log_error "No se pudo determinar el sistema init"
        return 2
    }

    # Verificar si es systemd
    if [ "$init_process" = "systemd" ]; then
        # Obtener versión de systemd
        local systemd_version
        systemd_version=$(systemctl --version | head -n1 | awk '{print $2}')
        log_success "systemd detectado (versión $systemd_version)"
        return 0
    else
        log_warning "Sistema init detectado: $init_process"
        return 1
    fi
}

# Función para obtener archivo de unidad systemd
# Uso: system_get_unit_file <nombre_unidad>
# Retorna: Ruta al archivo de unidad o error si no existe
# Ejemplo:
#   unit_file=$(system_get_unit_file "nginx.service")
#   if [ $? -eq 0 ]; then
#       echo "Archivo de unidad: $unit_file"
#   fi
system_get_unit_file() {
    local unit_name="$1"

    log_info "Buscando archivo de unidad para $unit_name..."

    # Verificar que se proporcionó un nombre de unidad
    if [ -z "$unit_name" ]; then
        log_error "Nombre de unidad no especificado"
        return 1
    }

    # Asegurar que tiene extensión .service
    if [[ ! "$unit_name" =~ \.service$ ]]; then
        unit_name="${unit_name}.service"
    fi

    # Buscar el archivo de unidad
    local unit_file
    unit_file=$(systemctl show -p FragmentPath --value "$unit_name" 2>/dev/null)

    if [ -z "$unit_file" ] || [ ! -f "$unit_file" ]; then
        log_error "Archivo de unidad no encontrado para $unit_name"
        return 1
    fi

    echo "$unit_file"
    log_success "Archivo de unidad encontrado: $unit_file"
    return 0
}

# Función para verificación completa de systemd
# Uso: system_verify_systemd
# Retorna:
#   0 - systemd está funcionando correctamente
#   1 - Hay problemas con systemd
# Ejemplo:
#   if system_verify_systemd; then
#       echo "systemd está en buen estado"
#   fi
system_verify_systemd() {
    log_info "Realizando verificación completa de systemd..."
    local issues_found=0

    # 1. Verificar que systemd es el init system
    if ! system_check_init; then
        log_error "systemd no es el sistema init"
        return 1
    fi

    # 2. Verificar estado del sistema
    local system_state
    system_state=$(systemctl is-system-running)
    log_info "Estado del sistema: $system_state"

    case "$system_state" in
        "running")
            log_success "Sistema funcionando normalmente"
            ;;
        "degraded")
            log_warning "Sistema en estado degradado"
            ((issues_found++))
            ;;
        "maintenance")
            log_error "Sistema en modo mantenimiento"
            ((issues_found++))
            ;;
        *)
            log_error "Estado del sistema desconocido: $system_state"
            ((issues_found++))
            ;;
    esac

    # 3. Verificar el journal
    if ! journalctl --verify >/dev/null 2>&1; then
        log_warning "Se encontraron problemas en el journal"
        ((issues_found++))
    fi

    # 4. Verificar servicios esenciales de systemd
    local essential_services=(
        "systemd-journald.service"
        "systemd-logind.service"
        "systemd-udevd.service"
    )

    for service in "${essential_services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            log_warning "Servicio esencial inactivo: $service"
            ((issues_found++))
        fi
    done

    # 5. Verificar tiempo de arranque
    local boot_time
    boot_time=$(systemd-analyze time 2>/dev/null)
    if [ $? -eq 0 ]; then
        log_info "Tiempo de arranque: $boot_time"
    else
        log_warning "No se pudo obtener el tiempo de arranque"
        ((issues_found++))
    fi

    # 6. Verificar espacio del journal
    local journal_size
    journal_size=$(journalctl --disk-usage | cut -d' ' -f7-)
    log_info "Tamaño del journal: $journal_size"

    # Resultado final
    if [ $issues_found -eq 0 ]; then
        log_success "Verificación de systemd completada sin problemas"
        return 0
    else
        log_warning "Se encontraron $issues_found problemas en systemd"
        return 1
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
#export -f get_available_memory
#export -f get_cpu_model
#export -f get_cpu_speed
#export -f check_cpu_throttling
#export -f get_load_average
#export -f system_check_init
#export -f system_get_unit_file
#export -f system_verify_systemd