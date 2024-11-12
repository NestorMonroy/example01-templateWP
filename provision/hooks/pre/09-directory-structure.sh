#!/usr/bin/env bash
# Pre-hook: Configuración de estructura de directorios
#
# Este script crea y configura la estructura completa de directorios
# para la instalación de WordPress, incluyendo permisos y ownership.

# Cargar helpers necesarios
source "$(dirname "${BASH_SOURCE[0]}")/../../../provision/helpers/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../../provision/helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../../provision/helpers/filesystem.sh"

# Verificar que los scripts anteriores se ejecutaron
for prev in {01..08}; do
    if [ ! -f "/tmp/${prev}-*.done" ]; then
        log_error "Los scripts anteriores no se han completado"
        exit 1
    fi
done

# Estructura de directorios base
declare -A DIRECTORIES=(
    # Directorio web público
    ["${PROJECT_DIR}/htdocs"]="755:www-data:www-data"

    # WordPress core y contenido
    ["${PROJECT_DIR}/htdocs/wordpress"]="755:www-data:www-data"
    ["${PROJECT_DIR}/htdocs/wp-content"]="755:www-data:www-data"
    ["${PROJECT_DIR}/htdocs/wp-content/uploads"]="775:www-data:www-data"
    ["${PROJECT_DIR}/htdocs/wp-content/plugins"]="755:www-data:www-data"
    ["${PROJECT_DIR}/htdocs/wp-content/themes"]="755:www-data:www-data"
    ["${PROJECT_DIR}/htdocs/wp-content/mu-plugins"]="755:www-data:www-data"
    ["${PROJECT_DIR}/htdocs/wp-content/languages"]="755:www-data:www-data"

    # Directorios de configuración
    ["${PROJECT_DIR}/config"]="755:root:root"
    ["${PROJECT_DIR}/config/application"]="755:root:root"
    ["${PROJECT_DIR}/config/environments"]="755:root:root"
    ["${PROJECT_DIR}/config/dropins"]="755:www-data:www-data"

    # Directorios de caché
    ["${PROJECT_DIR}/cache"]="775:www-data:www-data"
    ["${PROJECT_DIR}/cache/php"]="775:www-data:www-data"
    ["${PROJECT_DIR}/cache/nginx"]="775:www-data:nginx"

    # Directorios de logs
    ["${PROJECT_DIR}/logs"]="755:root:root"
    ["${PROJECT_DIR}/logs/nginx"]="755:www-data:nginx"
    ["${PROJECT_DIR}/logs/php"]="755:www-data:www-data"
    ["${PROJECT_DIR}/logs/mysql"]="755:mysql:mysql"
    ["${PROJECT_DIR}/logs/security"]="750:root:root"

    # Directorios de respaldo
    ["${PROJECT_DIR}/backups"]="750:root:root"
    ["${PROJECT_DIR}/backups/database"]="750:root:root"
    ["${PROJECT_DIR}/backups/files"]="750:root:root"
)

# Enlaces simbólicos requeridos
declare -A SYMLINKS=(
    ["${PROJECT_DIR}/htdocs/wp-content"]="${PROJECT_DIR}/wordpress/wp-content"
    ["${PROJECT_DIR}/htdocs/index.php"]="${PROJECT_DIR}/wordpress/index.php"
    ["${PROJECT_DIR}/htdocs/wp-config.php"]="${PROJECT_DIR}/config/wp-config.php"
)

log_header "Configurando estructura de directorios"

# Crear directorios y establecer permisos
for dir in "${!DIRECTORIES[@]}"; do
    # Separar permisos y ownership
    IFS=: read -r perms owner group <<< "${DIRECTORIES[$dir]}"

    log_info "Configurando directorio: $dir"

    # Crear directorio si no existe
    if ! ensure_directory "$dir" "$perms" "$owner" "$group"; then
        log_error "Error al crear directorio: $dir"
        exit 1
    fi

    # Establecer permisos recursivamente
    if ! set_permissions "$dir" "$perms" "$perms" "$owner" "$group"; then
        log_error "Error al establecer permisos: $dir"
        exit 1
    fi

    log_success "Directorio configurado: $dir"
done

# Crear enlaces simbólicos
for link in "${!SYMLINKS[@]}"; do
    target="${SYMLINKS[$link]}"

    log_info "Creando enlace simbólico: $link -> $target"

    # Crear enlace simbólico
    if ! create_symlink "$target" "$link" true; then
        log_error "Error al crear enlace simbólico: $link"
        exit 1
    fi

    log_success "Enlace simbólico creado: $link"
done

# Verificar permisos de escritura en directorios críticos
critical_dirs=(
    "${PROJECT_DIR}/htdocs/wp-content/uploads"
    "${PROJECT_DIR}/cache"
    "${PROJECT_DIR}/logs"
)

for dir in "${critical_dirs[@]}"; do
    if ! check_write_permission "$dir"; then
        log_error "No hay permisos de escritura en: $dir"
        exit 1
    fi
done

# Crear archivo de completion
touch "/tmp/09-directory-structure.done"

log_success "Estructura de directorios configurada exitosamente"
exit 0