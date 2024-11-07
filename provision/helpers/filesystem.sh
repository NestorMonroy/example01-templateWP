#!/usr/bin/env bash
# Funciones para manejo del sistema de archivos

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables para permisos por defecto
DEFAULT_FILE_MODE=644
DEFAULT_DIR_MODE=755
DEFAULT_OWNER="vagrant"
DEFAULT_GROUP="vagrant"

# Verificar si un path existe
path_exists() {
    local path="$1"
    [ -e "$path" ]
}

# Verificar si es un directorio
is_directory() {
    local path="$1"
    [ -d "$path" ]
}

# Verificar si es un archivo
is_file() {
    local path="$1"
    [ -f "$path" ]
}

# Verificar si es un enlace simbólico
is_symlink() {
    local path="$1"
    [ -L "$path" ]
}

# Crear un directorio si no existe
ensure_directory() {
    local dir="$1"
    local mode="${2:-$DEFAULT_DIR_MODE}"
    local owner="${3:-$DEFAULT_OWNER}"
    local group="${4:-$DEFAULT_GROUP}"

    if ! is_directory "$dir"; then
        log_info "Creando directorio: $dir"
        if ! mkdir -p "$dir"; then
            log_error "Error creando directorio: $dir"
            return 1
        fi
    fi

    # Establecer permisos
    chmod "$mode" "$dir"
    chown "${owner}:${group}" "$dir"

    log_success "Directorio asegurado: $dir"
    return 0
}

# Crear un archivo si no existe
ensure_file() {
    local file="$1"
    local content="${2:-}"
    local mode="${3:-$DEFAULT_FILE_MODE}"
    local owner="${4:-$DEFAULT_OWNER}"
    local group="${5:-$DEFAULT_GROUP}"

    # Crear directorio padre si no existe
    local parent_dir
    parent_dir=$(dirname "$file")
    ensure_directory "$parent_dir"

    # Crear archivo si no existe
    if ! is_file "$file"; then
        log_info "Creando archivo: $file"
        if ! touch "$file"; then
            log_error "Error creando archivo: $file"
            return 1
        fi
    fi

    # Escribir contenido si se proporciona
    if [ -n "$content" ]; then
        echo "$content" > "$file"
    fi

    # Establecer permisos
    chmod "$mode" "$file"
    chown "${owner}:${group}" "$file"

    log_success "Archivo asegurado: $file"
    return 0
}

# Crear un enlace simbólico
create_symlink() {
    local target="$1"
    local link="$2"
    local force="${3:-false}"

    # Verificar que el target existe
    if ! path_exists "$target"; then
        log_error "El target no existe: $target"
        return 1
    fi

    # Remover enlace existente si force=true
    if [ "$force" = true ] && path_exists "$link"; then
        rm -f "$link"
    fi

    # Crear enlace
    if ! ln -s "$target" "$link"; then
        log_error "Error creando enlace simbólico: $link -> $target"
        return 1
    fi

    log_success "Enlace simbólico creado: $link -> $target"
    return 0
}

# Copiar archivos o directorios
safe_copy() {
    local source="$1"
    local dest="$2"
    local backup="${3:-true}"

    # Verificar que el source existe
    if ! path_exists "$source"; then
        log_error "El source no existe: $source"
        return 1
    fi

    # Hacer backup si existe el destino
    if [ "$backup" = true ] && path_exists "$dest"; then
        local backup_path="${dest}.backup.$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$backup_path"
        log_info "Backup creado: $backup_path"
    fi

    # Copiar
    if ! cp -R "$source" "$dest"; then
        log_error "Error copiando: $source -> $dest"
        return 1
    fi

    log_success "Copia completada: $source -> $dest"
    return 0
}

# Mover archivos o directorios
safe_move() {
    local source="$1"
    local dest="$2"
    local backup="${3:-true}"

    # Verificar que el source existe
    if ! path_exists "$source"; then
        log_error "El source no existe: $source"
        return 1
    fi

    # Hacer backup si existe el destino
    if [ "$backup" = true ] && path_exists "$dest"; then
        local backup_path="${dest}.backup.$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$backup_path"
        log_info "Backup creado: $backup_path"
    fi

    # Mover
    if ! mv "$source" "$dest"; then
        log_error "Error moviendo: $source -> $dest"
        return 1
    fi

    log_success "Movimiento completado: $source -> $dest"
    return 0
}

# Eliminar archivos o directorios de forma segura
safe_remove() {
    local path="$1"
    local backup="${2:-true}"

    # Si no existe, salir
    if ! path_exists "$path"; then
        log_info "Path no existe: $path"
        return 0
    fi

    # Hacer backup si se solicita
    if [ "$backup" = true ]; then
        local backup_path="${path}.backup.$(date +%Y%m%d%H%M%S)"
        mv "$path" "$backup_path"
        log_info "Backup creado: $backup_path"
    else
        # Eliminar
        if ! rm -rf "$path"; then
            log_error "Error eliminando: $path"
            return 1
        fi
    fi

    log_success "Eliminación completada: $path"
    return 0
}

# Establecer permisos recursivamente
set_permissions() {
    local path="$1"
    local file_mode="${2:-$DEFAULT_FILE_MODE}"
    local dir_mode="${3:-$DEFAULT_DIR_MODE}"
    local owner="${4:-$DEFAULT_OWNER}"
    local group="${5:-$DEFAULT_GROUP}"

    if ! path_exists "$path"; then
        log_error "Path no existe: $path"
        return 1
    fi

    # Establecer propietario
    chown -R "${owner}:${group}" "$path"

    if is_directory "$path"; then
        # Establecer permisos para directorios
        find "$path" -type d -exec chmod "$dir_mode" {} \;
        # Establecer permisos para archivos
        find "$path" -type f -exec chmod "$file_mode" {} \;
    else
        # Establecer permisos para archivo
        chmod "$file_mode" "$path"
    fi

    log_success "Permisos establecidos para: $path"
    return 0
}

# Buscar y reemplazar en archivos
search_replace() {
    local file="$1"
    local search="$2"
    local replace="$3"
    local backup="${4:-true}"

    if ! is_file "$file"; then
        log_error "Archivo no existe: $file"
        return 1
    fi

    # Hacer backup si se solicita
    if [ "$backup" = true ]; then
        local backup_path="${file}.backup.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup_path"
        log_info "Backup creado: $backup_path"
    fi

    # Realizar reemplazo
    if ! sed -i "s|${search}|${replace}|g" "$file"; then
        log_error "Error en búsqueda y reemplazo: $file"
        return 1
    fi

    log_success "Búsqueda y reemplazo completado en: $file"
    return 0
}

# Verificar espacio en disco
check_disk_space() {
    local min_space="$1" # en MB
    local path="${2:-/}"

    local available_space
    available_space=$(df -m "$path" | awk 'NR==2 {print $4}')

    if [ "$available_space" -lt "$min_space" ]; then
        log_error "Espacio insuficiente en $path: ${available_space}MB (mínimo: ${min_space}MB)"
        return 1
    fi

    log_success "Espacio en disco suficiente: ${available_space}MB"
    return 0
}

# Crear archivo temporal
create_temp_file() {
    local prefix="${1:-tmp}"
    local suffix="${2:-}"

    local temp_file
    temp_file=$(mktemp "/tmp/${prefix}.XXXXXX${suffix}")

    if [ ! -f "$temp_file" ]; then
        log_error "Error creando archivo temporal"
        return 1
    fi

    echo "$temp_file"
    return 0
}

# Crear directorio temporal
create_temp_dir() {
    local prefix="${1:-tmp}"

    local temp_dir
    temp_dir=$(mktemp -d "/tmp/${prefix}.XXXXXX")

    if [ ! -d "$temp_dir" ]; then
        log_error "Error creando directorio temporal"
        return 1
    fi

    echo "$temp_dir"
    return 0
}