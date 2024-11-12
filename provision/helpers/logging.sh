#!/usr/bin/env bash
# Funciones de logging y formato de salida
#
# Este módulo proporciona un sistema completo de logging con soporte para:
# - Múltiples niveles de log (DEBUG, INFO, NOTICE, WARNING, ERROR, CRITICAL)
# - Salida coloreada en terminal
# - Salida a archivo
# - Formateo con tags
# - Timestamps
# - Progreso de operaciones
# - Logs específicos para backup
#
# Ejemplo de uso básico:
#   source ./logging.sh
#
#   set_log_file "/var/log/provision.log"
#   set_log_level "DEBUG"
#
#   log_info "Iniciando proceso"
#   log_debug "Variables: $VARS"
#   log_error "Algo falló"

# Asegurarse de que los colores estén disponibles
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Función para obtener timestamp actual con milisegundos
# Uso: timestamp=$(get_log_timestamp)
get_log_timestamp() {
    date "+%Y-%m-%d %H:%M:%S.%3N"
}

# Niveles de log disponibles y sus valores numéricos
# Menor número = más detallado
declare -A LOG_LEVELS=(
    ["DEBUG"]=0      # Información detallada para debugging
    ["INFO"]=1       # Información general (default)
    ["NOTICE"]=2     # Notificaciones importantes
    ["WARNING"]=3    # Advertencias
    ["ERROR"]=4      # Errores
    ["CRITICAL"]=5   # Errores críticos
    ["BACKUP"]=6     # Logs específicos de backup
)

# Colores asociados a cada nivel de log
declare -A LOG_COLORS=(
    ["DEBUG"]="${DEBUG_COLOR}"
    ["INFO"]="${INFO_COLOR}"
    ["NOTICE"]="${NOTICE_COLOR}"
    ["WARNING"]="${WARNING_COLOR}"
    ["ERROR"]="${ERROR_COLOR}"
    ["CRITICAL"]="${ERROR_COLOR}${BOLD}"
    ["BACKUP"]="${CYAN}${BOLD}"
)

# Nivel de log actual
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-1} # Default a INFO

# Archivo de log actual
CURRENT_LOG_FILE=""

# Variables para control de progreso
LOG_PROGRESS_CHAR="="
LOG_PROGRESS_WIDTH=50
LOG_LAST_PROGRESS_LENGTH=0

# Función para logging específico de backup
# Uso: log_backup <mensaje>
# Ejemplo: log_backup "Iniciando backup de archivos"
log_backup() {
    local message="$1"
    log_base "BACKUP" "$message"
}

# Función para mostrar barra de progreso en log
# Uso: log_show_progress <actual> <total> [mensaje]
# Ejemplo: log_show_progress 45 100 "Copiando archivos"
log_show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-}"
    local percentage=$((current * 100 / total))
    local progress=$((percentage * LOG_PROGRESS_WIDTH / 100))

    # Crear barra de progreso
    local bar=""
    for ((i=0; i<LOG_PROGRESS_WIDTH; i++)); do
        if [ $i -lt $progress ]; then
            bar+="$LOG_PROGRESS_CHAR"
        else
            bar+=" "
        fi
    done

    # Construir línea de progreso
    local progress_line="[${bar}] ${percentage}%"
    if [ -n "$message" ]; then
        progress_line+=" $message"
    fi

    # Calcular longitud para limpiar línea anterior
    local line_length=${#progress_line}
    if [ $line_length -lt $LOG_LAST_PROGRESS_LENGTH ]; then
        # Limpiar caracteres restantes de la línea anterior
        printf "%${LOG_LAST_PROGRESS_LENGTH}s\r" " "
    fi
    LOG_LAST_PROGRESS_LENGTH=$line_length

    # Mostrar progreso
    printf "\r${progress_line}"

    # Si llegamos al 100%, agregar nueva línea
    if [ $percentage -eq 100 ]; then
        echo
        LOG_LAST_PROGRESS_LENGTH=0
    fi
}


# Función para logging con progreso
# Uso: log_progress <actual> <total> <mensaje>
# Ejemplo: log_progress 50 100 "Procesando archivos"
log_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    local percentage=$((current * 100 / total))

    # Mostrar barra de progreso en stdout
    show_progress "$current" "$total" "$message"

    # Registrar en archivo de log si está configurado
    if [ -n "$CURRENT_LOG_FILE" ]; then
        echo "[$(get_log_timestamp)] PROGRESS: ($percentage%) $message" >> "$CURRENT_LOG_FILE"
    fi
}

# Función para iniciar logging de operación larga
# Uso: log_start_operation <mensaje>
# Ejemplo: log_start_operation "Copiando archivos grandes"
log_start_operation() {
    local message="$1"
    echo -n "[$(get_log_timestamp)] $message... "
}

# Función para finalizar logging de operación larga
# Uso: log_end_operation <estado>
# Ejemplo: log_end_operation "OK"
log_end_operation() {
    local status="$1"
    echo "$status"
}

# Función para formatear la salida con tags
# Uso: log_format_output "<b>texto</b> <error>error</error>"
# Tags disponibles:
#   <b> - Negrita
#   <i> - Itálica
#   <u> - Subrayado
#   <dim> - Atenuado
#   <info> - Color info
#   <success> - Color éxito
#   <warn> - Color advertencia
#   <error> - Color error
#   <notice> - Color noticia
#   <debug> - Color debug
#   <url> - Color URL
#   </> - Reset
log_format_output() {
    local MSG="${1}</>"

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
        ['<progress>']="${CYAN}"
        ['</progress>']="${CRESET}"
    )

    for TAG in "${!TAGS[@]}"; do
        local VAL="${TAGS[$TAG]}"
        MSG="${MSG//"${TAG}"/"${VAL}"}"
    done
    echo -e "${MSG}"
}

# Función base para logging
# Uso interno: log_base <nivel> <mensaje>
# Ejemplo: log_base "INFO" "Mensaje"
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
        timestamp=$(get_log_timestamp)
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
           "BACKUP")
                formatted_message="<notice>[BACKUP] ${message}</notice>"
                ;;
        esac

        # Formatear mensaje final
        formatted_message=$(log_format_output "${formatted_message}")

        # Imprimir a stdout
        echo -e "[${timestamp}] ${level}: ${formatted_message}"

        # Si hay un archivo de log definido, escribir sin formato
        if [ -n "$CURRENT_LOG_FILE" ]; then
            echo "[${timestamp}] ${level}: ${message}" >> "$CURRENT_LOG_FILE"
        fi
    fi
}

# Funciones específicas para cada nivel de log
# Uso: log_xxx "mensaje"
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
# Uso: set_log_file <ruta_archivo>
# Ejemplo: set_log_file "/var/log/provision.log"
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
# Uso: set_log_level <nivel>
# Ejemplo: set_log_level "DEBUG"
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
# Uso: log_separator [caracter] [longitud]
# Ejemplo: log_separator "-" 80
log_separator() {
    local char="${1:-"-"}"
    local length="${2:-80}"
    printf '%*s\n' "$length" | tr ' ' "$char"
}

# Función para imprimir un encabezado
# Uso: log_header <título> [caracter] [longitud]
# Ejemplo: log_header "Inicio de Proceso" "=" 80
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
# Uso: log_command <comando> [descripción]
# Ejemplo: log_command "apt-get update" "Actualizando repositorios"
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

# Ejemplo completo de uso del script
: '
#!/bin/bash
source ./logging.sh

# Configurar logging
set_log_file "/var/log/provision.log"
set_log_level "DEBUG"

# Usar encabezados
log_header "Inicio de Instalación"

# Logging básico
log_info "Iniciando proceso..."
log_debug "Variables cargadas"

# Ejecutar comandos
if ! log_command "apt-get update" "Actualizando sistema"; then
    log_error "Fallo en actualización"
    exit 1
fi

# Usar formato
log_info $(log_format_output "<b>Instalación completada</b>")

# Separadores
log_separator
log_info "Proceso finalizado"
'

# Inicializar logging si no está inicializado
if [ -z "$LOG_INITIALIZED" ]; then
    # Establecer nivel de log por defecto
    set_log_level "INFO"

    # Marcar como inicializado
    LOG_INITIALIZED=1

    log_debug "Sistema de logging inicializado"
fi

# Exportar funciones
#export -f get_log_timestamp
#export -f log_format_output
#export -f log_base
#export -f log_debug
#export -f log_info
#export -f log_notice
#export -f log_warning
#export -f log_error
#export -f log_critical
#export -f set_log_file
#export -f set_log_level
#export -f log_separator
#export -f log_header
#export -f log_command
#export -f log_backup
#export -f log_progress
#export -f show_progress
#export -f start_long_operation
#export -f end_long_operation