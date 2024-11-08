#!/usr/bin/env bash
# Manejo de errores
#
# Este módulo proporciona funciones para el manejo consistente de errores,
# incluyendo stack traces, reintentos de comandos y manejo silencioso de errores.
#
# Ejemplo de uso general:
#   source ./error.sh
#
#   # Configurar manejador global
#   trap 'handle_error "Error en script" $? $LINENO' ERR
#
#   # Usar reintentos
#   retry_command "wget http://example.com" "Descarga" 3 5
#
#   # Manejar error específico
#   if ! operation; then
#       handle_error "Falló la operación" 2
#   fi

# Importar dependencias
if [ ! "$(type -t log_error)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Función para manejar errores
# Uso: handle_error <mensaje> [código_salida] [número_línea]
# Parámetros:
#   mensaje: Descripción del error
#   código_salida: (opcional) Código de salida (default: 1)
#   número_línea: (opcional) Número de línea donde ocurrió el error
# Ejemplo:
#   handle_error "Archivo no encontrado" 2 $LINENO
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
# Uso: silent_error <mensaje> [código_retorno]
# Parámetros:
#   mensaje: Descripción del error
#   código_retorno: (opcional) Código de retorno (default: 1)
# Ejemplo:
#   if ! some_operation; then
#       silent_error "Operación falló pero continuamos"
#   fi
silent_error() {
    local message="$1"
    local exit_code="${2:-1}"

    log_error "$message"
    return $exit_code
}

# Función para ejecutar comando con retry
# Uso: retry_command <comando> [descripción] [max_intentos] [tiempo_espera]
# Parámetros:
#   comando: Comando a ejecutar
#   descripción: (opcional) Descripción para logs
#   max_intentos: (opcional) Número máximo de intentos (default: 3)
#   tiempo_espera: (opcional) Segundos entre intentos (default: 5)
# Ejemplo:
#   retry_command "curl -f http://api.example.com" "Verificar API" 5 10
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
            log_warning "Reintentando en $wait_time segundos..."
            sleep "$wait_time"
        fi
    done

    log_error "El comando falló después de $max_attempts intentos"
    return 1
}

# Ejemplo completo de uso del script
: '
#!/bin/bash
source ./error.sh

# Configurar manejador global de errores
trap "handle_error \"Error no manejado\" \$? \$LINENO" ERR

# Función con manejo de errores
check_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        handle_error "Archivo no encontrado: $file" 2
    fi
}

# Función con reintentos
download_file() {
    local url="$1"
    local output="$2"
    retry_command "wget -O $output $url" "Descargando archivo" 3 5
}

# Función con error silencioso
verify_optional() {
    if ! some_check; then
        silent_error "Verificación opcional falló"
        return 1
    fi
}

# Ejemplo de uso
check_file "/etc/config.conf"
download_file "http://example.com/file" "output.txt"
verify_optional || true  # Continuar aunque falle
'

# Configurar manejador de errores por defecto
trap 'handle_error "Se produjo un error no manejado" $? $LINENO' ERR

# Exportar funciones
#export -f handle_error
#export -f silent_error
#export -f retry_command