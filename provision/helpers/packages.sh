#!/usr/bin/env bash
# Funciones para gestión de paquetes y dependencias

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables para gestión de paquetes
APT_OPTIONS="-y --allow-downgrades --allow-remove-essential --allow-change-held-packages"
APT_QUIET="-qq"
DEBIAN_FRONTEND=noninteractive

# Cache de estado de paquetes
declare -A PACKAGE_CACHE

# Limpiar locks de dpkg
cleanup_dpkg_locks() {
    log_info "Limpiando locks de dpkg..."
    local lockfiles=(/var/lib/dpkg/lock*)
    if [ "${#lockfiles[@]}" ]; then
        rm -f /var/lib/dpkg/lock*
        log_success "Locks de dpkg eliminados"
    fi
}

# Actualizar lista de paquetes
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
apt_clean() {
    log_info "Limpiando cache de apt..."

    # Remover paquetes innecesarios
    apt-get autoremove -y &>/dev/null

    # Limpiar cache
    apt-get clean -y &>/dev/null

    log_success "Cache de apt limpiado"
}

# Verificar si un paquete está instalado
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
unhold_package() {
    local package="$1"

    if ! apt-mark unhold "$package"; then
        log_error "Error al liberar el paquete $package"
        return 1
    fi

    log_success "Paquete $package liberado"
    return 0
}

# Inicialización del módulo
apt_update >/dev/null || true