#!/usr/bin/env bash
# Manejo de errores
#
# Este módulo proporciona funciones para el manejo consistente de errores,
# incluyendo stack traces, reintentos de comandos y manejo silencioso de errores.
# También incluye manejo específico para operaciones de backup y restauración.
#
# NOTA DE COMPATIBILIDAD:
# Este script mantiene compatibilidad con las siguientes funciones legacy:
# - handle_error -> error_handle
# - silent_error -> error_handle_silent
# - retry_command -> error_retry_command
#
# Se recomienda usar las nuevas funciones con prefijo error_* para mantener
# consistencia. Las funciones antiguas están marcadas como deprecated y
# serán removidas en futuras versiones.

# Importar dependencias
if [ ! "$(type -t log_error)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Códigos de error personalizados
declare -A ERROR_CODES=(
    ["SUCCESS"]=0               # Operación exitosa
    ["GENERAL_ERROR"]=1         # Error general
    ["INVALID_ARGS"]=2          # Argumentos inválidos
    ["PERMISSION_DENIED"]=3     # Permisos denegados
    ["FILE_NOT_FOUND"]=4        # Archivo no encontrado
    ["COMMAND_NOT_FOUND"]=5     # Comando no encontrado
    ["INVALID_CONFIG"]=6        # Configuración inválida
    ["NETWORK_ERROR"]=7         # Error de red
    ["DISK_FULL"]=8            # Disco lleno
    ["BACKUP_ERROR"]=9          # Error en backup
    ["RESTORE_ERROR"]=10        # Error en restauración
    ["TIMEOUT_ERROR"]=11        # Timeout en operación
    ["LOCK_ERROR"]=12          # Error de bloqueo
    ["DEPENDENCY_ERROR"]=13     # Error de dependencia
)

# ====================
# Funciones Legacy (Deprecated)
# ====================

# Función para manejar errores (DEPRECATED)
# Uso: handle_error <mensaje> [código_salida] [número_línea]
# Parámetros:
#   mensaje: Descripción del error
#   código_salida: (opcional) Código de salida (default: 1)
#   número_línea: (opcional) Número de línea donde ocurrió el error
# Ejemplo:
#   handle_error "Archivo no encontrado" 2 $LINENO
# Nota: Esta función está deprecada. Use error_handle en su lugar.
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

    # Mostrar mensaje de deprecación
    log_warning "Deprecated: 'handle_error' está obsoleto, use 'error_handle'"

    # Si se especifica un código de salida, terminar el script
    if [ $exit_code -ne 0 ]; then
        exit "$exit_code"
    fi
}

# Función para manejar errores de manera silenciosa (DEPRECATED)
# Uso: silent_error <mensaje> [código_retorno]
# Parámetros:
#   mensaje: Descripción del error
#   código_retorno: (opcional) Código de retorno (default: 1)
# Ejemplo:
#   if ! some_operation; then
#       silent_error "Operación falló pero continuamos"
#   fi
# Nota: Esta función está deprecada. Use error_handle_silent en su lugar.
silent_error() {
    local message="$1"
    local exit_code="${2:-1}"

    log_error "$message"
    log_warning "Deprecated: 'silent_error' está obsoleto, use 'error_handle_silent'"
    return $exit_code
}

# Función para reintentar comandos (DEPRECATED)
# Uso: retry_command <comando> [descripción] [max_intentos] [tiempo_espera]
# Parámetros:
#   comando: Comando a ejecutar
#   descripción: (opcional) Descripción para logs (default: comando)
#   max_intentos: (opcional) Número máximo de intentos (default: 3)
#   tiempo_espera: (opcional) Segundos entre intentos (default: 5)
# Ejemplo:
#   retry_command "curl -f http://api.example.com" "Verificar API" 5 10
# Nota: Esta función está deprecada. Use error_retry_command en su lugar.
retry_command() {
    local cmd="$1"
    local description="${2:-$cmd}"
    local max_attempts="${3:-3}"
    local wait_time="${4:-5}"
    local attempt=1

    log_warning "Deprecated: 'retry_command' está obsoleto, use 'error_retry_command'"

    while [ $attempt -le $max_attempts ]; do
        log_info "Intento $attempt de $max_attempts: $description"

        if log_command "$cmd" "$description"; then
            return 0
        fi

        attempt=$((attempt + 1))

        if [ $attempt -le $max_attempts ]; then
            log_warning "Reintentando en $wait_time segundos..."
            sleep "$wait_time"
        fi
    done

    log_error "El comando falló después de $max_attempts intentos"
    return 1
}
# ====================
# Funciones Estandarizadas
# ====================

# Función para obtener stack trace de error
# Uso: error_get_stack_trace
# Retorna:
#   String con el stack trace completo en formato legible
# Ejemplo:
#   stack=$(error_get_stack_trace)
#   echo "Stack trace actual: $stack"
error_get_stack_trace() {
    local stack=""
    local frame=0

    while caller $frame > /dev/null; do
        local line func file
        read -r line func file < <(caller $frame)
        stack+="  en $func ($file:$line)\n"
        ((frame++))
    done

    echo -e "$stack"
}

# Función principal para manejo de errores
# Uso: error_handle <mensaje> [código_salida] [número_línea]
# Parámetros:
#   mensaje: Descripción detallada del error
#   código_salida: (opcional) Código de salida (default: 1)
#   número_línea: (opcional) Número de línea donde ocurrió el error
# Retorna:
#   No retorna si código_salida es != 0 (termina el script)
# Ejemplo:
#   error_handle "No se pudo acceder al archivo config.json" ${ERROR_CODES["FILE_NOT_FOUND"]} $LINENO
error_handle() {
    local message="$1"
    local exit_code="${2:-1}"
    local line_number="${3:-$LINENO}"
    local stack_trace

    stack_trace=$(error_get_stack_trace)

    # Logging detallado del error
    log_critical "$message"
    log_error "Stack trace:"
    log_error "$stack_trace"
    log_error "Código de salida: $exit_code"
    log_error "Línea: $line_number"

    # Información adicional en modo debug
    if [ "${LOG_LEVEL:-}" = "DEBUG" ]; then
        log_debug "Variables de entorno en el momento del error:"
        env | log_debug
    fi

    # Terminar script si se especifica código de salida
    if [ $exit_code -ne 0 ]; then
        exit "$exit_code"
    fi
}

# Función para manejar errores de manera silenciosa
# Uso: error_handle_silent <mensaje> [código_retorno]
# Parámetros:
#   mensaje: Descripción del error que no debe interrumpir la ejecución
#   código_retorno: (opcional) Código de retorno (default: 1)
# Retorna:
#   Código de retorno especificado
# Ejemplo:
#   if ! some_operation; then
#       error_handle_silent "La operación falló pero continuamos" ${ERROR_CODES["GENERAL_ERROR"]}
#   fi
error_handle_silent() {
    local message="$1"
    local exit_code="${2:-1}"

    log_error "$message"
    return $exit_code
}

# Función para manejar errores específicos de backup
# Uso: error_handle_backup <código> <mensaje> [directorio_backup]
# Parámetros:
#   código: Código de error específico del backup
#   mensaje: Descripción detallada del error de backup
#   directorio_backup: (opcional) Directorio de backup que causó el error
# Retorna:
#   Código de error proporcionado
# Ejemplo:
#   error_handle_backup ${ERROR_CODES["BACKUP_ERROR"]} "Fallo al crear backup" "/var/backups/site"
error_handle_backup() {
    local error_code="$1"
    local error_message="$2"
    local backup_dir="${3:-}"
    local stack_trace

    stack_trace=$(error_get_stack_trace)

    # Logging detallado del error de backup
    log_error "Error en operación de backup (código: $error_code)"
    log_error "Mensaje: $error_message"
    log_error "Stack trace:"
    log_error "$stack_trace"

    # Limpiar directorio de backup fallido si existe
    if [ -n "$backup_dir" ] && [ -d "$backup_dir" ]; then
        log_warning "Limpiando directorio de backup fallido: $backup_dir"
        if ! rm -rf "$backup_dir"; then
            log_error "No se pudo limpiar el directorio de backup: $backup_dir"
        fi
    fi

    # Registrar en log específico de errores de backup
    local error_log="${LOGS_DIR}/backup_errors.log"
    {
        echo "==== Error de Backup ===="
        echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Código: $error_code"
        echo "Mensaje: $error_message"
        echo "Directorio: $backup_dir"
        echo "Stack Trace:"
        echo "$stack_trace"
        echo "======================="
        echo
    } >> "$error_log"

    return "$error_code"
}

# Función para reintentar comandos con manejo de errores
# Uso: error_retry_command <comando> [descripción] [max_intentos] [tiempo_espera]
# Parámetros:
#   comando: Comando a ejecutar
#   descripción: (opcional) Descripción para los logs (default: comando)
#   max_intentos: (opcional) Número máximo de intentos (default: 3)
#   tiempo_espera: (opcional) Segundos entre intentos (default: 5)
# Retorna:
#   0 si el comando se ejecutó exitosamente
#   1 si se agotaron los intentos
# Ejemplo:
#   error_retry_command "wget http://example.com/file" "Descarga de archivo" 5 10
error_retry_command() {
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

        if [ $attempt -lt $max_attempts ]; then
            log_warning "Reintentando en $wait_time segundos..."
            sleep "$wait_time"
        else
            log_error "El comando falló después de $max_attempts intentos"
            return 1
        fi

        ((attempt++))
    done
}

# Función para verificar y limpiar locks de error
# Uso: error_check_locks <prefijo_lock>
# Parámetros:
#   prefijo_lock: Prefijo identificador para el tipo de lock
# Retorna:
#   0 si no hay locks activos
#   ERROR_CODES["LOCK_ERROR"] si hay locks activos
# Ejemplo:
#   if ! error_check_locks "backup"; then
#       log_error "Otro proceso de backup está en ejecución"
#       exit ${ERROR_CODES["LOCK_ERROR"]}
#   fi
error_check_locks() {
    local lock_prefix="$1"
    local lock_dir="/tmp/${lock_prefix}_locks"
    local max_lock_age=3600  # 1 hora en segundos

    if [ -d "$lock_dir" ]; then
        find "$lock_dir" -type f -mmin +60 -delete
        if [ -n "$(ls -A "$lock_dir")" ]; then
            log_warning "Locks activos encontrados para $lock_prefix"
            return ${ERROR_CODES["LOCK_ERROR"]}
        fi
    fi

    return ${ERROR_CODES["SUCCESS"]}
}
# ====================
# Configuración y Exportaciones
# ====================

# Configurar manejador de errores por defecto
# Este trap capturará cualquier error no manejado en el script
# y lo procesará usando error_handle
trap 'error_handle "Se produjo un error no manejado" $? $LINENO' ERR

# ====================
# Documentación de Uso
# ====================

: '
Este módulo proporciona un sistema completo de manejo de errores.

Uso básico:
-----------
# Manejo simple de errores
error_handle "Mensaje de error" 1

# Manejo silencioso
error_handle_silent "Error no crítico"

# Reintentar comando
error_retry_command "curl http://api.example.com" "Verificar API" 3 5

# Manejo de errores de backup
error_handle_backup ${ERROR_CODES["BACKUP_ERROR"]} "Error en backup" "/path/to/backup"

# Verificar locks
error_check_locks "backup"

Códigos de Error:
----------------
SUCCESS          = 0  # Operación exitosa
GENERAL_ERROR    = 1  # Error general
INVALID_ARGS     = 2  # Argumentos inválidos
PERMISSION_DENIED= 3  # Permisos denegados
FILE_NOT_FOUND   = 4  # Archivo no encontrado
...

Ejemplos de uso:
----------------
# Ejemplo 1: Manejo básico de errores
if ! some_operation; then
    error_handle "La operación falló" ${ERROR_CODES["GENERAL_ERROR"]}
fi

# Ejemplo 2: Reintentar una operación
error_retry_command "wget http://example.com/file" "Descarga" 3 5

# Ejemplo 3: Manejar error de backup
if ! create_backup; then
    error_handle_backup ${ERROR_CODES["BACKUP_ERROR"]} "Fallo en backup" "$BACKUP_DIR"
fi

Notas:
------
1. Las funciones legacy (handle_error, silent_error, retry_command) están
   marcadas como deprecated y serán removidas en futuras versiones.
2. Se recomienda usar las nuevas funciones con prefijo error_*.
3. Todos los errores son registrados en logs con stack trace completo.
4. En modo DEBUG se registra información adicional del entorno.
'

# ====================
# Exportación de Funciones
# ====================

# Exportar códigos de error
#export ERROR_CODES

# Exportar funciones estandarizadas
#export -f error_handle
#export -f error_handle_silent
#export -f error_handle_backup
#export -f error_retry_command
#export -f error_check_locks
#export -f error_get_stack_trace

# Exportar funciones legacy (deprecated)
#export -f handle_error
#export -f silent_error
#export -f retry_command

# ====================
# Verificación Final
# ====================

# Verificar que las funciones críticas estén disponibles
if ! declare -F error_handle >/dev/null; then
    echo "ERROR: Función crítica error_handle no está disponible"
    exit 1
fi

if ! declare -F error_get_stack_trace >/dev/null; then
    echo "ERROR: Función crítica error_get_stack_trace no está disponible"
    exit 1
fi

# Verificar variable necesaria para logs
if [ -z "$LOGS_DIR" ]; then
    echo "ADVERTENCIA: Variable LOGS_DIR no está definida"
fi