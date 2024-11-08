#!/bin/bash

# hooks/pre/02-network-checks.sh
# -------------------------------

# Verificar que estamos en el contexto correcto
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Cargar helpers necesarios
load_helpers "network.sh" "logging.sh" "error.sh"

check_network_requirements() {
    log_header "Verificación de Requisitos de Red"

    # Verificar conexión a internet
    log_info "Verificando conexión a internet..."
    if ! check_internet_connection; then
        handle_error "No hay conexión a Internet"
        return 1
    }

    # Verificar DNS y hosts requeridos
    log_info "Verificando acceso a servicios requeridos..."
    local REQUIRED_HOSTS=(
        "wordpress.org"
        "api.wordpress.org"
        "github.com"
        "packagist.org"
        "wpackagist.org"
        "downloads.wordpress.org"
    )

    local failed_hosts=()
    for host in "${REQUIRED_HOSTS[@]}"; do
        log_info "Verificando conexión a $host..."
        if ! check_host_connection "$host"; then
            failed_hosts+=("$host")
            log_warning "No se puede conectar a $host"
        else
            log_info "Conexión exitosa a $host"
        fi
    done

    if [ ${#failed_hosts[@]} -gt 0 ]; then
        handle_error "No se puede conectar a los siguientes hosts: ${failed_hosts[*]}"
        return 1
    }

    # Verificar puertos requeridos
    log_info "Verificando disponibilidad de puertos..."
    local REQUIRED_SERVICES=(
        "80:http"
        "443:https"
        "3306:mysql"
    )

    local failed_services=()
    for service in "${REQUIRED_SERVICES[@]}"; do
        local port="${service%%:*}"
        local name="${service#*:}"

        log_info "Verificando servicio $name (puerto $port)..."
        if ! check_port_availability "$port"; then
            failed_services+=("$name")
            log_warning "Puerto $port ($name) no está disponible"
        else
            log_info "Puerto $port ($name) está disponible"
        fi
    done

    if [ ${#failed_services[@]} -gt 0 ]; then
        handle_error "Los siguientes servicios no están disponibles: ${failed_services[*]}"
        return 1
    }

    # Verificar certificados SSL
    log_info "Verificando certificados SSL..."
    local HTTPS_HOSTS=(
        "wordpress.org"
        "github.com"
        "packagist.org"
        "wpackagist.org"
    )

    local ssl_warnings=0
    for host in "${HTTPS_HOSTS[@]}"; do
        log_info "Verificando certificado SSL de $host..."
        if ! check_ssl_certificate "$host"; then
            log_warning "Certificado SSL no válido o expirado para $host"
            ((ssl_warnings++))
        else
            log_info "Certificado SSL válido para $host"
        fi
    done

    if [ $ssl_warnings -gt 0 ]; then
        log_warning "Se encontraron $ssl_warnings advertencias en certificados SSL"
    }

    # Verificar velocidad de red (opcional)
    log_info "Verificando velocidad de conexión..."
    local download_speed=$(test_download_speed)
    local upload_speed=$(test_upload_speed)

    log_info "Velocidad de red:"
    log_info "- Descarga: ${download_speed} Mbps"
    log_info "- Subida: ${upload_speed} Mbps"

    if [ "$(echo "$download_speed < 1.0" | bc -l)" -eq 1 ]; then
        log_warning "La velocidad de descarga es baja (${download_speed} Mbps)"
    }

    log_success "Verificación de red completada exitosamente"
    return 0
}

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Validar que estamos en el contexto correcto
    validate_provision_env || {
        echo "Error: Entorno de provisión no inicializado"
        exit 1
    }

    # Ejecutar la verificación
    check_network_requirements
fi