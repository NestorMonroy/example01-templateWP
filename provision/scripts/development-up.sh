#!/bin/bash

# Colores para los mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directorio principal
WORDPRESS_DIR="/data/wordpress"
CONFIG_FILE="/vagrant/config.yml"

# Función para mostrar mensajes
log_message() {
    local level=$1
    local message=$2
    case $level in
        "info")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "warn")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "error")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar requisitos
check_requirements() {
    log_message "info" "Verificando requisitos..."

    # Verificar que estamos en ambiente Vagrant
    if [ ! -d "/vagrant" ]; then
        log_message "error" "Este script debe ejecutarse dentro de Vagrant"
        exit 1
    }

    # Verificar que existe el archivo de configuración
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "error" "No se encuentra el archivo config.yml"
        exit 1
    }

    # Verificar que WP-CLI está instalado
    if ! command_exists wp; then
        log_message "error" "WP-CLI no está instalado"
        exit 1
    }
}

# Función para configurar WordPress
setup_wordpress() {
    log_message "info" "Configurando WordPress..."

    cd "$WORDPRESS_DIR" || exit 1

    # Verificar si WordPress ya está instalado
    if ! wp core is-installed --quiet; then
        log_message "info" "Instalando WordPress..."

        # Obtener valores de config.yml usando Ruby (ya que está en formato YAML)
        site_title=$(ruby -ryaml -e "puts YAML.load_file('$CONFIG_FILE')['name']")
        admin_user="admin"
        admin_password=$(openssl rand -base64 12)
        admin_email="admin@${site_title}.local"

        # Instalar WordPress
        wp core install \
            --url="https://${site_title}.local" \
            --title="$site_title" \
            --admin_user="$admin_user" \
            --admin_password="$admin_password" \
            --admin_email="$admin_email" \
            --skip-email

        # Guardar credenciales en un archivo
        echo "WordPress instalado con las siguientes credenciales:" > /vagrant/.vagrant/wp-credentials.txt
        echo "URL: https://${site_title}.local" >> /vagrant/.vagrant/wp-credentials.txt
        echo "Usuario: $admin_user" >> /vagrant/.vagrant/wp-credentials.txt
        echo "Contraseña: $admin_password" >> /vagrant/.vagrant/wp-credentials.txt
        chmod 600 /vagrant/.vagrant/wp-credentials.txt

        log_message "info" "Credenciales guardadas en .vagrant/wp-credentials.txt"
    else
        log_message "info" "WordPress ya está instalado"
    fi
}

# Función para configurar el entorno de desarrollo
setup_development_environment() {
    log_message "info" "Configurando entorno de desarrollo..."

    cd "$WORDPRESS_DIR" || exit 1

    # Activar modo debug
    wp config set WP_DEBUG true --raw
    wp config set WP_DEBUG_LOG true --raw
    wp config set WP_DEBUG_DISPLAY false --raw

    # Desactivar actualizaciones automáticas
    wp config set AUTOMATIC_UPDATER_DISABLED true --raw

    # Configurar entorno de desarrollo
    wp config set WP_ENVIRONMENT_TYPE development

    # Instalar y activar plugins útiles para desarrollo
    plugins=(
        "query-monitor"
        "debug-bar"
        "theme-check"
        "user-switching"
    )

    for plugin in "${plugins[@]}"; do
        if ! wp plugin is-installed "$plugin"; then
            wp plugin install "$plugin" --activate
        elif ! wp plugin is-active "$plugin"; then
            wp plugin activate "$plugin"
        fi
    done

    # Configurar permisos
    log_message "info" "Configurando permisos..."
    sudo chown -R vagrant:www-data .
    sudo find . -type d -exec chmod 775 {} \;
    sudo find . -type f -exec chmod 664 {} \;
    sudo chmod 660 wp-config.php
}

# Función para limpiar y optimizar
cleanup_and_optimize() {
    log_message "info" "Limpiando y optimizando..."

    cd "$WORDPRESS_DIR" || exit 1

    # Eliminar temas y plugins por defecto innecesarios
    wp theme delete twentytwenty twentytwentyone twentytwentytwo
    wp plugin delete hello akismet

    # Eliminar posts y páginas de ejemplo
    wp post delete $(wp post list --post_type=post --format=ids) --force
    wp post delete $(wp post list --post_type=page --format=ids) --force

    # Optimizar la base de datos
    wp db optimize
}

# Función principal
main() {
    log_message "info" "Iniciando configuración del entorno de desarrollo WordPress..."

    check_requirements
    setup_wordpress
    setup_development_environment
    cleanup_and_optimize

    log_message "info" "¡Configuración completada!"
    log_message "info" "Puedes encontrar las credenciales en .vagrant/wp-credentials.txt"
}

# Ejecutar el script
main