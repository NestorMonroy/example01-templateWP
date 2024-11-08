#!/bin/bash
# setup-wordpress.sh

setup_wordpress() {
    log_header "Configurando WordPress con Composer"

    # Verificar que estamos en el directorio correcto
    cd "${PROJECT_DIR}" || {
        handle_error "No se puede acceder al directorio del proyecto"
        return 1
    }

    # Crear directorios necesarios
    mkdir -p htdocs/wp-content/{plugins,themes,mu-plugins,languages,uploads}

    # Establecer permisos iniciales
    chmod 755 htdocs/wp-content
    chmod 755 htdocs/wp-content/{plugins,themes,mu-plugins,languages}
    chmod 775 htdocs/wp-content/uploads

    # Instalar dependencias con Composer
    log_info "Instalando dependencias con Composer..."
    if [ "$ENVIRONMENT" = "production" ]; then
        composer install --no-dev --optimize-autoloader --no-interaction || {
            handle_error "Error al instalar dependencias de Composer"
            return 1
        }
    else
        composer install --optimize-autoloader --no-interaction || {
            handle_error "Error al instalar dependencias de Composer"
            return 1
        }
    fi

    # Verificar la instalación
    if [ ! -d "htdocs/wordpress" ] || [ ! -f "htdocs/wordpress/wp-load.php" ]; then
        handle_error "La instalación de WordPress parece incompleta"
        return 1
    }

    # Verificar symlink de wp-content
    if [ ! -L "htdocs/wordpress/wp-content" ]; then
        log_warning "Symlink de wp-content no encontrado, creándolo..."
        rm -rf "htdocs/wordpress/wp-content"
        ln -s ../wp-content "htdocs/wordpress/wp-content" || {
            handle_error "No se pudo crear el symlink de wp-content"
            return 1
        }
    fi

    # Configurar wp-config.php
    if [ ! -f "htdocs/wp-config.php" ]; then
        log_info "Creando wp-config.php..."
        envsubst < "config/wp-config.php.template" > "htdocs/wp-config.php" || {
            handle_error "Error al crear wp-config.php"
            return 1
        }
    fi

    # Establecer permisos finales
    log_info "Estableciendo permisos finales..."
    chown -R www-data:www-data htdocs/wp-content/uploads
    find htdocs/wp-content -type d -exec chmod 755 {} \;
    find htdocs/wp-content -type f -exec chmod 644 {} \;
    chmod 775 htdocs/wp-content/uploads

    log_success "WordPress instalado y configurado correctamente"
    return 0
}

# Ejecutar solo si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_wordpress
fi