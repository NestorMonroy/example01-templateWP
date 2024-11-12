#!/usr/bin/env bash
# Funciones para gestión de backups
#
# Este módulo proporciona funciones especializadas para la gestión de backups,
# incluyendo validación de ambiente, verificación de requisitos, generación
# de metadata y verificación de integridad.
#
# Las funciones de este módulo complementan las funcionalidades existentes en:
# - filesystem.sh: Para operaciones básicas de archivos
# - error.sh: Para manejo de errores específicos de backup
# - logging.sh: Para registro detallado de operaciones
#
# Variables de configuración requeridas:
# BACKUP_BASE_DIR      - Directorio base para backups
# BACKUP_TEMP_DIR      - Directorio temporal para operaciones
# PROJECT_DIR          - Directorio del proyecto
# WORDPRESS_PATH       - Ruta a la instalación de WordPress
# BACKUP_RETENTION_DAYS- Días a mantener backups
# MAX_BACKUP_SIZE_MB   - Tamaño máximo permitido para backup
# MIN_BACKUP_SPACE_MB  - Espacio mínimo requerido
# BACKUP_EXCLUDE_PATTERNS - Array de patrones a excluir
#
# Ejemplo de uso:
#   source ./backup.sh
#
#   # Validar ambiente
#   validate_backup_environment || exit 1
#
#   # Verificar requisitos
#   backup_check_requirements "$WORDPRESS_PATH" "$BACKUP_DIR" || exit 1
#
#   # Generar metadata
#   backup_generate_metadata "$BACKUP_DIR"
#
#   # Verificar integridad
#   backup_verify_integrity "$BACKUP_DIR"

# Importar dependencias necesarias
if [ ! "$(type -t log_info)" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Función para validar ambiente de backup
# Uso: validate_backup_environment
# Retorna:
#   0 si el ambiente es válido
#   1 si hay errores en la configuración
# Ejemplo:
#   if ! validate_backup_environment; then
#       log_error "Ambiente de backup inválido"
#       exit 1
#   fi
validate_backup_environment() {
    log_info "Validando ambiente de backup..."

    # Verificar variables necesarias
    local required_vars=(
        "BACKUP_BASE_DIR"
        "BACKUP_TEMP_DIR"
        "PROJECT_DIR"
        "WORDPRESS_PATH"
        "BACKUP_RETENTION_DAYS"
        "MAX_BACKUP_SIZE_MB"
        "MIN_BACKUP_SPACE_MB"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Variable requerida no definida: $var"
            return 1
        fi
    done

    # Verificar arrays de configuración
    if [ ${#BACKUP_EXCLUDE_PATTERNS[@]} -eq 0 ]; then
        log_warning "No hay patrones de exclusión definidos"
    fi

    log_success "Ambiente de backup validado correctamente"
    return 0
}

# Función para verificar requisitos de backup
# Uso: backup_check_requirements <directorio_origen> <directorio_backup>
# Parámetros:
#   directorio_origen: Ruta al directorio a respaldar
#   directorio_backup: Ruta donde se creará el backup
# Retorna:
#   0 si se cumplen todos los requisitos
#   1 si falta algún requisito
# Ejemplo:
#   if ! backup_check_requirements "/var/www/wordpress" "/backups"; then
#       log_error "No se cumplen los requisitos para backup"
#       exit 1
#   fi
backup_check_requirements() {
    local source_dir="$1"
    local backup_dir="$2"

    log_info "Verificando requisitos de backup..."

    # Primero validar el ambiente
    if ! validate_backup_environment; then
        return 1
    fi

    # Verificar espacio considerando exclusiones
    local source_size
    source_size=$(get_directory_size_mb "$source_dir")
    local required_space=$((source_size + MIN_BACKUP_SPACE_MB))

    if ! check_disk_space "$backup_dir" "$required_space"; then
        log_error "Espacio insuficiente para backup"
        return 1
    fi

    # Verificar permisos
    if ! check_write_permission "$backup_dir"; then
        log_error "Sin permisos de escritura en directorio de backup"
        return 1
    fi

    return 0
}

# Función para generar metadata del backup
# Uso: backup_generate_metadata <directorio_backup>
# Parámetros:
#   directorio_backup: Ruta donde se guardará la metadata
# Retorna:
#   0 si la metadata se genera correctamente
#   1 si hay algún error
# Ejemplo:
#   backup_generate_metadata "/backups/wp_backup_20240101"
backup_generate_metadata() {
    local backup_dir="$1"
    local meta_file="$backup_dir/meta/backup_info.json"

    ensure_directory "$(dirname "$meta_file")"

    cat > "$meta_file" << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "wordpress_version": "$(wp core version 2>/dev/null || echo "unknown")",
    "backup_type": "pre_provision",
    "exclude_patterns": [
        $(printf '"%s",' "${BACKUP_EXCLUDE_PATTERNS[@]}" | sed 's/,$//')
    ],
    "config": {
        "compression": $BACKUP_COMPRESSION,
        "include_plugins": $BACKUP_INCLUDE_PLUGINS,
        "include_themes": $BACKUP_INCLUDE_THEMES,
        "include_uploads": $BACKUP_INCLUDE_UPLOADS,
        "include_db": $BACKUP_INCLUDE_DB
    }
}
EOF
}

# Función para verificar integridad del backup
# Uso: backup_verify_integrity <directorio_backup>
# Parámetros:
#   directorio_backup: Ruta al backup a verificar
# Retorna:
#   0 si el backup está íntegro
#   1 si hay archivos faltantes o corrupciones
# Ejemplo:
#   if ! backup_verify_integrity "/backups/wp_backup_20240101"; then
#       log_error "Backup corrupto o incompleto"
#       return 1
#   fi
backup_verify_integrity() {
    local backup_dir="$1"
    local required_files=(
        "meta/backup_info.json"
        "meta/file_manifest.txt"
    )

    for file in "${required_files[@]}"; do
        if [ ! -f "$backup_dir/$file" ]; then
            log_error "Archivo requerido faltante: $file"
            return 1
        fi
    done

    return 0
}

# Exportar funciones
#export -f validate_backup_environment
#export -f backup_check_requirements
#export -f backup_generate_metadata
#export -f backup_verify_integrity