#!/usr/bin/env bash
# 02-backup-existing.sh

backup_existing_installation() {
    # Cargar helpers necesarios
    load_helpers "filesystem.sh" "logging.sh" "error.sh"

    log_info "Verificando instalaciones existentes de WordPress"

    if directory_exists "$WORDPRESS_PATH"; then
        local backup_timestamp=$(get_timestamp)
        local backup_dir="${BACKUP_PATH}/${backup_timestamp}"

        create_directory "$backup_dir" || \
            fail "No se pudo crear el directorio de backup"

        # Usar funciones del helper filesystem.sh
        backup_directory "$WORDPRESS_PATH" "${backup_dir}/files.tar.gz" || \
            fail "Error al respaldar archivos de WordPress"

        if command_exists "mysqldump"; then
            backup_database "wordpress" "${backup_dir}/database.sql" || \
                fail "Error al respaldar base de datos"
        fi

        log_success "Backup creado exitosamente en ${backup_dir}"
    else
        log_info "No se encontró instalación existente de WordPress"
    fi
}