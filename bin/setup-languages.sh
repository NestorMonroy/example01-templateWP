#!/bin/bash

# setup-languages.sh
setup_languages() {
    log_header "Configurando idiomas de WordPress"

    # Asegurar que el directorio de idiomas existe
    create_directory "${WORDPRESS_PATH}/wp-content/languages" 775 || {
        handle_error "No se pudo crear el directorio de idiomas"
        return 1
    }

    # Instalar idiomas usando WP-CLI
    log_info "Instalando paquetes de idiomas..."

    local languages=(
        "es_ES" # Español
        "en_GB" # Inglés británico
    )

    for lang in "${languages[@]}"; do
        if ! wp language core is-installed "$lang" --path="${WORDPRESS_PATH}" --allow-root; then
            log_info "Instalando idioma: $lang"
            wp language core install "$lang" --path="${WORDPRESS_PATH}" --allow-root || {
                log_warning "No se pudo instalar el idioma: $lang"
                continue
            }
        else
            log_info "El idioma $lang ya está instalado"
        fi
    done

    # Instalar traducciones de plugins
    log_info "Actualizando traducciones de plugins..."
    wp language plugin --all update --path="${WORDPRESS_PATH}" --allow-root

    # Instalar traducciones de temas
    log_info "Actualizando traducciones de temas..."
    wp language theme --all update --path="${WORDPRESS_PATH}" --allow-root

    # Configurar idioma por defecto
    if [ -n "$WP_DEFAULT_LANG" ]; then
        log_info "Configurando idioma por defecto: $WP_DEFAULT_LANG"
        wp config set WPLANG "$WP_DEFAULT_LANG" --path="${WORDPRESS_PATH}" --allow-root
    fi

    log_success "Configuración de idiomas completada"
    return 0
}

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_languages
fi