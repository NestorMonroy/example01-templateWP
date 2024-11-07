#!/usr/bin/env bash
# Configuraciones del sistema operativo

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi
if [ ! "$(type -t check_root)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/system.sh"
fi

# Verificar que estamos como root al cargar el módulo
check_root

# Gestión de límites del sistema
set_system_limits() {
    local limit_file="/etc/security/limits.conf"
    local nofile_soft="${1:-65535}"
    local nofile_hard="${2:-65535}"

    log_info "Configurando límites del sistema..."

    # Hacer backup del archivo original si no existe
    if [ ! -f "${limit_file}.orig" ]; then
        log_info "Creando backup de ${limit_file}"
        cp "$limit_file" "${limit_file}.orig"
        if [ $? -ne 0 ]; then
            log_error "Error creando backup de ${limit_file}"
            return 1
        fi
    fi

    # Remover configuraciones existentes de nofile
    local temp_file
    temp_file=$(mktemp)
    grep -v "^*.*nofile" "$limit_file" > "$temp_file"

    # Agregar nuevas configuraciones
    cat >> "$temp_file" << EOF
# Límites configurados por el script de provisión
* soft nofile $nofile_soft
* hard nofile $nofile_hard
EOF

    # Verificar la sintaxis del archivo temporal
    if ! ulimit -n "$nofile_soft" &>/dev/null; then
        log_error "La configuración de límites parece inválida"
        rm "$temp_file"
        return 1
    fi

    # Respaldar el archivo actual y mover el nuevo
    local backup_file="${limit_file}.$(date +%Y%m%d_%H%M%S)"
    cp "$limit_file" "$backup_file"
    mv "$temp_file" "$limit_file"

    # Establecer permisos correctos
    chmod 644 "$limit_file"

    # Verificar que los cambios se aplicaron
    if grep -q "^* soft nofile $nofile_soft" "$limit_file" && \
       grep -q "^* hard nofile $nofile_hard" "$limit_file"; then
        log_success "Límites del sistema configurados correctamente"
        return 0
    else
        log_error "Error verificando la configuración de límites"
        # Restaurar backup en caso de error
        mv "$backup_file" "$limit_file"
        return 1
    fi
}

# Función para verificar límites actuales
check_system_limits() {
    local soft_limit
    local hard_limit

    soft_limit=$(ulimit -Sn)
    hard_limit=$(ulimit -Hn)

    log_info "Límites actuales del sistema:"
    log_info "Soft limit (nofile): $soft_limit"
    log_info "Hard limit (nofile): $hard_limit"

    return 0
}

# Función para restaurar límites originales
restore_system_limits() {
    local limit_file="/etc/security/limits.conf"
    local orig_file="${limit_file}.orig"

    if [ -f "$orig_file" ]; then
        log_info "Restaurando configuración original de límites..."

        if cp "$orig_file" "$limit_file"; then
            log_success "Límites del sistema restaurados"
            return 0
        else
            log_error "Error restaurando límites del sistema"
            return 1
        fi
    else
        log_error "No se encuentra el archivo original de límites"
        return 1
    fi
}

# Configuración de Swap
set_swap() {
    local size="${1:-1024}" # MB
    local swapfile="/swapfile"

    if [ -f "$swapfile" ]; then
        log_warning "Archivo swap ya existe"
        return 0
    fi

    log_info "Creando archivo swap de ${size}MB..."

    # Crear archivo swap
    dd if=/dev/zero of="$swapfile" bs=1M count="$size" status=progress
    chmod 600 "$swapfile"
    mkswap "$swapfile"
    swapon "$swapfile"

    # Hacer permanente
    if ! grep -q "^$swapfile " /etc/fstab; then
        echo "$swapfile none swap sw 0 0" >> /etc/fstab
    fi

    log_success "Swap configurado correctamente"
    return 0
}

# Configuración de zona horaria
set_timezone() {
    local timezone="${1:-UTC}"

    log_info "Configurando zona horaria a $timezone..."

    if [ ! -f "/usr/share/zoneinfo/$timezone" ]; then
        log_error "Zona horaria $timezone no válida"
        return 1
    fi

    ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
    dpkg-reconfigure -f noninteractive tzdata

    log_success "Zona horaria configurada a $timezone"
    return 0
}

# Configuración de locales
set_locale() {
    local locale="${1:-en_US.UTF-8}"

    log_info "Configurando locale a $locale..."

    # Generar locale si no existe
    if ! locale -a | grep -q "^$locale$"; then
        log_info "Generando locale $locale..."
        if ! locale-gen "$locale"; then
            log_error "Error generando locale $locale"
            return 1
        fi
    fi

    # Configurar locale por defecto
    update-locale LANG="$locale" LC_ALL="$locale"

    log_success "Locale configurado a $locale"
    return 0
}

# Configuración de kernel
set_kernel_parameter() {
    local param="$1"
    local value="$2"
    local sysctl_file="/etc/sysctl.conf"

    log_info "Configurando parámetro del kernel $param=$value..."

    # Crear backup si no existe
    if [ ! -f "${sysctl_file}.orig" ]; then
        cp "$sysctl_file" "${sysctl_file}.orig"
    fi

    # Actualizar o agregar parámetro
    if grep -q "^$param = " "$sysctl_file"; then
        sed -i "s|^$param = .*|$param = $value|" "$sysctl_file"
    else
        echo "$param = $value" >> "$sysctl_file"
    fi

    # Aplicar cambios
    if ! sysctl -p; then
        log_error "Error aplicando parámetro del kernel"
        return 1
    fi

    log_success "Parámetro del kernel configurado correctamente"
    return 0
}

# Exportar funciones
#export -f set_system_limits
#export -f check_system_limits
#export -f restore_system_limits
#export -f set_swap
#export -f set_timezone
#export -f set_locale
#export -f set_kernel_parameter