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

# Verificar versión de software
# Uso: verify_software_version <comando> <versión_requerida> [patrón_versión] [descripción]
# Ejemplo:
#   verify_software_version "php" "8.1" "-v | head -n1" "PHP"
#   verify_software_version "mysql" "8.0" "--version" "MySQL Server"
verify_software_version() {
    local command="$1"
    local required_version="$2"
    local version_pattern="${3:---version}"
    local description="${4:-$command}"

    log_info "Verificando versión de $description..."

    # Verificar si el software está instalado
    if ! command -v "$command" >/dev/null; then
        log_error "$description no está instalado"
        return 1
    }

    # Obtener versión actual
    local current_version
    current_version=$($command $version_pattern 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "No se pudo determinar la versión de $description"
        return 1
    }

    # Verificar versión
    if [[ ! "$current_version" =~ $required_version ]]; then
        log_error "Versión de $description incorrecta"
        log_error "Esperada: $required_version"
        log_error "Actual: $current_version"
        return 1
    }

    log_success "Versión de $description correcta: $current_version"
    return 0
}

# Verificar extensiones/módulos de software
# Uso: verify_software_modules <comando> <módulos...> [comando_lista] [descripción]
# Ejemplo:
#   verify_software_modules "php" "mysqli pdo xml" "-m" "PHP"
#   verify_software_modules "apache2" "rewrite ssl" "-M" "Apache"
verify_software_modules() {
    local command="$1"
    local modules=("${@:2}")
    local list_command="${3:-}"
    local description="${4:-$command}"
    local missing=()
    local installed=()

    log_info "Verificando módulos de $description..."

    # Verificar si el software está instalado
    if ! command -v "$command" >/dev/null; then
        log_error "$description no está instalado"
        return 1
    }

    # Obtener lista de módulos
    local module_list
    if [ -n "$list_command" ]; then
        module_list=$($command $list_command 2>/dev/null)
    else
        module_list=$($command --help 2>/dev/null)
    fi

    # Verificar cada módulo
    for module in "${modules[@]}"; do
        if echo "$module_list" | grep -q "$module"; then
            installed+=("$module")
        else
            missing+=("$module")
        fi
    done

    # Mostrar resultados
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Módulos faltantes de $description: ${missing[*]}"
        return 1
    fi

    log_success "Todos los módulos requeridos de $description están instalados"
    return 0
}

# Verificar configuración de software
# Uso: verify_software_config <archivo_config> <directivas...>
# Ejemplo:
#   verify_software_config "/etc/php/8.1/fpm/php.ini" "memory_limit=256M" "max_execution_time=300"
#   verify_software_config "/etc/mysql/my.cnf" "max_connections=100"
verify_software_config() {
    local config_file="$1"
    shift
    local directives=("$@")
    local errors=0

    log_info "Verificando archivo de configuración: $config_file"

    # Verificar existencia del archivo
    if [ ! -f "$config_file" ]; then
        log_error "Archivo de configuración no encontrado: $config_file"
        return 1
    }

    # Verificar cada directiva
    for directive in "${directives[@]}"; do
        local key="${directive%%=*}"
        local value="${directive#*=}"

        if ! grep -q "^[[:space:]]*$key[[:space:]]*=[[:space:]]*$value" "$config_file"; then
            log_error "Directiva no encontrada o incorrecta: $key = $value"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        log_success "Todas las directivas verificadas correctamente"
        return 0
    else
        log_error "Se encontraron $errors errores en la configuración"
        return 1
    fi
}

# Verificar variables de entorno
# Uso: verify_environment_variables [modo] <variables...>
# Ejemplo:
#   verify_environment_variables "required" "PATH" "HOME" "USER"
#   verify_environment_variables "valued" "PATH=/usr/bin" "LANG=en_US.UTF-8"
verify_environment_variables() {
    local mode="${1:-required}"
    shift
    local variables=("$@")
    local errors=0

    log_info "Verificando variables de entorno..."

    case "$mode" in
        "required")
            # Verificar solo existencia
            for var in "${variables[@]}"; do
                if [ -z "${!var+x}" ]; then
                    log_error "Variable requerida no definida: $var"
                    ((errors++))
                fi
            done
            ;;
        "valued")
            # Verificar valor específico
            for var in "${variables[@]}"; do
                local key="${var%%=*}"
                local value="${var#*=}"
                if [ "${!key}" != "$value" ]; then
                    log_error "Variable $key tiene valor incorrecto"
                    log_error "Esperado: $value"
                    log_error "Actual: ${!key}"
                    ((errors++))
                fi
            done
            ;;
        *)
            log_error "Modo de verificación no válido: $mode"
            return 1
            ;;
    esac

    if [ $errors -eq 0 ]; then
        log_success "Todas las variables de entorno verificadas correctamente"
        return 0
    else
        log_error "Se encontraron $errors errores en las variables de entorno"
        return 1
    fi
}

# Verificar estado del entorno
# Uso: verify_environment_state <tipo_ambiente> <verificaciones...>
# Ejemplo:
#   verify_environment_state "production" "debug=false" "errors=log" "display_errors=0"
#   verify_environment_state "development" "debug=true" "errors=display"
verify_environment_state() {
    local env_type="$1"
    shift
    local checks=("$@")
    local errors=0

    log_info "Verificando estado del ambiente: $env_type"

    # Verificar cada condición del ambiente
    for check in "${checks[@]}"; do
        local key="${check%%=*}"
        local expected="${check#*=}"
        local actual

        # Intentar obtener valor actual según el tipo de verificación
        case "$key" in
            *_file)
                if [ ! -f "$expected" ]; then
                    log_error "Archivo requerido no existe: $expected"
                    ((errors++))
                fi
                ;;
            *_dir)
                if [ ! -d "$expected" ]; then
                    log_error "Directorio requerido no existe: $expected"
                    ((errors++))
                fi
                ;;
            *_permission)
                local path="${expected%%:*}"
                local perm="${expected#*:}"
                if ! verify_file_permission "$path" "$perm"; then
                    ((errors++))
                fi
                ;;
            *)
                if ! verify_environment_variables "valued" "${key}=${expected}"; then
                    ((errors++))
                fi
                ;;
        esac
    done

    if [ $errors -eq 0 ]; then
        log_success "Estado del ambiente $env_type verificado correctamente"
        return 0
    else
        log_error "Se encontraron $errors errores en el estado del ambiente"
        return 1
    fi
}

# Verificar requisitos del sistema de forma abstracta
# Uso: verify_system_condition <tipo> <condición> [args...]
# Tipos soportados: resource, version, state, limit
# Ejemplo:
#   verify_system_condition "resource" "memory" "1024" "MB"
#   verify_system_condition "version" "os" "Ubuntu" "22.04"
#   verify_system_condition "state" "load" "0.8"
#   verify_system_condition "limit" "nofile" "65535"
verify_system_condition() {
    local check_type="$1"
    local condition="$2"
    shift 2
    local args=("$@")

    case "$check_type" in
        "resource")
            case "$condition" in
                "memory")
                    local min_memory="${args[0]}"
                    local current_memory=$(get_total_memory)
                    if [ "$current_memory" -lt "$min_memory" ]; then
                        log_error "Memoria insuficiente: ${current_memory}${args[1]} (mínimo: ${min_memory}${args[1]})"
                        return 1
                    fi
                    ;;
                "cpu")
                    local min_cores="${args[0]}"
                    local current_cores=$(get_cpu_cores)
                    if [ "$current_cores" -lt "$min_cores" ]; then
                        log_error "Núcleos CPU insuficientes: $current_cores (mínimo: $min_cores)"
                        return 1
                    fi
                    ;;
                "disk")
                    local min_space="${args[0]}"
                    local mount_point="${args[1]:-/}"
                    if ! check_disk_space "$min_space" "$mount_point"; then
                        return 1
                    fi
                    ;;
                *)
                    log_error "Tipo de recurso no soportado: $condition"
                    return 1
                    ;;
            esac
            ;;
        "version")
            case "$condition" in
                "os")
                    local os_name="${args[0]}"
                    local os_version="${args[1]}"
                    if ! check_os_version "$os_name" "$os_version"; then
                        return 1
                    fi
                    ;;
                "kernel")
                    local min_version="${args[0]}"
                    local current_version=$(uname -r)
                    if ! verify_version "$current_version" "$min_version"; then
                        log_error "Versión de kernel no soportada: $current_version (mínimo: $min_version)"
                        return 1
                    fi
                    ;;
                *)
                    log_error "Tipo de versión no soportada: $condition"
                    return 1
                    ;;
            esac
            ;;
        "state")
            case "$condition" in
                "load")
                    local max_load="${args[0]}"
                    local current_load=$(get_load_average)
                    if (( $(echo "$current_load > $max_load" | bc -l) )); then
                        log_warning "Carga del sistema elevada: $current_load (máximo: $max_load)"
                        return 1
                    fi
                    ;;
                "throttling")
                    if ! check_cpu_throttling; then
                        log_warning "CPU en estado de throttling"
                        return 1
                    fi
                    ;;
                *)
                    log_error "Tipo de estado no soportado: $condition"
                    return 1
                    ;;
            esac
            ;;
        "limit")
            case "$condition" in
                "nofile"|"nproc"|"memlock")
                    local limit_value="${args[0]}"
                    if ! verify_system_limit "$condition" "$limit_value"; then
                        return 1
                    fi
                    ;;
                *)
                    log_error "Tipo de límite no soportado: $condition"
                    return 1
                    ;;
            esac
            ;;
        *)
            log_error "Tipo de verificación no soportado: $check_type"
            return 1
            ;;
    esac

    return 0
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