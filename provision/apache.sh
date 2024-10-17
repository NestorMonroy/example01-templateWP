# !/bin/bash

# Función para ejecutar comandos de Apache
execute_apache_command() {
    # Acepta comandos de Apache como argumentos
    for command in "$@"; do
        # Ejecutar el comando usando sudo
        sudo $command || error_exit "Error al ejecutar el comando de Apache: $command."
    done
}

# Función para habilitar sitios
enable_sites() {
    # Acepta una lista de sitios a habilitar
    for site in "$@"; do
        sudo a2ensite "$site" || error_exit "Error al habilitar el sitio: $site."
    done
}

# Función para deshabilitar sitios
disable_sites() {
    # Acepta una lista de sitios a deshabilitar
    for site in "$@"; do
        sudo a2dissite "$site" || error_exit "Error al deshabilitar el sitio: $site."
    done
}

# Función para habilitar módulos
enable_modules() {
    # Acepta una lista de módulos a habilitar
    for module in "$@"; do
        sudo a2enmod "$module" || error_exit "Error al habilitar el módulo: $module."
    done
}

# Función para recargar Apache
reload_apache() {
    sudo service apache2 reload || error_exit "Error al recargar Apache."
}