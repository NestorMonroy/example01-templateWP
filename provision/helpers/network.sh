#!/usr/bin/env bash
# Funciones para gestión y verificación de red

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables de red
NETWORK_TIMEOUT=${NETWORK_TIMEOUT:-5}
NETWORK_RETRIES=${NETWORK_RETRIES:-3}
CURL_OPTIONS="--silent --fail --location --connect-timeout ${NETWORK_TIMEOUT}"
WGET_OPTIONS="--quiet --timeout=${NETWORK_TIMEOUT} --tries=${NETWORK_RETRIES}"

# URLs importantes para verificar conectividad
declare -A IMPORTANT_URLS=(
    ["packagist"]="https://packagist.org"
    ["github"]="https://github.com"
    ["composer"]="https://getcomposer.org"
    ["wordpress"]="https://wordpress.org"
)

# Función para verificar conexión a internet
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
    }

    log_success "Conexión a internet verificada"
    return 0
}

# Verificar conexión a un host específico
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

# Verificar si un puerto está en uso
is_port_in_use() {
    local port="$1"
    local protocol="${2:-tcp}"

    case "$protocol" in
        tcp)
            netstat -tln | grep -q ":${port} "
            ;;
        udp)
            netstat -uln | grep -q ":${port} "
            ;;
        *)
            log_error "Protocolo no soportado: $protocol"
            return 1
            ;;
    esac
}

# Encontrar siguiente puerto disponible
find_next_available_port() {
    local start_port="$1"
    local end_port="${2:-65535}"
    local protocol="${3:-tcp}"

    for port in $(seq "$start_port" "$end_port"); do
        if ! is_port_in_use "$port" "$protocol"; then
            echo "$port"
            return 0
        fi
    done

    log_error "No se encontraron puertos disponibles entre $start_port y $end_port"
    return 1
}

# Verificar certificado SSL
check_ssl_certificate() {
    local domain="$1"
    local port="${2:-443}"

    if ! echo | openssl s_client -connect "${domain}:${port}" 2>/dev/null | \
        openssl x509 -noout -dates; then
        log_error "No se pudo verificar el certificado SSL para $domain"
        return 1
    fi
}

# Inicialización del módulo
check_internet_connection || {
    log_error "Se requiere conexión a internet para continuar"
    exit 1
}