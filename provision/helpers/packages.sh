#!/usr/bin/env bash
# Funciones para gestión de paquetes y dependencias
#
# Este script proporciona funciones para gestionar paquetes en sistemas Debian/Ubuntu,
# incluyendo instalación, actualización, remoción y gestión de repositorios.
#
# Ejemplo de uso general:
#   source ./packages.sh
#
#   # Actualizar e instalar paquetes
#   apt_update
#   install_packages nginx php mysql-server
#
#   # Gestionar repositorios
#   add_ppa "ondrej/php"
#   hold_package "nginx"

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables para gestión de paquetes
# Configuraciones predeterminadas para apt-get y dpkg
APT_OPTIONS="-y --allow-downgrades --allow-remove-essential --allow-change-held-packages"
APT_QUIET="-qq"
DEBIAN_FRONTEND=noninteractive

# Cache de estado de paquetes
# Almacena el estado de instalación de paquetes para mejorar rendimiento
declare -A PACKAGE_CACHE

# Limpiar locks de dpkg
# Uso: cleanup_dpkg_locks
# Ejemplo:
#   cleanup_dpkg_locks || exit 1
cleanup_dpkg_locks() {
    log_info "Limpiando locks de dpkg..."
    local lockfiles=(/var/lib/dpkg/lock*)
    if [ "${#lockfiles[@]}" ]; then
        rm -f /var/lib/dpkg/lock*
        log_success "Locks de dpkg eliminados"
    fi
}

# Actualizar lista de paquetes
# Uso: apt_update
# Ejemplo:
#   if apt_update; then
#       echo "Repositorios actualizados"
#   fi
apt_update() {
    log_info "Actualizando lista de paquetes..."
    cleanup_dpkg_locks

    # Actualizar llaves de apt
    apt-key update -y &>/dev/null || true

    # Limpiar y actualizar
    rm -rf /var/lib/apt/lists/*
    if ! apt-get update $APT_QUIET; then
        log_error "Error actualizando paquetes"
        return 1
    fi

    log_success "Lista de paquetes actualizada"
    return 0
}

# Actualizar paquetes instalados
# Uso: apt_upgrade
# Ejemplo:
#   apt_upgrade || log_error "Fallo en actualización"
apt_upgrade() {
    log_info "Actualizando paquetes instalados..."
    cleanup_dpkg_locks

    dpkg --configure -a
    if ! apt-get $APT_OPTIONS upgrade --fix-missing; then
        log_error "Error actualizando paquetes"
        return 1
    fi

    log_success "Paquetes actualizados"
    return 0
}

# Limpiar cache de apt
# Uso: apt_clean
# Ejemplo:
#   apt_clean  # Limpia cache y paquetes no necesarios
apt_clean() {
    log_info "Limpiando cache de apt..."

    # Remover paquetes innecesarios
    apt-get autoremove -y &>/dev/null

    # Limpiar cache
    apt-get clean -y &>/dev/null

    log_success "Cache de apt limpiado"
}

# Verificar si un paquete está instalado
# Uso: is_package_installed <nombre_paquete>
# Ejemplo:
#   if is_package_installed "nginx"; then
#       echo "Nginx está instalado"
#   fi
is_package_installed() {
    local package="$1"

    # Usar cache si existe
    if [ -n "${PACKAGE_CACHE[$package]}" ]; then
        return "${PACKAGE_CACHE[$package]}"
    fi

    # Verificar instalación
    if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
        PACKAGE_CACHE[$package]=0
        return 0
    else
        PACKAGE_CACHE[$package]=1
        return 1
    fi
}

# Instalar paquetes
# Uso: install_packages <paquete1> [paquete2] [...]
# Ejemplo:
#   install_packages nginx php-fpm mysql-server
#   install_packages $(cat lista_paquetes.txt)
install_packages() {
    local packages=("$@")
    local packages_to_install=()

    # Verificar qué paquetes necesitan instalarse
    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            packages_to_install+=("$package")
        fi
    done

    # Si no hay paquetes para instalar, salir
    if [ ${#packages_to_install[@]} -eq 0 ]; then
        log_info "No hay paquetes nuevos para instalar"
        return 0
    fi

    # Actualizar e instalar
    log_info "Instalando paquetes: ${packages_to_install[*]}"
    cleanup_dpkg_locks
    apt_update

    if ! apt-get $APT_OPTIONS install --fix-missing "${packages_to_install[@]}"; then
        log_error "Error instalando paquetes"
        return 1
    fi

    # Verificar instalación
    local failed_packages=()
    for package in "${packages_to_install[@]}"; do
        if ! is_package_installed "$package"; then
            failed_packages+=("$package")
        fi
    done

    if [ ${#failed_packages[@]} -gt 0 ]; then
        log_error "Los siguientes paquetes no se instalaron correctamente: ${failed_packages[*]}"
        return 1
    fi

    log_success "Paquetes instalados correctamente"
    return 0
}

# Remover paquetes
# Uso: remove_packages <paquete1> [paquete2] [...]
# Ejemplo:
#   remove_packages apache2 mysql-server
#   remove_packages $(cat paquetes_obsoletos.txt)
remove_packages() {
    local packages=("$@")
    local packages_to_remove=()

    # Verificar qué paquetes necesitan removerse
    for package in "${packages[@]}"; do
        if is_package_installed "$package"; then
            packages_to_remove+=("$package")
        fi
    done

    # Si no hay paquetes para remover, salir
    if [ ${#packages_to_remove[@]} -eq 0 ]; then
        log_info "No hay paquetes para remover"
        return 0
    fi

    # Remover paquetes
    log_info "Removiendo paquetes: ${packages_to_remove[*]}"
    cleanup_dpkg_locks

    if ! apt-get $APT_OPTIONS remove --purge "${packages_to_remove[@]}"; then
        log_error "Error removiendo paquetes"
        return 1
    fi

    # Actualizar cache
    for package in "${packages_to_remove[@]}"; do
        PACKAGE_CACHE[$package]=1
    done

    log_success "Paquetes removidos correctamente"
    return 0
}

# Agregar un repositorio PPA
# Uso: add_ppa <nombre_ppa>
# Ejemplo:
#   add_ppa "ondrej/php"
#   add_ppa "ppa:nginx/stable"
add_ppa() {
    local ppa="$1"
    local keyring_path="/etc/apt/trusted.gpg.d"

    log_info "Agregando PPA: $ppa"

    # Verificar si add-apt-repository está instalado
    if ! command -v add-apt-repository >/dev/null; then
        install_packages software-properties-common
    fi

    # Agregar PPA
    if ! add-apt-repository -y "ppa:$ppa"; then
        log_error "Error agregando PPA: $ppa"
        return 1
    fi

    apt_update
    log_success "PPA agregado: $ppa"
    return 0
}

# Agregar una llave GPG
# Uso: add_apt_key <url_llave> [ruta_destino]
# Ejemplo:
#   add_apt_key "https://packages.example.com/key.gpg"
#   add_apt_key "https://nginx.org/keys/nginx_signing.key" "/usr/share/keyrings/nginx-archive-keyring.gpg"
add_apt_key() {
    local key_url="$1"
    local key_path="${2:-}"

    log_info "Agregando llave APT..."

    if [ -n "$key_path" ]; then
        if ! curl -fsSL "$key_url" | gpg --dearmor > "$key_path"; then
            log_error "Error descargando/instalando llave APT"
            return 1
        fi
    else
        if ! curl -fsSL "$key_url" | apt-key add -; then
            log_error "Error agregando llave APT"
            return 1
        fi
    fi

    log_success "Llave APT agregada"
    return 0
}

# Agregar un repositorio externo
# Uso: add_apt_repository <repositorio> <nombre_archivo>
# Ejemplo:
#   add_apt_repository "deb https://nginx.org/packages/debian/ bullseye nginx" "nginx.list"
add_apt_repository() {
    local repo="$1"
    local repo_file="$2"

    log_info "Agregando repositorio: $repo"

    # Crear archivo de repositorio
    echo "$repo" > "/etc/apt/sources.list.d/$repo_file"

    apt_update
    log_success "Repositorio agregado: $repo"
    return 0
}

# Mantener un paquete en su versión actual
# Uso: hold_package <nombre_paquete>
# Ejemplo:
#   hold_package "nginx"  # Evita actualizaciones de nginx
hold_package() {
    local package="$1"

    if ! is_package_installed "$package"; then
        log_error "El paquete $package no está instalado"
        return 1
    fi

    if ! apt-mark hold "$package"; then
        log_error "Error al mantener el paquete $package"
        return 1
    fi

    log_success "Paquete $package mantenido en su versión actual"
    return 0
}

# Liberar un paquete mantenido
# Uso: unhold_package <nombre_paquete>
# Ejemplo:
#   unhold_package "nginx"  # Permite actualizaciones de nginx
unhold_package() {
    local package="$1"

    if ! apt-mark unhold "$package"; then
        log_error "Error al liberar el paquete $package"
        return 1
    fi

    log_success "Paquete $package liberado"
    return 0
}

# Ejemplo de uso completo del script
: '
#!/bin/bash
source ./packages.sh

# Actualizar sistema
apt_update
apt_upgrade

# Instalar stack LEMP
PACKAGES=(
    "nginx"
    "php8.1-fpm"
    "php8.1-mysql"
    "mysql-server"
)

# Agregar repositorio PHP
add_ppa "ondrej/php"
apt_update

# Instalar paquetes
install_packages "${PACKAGES[@]}"

# Mantener versión de nginx
hold_package "nginx"

# Limpiar sistema
apt_clean
'

# Exportar funciones
#export -f cleanup_dpkg_locks
#export -f apt_update
#export -f apt_upgrade
#export -f apt_clean
#export -f is_package_installed
#export -f install_packages
#export -f remove_packages
#export -f add_ppa
#export -f add_apt_key
#export -f add_apt_repository
#export -f hold_package
#export -f unhold_package

# Inicialización del módulo
# Actualizar la lista de paquetes silenciosamente al cargar el script
#apt_update >/dev/null || true