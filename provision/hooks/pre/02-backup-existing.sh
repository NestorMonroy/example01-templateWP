#!/usr/bin/env bash
# Pre-hook: Backup del Sistema Existente
#
# Este hook realiza un backup completo del sistema antes de cualquier modificación,
# permitiendo rollback en caso de fallos durante la provisión.
#
# Depende de los siguientes helpers:
# - environment.sh: Para gestión del entorno y funciones de backup
# - filesystem.sh: Para operaciones de archivos
# - system.sh: Para información del sistema
# - error.sh: Para manejo consistente de errores
# - config.sh: Para variables de configuración
# - backup.sh: Para funciones específicas de backup
#
# Pasos de backup:
# 1. Validación del contexto de ejecución y ambiente
# 2. Verificación de espacio para backup
# 3. Backup de archivos WordPress
# 4. Backup de base de datos
# 5. Backup de configuraciones
# 6. Documentación del estado del sistema

# 1. Validación del contexto de ejecución
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Obtener el directorio base de provisión
HOOKS_BASE="${PROVISION_DIR}/hooks"

# Importar helpers necesarios usando la función de hooks.sh
load_helpers "environment.sh" "filesystem.sh" "system.sh" "error.sh" "backup.sh" "logging.sh"

# 1. Función para validar el entorno de backup
validate_backup_env() {
    log_info "PASO 1: Validación del Entorno de Backup"
    log_info "---------------------------------------"

    # 1.1 Verificar que estamos como root (usando system.sh)
    log_info "Verificando permisos de ejecución..."
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    }

    # 1.2 Validar inicialización del entorno (usando environment.sh)
    log_info "Verificando inicialización del entorno..."
    if ! validate_provision_env; then
        error_handle "Entorno de provisión no inicializado" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    }

    # 1.3 Validar ambiente de backup (usando backup.sh)
    log_info "Verificando configuración de backup..."
    if ! validate_backup_environment; then
        error_handle "Configuración de backup inválida" ${ERROR_CODES["BACKUP_ERROR"]}
        return 1
    }

    # 1.4 Verificar espacio en disco (usando system.sh)
    local required_space="$MIN_BACKUP_SPACE_MB"
    log_info "Verificando espacio en disco (mínimo: ${required_space}MB)..."
    if ! check_disk_space "$BACKUP_BASE_DIR" "$required_space"; then
        error_handle "Espacio insuficiente en $BACKUP_BASE_DIR" ${ERROR_CODES["DISK_FULL"]}
        return 1
    }

    # 1.5 Verificar permisos de escritura (usando filesystem.sh)
    log_info "Verificando permisos de escritura..."
    local dirs_to_check=(
        "$BACKUP_BASE_DIR:Directorio de backups"
        "$BACKUP_TEMP_DIR:Directorio temporal"
        "$WORDPRESS_PATH:Directorio WordPress"
    )

    for dir_info in "${dirs_to_check[@]}"; do
        IFS=':' read -r dir description <<< "$dir_info"
        log_info "- Verificando $description..."

        if [ -d "$dir" ]; then
            if ! check_write_permission "$dir"; then
                error_handle "Sin permisos de escritura en $description" ${ERROR_CODES["PERMISSION_DENIED"]}
                return 1
            fi
        elif [ "$dir" != "$WORDPRESS_PATH" ]; then
            if ! ensure_directory "$dir" 750 "root" "root"; then
                error_handle "No se pudo crear $description" ${ERROR_CODES["GENERAL_ERROR"]}
                return 1
            fi
        else
            log_warning "No se encontró instalación WordPress en $dir"
        fi
    done

    # 1.6 Verificar backup anterior (usando environment.sh)
    log_info "Verificando backup anterior..."
    local last_provision_time
    last_provision_time=$(get_last_provision_time)
    if [ "$last_provision_time" != "Never" ]; then
        local last_backup_dir="${BACKUP_BASE_DIR}/pre_provision_${last_provision_time}"
        if [ -d "$last_backup_dir" ]; then
            log_info "- Backup anterior encontrado: ${last_provision_time}"
            if [ "$BACKUP_RETENTION_DAYS" -gt 0 ]; then
                log_info "- Se mantendrá por $BACKUP_RETENTION_DAYS días"
            fi
        fi
    fi

    log_success "Validación del entorno completada exitosamente"
    return 0
}

# 2. Función para verificar espacio y requisitos para backup
verify_backup_requirements() {
    log_info "PASO 2: Verificación de Espacio y Requisitos para Backup"
    log_info "---------------------------------------------------"

    # 2.1 Calcular espacio necesario para WordPress
    log_info "Calculando espacio necesario..."
    local wp_size=0
    if [ -d "$WORDPRESS_PATH" ]; then
        wp_size=$(get_directory_size_mb "$WORDPRESS_PATH")
        log_info "- Tamaño WordPress: ${wp_size}MB"
    else
        log_warning "No se pudo calcular tamaño de WordPress (directorio no existe)"
    }

    # 2.2 Calcular espacio para base de datos
    local db_size=0
    log_info "Calculando tamaño de base de datos..."
    if command -v wp >/dev/null && wp core is-installed; then
        db_size=$(wp db size --format=mb | cut -d' ' -f1)
        log_info "- Tamaño Base de Datos: ${db_size}MB"
    else
        log_warning "No se pudo determinar tamaño de base de datos"
        # Asignar tamaño estimado
        db_size=100
        log_info "- Usando tamaño estimado de BD: ${db_size}MB"
    fi

    # 2.3 Calcular espacio total requerido
    local total_required=$((wp_size + db_size + MIN_BACKUP_SPACE_MB))
    local extra_space=$((total_required * 20 / 100)) # 20% extra por seguridad
    total_required=$((total_required + extra_space))

    log_info "Requisitos de espacio:"
    log_info "- Archivos WordPress: ${wp_size}MB"
    log_info "- Base de datos: ${db_size}MB"
    log_info "- Espacio mínimo adicional: ${MIN_BACKUP_SPACE_MB}MB"
    log_info "- Espacio extra (20%): ${extra_space}MB"
    log_info "- Total requerido: ${total_required}MB"

    # 2.4 Verificar espacio disponible
    local available_space
    available_space=$(get_free_space_mb "$BACKUP_BASE_DIR")
    log_info "Espacio disponible en ${BACKUP_BASE_DIR}: ${available_space}MB"

    if [ "$available_space" -lt "$total_required" ]; then
        log_error "Espacio insuficiente para backup"
        log_error "- Requerido: ${total_required}MB"
        log_error "- Disponible: ${available_space}MB"
        return 1
    fi

    # 2.5 Verificar límite máximo de backup
    if [ "$total_required" -gt "$MAX_BACKUP_SIZE_MB" ]; then
        log_error "Tamaño de backup excede el límite máximo"
        log_error "- Tamaño estimado: ${total_required}MB"
        log_error "- Límite máximo: ${MAX_BACKUP_SIZE_MB}MB"
        return 1
    fi

    # 2.6 Verificar espacio para compresión
    if [ "$BACKUP_COMPRESSION" = true ]; then
        local compression_space=$((total_required * 30 / 100)) # 30% extra para compresión
        if [ "$available_space" -lt "$((total_required + compression_space))" ]; then
            log_warning "Espacio insuficiente para compresión, se desactivará"
            BACKUP_COMPRESSION=false
        else
            log_info "Espacio reservado para compresión: ${compression_space}MB"
        fi
    fi

    # 2.7 Verificar espacio para backup temporal
    log_info "Verificando espacio en directorio temporal..."
    local temp_space
    temp_space=$(get_free_space_mb "$BACKUP_TEMP_DIR")
    if [ "$temp_space" -lt "$((total_required / 2))" ]; then
        log_error "Espacio temporal insuficiente en $BACKUP_TEMP_DIR"
        return 1
    }

    log_success "Verificación de espacio y requisitos completada"
    return 0
}

# 3. Función para realizar backup de archivos WordPress
backup_wordpress_files() {
    log_info "PASO 3: Backup de Archivos WordPress"
    log_info "-----------------------------------"

    # 3.1 Verificar existencia de directorio WordPress
    log_info "Verificando instalación WordPress..."
    if [ ! -d "$WORDPRESS_PATH" ]; then
        log_warning "Directorio WordPress no encontrado en: $WORDPRESS_PATH"
        return 0  # No es error crítico, podría ser instalación nueva
    }

    # 3.2 Preparar directorios para backup
    local backup_wp_dir="$BACKUP_DIR/files/wordpress"
    log_info "Preparando directorios de backup..."
    if ! ensure_directory "$backup_wp_dir" 750 "root" "root"; then
        log_error "No se pudo crear directorio para backup de archivos"
        return 1
    }

    # 3.3 Determinar elementos a respaldar
    local includes=()
    local excludes=()

    # 3.3.1 Configurar inclusiones según configuración
    if [ "$BACKUP_INCLUDE_PLUGINS" = true ]; then
        includes+=("wp-content/plugins")
        log_info "- Incluyendo plugins"
    fi
    if [ "$BACKUP_INCLUDE_THEMES" = true ]; then
        includes+=("wp-content/themes")
        log_info "- Incluyendo themes"
    fi
    if [ "$BACKUP_INCLUDE_UPLOADS" = true ]; then
        includes+=("wp-content/uploads")
        log_info "- Incluyendo uploads"
    fi

    # 3.3.2 Configurar exclusiones
    for pattern in "${BACKUP_EXCLUDE_PATTERNS[@]}"; do
        excludes+=("--exclude=$pattern")
        log_info "- Excluyendo: $pattern"
    done

    # 3.4 Calcular tamaño de la copia
    log_info "Calculando tamaño total a copiar..."
    local total_size
    total_size=$(get_directory_size_mb "$WORDPRESS_PATH")
    log_info "- Tamaño total: ${total_size}MB"

    # 3.5 Realizar backup con rsync
    log_info "Iniciando copia de archivos..."
    local rsync_opts=(
        -av                  # Archive mode + verbose
        --delete            # Delete extraneous files
        --relative          # Use relative paths
        "${excludes[@]}"    # Patrones de exclusión
    )

    # 3.5.1 Copiar archivos base de WordPress
    if ! rsync "${rsync_opts[@]}" \
        "$WORDPRESS_PATH"/{wp-admin,wp-includes,wp-*.php} \
        "$backup_wp_dir/" 2>/dev/null; then
        log_error "Error copiando archivos base de WordPress"
        return 1
    fi

    # 3.5.2 Copiar elementos configurados
    if [ ${#includes[@]} -gt 0 ]; then
        if ! rsync "${rsync_opts[@]}" \
            "$WORDPRESS_PATH"/"${includes[@]}" \
            "$backup_wp_dir/" 2>/dev/null; then
            log_error "Error copiando contenido WordPress"
            return 1
        fi
    fi

    # 3.6 Verificar integridad de la copia
    log_info "Verificando integridad del backup..."
    local backup_size
    backup_size=$(get_directory_size_mb "$backup_wp_dir")

    # 3.6.1 Verificar tamaño resultante
    if [ "$backup_size" -eq 0 ]; then
        log_error "Backup vacío o fallido"
        return 1
    fi

    # 3.6.2 Registrar detalles del backup
    {
        echo "=== Detalles del Backup de Archivos ==="
        echo "Fecha: $(date)"
        echo "Origen: $WORDPRESS_PATH"
        echo "Destino: $backup_wp_dir"
        echo "Tamaño original: ${total_size}MB"
        echo "Tamaño backup: ${backup_size}MB"
        echo "Elementos incluidos:"
        printf -- "- %s\n" "${includes[@]}"
        echo "Elementos excluidos:"
        printf -- "- %s\n" "${BACKUP_EXCLUDE_PATTERNS[@]}"
    } > "$BACKUP_DIR/meta/files_backup_info.txt"

    # 3.7 Comprimir si está configurado
    if [ "$BACKUP_COMPRESSION" = true ]; then
        log_info "Comprimiendo backup de archivos..."
        if ! tar -czf "$backup_wp_dir.tar.gz" -C "$backup_wp_dir" . ; then
            log_error "Error comprimiendo backup de archivos"
            return 1
        fi
        # Si la compresión fue exitosa, eliminar directorio original
        rm -rf "$backup_wp_dir"
        log_success "Backup comprimido exitosamente"
    fi

    log_success "Backup de archivos WordPress completado"
    log_info "- Elementos respaldados: ${#includes[@]}"
    log_info "- Tamaño final: ${backup_size}MB"
    return 0
}

# 4. Función para realizar backup de la base de datos
backup_database() {
    log_info "PASO 4: Backup de Base de Datos"
    log_info "------------------------------"

    # 4.1 Verificar si hay base de datos para respaldar
    log_info "Verificando base de datos WordPress..."
    if [ "$BACKUP_INCLUDE_DB" != true ]; then
        log_info "Backup de base de datos desactivado en configuración"
        return 0
    }

    # 4.2 Preparar directorio para backup de BD
    local backup_db_dir="$BACKUP_DIR/database"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local dump_file="$backup_db_dir/wordpress_${timestamp}.sql"

    log_info "Preparando directorio para backup de base de datos..."
    if ! ensure_directory "$backup_db_dir" 750 "root" "root"; then
        log_error "No se pudo crear directorio para backup de base de datos"
        return 1
    }

    # 4.3 Verificar herramientas necesarias
    log_info "Verificando herramientas necesarias..."

    # 4.3.1 Verificar WP-CLI
    if ! command -v wp >/dev/null; then
        log_error "WP-CLI no está instalado"
        return 1
    fi

    # 4.3.2 Verificar si WordPress está instalado
    if ! wp core is-installed --path="$WORDPRESS_PATH"; then
        log_warning "WordPress no está instalado o configurado"
        return 0
    }

    # 4.4 Obtener información de la base de datos
    log_info "Obteniendo información de la base de datos..."
    local db_size
    db_size=$(wp db size --format=mb | cut -d' ' -f1)
    log_info "- Tamaño de la base de datos: ${db_size}MB"

    # 4.5 Configurar opciones de mysqldump
    local dump_opts=(
        "--add-drop-table"
        "--extended-insert"
    )

    # 4.5.1 Agregar opciones según configuración
    if [ "$DB_BACKUP_SINGLE_TRANSACTION" = true ]; then
        dump_opts+=("--single-transaction")
        log_info "- Usando transacción única"
    fi
    if [ "$DB_BACKUP_ROUTINES" = true ]; then
        dump_opts+=("--routines")
        log_info "- Incluyendo rutinas"
    fi
    if [ "$DB_BACKUP_EVENTS" = true ]; then
        dump_opts+=("--events")
        log_info "- Incluyendo eventos"
    fi
    if [ "$DB_BACKUP_TRIGGERS" = true ]; then
        dump_opts+=("--triggers")
        log_info "- Incluyendo triggers"
    fi

    # 4.6 Realizar el dump
    log_info "Iniciando backup de base de datos..."
    if ! wp db export "$dump_file" "${dump_opts[@]}" --path="$WORDPRESS_PATH"; then
        log_error "Error durante el backup de la base de datos"
        return 1
    fi

    # 4.7 Verificar el dump generado
    if [ ! -f "$dump_file" ]; then
        log_error "Archivo de dump no fue creado"
        return 1
    fi

    local dump_size
    dump_size=$(get_file_size_mb "$dump_file")
    log_info "- Tamaño del dump: ${dump_size}MB"

    # 4.8 Comprimir si está configurado
    if [ "$DB_BACKUP_COMPRESS" = true ]; then
        log_info "Comprimiendo dump de base de datos..."
        if ! gzip -f "$dump_file"; then
            log_error "Error comprimiendo dump de base de datos"
            return 1
        fi
        dump_file="${dump_file}.gz"
        log_success "Dump comprimido exitosamente"
    fi

    # 4.9 Registrar información del backup
    {
        echo "=== Detalles del Backup de Base de Datos ==="
        echo "Fecha: $(date)"
        echo "Archivo: $(basename "$dump_file")"
        echo "Tamaño original: ${db_size}MB"
        echo "Tamaño dump: ${dump_size}MB"
        echo "Opciones usadas:"
        printf -- "- %s\n" "${dump_opts[@]}"
        echo "Versión MySQL: $(mysql --version)"
        echo "Compresión: $DB_BACKUP_COMPRESS"
    } > "$BACKUP_DIR/meta/database_backup_info.txt"

    log_success "Backup de base de datos completado"
    return 0
}

# 5. Función para realizar backup de configuraciones
backup_configurations() {
    log_info "PASO 5: Backup de Configuraciones"
    log_info "--------------------------------"

    # 5.1 Preparar directorio para configuraciones
    local backup_config_dir="$BACKUP_DIR/config"
    log_info "Preparando directorio para configuraciones..."
    if ! ensure_directory "$backup_config_dir" 750 "root" "root"; then
        log_error "No se pudo crear directorio para backup de configuraciones"
        return 1
    }

    # 5.2 Definir configuraciones a respaldar
    local server_configs=(
        # Configuraciones de servidor web
        "/etc/nginx/sites-available:nginx-sites:660"
        "/etc/nginx/sites-enabled:nginx-enabled:660"
        "/etc/nginx/nginx.conf:nginx-conf:644"
        "/etc/apache2/sites-available:apache-sites:660"
        "/etc/apache2/apache2.conf:apache-conf:644"
        # Configuraciones de PHP
        "/etc/php/$PHP_VERSION/fpm:php-fpm:644"
        "/etc/php/$PHP_VERSION/cli:php-cli:644"
        # Configuraciones de MySQL
        "/etc/mysql/mysql.conf.d:mysql:600"
    )

    # 5.3 Backup de archivos de configuración del servidor
    log_info "Respaldando configuraciones del servidor..."
    local failed_configs=0

    for config in "${server_configs[@]}"; do
        IFS=':' read -r src_path dest_name perms <<< "$config"
        local dest_path="$backup_config_dir/$dest_name"

        # 5.3.1 Verificar si existe la configuración
        if [ -e "$src_path" ]; then
            log_info "- Respaldando $dest_name..."

            # Crear directorio si es necesario
            ensure_directory "$(dirname "$dest_path")"

            # Copiar configuración
            if ! cp -r "$src_path" "$dest_path" 2>/dev/null; then
                log_warning "No se pudo copiar $src_path"
                ((failed_configs++))
                continue
            fi

            # Establecer permisos
            chmod -R "$perms" "$dest_path"
        else
            log_info "- Configuración no encontrada: $src_path"
        fi
    done

    # 5.4 Backup de wp-config.php
    log_info "Respaldando configuración de WordPress..."
    if [ -f "$WORDPRESS_PATH/wp-config.php" ]; then
        local wp_config_backup="$backup_config_dir/wordpress/wp-config.php"
        ensure_directory "$(dirname "$wp_config_backup")"

        if cp "$WORDPRESS_PATH/wp-config.php" "$wp_config_backup"; then
            chmod 600 "$wp_config_backup"
            log_success "- wp-config.php respaldado"
        else
            log_error "Error respaldando wp-config.php"
            ((failed_configs++))
        fi
    else
        log_warning "wp-config.php no encontrado"
    fi

    # 5.5 Backup de configuraciones de virtualhost
    log_info "Respaldando configuraciones de virtualhost..."
    local vhost_backup_dir="$backup_config_dir/vhosts"
    ensure_directory "$vhost_backup_dir"

    # 5.5.1 Nginx vhosts
    if [ -d "/etc/nginx/sites-available" ]; then
        cp -r "/etc/nginx/sites-available" "$vhost_backup_dir/nginx"
        log_success "- Configuraciones Nginx respaldadas"
    fi

    # 5.5.2 Apache vhosts
    if [ -d "/etc/apache2/sites-available" ]; then
        cp -r "/etc/apache2/sites-available" "$vhost_backup_dir/apache"
        log_success "- Configuraciones Apache respaldadas"
    fi

    # 5.6 Backup de certificados SSL si existen
    log_info "Verificando certificados SSL..."
    local ssl_backup_dir="$backup_config_dir/ssl"
    local ssl_dirs=(
        "/etc/letsencrypt/live"
        "/etc/ssl/private"
    )

    for ssl_dir in "${ssl_dirs[@]}"; do
        if [ -d "$ssl_dir" ]; then
            local dest_dir="$ssl_backup_dir/$(basename "$ssl_dir")"
            ensure_directory "$dest_dir" 700 "root" "root"

            if cp -rL "$ssl_dir" "$dest_dir" 2>/dev/null; then
                log_success "- Certificados en $ssl_dir respaldados"
            else
                log_warning "No se pudieron respaldar certificados en $ssl_dir"
                ((failed_configs++))
            fi
        fi
    done

    # 5.7 Generar resumen de configuraciones
    {
        echo "=== Resumen de Backup de Configuraciones ==="
        echo "Fecha: $(date)"
        echo "Total configuraciones verificadas: ${#server_configs[@]}"
        echo "Configuraciones fallidas: $failed_configs"
        echo
        echo "=== Configuraciones respaldadas ==="
        find "$backup_config_dir" -type f -exec ls -l {} \;
    } > "$BACKUP_DIR/meta/config_backup_info.txt"

    # 5.8 Verificar resultado
    if [ $failed_configs -gt 0 ]; then
        log_warning "Algunas configuraciones no pudieron respaldarse ($failed_configs fallos)"
        # No retornamos error para no detener el proceso
    else
        log_success "Backup de configuraciones completado exitosamente"
    fi

    return 0
}

# 6. Función para documentar estado del sistema
document_system_state() {
    log_info "PASO 6: Documentación del Estado del Sistema"
    log_info "----------------------------------------"

    # 6.1 Preparar directorio de documentación
    local doc_dir="$BACKUP_DIR/meta"
    log_info "Preparando directorio de documentación..."
    if ! ensure_directory "$doc_dir" 750 "root" "root"; then
        log_error "No se pudo crear directorio de documentación"
        return 1
    }

    # 6.2 Documentar información del sistema
    log_info "Recopilando información del sistema..."
    {
        echo "=== Información del Sistema ==="
        echo "Fecha y hora: $(date)"
        echo "Hostname: $(hostname -f)"
        echo "Sistema operativo: $(get_os_info)"
        echo "Kernel: $(uname -r)"
        echo "Arquitectura: $(uname -m)"

        # Información de recursos
        echo -e "\n=== Recursos del Sistema ==="
        echo "CPU: $(get_cpu_model)"
        echo "Cores: $(get_cpu_cores)"
        echo "Memoria total: $(get_total_memory)MB"
        echo "Memoria disponible: $(get_available_memory)MB"
        echo "Espacio en disco: $(get_disk_space)"
        echo "Carga del sistema: $(get_load_average)"

        # Estado de CPU
        check_cpu_throttling
        local throttling_status=$?
        if [ $throttling_status -eq 0 ]; then
            echo "Estado CPU: Throttling detectado"
        else
            echo "Estado CPU: Normal"
        fi
    } > "$doc_dir/system_info.txt"

    # 6.3 Documentar versiones de software
    log_info "Documentando versiones de software..."
    {
        echo "=== Versiones de Software ==="
        echo "PHP Version: $(php -v 2>/dev/null | head -n1)"
        echo "MySQL Version: $(mysql --version 2>/dev/null)"
        echo "Apache Version: $(apache2 -v 2>/dev/null | head -n1)"
        echo "Nginx Version: $(nginx -v 2>/dev/null)"
        echo "WordPress Version: $(wp core version --path="$WORDPRESS_PATH" 2>/dev/null || echo "No instalado")"

        # Información de plugins y temas si WordPress está instalado
        if wp core is-installed --path="$WORDPRESS_PATH" 2>/dev/null; then
            echo -e "\n=== Plugins de WordPress ==="
            wp plugin list --path="$WORDPRESS_PATH" --format=csv

            echo -e "\n=== Temas de WordPress ==="
            wp theme list --path="$WORDPRESS_PATH" --format=csv
        fi
    } > "$doc_dir/software_versions.txt"

    # 6.4 Documentar servicios activos
    log_info "Documentando estado de servicios..."
    {
        echo "=== Servicios Activos ==="
        systemctl list-units --type=service --state=running

        echo -e "\n=== Puertos en Uso ==="
        netstat -tuln

        echo -e "\n=== Procesos Principales ==="
        ps aux | head -n 20
    } > "$doc_dir/services_state.txt"

    # 6.5 Documentar configuraciones de red
    log_info "Documentando configuración de red..."
    {
        echo "=== Configuración de Red ==="
        echo "Interfaces:"
        ip addr show

        echo -e "\n=== Tabla de Rutas ==="
        ip route list

        echo -e "\n=== Resolución DNS ==="
        cat /etc/resolv.conf

        echo -e "\n=== Hosts ==="
        cat /etc/hosts
    } > "$doc_dir/network_config.txt"

    # 6.6 Generar manifiesto del backup
    log_info "Generando manifiesto del backup..."
    {
        echo "=== Manifiesto de Backup ==="
        echo "Timestamp: $BACKUP_TIMESTAMP"
        echo "Directorio: $BACKUP_DIR"

        echo -e "\n=== Estructura del Backup ==="
        tree -a -u -g -p "$BACKUP_DIR" 2>/dev/null || find "$BACKUP_DIR" -ls

        echo -e "\n=== Checksums ==="
        find "$BACKUP_DIR" -type f -exec sha256sum {} \; | sort -k2
    } > "$doc_dir/backup_manifest.txt"

    # 6.7 Resumen de espacio utilizado
    log_info "Calculando espacio utilizado..."
    {
        echo "=== Uso de Espacio ==="
        echo "Total backup: $(get_directory_size_mb "$BACKUP_DIR")MB"
        for subdir in "$BACKUP_DIR"/*; do
            if [ -d "$subdir" ]; then
                echo "$(basename "$subdir"): $(get_directory_size_mb "$subdir")MB"
            fi
        done
    } > "$doc_dir/space_usage.txt"

    # 6.8 Verificar documentación
    local required_docs=(
        "system_info.txt"
        "software_versions.txt"
        "services_state.txt"
        "network_config.txt"
        "backup_manifest.txt"
        "space_usage.txt"
    )

    local missing=0
    for doc in "${required_docs[@]}"; do
        if [ ! -f "$doc_dir/$doc" ]; then
            log_error "Documento faltante: $doc"
            ((missing++))
        fi
    done

    if [ $missing -gt 0 ]; then
        log_warning "Algunos documentos no se generaron ($missing faltantes)"
    else
        log_success "Documentación completada exitosamente"
    fi

    return 0
}

# Función principal del hook
main() {
    log_header "Pre-Hook: Backup del Sistema Existente"
    log_info "====================================="

    # 1. Establecer el paso actual de provisión
    export PROVISION_STEP="backup_existing"

    # 2. Definir pasos del backup
    local -A backup_steps=(
        ["validate_backup_env"]="Validación del Entorno"
        ["verify_backup_requirements"]="Verificación de Requisitos"
        ["backup_wordpress_files"]="Backup de Archivos WordPress"
        ["backup_database"]="Backup de Base de Datos"
        ["backup_configurations"]="Backup de Configuraciones"
        ["document_system_state"]="Documentación del Sistema"
    )

    # 3. Inicializar contadores
    local total_steps=${#backup_steps[@]}
    local current_step=0
    local failed_steps=0

    # 4. Registrar inicio del backup
    log_info "Iniciando proceso de backup"
    log_info "- Total de pasos: $total_steps"
    log_info "- Timestamp: $BACKUP_TIMESTAMP"
    log_info "- Directorio: $BACKUP_DIR"

    # 5. Ejecutar cada paso
    for step_func in "${!backup_steps[@]}"; do
        ((current_step++))
        local step_name="${backup_steps[$step_func]}"

        # 5.1 Mostrar progreso
        log_info ""
        log_info "Paso $current_step de $total_steps: $step_name"
        log_info "----------------------------------------"

        # 5.2 Ejecutar paso
        if ! $step_func; then
            ((failed_steps++))

            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                error_handle "Falló el paso: $step_name" ${ERROR_CODES["BACKUP_ERROR"]}
                cleanup_failed_backup
                return 1
            else
                log_warning "Falló el paso pero continuando por PROVISION_CONTINUE_ON_ERROR=true"
            fi
        fi

        # 5.3 Actualizar estado
        save_provision_state "backup_step_${current_step}_completed"

        # 5.4 Mostrar progreso
        local percent=$((current_step * 100 / total_steps))
        log_progress "$current_step" "$total_steps" "$step_name completado"
    done

    # 6. Verificación final
    log_info ""
    log_info "Realizando verificación final..."

    # 6.1 Verificar integridad del backup
    if ! backup_verify_integrity "$BACKUP_DIR"; then
        error_handle "Verificación final de integridad falló" ${ERROR_CODES["BACKUP_ERROR"]}
        return 1
    fi

    # 6.2 Registrar backup completado
    echo "$BACKUP_TIMESTAMP" > "${PROVISION_DIR}/tmp/last_backup"

    # 6.3 Generar resumen final
    {
        echo "=== Resumen del Backup ==="
        echo "Timestamp: $BACKUP_TIMESTAMP"
        echo "Directorio: $BACKUP_DIR"
        echo "Pasos totales: $total_steps"
        echo "Pasos fallidos: $failed_steps"
        echo "Espacio utilizado: $(get_directory_size_mb "$BACKUP_DIR")MB"
        echo "Fecha finalización: $(date)"
        echo "Estado: $([ $failed_steps -eq 0 ] && echo 'Exitoso' || echo 'Con advertencias')"
    } > "$BACKUP_DIR/meta/backup_summary.txt"

    # 7. Limpiar backups antiguos si es necesario
    if [ "$failed_steps" -eq 0 ]; then
        backup_cleanup "$BACKUP_BASE_DIR" "$BACKUP_RETENTION_DAYS" "pre_provision_*"
    fi

    # 8. Mostrar resultado final
    log_info ""
    if [ "$failed_steps" -eq 0 ]; then
        log_success "Backup completado exitosamente"
        log_info "- Directorio: $BACKUP_DIR"
        log_info "- Log: $BACKUP_LOG"
        return 0
    else
        log_warning "Backup completado con advertencias ($failed_steps fallos)"
        return 1
    fi
}

# Función para limpiar en caso de fallo
cleanup_failed_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        log_info "Limpiando backup fallido..."
        rm -rf "$BACKUP_DIR"
    fi
}

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 1. Verificar que somos root
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        exit 1
    fi

    # 2. Configurar manejo de errores
    set -e
    trap 'error_handle "Error en línea $LINENO" $? $LINENO' ERR

    # 3. Establecer handler específico para backup
    trap 'error_handle_backup ${ERROR_CODES["BACKUP_ERROR"]} "Error durante el backup" "$BACKUP_DIR"' ERR

    # 4. Ejecutar script
    main
    exit_code=$?

    # 5. Limpiar si es necesario
    if [ $exit_code -ne 0 ] && [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
        cleanup_failed_backup
    fi

    exit $exit_code
fi