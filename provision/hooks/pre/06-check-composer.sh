#!/bin/bash

# 06-check-composer.sh
# -------------------------------
check_composer_requirements() {
    # Cargar helpers necesarios
    load_helpers "packages.sh" "system.sh" "logging.sh" "error.sh" "network.sh"

    log_info "Verificando requisitos de Composer"

    # Verificar PHP y extensiones requeridas
    local php_extensions=(
        "curl"
        "mbstring"
        "xml"
        "zip"
        "json"

    )

    # Verificar PHP CLI
    if ! command_exists "php"; then
        fail "PHP CLI no está instalado"
    fi

    # Verificar versión mínima de PHP
    local php_version=$(php -r "echo PHP_VERSION;")
    if ! version_greater_equal "$php_version" "7.4"; then
        fail "Se requiere PHP 7.4 o superior. Versión actual: $php_version"
    fi

    # Verificar extensiones PHP
    for ext in "${php_extensions[@]}"; do
        if ! php -m | grep -qi "^$ext$"; then
            fail "Extensión PHP requerida no encontrada: $ext"
        fi
    fi

    # Verificar/Instalar Composer
    if ! command_exists "composer"; then
        log_info "Composer no encontrado. Procediendo con la instalación"
        install_composer || fail "No se pudo instalar Composer"
    else
        log_info "Composer ya está instalado. Verificando versión..."
        composer_update_check
    fi

    # Verificar composer.json
    if [ -f "${WORDPRESS_PATH}/composer.json" ]; then
        log_info "Encontrado composer.json existente"
        validate_composer_json || fail "composer.json inválido"
    else
        log_info "Creando composer.json inicial"
        create_default_composer_json || fail "No se pudo crear composer.json"
    fi

    log_success "Verificación de Composer completada"
}

# Funciones auxiliares específicas para Composer
# -------------------------------

install_composer() {
    log_info "Instalando Composer..."

    # Verificar curl
    if ! command_exists "curl"; then
        install_package "curl" || return 1
    fi

    # Descargar el instalador
    local EXPECTED_CHECKSUM="$(curl -sSL https://composer.github.io/installer.sig)"
    curl -sSL https://getcomposer.org/installer -o composer-setup.php || return 1

    # Verificar checksum
    local ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        rm composer-setup.php
        fail "Verificación del instalador de Composer fallida"
        return 1
    fi

    # Instalar Composer globalmente
    php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer || return 1
    rm composer-setup.php

    # Verificar instalación
    if ! command_exists "composer"; then
        return 1
    fi

    return 0
}

composer_update_check() {
    if ! composer self-update --quiet; then
        log_warning "No se pudo actualizar Composer, continuando con la versión actual"
    fi
}

validate_composer_json() {
    cd "${WORDPRESS_PATH}" || return 1
    if ! composer validate --quiet; then
        return 1
    fi
    return 0
}

create_default_composer_json() {
    cat > "${WORDPRESS_PATH}/composer.json" << 'EOF'
{
    "name": "wordpress/site",
    "description": "WordPress site managed with Composer",
    "type": "project",
    "require": {
        "php": ">=7.4",
        "johnpbloch/wordpress": "^6.0",
        "wpackagist-plugin/wordpress-seo": "^20.0",
        "wpackagist-plugin/w3-total-cache": "^2.0"
    },
    "require-dev": {
        "wpackagist-plugin/query-monitor": "^3.0",
        "wpackagist-plugin/debug-bar": "^1.0"
    },
    "repositories": [
        {
            "type": "composer",
            "url": "https://wpackagist.org",
            "only": ["wpackagist-plugin/*", "wpackagist-theme/*"]
        }
    ],
    "extra": {
        "wordpress-install-dir": "wp",
        "installer-paths": {
            "wp-content/plugins/{$name}/": ["type:wordpress-plugin"],
            "wp-content/themes/{$name}/": ["type:wordpress-theme"]
        }
    },
    "config": {
        "allow-plugins": {
            "johnpbloch/wordpress-core-installer": true,
            "composer/installers": true
        }
    }
}
EOF

    # Crear .gitignore si no existe
    if [ ! -f "${WORDPRESS_PATH}/.gitignore" ]; then
        cat > "${WORDPRESS_PATH}/.gitignore" << 'EOF'
/wp
/vendor
/wp-content/plugins/*
/wp-content/themes/*
/wp-content/uploads/*
.env
EOF
    fi

    return 0
}

# Registro del nuevo hook
# -------------------------------
register_composer_hook() {
    # Debe ejecutarse después de check_dependencies pero antes de prepare_directories
    register_hook "pre-provision" "check_composer_requirements" 35
    log_success "Hook de Composer registrado exitosamente"
}

# Configuración inicial
# -------------------------------
init_composer_config() {
    # Configuración por defecto si no está definida
    : ${COMPOSER_ALLOW_SUPERUSER:=1}  # Permitir ejecutar como root
    : ${COMPOSER_NO_INTERACTION:=1}    # Modo no interactivo
    : ${COMPOSER_HOME:="/root/.composer"}

    # Exportar variables de entorno necesarias
    export COMPOSER_ALLOW_SUPERUSER
    export COMPOSER_NO_INTERACTION
    export COMPOSER_HOME

    # Registrar el hook
    register_composer_hook
}