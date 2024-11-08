#!/usr/bin/env bash
# Funciones para manejo del sistema de archivos
#
# Este módulo proporciona funciones para la gestión segura del sistema de archivos,
# incluyendo creación, modificación, copia y eliminación de archivos y directorios.
#
# Ejemplo de uso general:
#   source ./filesystem.sh
#
#   # Crear estructura de directorios
#   ensure_directory "/var/www/app" 755 "www-data" "www-data"
#
#   # Gestionar archivos de forma segura
#   safe_copy "config.orig" "config.php" true
#   set_permissions "/var/www" 644 755 "www-data" "www-data"

# Importar módulos necesarios
if [ -z "$CRESET" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Variables para permisos por defecto
# Estas variables definen los permisos y propietarios predeterminados
DEFAULT_FILE_MODE=644           # Permisos predeterminados para archivos
DEFAULT_DIR_MODE=755           # Permisos predeterminados para directorios
DEFAULT_OWNER="vagrant"        # Usuario propietario predeterminado
DEFAULT_GROUP="vagrant"        # Grupo propietario predeterminado

# Funciones de verificación básicas
# Uso: path_exists <ruta>
# Ejemplo:
#   if path_exists "/etc/hosts"; then
#       echo "El archivo existe"
#   fi
path_exists() {
    local path="$1"
    [ -e "$path" ]
}

# Verificar si es un directorio
# Uso: is_directory <ruta>
# Ejemplo:
#   if is_directory "/var/www"; then
#       echo "Es un directorio"
#   fi
is_directory() {
    local path="$1"
    [ -d "$path" ]
}

# Verificar si es un archivo
# Uso: is_file <ruta>
# Ejemplo:
#   if is_file "config.php"; then
#       echo "Es un archivo"
#   fi
is_file() {
    local path="$1"
    [ -f "$path" ]
}

# Verificar si es un enlace simbólico
# Uso: is_symlink <ruta>
# Ejemplo:
#   if is_symlink "/var/www/html"; then
#       echo "Es un enlace simbólico"
#   fi
is_symlink() {
    local path="$1"
    [ -L "$path" ]
}

# Crear un directorio si no existe
# Uso: ensure_directory <directorio> [modo] [propietario] [grupo]
# Ejemplo:
#   ensure_directory "/var/www/app" 755 "www-data" "www-data"
#   ensure_directory "/var/log/app"  # Usa valores predeterminados
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
# Uso: ensure_file <archivo> [contenido] [modo] [propietario] [grupo]
# Ejemplo:
#   ensure_file "/etc/app.conf" "config=valor" 644 "root" "root"
#   ensure_file "info.txt" "Hola mundo"  # Usa valores predeterminados
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
# Uso: create_symlink <destino> <enlace> [forzar]
# Ejemplo:
#   create_symlink "/var/www/app" "/var/www/html" true
#   create_symlink "/etc/nginx/sites-available/default" "/etc/nginx/sites-enabled/default"
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
# Copiar archivos o directorios de forma segura
# Uso: safe_copy <origen> <destino> [backup]
# Ejemplo:
#   safe_copy "config.php" "/etc/app/config.php" true
#   safe_copy "/var/www/app" "/var/www/backup"
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

# Mover archivos o directorios de forma segura
# Uso: safe_move <origen> <destino> [backup]
# Ejemplo:
#   safe_move "app.new" "app" true
#   safe_move "temp.txt" "final.txt"
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
# Uso: safe_remove <ruta> [backup]
# Ejemplo:
#   safe_remove "/var/www/old_app" true
#   safe_remove "temp.txt" false  # Eliminar sin backup
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
# Uso: set_permissions <ruta> [modo_archivo] [modo_dir] [propietario] [grupo]
# Ejemplo:
#   set_permissions "/var/www/app" 644 755 "www-data" "www-data"
#   set_permissions "config.php" 600  # Solo modo archivo
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
# Uso: search_replace <archivo> <buscar> <reemplazar> [backup]
# Ejemplo:
#   search_replace "config.php" "desarrollo" "produccion" true
#   search_replace ".env" "DEBUG=true" "DEBUG=false"
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
# Uso: check_disk_space <espacio_minimo_mb> [ruta]
# Ejemplo:
#   check_disk_space 1000 "/var/www"
#   check_disk_space 500  # Verifica root (/)
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
# Uso: temp_file=$(create_temp_file [prefijo] [sufijo])
# Ejemplo:
#   temp_file=$(create_temp_file "backup" ".sql")
#   echo "datos" > "$temp_file"
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
# Uso: temp_dir=$(create_temp_dir [prefijo])
# Ejemplo:
#   temp_dir=$(create_temp_dir "build")
#   cp -r ./src/* "$temp_dir/"
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

# Obtener espacio libre en MB para un directorio
# Uso: espacio_libre=$(get_free_space_mb "/var/www")
# Ejemplo:
#   if [ "$(get_free_space_mb "/var")" -lt 1000 ]; then
#       echo "Espacio insuficiente"
#   fi
get_free_space_mb() {
    local dir="$1"
    df -m "$dir" | awk 'NR==2 {print $4}'
}

# Obtener espacio total en MB para un directorio
# Uso: espacio_total=$(get_total_space_mb "/var/www")
# Ejemplo:
#   echo "Espacio total: $(get_total_space_mb "/var")MB"
get_total_space_mb() {
    local dir="$1"
    df -m "$dir" | awk 'NR==2 {print $2}'
}

# Obtener el tamaño de un directorio en MB
# Uso: tamaño=$(get_directory_size_mb "/var/www")
# Ejemplo:
#   echo "Tamaño del directorio: $(get_directory_size_mb "/var/www")MB"
get_directory_size_mb() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sm "$dir" | cut -f1
    else
        echo "0"
    fi
}

# Verificar permisos de escritura en un directorio
# Uso: check_write_permission "/var/www"
# Ejemplo:
#   if check_write_permission "/var/www"; then
#       echo "Tenemos permisos de escritura"
#   fi
check_write_permission() {
    local dir="$1"
    local test_file="$dir/.write_test"

    # Intentar crear un archivo de prueba
    if ! touch "$test_file" 2>/dev/null; then
        return 1
    fi

    # Limpiar archivo de prueba
    rm -f "$test_file"
    return 0
}

# Ejemplo completo de uso del script
: '
#!/bin/bash
source ./filesystem.sh

# Crear estructura de directorios para una aplicación web
ensure_directory "/var/www/app" 755 "www-data" "www-data"
ensure_directory "/var/www/app/logs" 775 "www-data" "www-data"
ensure_directory "/var/www/app/cache" 775 "www-data" "www-data"

# Crear y configurar archivos
ensure_file "/var/www/app/.env" "APP_ENV=production" 640 "www-data" "www-data"
ensure_file "/var/www/app/config.php" "<?php return [];" 644 "www-data" "www-data"

# Crear enlaces simbólicos
create_symlink "/var/www/app" "/var/www/html" true

# Copiar archivos con backup
safe_copy "/etc/nginx/nginx.conf.orig" "/etc/nginx/nginx.conf"

# Establecer permisos recursivamente
set_permissions "/var/www/app" 644 755 "
'

# Exportar funciones
#export -f path_exists
#export -f is_directory
#export -f is_file
#export -f is_symlink
#export -f ensure_directory
#export -f ensure_file
#export -f create_symlink
#export -f safe_copy
#export -f safe_move
#export -f safe_remove
#export -f set_permissions
#export -f search_replace
#export -f check_disk_space
#export -f create_temp_file
#export -f create_temp_dir
#export -f get_free_space_mb
#export -f get_total_space_mb
#export -f get_directory_size_mb
#export -f check_write_permission

# Variables exportadas
#export DEFAULT_FILE_MODE
#export DEFAULT_DIR_MODE
#export DEFAULT_OWNER
#export DEFAULT_GROUP