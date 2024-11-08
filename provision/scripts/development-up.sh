#!/usr/bin/env bash

# Cargar helpers necesarios
source "$(dirname "$0")/helpers/logging.sh"
source "$(dirname "$0")/helpers/error.sh"

log_header "Configuración inicial post-arranque de la máquina virtual"

# 1. Verificación y configuración de usuarios del sistema
setup_system_users() {
    log_info "Verificando usuarios y grupos del sistema..."

    # Array de usuarios necesarios: usuario:grupo:shell:descripción
    local system_users=(
        "www-data:www-data:/usr/sbin/nologin:Web Server User"
        "nginx:nginx:/usr/sbin/nologin:Nginx User"
        "ssl-cert:ssl-cert:/usr/sbin/nologin:SSL Certificate User"
    )

    for user_info in "${system_users[@]}"; do
        IFS=':' read -r user group shell description <<< "$user_info"

        # Crear grupo si no existe
        if ! getent group "$group" >/dev/null; then
            log_info "Creando grupo $group..."
            groupadd -f "$group"
        fi

        # Crear usuario si no existe
        if ! id -u "$user" >/dev/null 2>&1; then
            log_info "Creando usuario $user ($description)..."
            useradd -r -s "$shell" -g "$group" -d "/nonexistent" -c "$description" "$user"
        fi

        # Asegurar que el usuario esté en su grupo principal
        usermod -g "$group" "$user"
    }

    # Configurar grupos adicionales para usuarios
    # Por ejemplo, añadir www-data al grupo ssl-cert para acceso a certificados
    usermod -a -G ssl-cert www-data

    log_success "Usuarios y grupos del sistema configurados correctamente"
}

# 2. Verificar requisitos del sistema
check_system_requirements() {
    log_info "Verificando requisitos del sistema..."

    if [ "$(id -u)" -ne 0 ]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi

    if [ ! -f /etc/os-release ] || ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Este script está diseñado para Ubuntu"
        exit 1
    fi

    log_success "Requisitos del sistema verificados correctamente"
}

# 3. Crear directorios base con permisos correctos
setup_base_directories() {
    log_info "Configurando directorios base..."

    # Directorios críticos del sistema
    local base_dirs=(
        "/var/log/wordpress:755:www-data:www-data"
        "/var/www:755:www-data:www-data"
        "/var/log/nginx:755:nginx:adm"
        "/etc/nginx/ssl:750:root:ssl-cert"
        "/tmp/wordpress:777:www-data:www-data"
    )

    for dir_info in "${base_dirs[@]}"; do
        IFS=':' read -r dir perms owner group <<< "$dir_info"

        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
        fi

        chmod "$perms" "$dir"
        chown "${owner}:${group}" "$dir"
    done

    log_success "Directorios base configurados correctamente"
}

# Función principal
main() {
    log_header "Iniciando configuración post-arranque"

    check_system_requirements
    setup_system_users
    setup_base_directories

    log_success "Configuración post-arranque completada exitosamente"
}

# Ejecutar script
main "$@"