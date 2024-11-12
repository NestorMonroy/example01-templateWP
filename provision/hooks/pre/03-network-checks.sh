#!/bin/bash

# Pre-hook: Verificación de conectividad a internet
#
# Pasos de verificación:
# 1. Verificación de conectividad básica a internet
# 2. Verificación de resolución DNS
# 3. Verificación de latencia
# 4. Verificación de velocidad de conexión
#
# Cada paso incluye:
# - Recolección de datos de conectividad
# - Validación contra requisitos mínimos
# - Registro detallado de resultados
# - Manejo de errores y advertencias

# 1. Validación del contexto de ejecución
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Cargar helpers necesarios
load_helpers "network.sh" "logging.sh" "error.sh"

# Configuración de requisitos de red
declare -A NETWORK_REQUIREMENTS=(
    ["min_download_speed"]="1.0"     # MB/s
    ["min_upload_speed"]="0.5"       # MB/s
    ["max_latency"]="300"            # ms
    ["dns_timeout"]="5"              # segundos
)


# URLs para pruebas de velocidad
declare -a SPEED_TEST_URLS=(
    "https://speed.hetzner.de/10MB.bin"
    "https://wordpress.org/latest.zip"
    "https://github.com/wordpress/wordpress/archive/master.zip"
)

# Hosts para pruebas de latencia
declare -a LATENCY_TEST_HOSTS=(
    "8.8.8.8"        # Google DNS
    "1.1.1.1"        # Cloudflare DNS
    "208.67.222.222" # OpenDNS
)

# Hosts para pruebas de DNS
declare -a DNS_TEST_DOMAINS=(
    "google.com"
    "cloudflare.com"
    "github.com"
)

# 1 Función para verificar conectividad básica a internet
check_basic_connectivity() {
    log_info "PASO 1: Verificación de Conectividad Básica"
    log_info "----------------------------------------"
    local has_errors=0
    local successful_checks=0
    local required_checks=2  # Número mínimo de verificaciones exitosas requeridas

    # 1.1 Verificar conexión básica a internet usando el helper
    log_info "Verificando conexión básica a internet..."
    if check_internet_connection "$NETWORK_TIMEOUT"; then
        ((successful_checks++))
    else
        ((has_errors++))
    fi

    # 1.2 Verificar IP pública usando el helper
    log_info "Verificando IP pública..."
    local public_ip
    if public_ip=$(get_public_ip); then
        log_success "IP pública detectada: $public_ip"
        ((successful_checks++))
    else
        log_warning "No se pudo determinar la IP pública"
        ((has_errors++))
    fi

    # 1.3 Evaluar resultados
    log_info "Resumen de verificaciones básicas:"
    log_info "- Verificaciones exitosas: $successful_checks/2"
    log_info "- Verificaciones requeridas: $required_checks"

    # 1.4 Validar resultados contra requisitos
    if [ $successful_checks -lt $required_checks ]; then
        log_error "Verificación básica insuficiente: $successful_checks/2 verificaciones exitosas"
        return 1
    fi

    if [ $has_errors -eq 0 ]; then
        log_success "Verificación de conectividad básica completamente exitosa"
    else
        log_warning "Verificación de conectividad básica completada con advertencias"
    fi

    return $has_errors
}

# 2. Función para verificar la resolución DNS
check_dns_resolution() {
    log_info "PASO 2: Verificación de Resolución DNS"
    log_info "----------------------------------------"
    local has_errors=0
    local successful_resolutions=0
    local required_resolutions=2  # Mínimo de resoluciones exitosas requeridas

    # 2.1 Verificar resolución de dominios críticos
    local -a TEST_DOMAINS=(
        "google.com"
        "cloudflare.com"
        "github.com"
    )

    # 2.2 Probar resolución de cada dominio
    for domain in "${TEST_DOMAINS[@]}"; do
        log_info "Verificando resolución de $domain..."
        if check_host_connection "$domain" 80 "$NETWORK_TIMEOUT"; then
            log_success "✓ Resolución exitosa para $domain"
            ((successful_resolutions++))
        else
            log_warning "✗ No se pudo resolver $domain"
            ((has_errors++))
        fi
    done

    # 2.3 Verificar servidor DNS primario (8.8.8.8)
    log_info "Verificando conectividad con DNS primario (8.8.8.8)..."
    if check_host_connection "8.8.8.8" 53 "$NETWORK_TIMEOUT"; then
        log_success "✓ DNS primario accesible"
        ((successful_resolutions++))
    else
        log_warning "✗ DNS primario no accesible"
        ((has_errors++))
    fi

    # 2.4 Verificar servidor DNS secundario (8.8.4.4)
    log_info "Verificando conectividad con DNS secundario (8.8.4.4)..."
    if check_host_connection "8.8.4.4" 53 "$NETWORK_TIMEOUT"; then
        log_success "✓ DNS secundario accesible"
        ((successful_resolutions++))
    else
        log_warning "✗ DNS secundario no accesible"
        ((has_errors++))
    fi

    # 2.5 Evaluar resultados
    log_info "Resumen de resolución DNS:"
    log_info "- Resoluciones exitosas: $successful_resolutions/$(( ${#TEST_DOMAINS[@]} + 2 ))"
    log_info "- Resoluciones requeridas: $required_resolutions"

    # 2.6 Validar resultados contra requisitos
    if [ $successful_resolutions -lt $required_resolutions ]; then
        log_error "Resolución DNS insuficiente: $successful_resolutions resoluciones exitosas"
        return 1
    fi

    if [ $has_errors -eq 0 ]; then
        log_success "Verificación de resolución DNS completamente exitosa"
    else
        log_warning "Verificación de resolución DNS completada con advertencias"
    fi

    return $has_errors
}

# Función para verificar la latencia de red
# Realiza pruebas de latencia contra hosts de referencia
# y valida que estén dentro de los límites aceptables
check_network_latency() {
    log_info "PASO 3: Verificación de Latencia"
    log_info "------------------------------"
    local has_errors=0
    local total_latency=0
    local successful_tests=0

    local MAX_ACCEPTABLE_LATENCY=${MAX_ACCEPTABLE_LATENCY:-100} # ms
    local MAX_ACCEPTABLE_JITTER=${MAX_ACCEPTABLE_JITTER:-50}   # ms
    local PING_COUNT=5
    local PING_TIMEOUT=$NETWORK_TIMEOUT

    # 3.1 Medir latencia para cada host
    log_info "Midiendo latencia hacia hosts de referencia..."
    for host in "${LATENCY_HOSTS[@]}"; do
        log_info "Probando latencia hacia $host..."

        # Verificar primero si el host es accesible
        if ! check_host_connection "$host"; then
            log_warning "✗ Host $host no accesible, omitiendo prueba de latencia"
            continue
        }

        # 3.2 Realizar medición de latencia con timeout
        local ping_result
        if ping_result=$(ping -c $PING_COUNT -W $PING_TIMEOUT -q "$host" 2>/dev/null); then
            local latency=$(echo "$ping_result" | awk -F'/' 'END{print $5}')

            if [ -n "$latency" ] && [ "$latency" != "0" ]; then
                latency=${latency%.*}  # Remover decimales
                log_success "✓ Latencia a $host: ${latency}ms"
                total_latency=$((total_latency + latency))
                ((successful_tests++))
            else
                log_warning "✗ Resultado de latencia inválido para $host"
            fi
        else
            log_warning "✗ Error al medir latencia para $host"
        fi
    done

    # 3.3 Calcular y evaluar latencia promedio
    if [ $successful_tests -gt 0 ]; then
        local avg_latency=$((total_latency / successful_tests))
        log_info "Resumen de latencia:"
        log_info "- Latencia promedio: ${avg_latency}ms"
        log_info "- Máxima permitida: ${MAX_ACCEPTABLE_LATENCY}ms"

        # 3.4 Validar contra requisitos
        if [ $avg_latency -gt $MAX_ACCEPTABLE_LATENCY ]; then
            log_error "Latencia promedio muy alta: ${avg_latency}ms"
            ((has_errors++))
        else
            log_success "Latencia dentro de límites aceptables"
        fi
    else
        log_error "No se pudo medir la latencia en ningún host"
        return 1
    fi

    # 3.5 Verificar variación de latencia (jitter)
    log_info "Verificando estabilidad de latencia..."
    local reference_host="8.8.8.8"  # Usar Google DNS como referencia para jitter

    if check_host_connection "$reference_host"; then
        local jitter_result
        if jitter_result=$(ping -c 10 -W $PING_TIMEOUT -q "$reference_host" 2>/dev/null); then
            local jitter=$(echo "$jitter_result" | awk -F'/' 'END{print $7}')

            if [ -n "$jitter" ] && [ "$jitter" != "0" ]; then
                jitter=${jitter%.*}
                log_info "- Variación de latencia (jitter): ${jitter}ms"

                if [ "$jitter" -gt "$MAX_ACCEPTABLE_JITTER" ]; then
                    log_warning "Alta variación en la latencia detectada"
                    ((has_errors++))
                else
                    log_success "Variación de latencia dentro de límites aceptables"
                fi
            fi
        fi
    else
        log_warning "No se pudo medir el jitter: host de referencia no accesible"
        ((has_errors++))
    fi

    if [ $has_errors -eq 0 ]; then
        log_success "Verificación de latencia completamente exitosa"
    else
        log_warning "Verificación de latencia completada con advertencias"
    fi

    return $has_errors
}

# Función para verificar la velocidad de conexión
check_connection_speed() {
    log_info "PASO 4: Verificación de Velocidad de Conexión"
    log_info "------------------------------------------"
    local has_errors=0
    local TEST_FILE_SIZE=10                            # MB
    local TEST_TIMEOUT=$((NETWORK_TIMEOUT * 4))        # Dar más tiempo para pruebas de velocidad

    # 4.1 Verificar conexión antes de las pruebas
    if ! check_internet_connection "$NETWORK_TIMEOUT"; then
        log_error "No hay conexión a internet estable para realizar pruebas de velocidad"
        return 1
    }

    # 4.2 Prueba de velocidad de descarga
    log_info "Realizando prueba de velocidad de descarga..."
    local download_speed=0
    local test_file="/tmp/speedtest_$$"  # Usar PID para evitar conflictos

    for url in "${SPEED_TEST_URLS[@]}"; do
        log_info "Intentando descarga desde: $url"

        # Usar download_file del helper con tiempo medido
        local start_time=$(date +%s.%N)
        if download_file "$url" "$test_file" "archivo de prueba" >/dev/null 2>&1; then
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc)
            local file_size

            if file_size=$(stat -f%z "$test_file" 2>/dev/null || stat -c%s "$test_file"); then
                download_speed=$(echo "scale=2; $file_size / 1048576 / $duration" | bc)
                rm -f "$test_file"

                log_success "Prueba de descarga completada"
                break
            fi
        fi
        log_warning "Falló la descarga desde $url, intentando siguiente servidor..."
    done

       # 4.3 Evaluar resultado de descarga
       if [ -n "$download_speed" ] && [ "$download_speed" != "0" ]; then
           log_info "Velocidad de descarga: ${download_speed} MB/s"

           if (( $(echo "$download_speed < $MIN_DOWNLOAD_SPEED" | bc -l) )); then
               log_error "Velocidad de descarga por debajo del mínimo requerido (${MIN_DOWNLOAD_SPEED} MB/s)"
               ((has_errors++))
           else
               log_success "Velocidad de descarga aceptable"
           fi
       else
           log_error "No se pudo medir la velocidad de descarga"
           ((has_errors++))
       fi

       # 4.4 Prueba de velocidad de subida
       log_info "Realizando prueba de velocidad de subida..."
       local upload_speed=0

       # Crear archivo de prueba con tamaño específico
       if dd if=/dev/zero of="$test_file" bs=1M count=$TEST_FILE_SIZE 2>/dev/null; then
           local start_time=$(date +%s.%N)

           # Intentar subida a transfer.sh (servicio gratuito de file sharing)
           if curl -s -m "$TEST_TIMEOUT" -T "$test_file" "https://transfer.sh/" >/dev/null 2>&1; then
               local end_time=$(date +%s.%N)
               local duration=$(echo "$end_time - $start_time" | bc)
               upload_speed=$(echo "scale=2; $TEST_FILE_SIZE / $duration" | bc)

               log_success "Prueba de subida completada"
           else
               log_error "Falló la prueba de subida"
               ((has_errors++))
           fi
           rm -f "$test_file"
       else
           log_error "No se pudo crear el archivo de prueba para subida"
           ((has_errors++))
       fi

       # 4.5 Evaluar resultado de subida
       if [ -n "$upload_speed" ] && [ "$upload_speed" != "0" ]; then
           log_info "Velocidad de subida: ${upload_speed} MB/s"

           if (( $(echo "$upload_speed < $MIN_UPLOAD_SPEED" | bc -l) )); then
               log_error "Velocidad de subida por debajo del mínimo requerido (${MIN_UPLOAD_SPEED} MB/s)"
               ((has_errors++))
           else
               log_success "Velocidad de subida aceptable"
           fi
       fi

       # 4.6 Resumen final
       if [ $has_errors -eq 0 ]; then
           log_success "Pruebas de velocidad completadas exitosamente"
           log_info "Resumen de velocidades:"
           log_info "- Descarga: ${download_speed} MB/s (mín: ${MIN_DOWNLOAD_SPEED} MB/s)"
           log_info "- Subida: ${upload_speed} MB/s (mín: ${MIN_UPLOAD_SPEED} MB/s)"
       else
           log_warning "Se encontraron problemas en las pruebas de velocidad"
       fi

       return $has_errors
}


# Función principal que coordina todas las verificaciones de red
check_network_requirements() {
    log_info "VERIFICACIÓN DE CONECTIVIDAD A INTERNET"
    log_info "======================================="
    local has_errors=0
    local has_warnings=0
    local start_time=$(date +%s)
    local step_results=()

    # 0. Verificar disponibilidad de herramientas necesarias
    log_info "Verificando herramientas necesarias..."
    local required_tools=("ping" "curl" "nc" "dig" "bc")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Herramientas faltantes: ${missing_tools[*]}"
        return 1
    }

    # 1. Ejecutar verificaciones en orden
    log_info "Iniciando serie de verificaciones..."

    # 1.1 Verificar conectividad básica
    log_info "Ejecutando verificación de conectividad básica..."
    if check_basic_connectivity; then
        step_results+=("✓ Conectividad básica: OK")
    else
        step_results+=("✗ Conectividad básica: FALLÓ")
        log_error "Falló la verificación de conectividad básica"
        ((has_errors++))
    fi

    # 1.2 Verificar resolución DNS
    if [ $has_errors -eq 0 ]; then
        log_info "Ejecutando verificación de DNS..."
        if check_dns_resolution; then
            step_results+=("✓ Resolución DNS: OK")
        else
            step_results+=("✗ Resolución DNS: FALLÓ")
            log_error "Falló la verificación de DNS"
            ((has_errors++))
        fi
    else
        step_results+=("- Resolución DNS: OMITIDO")
        log_warning "Omitiendo verificación DNS debido a errores previos"
    fi

    # 1.3 Verificar latencia
    if [ $has_errors -eq 0 ]; then
        log_info "Ejecutando verificación de latencia..."
        if check_network_latency; then
            step_results+=("✓ Latencia: OK")
        else
            step_results+=("! Latencia: ADVERTENCIA")
            log_warning "Se detectaron problemas de latencia"
            ((has_warnings++))
        fi
    else
        step_results+=("- Latencia: OMITIDO")
        log_warning "Omitiendo verificación de latencia debido a errores previos"
    fi

    # 1.4 Verificar velocidad de conexión
    if [ $has_errors -eq 0 ]; then
        log_info "Ejecutando verificación de velocidad..."
        if check_connection_speed; then
            step_results+=("✓ Velocidad: OK")
        else
            step_results+=("! Velocidad: ADVERTENCIA")
            log_warning "Se detectaron problemas de velocidad"
            ((has_warnings++))
        fi
    else
        step_results+=("- Velocidad: OMITIDO")
        log_warning "Omitiendo verificación de velocidad debido a errores previos"
    fi

    # 2. Calcular tiempo total de ejecución
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # 3. Mostrar resumen detallado de verificaciones
    log_info "\nResumen de verificaciones de red:"
    log_info "================================="
    printf "\n"
    for result in "${step_results[@]}"; do
        log_info "$result"
    done
    printf "\n"
    log_info "Estadísticas:"
    log_info "- Tiempo total: ${duration} segundos"
    log_info "- Errores encontrados: $has_errors"
    log_info "- Advertencias: $has_warnings"

    # 4. Determinar resultado final
    if [ $has_errors -gt 0 ]; then
        log_error "La verificación de red falló con $has_errors errores y $has_warnings advertencias"
        return 1
    elif [ $has_warnings -gt 0 ]; then
        log_warning "Verificación de red completada con $has_warnings advertencias"
        return 0
    else
        log_success "Verificación de red completada exitosamente"
        return 0
    fi
}


# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Configurar manejo de errores
    set -euo pipefail
    trap 'handle_error $? ${LINENO}' ERR

    # Validar que estamos en el contexto correcto
    validate_provision_env || {
        echo "Error: Entorno de provisión no inicializado"
        exit 1
    }

    # Ejecutar verificaciones
    check_network_requirements
    exit $?
fi

