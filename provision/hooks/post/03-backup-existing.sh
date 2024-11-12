#!/usr/bin/env bash

# hooks/pre/03-backup-existing.sh
# -------------------------------

# Verificar que estamos en el contexto correcto
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Cargar helpers necesarios
load_helpers "filesystem.sh" "logging.sh" "error.sh"

backup_existing_installation() {
    log_header "Backup de Instalación Existente"

    # Verificar espacio disponible antes de iniciar
    local required_space=$(($(get_directory_size "$WORDPRESS_PATH") * 2))
    local available_space=$(get_available_space "$BACKUP_PATH")

    if [ $available_space -lt $required_space ]; then
        handle_error "Espacio insuficiente para backup. Necesario: ${required_space}MB, Disponible: ${available_space}MB"
        return 1
    }

    # Verificar instalación existente
    if directory_exists "$WORDPRESS_PATH"; then
        log_info "Instalación existente encontrada en $WORDPRESS_PATH"

        # Crear directorio de backup con timestamp
        local backup_timestamp=$(get_timestamp)
        local backup_dir="${BACKUP_PATH}/${backup_timestamp}"

        # Crear estructura de backup
        create_directory "$backup_dir" || {
            handle_error "No se pudo crear el directorio de backup: $backup_dir"
            return 1
        }

        # Backup de archivos
        log_info "Respaldando archivos..."
        backup_directory "$WORDPRESS_PATH" "${backup_dir}/files.tar.gz" || {
            handle_error "Error al respaldar archivos de WordPress"
            return 1
        }

        # Backup de base de datos
        if command_exists "mysqldump" && check_mysql_connection; then
            log_info "Respaldando base de datos..."

            # Intentar detectar nombre de la base de datos
            local wp_config="${WORDPRESS_PATH}/wp-config.php"
            local db_name="wordpress"

            if [ -f "$wp_config" ]; then
                db_name=$(grep DB_NAME "$wp_config" | cut -d \' -f 4)
            }

            backup_database "$db_name" "${backup_dir}/database.sql" || {
                handle_error "Error al respaldar base de datos"
                return 1
            }
        else
            log_warning "No se puede realizar backup de base de datos - mysqldump no disponible"
        fi

        # Crear archivo de metadatos
        cat > "${backup_dir}/backup-info.txt" << EOF
Backup de WordPress
Fecha: $(date)
Directorio origen: $WORDPRESS_PATH
Base de datos: $db_name
Tamaño de archivos: $(du -sh "${backup_dir}/files.tar.gz" | cut -f1)
EOF

        # Verificar integridad del backup
        log_info "Verificando integridad del backup..."
        if ! verify_backup_integrity "$backup_dir"; then
            log_warning "El backup se completó pero la verificación de integridad falló"
        fi

        # Limpiar backups antiguos si es necesario
        cleanup_old_backups

        log_success "Backup completado exitosamente en ${backup_dir}"
    else
        log_info "No se encontró instalación existente en $WORDPRESS_PATH"
    fi

    return 0
}

# Función auxiliar para limpiar backups antiguos
cleanup_old_backups() {
    local max_backups=${MAX_BACKUPS:-5}
    local backup_count=$(ls -1 "$BACKUP_PATH" | wc -l)

    if [ "$backup_count" -gt "$max_backups" ]; then
        log_info "Limpiando backups antiguos..."
        ls -1t "$BACKUP_PATH" | tail -n +$((max_backups + 1)) | while read -r backup; do
            log_info "Eliminando backup antiguo: $backup"
            safe_remove "${BACKUP_PATH}/${backup}"
        done
    fi
}

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Validar que estamos en el contexto correcto
    validate_provision_env || {
        echo "Error: Entorno de provisión no inicializado"
        exit 1
    }

    # Ejecutar el backup
    backup_existing_installation
fi