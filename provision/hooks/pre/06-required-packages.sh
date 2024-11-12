# 04-check-dependencies.sh
# -------------------------------
check_dependencies() {
    # Cargar helpers necesarios
    load_helpers "packages.sh" "logging.sh" "error.sh"

    log_info "Verificando dependencias de software"

    local missing_packages=()

    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! is_package_installed "$package"; then
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        fail "Paquetes faltantes: ${missing_packages[*]}"
    fi

    log_success "Todas las dependencias están instaladas"
}
