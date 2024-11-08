#!/usr/bin/env bash
#  03-check-ports.sh

check_required_ports() {
    # Cargar helpers necesarios
    load_helpers "network.sh" "logging.sh" "error.sh"

    log_info "Verificando disponibilidad de puertos requeridos"

    for port in "${REQUIRED_PORTS[@]}"; do
        if ! is_port_available "$port"; then
            fail "El puerto ${port} está en uso"
        fi
    done

    log_success "Todos los puertos requeridos están disponibles"
}
