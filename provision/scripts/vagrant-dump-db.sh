#!/bin/bash

# Colores para los mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración de directorios y archivos
WORDPRESS_DIR="/data/wordpress"
BACKUP_DIR="/vagrant/.vagrant/database"
CONFIG_FILE="/vagrant/config.yml"
DATE_FORMAT=$(date +"%Y-%m-%d_%H-%M-%S")
MAX_BACKUPS=5  # Número máximo de backups a mantener

# Función para mostrar mensajes
log_message() {
    local level=$1
    local message=$2
    case $level in
        "info")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "warn")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "error")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Función para verificar requisitos
check_requirements() {
    log_message "info" "Verificando requisitos..."

    # Verificar que estamos en ambiente Vagrant
    if [ ! -d "/vagrant" ]; then
        log_message "error" "Este script debe ejecutarse dentro de Vagrant"
        exit 1
    }

    # Verificar que WP-CLI está instalado
    if ! command -v wp >/dev/null 2>&1; then
        log_message "error" "WP-CLI no está instalado"
        exit 1
    }

    # Verificar que existe el directorio de WordPress
    if [ ! -d "$WORDPRESS_DIR" ]; then
        log_message "error" "No se encuentra el directorio de WordPress"
        exit 1
    }

    # Crear directorio de backups si no existe
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        chmod 775 "$BACKUP_DIR"
        log_message "info" "Directorio de backups creado: $BACKUP_DIR"
    fi
}

# Función para limpiar backups antiguos
cleanup_old_backups() {
    log_message "info" "Limpiando backups antiguos..."

    # Obtener lista de backups ordenados por fecha
    local backup_files=("$BACKUP_DIR"/*.sql)
    local num_backups=${#backup_files[@]}

    # Si hay más backups que el máximo permitido, eliminar los más antiguos
    if [ $num_backups -gt $MAX_BACKUPS ]; then
        local excess=$((num_backups - MAX_BACKUPS))
        for ((i=0; i<excess; i++)); do
            rm "${backup_files[i]}"
            log_message "info" "Backup antiguo eliminado: ${backup_files[i]}"
        done
    fi
}

# Función para obtener el nombre de la base de datos
get_database_name() {
    cd "$WORDPRESS_DIR" || exit 1
    wp config get DB_NAME --quiet
}

# Función para realizar el backup
perform_backup() {
    local db_name=$(get_database_name)
    local backup_file="$BACKUP_DIR/backup_${db_name}_${DATE_FORMAT}.sql"

    log_message "info" "Iniciando backup de la base de datos..."

    cd "$WORDPRESS_DIR" || exit 1

    # Exportar la base de datos
    if wp db export "$backup_file" --add-drop-table; then
        # Comprimir el archivo SQL
        gzip -f "$backup_file"
        backup_file="${backup_file}.gz"

        # Establecer permisos
        chmod 664 "$backup_file"
        chown vagrant:vagrant "$backup_file"

        log_message "info" "Backup completado: $backup_file"

        # Mostrar estadísticas
        local size=$(du -h "$backup_file" | cut -f1)
        log_message "info" "Tamaño del backup: $size"
    else
        log_message "error" "Error al realizar el backup"
        exit 1
    fi
}

# Función para generar archivo de información
generate_info_file() {
    local db_name=$(get_database_name)
    local info_file="$BACKUP_DIR/backup_${db_name}_${DATE_FORMAT}.info"

    {
        echo "Fecha de backup: $(date)"
        echo "Base de datos: $db_name"
        echo "Versión de WordPress: $(wp core version)"
        echo "Plugins activos:"
        wp plugin list --status=active --format=csv | sed 's/^/  - /'
        echo "Tema activo:"
        wp theme list --status=active --format=csv | sed 's/^/  - /'
    } > "$info_file"

    chmod 664 "$info_file"
    chown vagrant:vagrant "$info_file"
}

# Función para verificar el backup
verify_backup() {
    local backup_file="${BACKUP_DIR}/backup_$(get_database_name)_${DATE_FORMAT}.sql.gz"

    if [ -f "$backup_file" ]; then
        local size=$(du -b "$backup_file" | cut -f1)
        if [ "$size" -gt 0 ]; then
            log_message "info" "Verificación del backup exitosa"
            return 0
        fi
    fi

    log_message "error" "Verificación del backup fallida"
    return 1
}

# Función principal
main() {
    log_message "info" "Iniciando proceso de backup de la base de datos..."

    check_requirements
    perform_backup
    generate_info_file
    verify_backup
    cleanup_old_backups

    log_message "info" "Proceso de backup completado"
}

# Ejecutar el script
main