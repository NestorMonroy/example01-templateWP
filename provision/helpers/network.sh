#!/usr/bin/env bash
# Funciones para gestión y verificación de red
#
# Este script proporciona funciones para verificar conectividad de red,
# descargar archivos, verificar servicios y gestionar configuraciones de red.
#
# Ejemplo de uso general:
#   source ./network.sh
#
#   # Verificar conexión a internet
#   check_internet_connection
#
#   # Descargar WordPress
#   download_file "https://wordpress.org/latest.zip" "/tmp/wp.zip" "WordPress"
#
#   # Verificar servicios críticos
#   check_required_services

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables de red
# Configura timeouts y reintentos para operaciones de red
NETWORK_TIMEOUT=${NETWORK_TIMEOUT:-5}    # Timeout predeterminado en segundos
NETWORK_RETRIES=${NETWORK_RETRIES:-3}    # Número de intentos de reintento

# Opciones predeterminadas para herramientas de red
CURL_OPTIONS="--silent --fail --location --connect-timeout ${NETWORK_TIMEOUT}"
WGET_OPTIONS="--quiet --timeout=${NETWORK_TIMEOUT} --tries=${NETWORK_RETRIES}"

# URLs importantes para verificar conectividad
# Ejemplo: check_required_services verificará estas URLs
declare -A IMPORTANT_URLS=(
    ["packagist"]="https://packagist.org"
    ["github"]="https://github.com"
    ["composer"]="https://getcomposer.org"
    ["wordpress"]="https://wordpress.org"
)

# Función para verificar conexión a internet
# Uso: check_internet_connection [timeout]
# Ejemplo:
#   if check_internet_connection 10; then
#       echo "Tenemos conexión"
#   fi
check_internet_connection() {
    local timeout="${1:-5}"
    log_info "Verificando conexión a internet..."

    # Intentar resolver Google DNS
    if ! ping -c 1 -W "$timeout" 8.8.8.8 >/dev/null 2>&1; then
        log_error "No hay conexión a internet (ping a 8.8.8.8 falló)"
        return 1
    fi

    # Verificar resolución DNS
    if ! ping -c 1 -W "$timeout" google.com >/dev/null 2>&1; then
        log_error "La resolución DNS falló (ping a google.com falló)"
        return 1
    fi

    log_success "Conexión a internet verificada"
    return 0
}

# Verificar conexión a un host específico
# Uso: check_host_connection <host> [puerto] [timeout]
# Ejemplo:
#   check_host_connection "wordpress.org" 443 5
check_host_connection() {
    local host="$1"
    local port="${2:-80}"
    local timeout="${3:-${NETWORK_TIMEOUT}}"

    log_info "Verificando conexión a ${host}:${port}..."

    if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
        log_success "Conexión exitosa a ${host}:${port}"
        return 0
    else
        log_error "No se puede conectar a ${host}:${port}"
        return 1
    fi
}

# Verificar que los servicios necesarios estén disponibles
# Uso: check_required_services
# Ejemplo:
#   if check_required_services; then
#       echo "Todos los servicios están disponibles"
#   fi
check_required_services() {
    log_info "Verificando servicios requeridos..."
    local failed_services=()

    for service in "${!IMPORTANT_URLS[@]}"; do
        local url="${IMPORTANT_URLS[$service]}"
        if ! curl $CURL_OPTIONS "$url" >/dev/null 2>&1; then
            failed_services+=("$service")
        fi
    done

    if [ ${#failed_services[@]} -gt 0 ]; then
        log_error "Los siguientes servicios no están disponibles:"
        for service in "${failed_services[@]}"; do
            log_error "- $service (${IMPORTANT_URLS[$service]})"
        done
        return 1
    fi

    log_success "Todos los servicios requeridos están disponibles"
    return 0
}

# Descargar archivo con progreso
# Uso: download_file <url> <ruta_destino> [descripción]
# Ejemplo:
#   download_file "https://wordpress.org/latest.zip" "/tmp/wp.zip" "WordPress"
download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-archivo}"

    log_info "Descargando $description..."

    if command -v wget >/dev/null 2>&1; then
        if wget $WGET_OPTIONS -O "$output" "$url"; then
            log_success "Descarga completada: $description"
            return 0
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl $CURL_OPTIONS --output "$output" "$url"; then
            log_success "Descarga completada: $description"
            return 0
        fi
    else
        log_error "Se requiere wget o curl para descargar archivos"
        return 1
    fi

    log_error "Error al descargar $description"
    return 1
}

# Verificar checksum de un archivo
# Uso: verify_checksum <archivo> <checksum_esperado> [algoritmo]
# Ejemplo:
#   verify_checksum "wordpress.zip" "abc123..." "sha256"
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"

    if [ ! -f "$file" ]; then
        log_error "Archivo no encontrado: $file"
        return 1
    fi

    local actual_checksum
    case "$algorithm" in
        md5)
            actual_checksum=$(md5sum "$file" | cut -d' ' -f1)
            ;;
        sha1)
            actual_checksum=$(sha1sum "$file" | cut -d' ' -f1)
            ;;
        sha256)
            actual_checksum=$(sha256sum "$file" | cut -d' ' -f1)
            ;;
        sha384)
            actual_checksum=$(sha384sum "$file" | cut -d' ' -f1)
            ;;
        sha512)
            actual_checksum=$(sha512sum "$file" | cut -d' ' -f1)
            ;;
        *)
            log_error "Algoritmo de checksum no soportado: $algorithm"
            return 1
            ;;
    esac

    if [ "$actual_checksum" = "$expected_checksum" ]; then
        log_success "Verificación de checksum exitosa"
        return 0
    else
        log_error "Verificación de checksum fallida"
        log_error "Esperado: $expected_checksum"
        log_error "Actual: $actual_checksum"
        return 1
    fi
}

# Obtener IP pública
# Uso: ip=$(get_public_ip)
# Ejemplo:
#   if ip=$(get_public_ip); then
#       echo "Mi IP pública es: $ip"
#   fi
get_public_ip() {
    local ip

    # Intentar diferentes servicios
    for service in \
        "https://ipinfo.io/ip" \
        "https://api.ipify.org" \
        "https://icanhazip.com" \
        "https://ifconfig.me/ip"; do

        ip=$(curl $CURL_OPTIONS "$service" 2>/dev/null)
        if [ $? -eq 0 ] && [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done

    log_error "No se pudo obtener la IP pública"
    return 1
}

# Agregar entrada al archivo hosts
# Uso: add_hosts_entry <ip> <hostname>
# Ejemplo:
#   add_hosts_entry "127.0.0.1" "local.wordpress.test"
add_hosts_entry() {
    local ip="$1"
    local hostname="$2"
    local hosts_file="/etc/hosts"

    # Remover entrada existente
    sed -i "/ ${hostname}$/d" "$hosts_file"

    # Agregar nueva entrada
    echo "$ip $hostname" >> "$hosts_file"

    log_success "Entrada agregada a hosts: $ip $hostname"
}

# Verificar certificado SSL
# Uso: check_ssl_certificate <dominio> [puerto]
# Ejemplo:
#   if check_ssl_certificate "wordpress.org" 443; then
#       echo "Certificado SSL válido"
#   fi
check_ssl_certificate() {
    local domain="$1"
    local port="${2:-443}"

    if ! echo | openssl s_client -connect "${domain}:${port}" 2>/dev/null | \
        openssl x509 -noout -dates; then
        log_error "No se pudo verificar el certificado SSL para $domain"
        return 1
    fi
}

# Agregar después de las funciones existentes en network.sh

# Verificar si un puerto está en el rango privilegiado
# Uso: is_privileged_port <puerto>
# Retorna:
#   0 - Es puerto privilegiado
#   1 - No es puerto privilegiado
is_privileged_port() {
    local port="$1"
    [ "$port" -lt 1024 ]
}

# Verificar si se puede hacer bind a un puerto
# Uso: can_bind_to_port <puerto>
# Retorna:
#   0 - Se puede hacer bind
#   1 - No se puede hacer bind
can_bind_to_port() {
    local port="$1"
    local user_id="$(id -u)"

    if is_privileged_port "$port"; then
        [ "$user_id" -eq 0 ]
        return $?
    fi

    return 0
}

# Verificar disponibilidad y estado de un puerto específico
# Uso: verify_port <puerto> [descripción] [protocolo] [timeout]
# Retorna:
#   0 - Puerto disponible
#   1 - Puerto no disponible
#   2 - Error en verificación
# Verificar disponibilidad de un puerto usando solo herramientas base
verify_port() {
    local port="$1"
    local description="${2:-Puerto $port}"
    local protocol="${3:-tcp}"
    local timeout="${4:-5}"

    log_info "Verificando $description (puerto $port/$protocol)..."

    # Validar el puerto
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Puerto inválido: $port"
        return 2
    fi

    # Verificar si el puerto está en uso (usando netstat que es más común)
    if netstat -tuln | grep -q ":${port}[[:space:]]"; then
        # El puerto está en uso
        return 1
    fi

    # Intento alternativo de verificación usando diferentes herramientas
    # en orden de preferencia
    if command -v nc >/dev/null; then
        # Usando netcat
        if nc -z localhost "$port" 2>/dev/null; then
            return 1
        fi
    elif command -v timeout >/dev/null; then
        # Usando bash y timeout
        if timeout "$timeout" bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
            return 1
        fi
    else
        # Usando solo bash (con timeout manual mediante subshell y kill)
        local pid
        (bash -c "echo >/dev/tcp/localhost/$port") 2>/dev/null & pid=$!
        sleep "$timeout"
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            return 1
        fi
    fi

    # Verificación adicional para puertos privilegiados
    if [ "$port" -lt 1024 ] && [ "$(id -u)" != "0" ]; then
        log_warning "Puerto privilegiado ($port < 1024) requiere permisos root"
        return 2
    fi

    return 0
}


# Obtener información detallada de un puerto
# Uso: get_port_info <puerto> [protocolo]
# Salida: Información en formato key=value
# Obtener información detallada de un puerto sin dependencias externas
get_port_info() {
    local port="$1"
    local protocol="${2:-tcp}"
    local info=""

    # Intentar obtener información usando diferentes herramientas
    # en orden de preferencia
    if command -v lsof >/dev/null; then
        # Usando lsof si está disponible
        local process_info
        process_info=$(lsof -i :"$port" -P -n 2>/dev/null)
        if [ -n "$process_info" ]; then
            info+="PROCESS=$(echo "$process_info" | tail -n 1 | awk '{print $1}')\n"
            info+="PID=$(echo "$process_info" | tail -n 1 | awk '{print $2}')\n"
            info+="USER=$(echo "$process_info" | tail -n 1 | awk '{print $3}')\n"
        fi
    else
        # Usando netstat como alternativa
        local netstat_info
        netstat_info=$(netstat -tulnp 2>/dev/null | grep ":${port}[[:space:]]")
        if [ -n "$netstat_info" ]; then
            info+="PROCESS=$(echo "$netstat_info" | awk '{print $NF}')\n"
            info+="STATE=$(echo "$netstat_info" | awk '{print $6}')\n"
        fi
    fi

    # Información adicional basada en sistema
    info+="PRIVILEGED=$([ "$port" -lt 1024 ] && echo "yes" || echo "no")\n"
    info+="PROTOCOL=$protocol\n"
    info+="PORT=$port\n"

    echo -e "$info"
}

# Verificar rápidamente si un puerto está en uso
is_port_active() {
    local port="$1"
    local protocol="${2:-tcp}"

    # Primero intentar con netstat (más común)
    if netstat -tuln | grep -q ":${port}[[:space:]]"; then
        return 0
    fi

    # Si netstat no muestra nada, intentar con una conexión rápida
    if ! (echo >/dev/tcp/localhost/"$port") 2>/dev/null; then
        return 1
    fi

    return 0
}

# Ejemplo de uso completo del script
: '
# Verificar conexión básica
check_internet_connection

# Descargar WordPress y verificar su checksum
download_file "https://wordpress.org/latest.zip" "/tmp/wordpress.zip" "WordPress"
verify_checksum "/tmp/wordpress.zip" "abc123..." "sha256"

# Configurar host local
ip=$(get_public_ip)
add_hosts_entry "$ip" "mi-wordpress.local"

# Verificar servicios y SSL
check_required_services
check_ssl_certificate "wordpress.org"
'

# Exportar funciones
#export -f check_internet_connection
#export -f check_host_connection
#export -f check_required_services
#export -f download_file
#export -f verify_checksum
#export -f get_public_ip
#export -f add_hosts_entry
#export -f check_ssl_certificate