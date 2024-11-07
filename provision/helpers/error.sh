#!/usr/bin/env bash
# Manejo de errores

# Importar dependencias
if [ ! "$(type -t log_error)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

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
            log_warning "Reintentando en $wait_time segundos..."
            sleep "$wait_time"
        fi
    done

    log_error "El comando falló después de $max_attempts intentos"
    return 1
}

# Configurar manejador de errores por defecto
trap 'handle_error "Se produjo un error no manejado" $? $LINENO' ERR

# Exportar funciones
#export -f handle_error
#export -f silent_error
#export -f retry_command