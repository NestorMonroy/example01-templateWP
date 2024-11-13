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

# Agregar después de las funciones existentes en packages.sh

# Función para validar el sistema completo de paquetes
# Uso: validate_package_system
# Ejemplo:
#   if validate_package_system; then
#       echo "Sistema de paquetes OK"
#   fi
validate_package_system() {
    log_info "Validando sistema de paquetes..."

    # Verificar y limpiar locks
    cleanup_dpkg_locks

    # Verificar base de datos de dpkg
    if ! dpkg --configure -a &>/dev/null; then
        log_error "Base de datos de dpkg corrupta"
        return 1
    }

    # Verificar sources.list
    if [ ! -f "/etc/apt/sources.list" ]; then
        log_error "sources.list no encontrado"
        return 1
    }

    # Verificar repositorios
    if ! apt_update; then
        log_error "No se puede acceder a los repositorios"
        return 1
    }

    log_success "Sistema de paquetes validado correctamente"
    return 0
}

# Función para verificar versiones específicas de paquetes
# Uso: verify_package_versions [paquete:versión] ...
# Ejemplo:
#   verify_package_versions "php:8.1" "mysql:8.0"
verify_package_versions() {
    local packages=("$@")
    local failed=0

    log_info "Verificando versiones de paquetes..."

    for package_spec in "${packages[@]}"; do
        local package_name=${package_spec%%:*}
        local required_version=${package_spec#*:}

        if ! is_package_installed "$package_name"; then
            log_error "Paquete no instalado: $package_name"
            ((failed++))
            continue
        }

        local installed_version
        installed_version=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null)

        if [[ ! "$installed_version" =~ ^$required_version ]]; then
            log_error "Versión incorrecta de $package_name: $installed_version (requerida: $required_version)"
            ((failed++))
        else
            log_success "Versión correcta de $package_name: $installed_version"
        fi
    done

    return $failed
}

# Función para instalar grupo de paquetes con logging
# Uso: install_package_group <nombre_grupo> <paquetes...>
# Ejemplo:
#   install_package_group "php" "php8.1-cli" "php8.1-fpm" "php8.1-mysql"
#   install_package_group "base" "${SYSTEM_PACKAGES[@]}"
install_package_group() {
    local group_name="$1"
    shift
    local packages=("$@")

    if [ ${#packages[@]} -eq 0 ]; then
        log_warning "No hay paquetes para instalar en el grupo $group_name"
        return 0
    }

    log_info "Instalando grupo de paquetes: $group_name"
    log_info "Paquetes a instalar: ${packages[*]}"

    # Intentar instalar
    if ! install_packages "${packages[@]}"; then
        log_error "Error instalando grupo $group_name"
        return 1
    fi

    # Verificar instalación
    local failed=0
    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            log_error "Verificación fallida para: $package"
            ((failed++))
        else
            log_success "Verificado: $package"
        fi
    done

    if [ $failed -eq 0 ]; then
        log_success "Instalación de $group_name completada exitosamente"
        return 0
    else
        log_error "Instalación de $group_name completada con $failed errores"
        return 1
    fi
}

# Función para verificar grupo de paquetes
# Uso: verify_package_group <nombre_grupo> <paquetes...>
# Ejemplo:
#   verify_package_group "php" "php8.1-cli" "php8.1-fpm" "php8.1-mysql"
#   verify_package_group "base" "${SYSTEM_PACKAGES[@]}"
verify_package_group() {
    local group_name="$1"
    shift
    local packages=("$@")
    local failed=0

    if [ ${#packages[@]} -eq 0 ]; then
        log_warning "No hay paquetes para verificar en el grupo $group_name"
        return 0
    }

    log_info "Verificando grupo de paquetes: $group_name"

    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            log_error "No instalado: $package"
            ((failed++))
            continue
        fi

        # Si el paquete tiene una versión específica requerida
        if [[ " ${PACKAGE_VERSIONS[*]} " =~ " ${package}:"* ]]; then
            local version_spec
            version_spec=$(echo "${PACKAGE_VERSIONS[@]}" | grep -o "${package}:[^ ]*")
            if ! verify_package_versions "$version_spec"; then
                ((failed++))
            fi
        fi
    done

    if [ $failed -eq 0 ]; then
        log_success "Verificación de $group_name completada exitosamente"
        return 0
    else
        log_error "Verificación de $group_name completada con $failed errores"
        return 1
    fi
}

# Función para preparar el entorno de paquetes
# Uso: prepare_package_environment
# Ejemplo:
#   if prepare_package_environment; then
#       install_packages ...
#   fi
prepare_package_environment() {
    log_info "Preparando entorno de paquetes..."

    # Limpiar locks de dpkg
    if ! cleanup_dpkg_locks; then
        log_error "Error limpiando locks de dpkg"
        return 1
    fi

    # Configurar dpkg para instalación no interactiva
    export DEBIAN_FRONTEND=noninteractive

    # Reparar dependencias rotas si existen
    if ! dpkg --configure -a; then
        log_error "Error configurando paquetes pendientes"
        return 1
    fi

    # Actualizar índices de paquetes
    if ! apt_update; then
        log_error "Error actualizando índices de paquetes"
        return 1
    fi

    log_success "Entorno de paquetes preparado correctamente"
    return 0
}

# Función para limpiar después de instalación de paquetes
# Uso: cleanup_after_install [mantener_cache]
# Ejemplo:
#   cleanup_after_install        # Limpieza completa
#   cleanup_after_install true   # Mantener cache de apt
cleanup_after_install() {
    local keep_cache="${1:-false}"
    log_info "Limpiando después de instalación..."

    # Remover paquetes huérfanos
    if ! apt-get autoremove -y; then
        log_warning "Error removiendo paquetes huérfanos"
    fi

    # Limpiar archivos temporales de dpkg
    cleanup_dpkg_locks

    # Limpiar cache de apt si no se especifica mantenerla
    if [ "$keep_cache" != "true" ]; then
        if ! apt_clean; then
            log_warning "Error limpiando cache de apt"
        fi
    fi

    log_success "Limpieza post-instalación completada"
    return 0
}


# Función para configurar paquetes instalados
# Uso: configure_installed_packages <tipo> [configuración]
# Ejemplo:
#   configure_installed_packages "php" "memory_limit=256M max_execution_time=300"
#   configure_installed_packages "mysql" "max_connections=100"
configure_installed_packages() {
    local package_type="$1"
    local configs="${2:-}"
    local config_file=""
    local modified=0

    log_info "Configurando $package_type..."

    case "$package_type" in
        "php")
            local php_version="${PHP_VERSION:-8.1}"
            config_file="/etc/php/$php_version/fpm/php.ini"
            ;;
        "mysql")
            config_file="/etc/mysql/mysql.conf.d/mysqld.cnf"
            ;;
        "nginx")
            config_file="/etc/nginx/nginx.conf"
            ;;
        *)
            log_error "Tipo de paquete no soportado: $package_type"
            return 1
            ;;
    esac

    # Verificar archivo de configuración
    if [ ! -f "$config_file" ]; then
        log_error "Archivo de configuración no encontrado: $config_file"
        return 1
    }

    # Hacer backup del archivo de configuración
    if ! safe_copy "$config_file" "${config_file}.bak" true; then
        log_error "No se pudo crear backup de $config_file"
        return 1
    }

    # Aplicar configuraciones
    IFS=' ' read -ra config_array <<< "$configs"
    for config in "${config_array[@]}"; do
        local key="${config%%=*}"
        local value="${config#*=}"

        # Usar search_replace del filesystem.sh
        if search_replace "$config_file" "^$key.*" "$key = $value" true; then
            ((modified++))
            log_info "Configuración actualizada: $key = $value"
        fi
    done

    if [ $modified -gt 0 ]; then
        log_success "Configuración de $package_type actualizada ($modified cambios)"
        return 0
    else
        log_warning "No se realizaron cambios en la configuración de $package_type"
        return 1
    fi
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
#export -f validate_package_system
#export -f verify_package_versions
#export -f configure_installed_packages

# Inicialización del módulo
# Actualizar la lista de paquetes silenciosamente al cargar el script
#apt_update >/dev/null || true