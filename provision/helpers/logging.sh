#!/usr/bin/env bash
# Funciones de logging y formato de salida

# Asegurarse de que los colores estén disponibles
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Timestamp para logs
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Niveles de log
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["NOTICE"]=2
    ["WARNING"]=3
    ["ERROR"]=4
    ["CRITICAL"]=5
)

# Colores por nivel de log
declare -A LOG_COLORS=(
    ["DEBUG"]="${DEBUG_COLOR}"
    ["INFO"]="${INFO_COLOR}"
    ["NOTICE"]="${NOTICE_COLOR}"
    ["WARNING"]="${WARNING_COLOR}"
    ["ERROR"]="${ERROR_COLOR}"
    ["CRITICAL"]="${ERROR_COLOR}${BOLD}"
)

# Nivel de log actual (puede modificarse en tiempo de ejecución)
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-1} # Default a INFO

# Archivo de log actual
CURRENT_LOG_FILE=""

# Función para formatear la salida con tags
format_output() {
    declare -A TAGS=(
        ['<b>']="${BOLD}"
        ['</b>']="${UNBOLD}"
        ['<dim>']="${DIM}"
        ['</dim>']="${UNDIM}"
        ['<i>']="${ITALIC}"
        ['</i>']="${UNITALIC}"
        ['<u>']="${UNDERLINE}"
        ['</u>']="${NOUNDERLINE}"
        ['<info>']="${INFO_COLOR}"
        ['</info>']="${CRESET}"
        ['<success>']="${SUCCESS_COLOR}"
        ['</success>']="${CRESET}"
        ['<warn>']="${WARNING_COLOR}"
        ['</warn>']="${CRESET}"
        ['<error>']="${ERROR_COLOR}"
        ['</error>']="${CRESET}"
        ['<notice>']="${NOTICE_COLOR}"
        ['</notice>']="${CRESET}"
        ['<debug>']="${DEBUG_COLOR}"
        ['</debug>']="${CRESET}"
        ['<url>']="${URL_COLOR}"
        ['</url>']="${CRESET}"
        ['</>']="${CRESET}"
    )

    local MSG="${1}</>"
    for TAG in "${!TAGS[@]}"; do
        local VAL="${TAGS[$TAG]}"
        MSG="${MSG//"${TAG}"/"${VAL}"}"
    done
    echo -e "${MSG}"
}

# Función base para logging
log_base() {
    local level="$1"
    local message="$2"
    local color="${LOG_COLORS[$level]}"

    # Verificar si el nivel es válido
    if [ -z "${LOG_LEVELS[$level]}" ]; then
        echo "Nivel de log inválido: $level"
        return 1
    }

    # Verificar nivel de log
    if [ "${LOG_LEVELS[$level]}" -ge "$CURRENT_LOG_LEVEL" ]; then
        local timestamp
        timestamp=$(get_timestamp)
        local formatted_message

        # Formatear mensaje según el nivel
        case "$level" in
            "DEBUG")
                formatted_message="<debug>${message}</debug>"
                ;;
            "INFO")
                formatted_message="<info>${message}</info>"
                ;;
            "NOTICE")
                formatted_message="<notice>${message}</notice>"
                ;;
            "WARNING")
                formatted_message="<warn>${message}</warn>"
                ;;
            "ERROR")
                formatted_message="<error>${message}</error>"
                ;;
            "CRITICAL")
                formatted_message="<error><b>${message}</b></error>"
                ;;
        esac

        # Formatear mensaje final
        formatted_message=$(format_output "${formatted_message}")

        # Imprimir a stdout
        echo -e "[${timestamp}] ${level}: ${formatted_message}"

        # Si hay un archivo de log definido, escribir sin formato
        if [ -n "$CURRENT_LOG_FILE" ]; then
            echo "[${timestamp}] ${level}: ${message}" >> "$CURRENT_LOG_FILE"
        fi
    fi
}

# Funciones específicas para cada nivel de log
log_debug() {
    log_base "DEBUG" "$1"
}

log_info() {
    log_base "INFO" "$1"
}

log_notice() {
    log_base "NOTICE" "$1"
}

log_warning() {
    log_base "WARNING" "$1"
}

log_error() {
    log_base "ERROR" "$1"
}

log_critical() {
    log_base "CRITICAL" "$1"
}

# Función para configurar archivo de log
set_log_file() {
    local log_file="$1"
    local log_dir
    log_dir=$(dirname "$log_file")

    # Crear directorio si no existe
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi

    # Verificar si podemos escribir
    if touch "$log_file" 2>/dev/null; then
        CURRENT_LOG_FILE="$log_file"
        log_info "Archivo de log establecido: $log_file"
    else
        log_error "No se puede escribir en el archivo de log: $log_file"
        return 1
    fi
}

# Función para configurar nivel de log
set_log_level() {
    local level="$1"
    if [[ -n "${LOG_LEVELS[$level]}" ]]; then
        CURRENT_LOG_LEVEL="${LOG_LEVELS[$level]}"
        log_info "Nivel de log establecido a: $level (${LOG_LEVELS[$level]})"
    else
        log_error "Nivel de log inválido: $level"
        return 1
    fi
}



# Función para imprimir una línea separadora
log_separator() {
    local char="${1:-"-"}"
    local length="${2:-80}"
    printf '%*s\n' "$length" | tr ' ' "$char"
}

# Función para imprimir un encabezado
log_header() {
    local title="$1"
    local char="${2:-"="}"
    local length="${3:-80}"

    echo
    log_separator "$char" "$length"
    echo -e "${BOLD}${title}${CRESET}"
    log_separator "$char" "$length"
    echo
}

# Función para ejecutar y loguear comandos
log_command() {
    local cmd="$1"
    local description="${2:-$cmd}"
    local output
    local status

    log_info "Ejecutando: $description"
    log_debug "Comando: $cmd"

    # Ejecutar comando y capturar salida y estado
    output=$($cmd 2>&1)
    status=$?

    if [ $status -ne 0 ]; then
        log_error "Comando falló con estado $status"
        log_error "Salida del comando:"
        log_error "$output"
        return $status
    else
        log_debug "Comando ejecutado exitosamente"
        log_debug "Salida del comando:"
        log_debug "$output"
        return 0
    fi
}

# Función para manejar errores
handle_error() {
    local message="$1"
    local exit_code="${2:-1}"
    local line_number="${3:-$LINENO}"

    # Obtener stack trace
    local stack=""
    local frame=0

    while caller $frame > /dev/null; do
        local trace
        trace="$(caller $frame)"
        stack+="  en línea ${trace%% *} de ${trace##* }\n"
        ((frame++))
    done

    # Loguear error con detalles
    log_critical "$message"
    log_error "Stack trace:"
    log_error "$stack"
    log_error "Código de salida: $exit_code"

    # Si se especifica un código de salida, terminar el script
    if [ $exit_code -ne 0 ]; then
        exit "$exit_code"
    fi
}

# Función para manejar errores de manera silenciosa
silent_error() {
    local message="$1"
    local exit_code="${2:-1}"

    log_error "$message"
    return $exit_code
}

# Función para ejecutar comando con retry
retry_command() {
    local cmd="$1"
    local description="${2:-$cmd}"
    local max_attempts="${3:-3}"
    local wait_time="${4:-5}"
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log_info "Intento $attempt de $max_attempts: $description"

        if log_command "$cmd" "$description"; then
            return 0
        fi

        attempt=$((attempt + 1))

        if [ $attempt -le $max_attempts ]; then
            warning "Reintentando en $wait_time segundos..."
            sleep "$wait_time"
        fi
    done

    log_error "El comando falló después de $max_attempts intentos"
    return 1
}

# Inicializar logging si no está inicializado
if [ -z "$LOG_INITIALIZED" ]; then
    # Configurar manejador de errores por defecto
    trap 'handle_error "Se produjo un error no manejado" $? $LINENO' ERR

    # Establecer nivel de log por defecto
    set_log_level "INFO"

    # Marcar como inicializado
    LOG_INITIALIZED=1

    log_debug "Sistema de logging inicializado"
fi

