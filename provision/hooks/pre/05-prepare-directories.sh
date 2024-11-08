# 05-prepare-directories.sh
# -------------------------------
prepare_directories() {
    # Cargar helpers necesarios
    load_helpers "filesystem.sh" "logging.sh" "error.sh"

    log_info "Preparando estructura de directorios para WordPress"

    # Crear estructura base
    declare -A wp_dirs=(
        ["${WORDPRESS_PATH}"]="755"
        ["${WORDPRESS_PATH}/wp-content/uploads"]="775"
        ["${WORDPRESS_PATH}/wp-content/plugins"]="755"
        ["${WORDPRESS_PATH}/wp-content/themes"]="755"
        ["${WORDPRESS_PATH}/wp-content/cache"]="755"
    )

    for dir in "${!wp_dirs[@]}"; do
        create_directory "$dir" "${wp_dirs[$dir]}" || \
            fail "Error al crear directorio: $dir"
    done

    # Establecer propietario correcto
    set_ownership "$WORDPRESS_PATH" "www-data" "www-data" || \
        fail "Error al establecer permisos de directorios"

    log_success "Estructura de directorios preparada correctamente"
}