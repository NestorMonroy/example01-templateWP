#!/usr/bin/env bash
# Pre-hook: Configuración de Composer y WordPress
#
# Este script realiza la instalación y configuración de Composer, junto con
# la instalación de WordPress y sus dependencias vía Composer.
#
#

# Verificar que se ejecuta desde el sistema de provisión
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Obtener el directorio base de provisión
HOOKS_BASE="${PROVISION_DIR}/hooks"

# Importar helpers necesarios
load_helpers "system.sh" "packages.sh" "network.sh" "filesystem.sh" "services.sh" "error.sh" "logging.sh"

# 1. Función para validar el entorno
validate_composer_env() {
    log_info "PASO 1: Validación del Entorno para Composer"
    log_info "----------------------------------------"

    # 1.1 Verificar que somos root
    log_info "Verificando permisos de ejecución..."
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    fi

    # 1.2 Validar inicialización del entorno
    log_info "Verificando inicialización del entorno..."
    if ! validate_provision_env; then
        error_handle "Entorno de provisión no inicializado" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    fi

    # 1.3 Verificar conectividad a Internet
    log_info "Verificando conectividad a Internet..."
    if ! check_internet_connection; then
        error_handle "Se requiere conexión a Internet" ${ERROR_CODES["NETWORK_ERROR"]}
        return 1
    fi

    # 1.4 Verificar PHP instalado
    log_info "Verificando instalación de PHP..."
    if ! command -v php >/dev/null; then
        log_error "PHP no está instalado"
        return 1
    fi

    # 1.5 Verificar versión de PHP
    log_info "Verificando versión de PHP..."
    if ! verify_software_version "php" "${PHP_VERSION}" "-v" "PHP"; then
        error_handle "Versión de PHP incorrecta" ${ERROR_CODES["DEPENDENCY_ERROR"]}
        return 1
    fi

    # 1.6 Verificar directorio de WordPress
    log_info "Verificando directorio de WordPress..."
    if ! ensure_directory "$WORDPRESS_PATH" 755 "www-data" "www-data"; then
        error_handle "No se pudo crear/verificar el directorio WordPress" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    fi

    # 1.7 Verificar permisos de escritura
    log_info "Verificando permisos de escritura..."
    local dirs_to_check=(
        "$WORDPRESS_PATH:Directorio WordPress"
        "/usr/local/bin:Directorio de binarios"
    )

    for dir_info in "${dirs_to_check[@]}"; do
        IFS=':' read -r dir description <<< "$dir_info"
        log_info "- Verificando $description..."

        if [ ! -d "$dir" ]; then
            error_handle "Directorio no encontrado: $description" ${ERROR_CODES["FILE_NOT_FOUND"]}
            return 1
        fi

        if ! check_write_permission "$dir"; then
            error_handle "Sin permisos de escritura en $description" ${ERROR_CODES["PERMISSION_DENIED"]}
            return 1
        fi
    done

    log_success "Validación del entorno completada exitosamente"
    return 0
}

# 2. Función para verificar requisitos de PHP
verify_php_requirements() {
    log_info "PASO 2: Verificación de Requisitos de PHP"
    log_info "----------------------------------------"

    # 2.1 Verificar memoria disponible para PHP
    log_info "Verificando límites de memoria PHP..."
    local current_memory_limit
    current_memory_limit=$(php -r "echo ini_get('memory_limit');")

    if ! verify_software_config "/etc/php/${PHP_VERSION}/cli/php.ini" \
        "memory_limit=${PHP_DEVELOPMENT_CONFIG[memory_limit]}" \
        "max_execution_time=${PHP_DEVELOPMENT_CONFIG[max_execution_time]}"; then
        log_warning "La configuración de PHP no es óptima para Composer"

        # Intentar configurar PHP CLI específicamente para Composer
        log_info "Configurando PHP CLI para Composer..."
        if ! configure_php_cli; then
            error_handle "No se pudo configurar PHP para Composer" ${ERROR_CODES["INVALID_CONFIG"]}
            return 1
        fi
    fi

    # 2.2 Verificar extensiones requeridas
    log_info "Verificando extensiones PHP requeridas..."
    if ! verify_php_extensions "${PHP_REQUIRED_EXTENSIONS[@]}"; then
        # Intentar instalar extensiones faltantes
        log_info "Instalando extensiones PHP faltantes..."
        for ext in "${PHP_REQUIRED_EXTENSIONS[@]}"; do
            install_packages "php${PHP_VERSION}-${ext}" || true
        done

        # Verificar nuevamente
        if ! verify_php_extensions "${PHP_REQUIRED_EXTENSIONS[@]}"; then
            error_handle "No se pudieron instalar todas las extensiones requeridas" ${ERROR_CODES["DEPENDENCY_ERROR"]}
            return 1
        fi
    fi

    # 2.3 Verificar opciones de PHP para desarrollo
    log_info "Verificando configuración de PHP para desarrollo..."
    local php_cli_config="/etc/php/${PHP_VERSION}/cli/php.ini"
    local php_fpm_config="/etc/php/${PHP_VERSION}/fpm/php.ini"

    for config_file in "$php_cli_config" "$php_fpm_config"; do
        if [ -f "$config_file" ]; then
            log_info "Verificando: $config_file"
            for key in "${!PHP_DEVELOPMENT_CONFIG[@]}"; do
                local value="${PHP_DEVELOPMENT_CONFIG[$key]}"
                if ! grep -q "^$key\s*=\s*$value" "$config_file"; then
                    log_warning "Configuración no óptima en $config_file: $key = $value"
                fi
            done
        fi
    done

    # 2.4 Verificar estado del servicio PHP-FPM
    log_info "Verificando servicio PHP-FPM..."
    if ! service_is_running "php${PHP_VERSION}-fpm"; then
        log_warning "PHP-FPM no está en ejecución"
        if ! service_control "start" "php${PHP_VERSION}-fpm" "PHP-FPM"; then
            error_handle "No se pudo iniciar PHP-FPM" ${ERROR_CODES["SERVICE_ERROR"]}
            return 1
        fi
    fi

    log_success "Verificación de requisitos PHP completada exitosamente"
    return 0
}

# Función auxiliar para configurar PHP CLI
configure_php_cli() {
    local php_cli_ini="/etc/php/${PHP_VERSION}/cli/php.ini"

    for key in "${!PHP_DEVELOPMENT_CONFIG[@]}"; do
        local value="${PHP_DEVELOPMENT_CONFIG[$key]}"
        if ! search_replace "$php_cli_ini" "^;?${key}\s*=.*" "${key} = ${value}"; then
            log_error "No se pudo configurar $key en PHP CLI"
            return 1
        fi
    done

    return 0
}

# 3. Función para instalar Composer
install_composer() {
    log_info "PASO 3: Instalación de Composer"
    log_info "------------------------------"

    # 3.1 Verificar si Composer ya está instalado
    if command -v composer >/dev/null && [ -x "${COMPOSER_CONFIG[bin_path]}" ]; then
        local current_version
        current_version=$(composer --version | cut -d' ' -f3)
        log_info "Composer ya está instalado (versión: $current_version)"

        # Verificar si es la versión requerida
        if [ "$current_version" = "${COMPOSER_CONFIG[version]}" ]; then
            log_success "Composer ya está en la versión correcta"
            return 0
        fi
        log_info "Se actualizará Composer a la versión ${COMPOSER_CONFIG[version]}"
    fi

    # 3.2 Crear directorio temporal para la instalación
    local temp_dir
    temp_dir=$(mktemp -d)
    log_info "Usando directorio temporal: $temp_dir"

    # 3.3 Descargar instalador de Composer
    log_info "Descargando instalador de Composer..."
    local installer="$temp_dir/composer-setup.php"
    if ! download_file "${COMPOSER_CONFIG[download_url]}" "$installer" "Instalador de Composer"; then
        error_handle "Error descargando instalador de Composer" ${ERROR_CODES["NETWORK_ERROR"]}
        rm -rf "$temp_dir"
        return 1
    fi

    # 3.4 Verificar firma del instalador
    log_info "Verificando firma del instalador..."
    if ! verify_checksum "$installer" "${COMPOSER_CONFIG[checksum]}" "sha384"; then
        error_handle "Firma del instalador de Composer inválida" ${ERROR_CODES["SECURITY_ERROR"]}
        rm -rf "$temp_dir"
        return 1
    fi

    # 3.5 Ejecutar instalación
    log_info "Instalando Composer..."
    if ! php "$installer" \
        --quiet \
        --install-dir=/usr/local/bin \
        --filename=composer; then
        error_handle "Error durante la instalación de Composer" ${ERROR_CODES["GENERAL_ERROR"]}
        rm -rf "$temp_dir"
        return 1
    fi

    # 3.6 Limpiar instalador
    rm -rf "$temp_dir"

    # 3.7 Verificar instalación
    if ! composer --version >/dev/null 2>&1; then
        error_handle "Error verificando instalación de Composer" ${ERROR_CODES["GENERAL_ERROR"]}
        return 1
    fi

    # 3.8 Configurar permisos
    log_info "Configurando permisos..."
    if ! chmod 755 "${COMPOSER_CONFIG[bin_path]}"; then
        error_handle "Error configurando permisos de Composer" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    fi

    # 3.9 Configurar ambiente global
    log_info "Configurando ambiente de Composer..."
    composer config -g process-timeout 3000
    composer config -g preferred-install dist
    composer config -g github-protocols https
    composer clear-cache

    # 3.10 Verificar configuración final
    local installed_version
    installed_version=$(composer --version | cut -d' ' -f3)
    if [ "$installed_version" = "${COMPOSER_CONFIG[version]}" ]; then
        log_success "Composer ${COMPOSER_CONFIG[version]} instalado correctamente"
        return 0
    else
        log_error "Versión instalada ($installed_version) no coincide con la requerida (${COMPOSER_CONFIG[version]})"
        return 1
    fi
}

# 4. Función para configurar PHP en modo desarrollo
configure_php_for_development() {
    log_info "PASO 4: Configuración de PHP para Desarrollo"
    log_info "-------------------------------------------"

    # 4.1 Identificar archivos de configuración
    log_info "Identificando archivos de configuración..."
    local php_ini_files=(
        "/etc/php/${PHP_VERSION}/cli/php.ini:CLI"
        "/etc/php/${PHP_VERSION}/fpm/php.ini:FPM"
    )

    local config_changed=false

    # 4.2 Iterar sobre cada archivo de configuración
    for php_ini_info in "${php_ini_files[@]}"; do
        IFS=':' read -r php_ini type <<< "$php_ini_info"

        if [ ! -f "$php_ini" ]; then
            log_error "No se encontró archivo de configuración PHP para $type: $php_ini"
            continue
        }

        log_info "Configurando PHP $type ($php_ini)..."

        # 4.3 Configurar opciones de desarrollo
        for key in "${!PHP_DEVELOPMENT_CONFIG[@]}"; do
            local value="${PHP_DEVELOPMENT_CONFIG[$key]}"
            log_info "- Configurando $key = $value"

            if ! search_replace "$php_ini" "^;?\s*$key\s*=.*" "$key = $value"; then
                log_error "No se pudo configurar $key en $php_ini"
                continue
            fi
            config_changed=true
        done

        # 4.4 Configuraciones adicionales específicas para desarrollo
        local dev_settings=(
            "display_startup_errors = On"
            "log_errors = On"
            "error_log = /var/log/php/error.log"
            "html_errors = On"
            "zend.exception_ignore_args = Off"
            "zend.exception_string_param_max_len = 15"
            "xdebug.show_exception_trace = Off"
        )

        for setting in "${dev_settings[@]}"; do
            local key="${setting%%=*}"
            local value="${setting#*=}"

            log_info "- Configurando $key = $value"
            if ! search_replace "$php_ini" "^;?\s*$key\s*=.*" "$setting"; then
                log_error "No se pudo configurar $setting en $php_ini"
                continue
            fi
            config_changed=true
        done
    done

    # 4.5 Crear directorio para logs si no existe
    if [ ! -d "/var/log/php" ]; then
        log_info "Creando directorio para logs de PHP..."
        if ! ensure_directory "/var/log/php" 775 "www-data" "www-data"; then
            log_error "No se pudo crear el directorio de logs"
            return 1
        fi
    fi

    # 4.6 Reiniciar PHP-FPM si hubo cambios
    if [ "$config_changed" = true ]; then
        log_info "Aplicando cambios en PHP-FPM..."
        if ! service_control "restart" "php${PHP_VERSION}-fpm" "PHP-FPM"; then
            log_error "Error reiniciando PHP-FPM"
            return 1
        fi
        log_success "PHP-FPM reiniciado exitosamente"
    else
        log_info "No se requieren cambios en la configuración"
    fi

    # 4.7 Verificar configuración
    log_info "Verificando configuración..."
    local config_errors=0

    for key in "${!PHP_DEVELOPMENT_CONFIG[@]}"; do
        local expected="${PHP_DEVELOPMENT_CONFIG[$key]}"
        local actual
        actual=$(php -r "echo ini_get('$key');")

        if [ "$actual" != "$expected" ]; then
            log_error "Configuración incorrecta para $key:"
            log_error "- Esperado: $expected"
            log_error "- Actual: $actual"
            ((config_errors++))
        fi
    done

    if [ $config_errors -gt 0 ]; then
        error_handle "Se encontraron $config_errors errores en la configuración" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    fi

    log_success "Configuración de PHP para desarrollo completada"
    return 0
}

# 5. Función para instalar WordPress vía Composer
install_wordpress_composer() {
    log_info "PASO 5: Instalación de WordPress vía Composer"
    log_info "------------------------------------------"

    # 5.1 Verificar composer.json
    log_info "Verificando composer.json..."
    if [ ! -f "${WORDPRESS_PATH}/composer.json" ]; then
        error_handle "No se encontró composer.json en ${WORDPRESS_PATH}" ${ERROR_CODES["FILE_NOT_FOUND"]}
        return 1
    }

    # 5.2 Validar composer.json
    log_info "Validando composer.json..."
    if ! composer validate "${WORDPRESS_PATH}/composer.json" --strict; then
        error_handle "composer.json inválido" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    }

    # 5.3 Cambiar al directorio de WordPress
    log_info "Cambiando al directorio de WordPress..."
    if ! cd "${WORDPRESS_PATH}"; then
        error_handle "No se pudo acceder al directorio ${WORDPRESS_PATH}" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    }

    # 5.4 Instalar dependencias
    log_info "Instalando dependencias via Composer..."
    export COMPOSER_ALLOW_SUPERUSER=1

    local composer_options=(
        "--no-interaction"
        "--prefer-dist"
        "--optimize-autoloader"
    )

    # Verificar si estamos en desarrollo
    if [ "${APP_ENV:-production}" = "development" ]; then
        composer_options+=("--dev")
    else
        composer_options+=("--no-dev")
    fi

    if ! composer install "${composer_options[@]}"; then
        error_handle "Error instalando dependencias de Composer" ${ERROR_CODES["DEPENDENCY_ERROR"]}
        return 1
    fi

    # 5.5 Verificar instalación
    log_info "Verificando instalación..."

    # 5.5.1 Verificar estructura básica de WordPress
    local required_files=(
        "wp-config.php"
        "wp-content"
        "wp-admin"
        "wp-includes"
        "index.php"
    )

    local missing_files=()
    for file in "${required_files[@]}"; do
        if [ ! -e "$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Faltan archivos requeridos: ${missing_files[*]}"
        return 1
    fi

    # 5.5.2 Verificar permisos
    log_info "Configurando permisos..."

    # Configurar permisos de archivos y directorios
    find . -type f -exec chmod 644 {} \;
    find . -type d -exec chmod 755 {} \;

    # Permisos especiales para wp-content
    chmod 775 wp-content
    chmod 775 wp-content/themes
    chmod 775 wp-content/plugins

    # Crear y configurar uploads si no existe
    if [ ! -d "wp-content/uploads" ]; then
        mkdir -p wp-content/uploads
    fi
    chmod 775 wp-content/uploads

    # Establecer propietario
    chown -R www-data:www-data .

    # 5.6 Verificar autoloader
    log_info "Verificando autoloader de Composer..."
    if [ ! -f "vendor/autoload.php" ]; then
        log_error "No se encontró el autoloader de Composer"
        return 1
    fi

    # 5.7 Limpiar caché de Composer
    log_info "Limpiando caché de Composer..."
    composer clear-cache

    log_success "Instalación de WordPress vía Composer completada exitosamente"
    return 0
}

# 6. Función para documentar estado de la instalación
document_installation_state() {
    log_info "PASO 6: Documentación del Estado de la Instalación"
    log_info "----------------------------------------------"

    local doc_dir="${PROVISION_DIR}/meta/composer"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    # 6.1 Crear directorio para documentación
    log_info "Preparando directorio de documentación..."
    if ! ensure_directory "$doc_dir" 755 "root" "root"; then
        log_error "No se pudo crear directorio de documentación"
        return 1
    fi

    # 6.2 Documentar versiones instaladas
    log_info "Documentando versiones instaladas..."
    {
        echo "=== Versiones Instaladas ==="
        echo "Fecha: $(date)"
        echo "PHP Version: $(php -v | head -n1)"
        echo "Composer Version: $(composer --version)"
        echo "WordPress Version: $(wp core version --path="${WORDPRESS_PATH}" 2>/dev/null || echo "No disponible")"
        echo
    } > "${doc_dir}/versions_${timestamp}.txt"

    # 6.3 Documentar configuraciones
    log_info "Documentando configuraciones..."
    {
        echo "=== Configuraciones PHP ==="
        echo "Fecha: $(date)"
        for key in "${!PHP_DEVELOPMENT_CONFIG[@]}"; do
            echo "$key = $(php -r "echo ini_get('$key');")"
        done
        echo
        echo "=== Configuraciones Composer ==="
        composer config -gl
        echo
    } > "${doc_dir}/config_${timestamp}.txt"

    # 6.4 Generar manifiesto de dependencias
    log_info "Generando manifiesto de dependencias..."
    if [ -d "${WORDPRESS_PATH}" ]; then
        cd "${WORDPRESS_PATH}"
        {
            echo "=== Dependencias Instaladas ==="
            echo "Fecha: $(date)"
            echo
            echo "-- Dependencias de Composer --"
            composer show
            echo
            if [ -f "composer.lock" ]; then
                echo "-- Composer Lock Hash --"
                sha256sum composer.lock
            fi
        } > "${doc_dir}/dependencies_${timestamp}.txt"
    fi

    # 6.5 Documentar estado de plugins y temas
    log_info "Documentando plugins y temas..."
    {
        echo "=== Plugins y Temas Instalados ==="
        echo "Fecha: $(date)"
        echo
        if command -v wp >/dev/null && [ -d "${WORDPRESS_PATH}" ]; then
            echo "-- Plugins Instalados --"
            wp plugin list --path="${WORDPRESS_PATH}" 2>/dev/null || echo "No se pudo obtener lista de plugins"
            echo
            echo "-- Temas Instalados --"
            wp theme list --path="${WORDPRESS_PATH}" 2>/dev/null || echo "No se pudo obtener lista de temas"
        else
            echo "WP-CLI no disponible o WordPress no instalado"
        fi
    } > "${doc_dir}/wp_components_${timestamp}.txt"

    # 6.6 Capturar logs relevantes
    log_info "Capturando logs relevantes..."
    {
        echo "=== Logs Relevantes ==="
        echo "Fecha: $(date)"
        echo
        echo "-- PHP FPM Log --"
        tail -n 50 /var/log/php"${PHP_VERSION}"-fpm.log 2>/dev/null || echo "Log no disponible"
        echo
        echo "-- PHP Error Log --"
        tail -n 50 /var/log/php/error.log 2>/dev/null || echo "Log no disponible"
    } > "${doc_dir}/logs_${timestamp}.txt"

    # 6.7 Generar resumen de instalación
    log_info "Generando resumen de instalación..."
    {
        echo "=== Resumen de Instalación ==="
        echo "Fecha: $(date)"
        echo "Timestamp: $timestamp"
        echo
        echo "-- Estado Final --"
        echo "PHP: $(php -r "echo PHP_VERSION;")"
        echo "Composer: $(composer --version | cut -d' ' -f3)"
        echo "WordPress Path: ${WORDPRESS_PATH}"
        echo
        echo "-- Verificaciones --"
        echo "Composer instalado: $(command -v composer >/dev/null && echo "Sí" || echo "No")"
        echo "WordPress instalado: $([ -f "${WORDPRESS_PATH}/wp-load.php" ] && echo "Sí" || echo "No")"
        echo "Autoloader presente: $([ -f "${WORDPRESS_PATH}/vendor/autoload.php" ] && echo "Sí" || echo "No")"
        echo
        echo "-- Documentación Generada --"
        ls -l "$doc_dir" | awk '{print $9}'
    } > "${doc_dir}/summary_${timestamp}.txt"

    # 6.8 Verificar documentación generada
    local required_docs=(
        "versions_${timestamp}.txt"
        "config_${timestamp}.txt"
        "dependencies_${timestamp}.txt"
        "wp_components_${timestamp}.txt"
        "logs_${timestamp}.txt"
        "summary_${timestamp}.txt"
    )

    local missing=0
    for doc in "${required_docs[@]}"; do
        if [ ! -f "${doc_dir}/${doc}" ]; then
            log_error "Documento faltante: $doc"
            ((missing++))
        fi
    done

    if [ $missing -gt 0 ]; then
        log_warning "Faltan $missing documentos de instalación"
    else
        log_success "Documentación completada exitosamente"
    fi

    return 0
}

# Función principal del hook
main() {
    log_header "Pre-Hook: Configuración de Composer y WordPress"
    log_info "====================================="

    # 1. Establecer el paso actual de provisión
    export PROVISION_STEP="composer_setup"

    # 2. Definir pasos de la instalación
    local -A setup_steps=(
        ["validate_composer_env"]="Validación del Entorno"
        ["verify_php_requirements"]="Verificación de Requisitos PHP"
        ["install_composer"]="Instalación de Composer"
        ["configure_php_for_development"]="Configuración PHP para Desarrollo"
        ["install_wordpress_composer"]="Instalación WordPress vía Composer"
        ["document_installation_state"]="Documentación de la Instalación"
    )

    # 3. Inicializar contadores
    local total_steps=${#setup_steps[@]}
    local current_step=0
    local failed_steps=0

    # 4. Registrar inicio de la instalación
    log_info "Iniciando proceso de configuración"
    log_info "- Total de pasos: $total_steps"
    log_info "- Timestamp: $PROVISION_TIMESTAMP"

    # 5. Ejecutar cada paso
    for step_func in "${!setup_steps[@]}"; do
        ((current_step++))
        local step_name="${setup_steps[$step_func]}"

        # 5.1 Mostrar progreso
        log_info ""
        log_info "Paso $current_step de $total_steps: $step_name"
        log_info "----------------------------------------"

        # 5.2 Ejecutar paso
        if ! $step_func; then
            ((failed_steps++))

            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                error_handle "Falló el paso: $step_name" ${ERROR_CODES["GENERAL_ERROR"]}
                return 1
            else
                log_warning "Falló el paso pero continuando por PROVISION_CONTINUE_ON_ERROR=true"
            fi
        fi

        # 5.3 Actualizar estado
        save_provision_state "composer_step_${current_step}_completed"

        # 5.4 Mostrar progreso
        local percent=$((current_step * 100 / total_steps))
        log_progress "$current_step" "$total_steps" "$step_name completado"
    done

    # 6. Verificación final
    log_info ""
    log_info "Realizando verificación final..."

    # 6.1 Verificar instalación completa
    if ! command -v composer >/dev/null 2>&1; then
        log_error "Composer no está instalado correctamente"
        return 1
    fi

    # 6.2 Registrar instalación completada
    echo "$PROVISION_TIMESTAMP" > "${PROVISION_DIR}/tmp/composer_installed"

    # 6.3 Generar resumen final
    {
        echo "=== Resumen de Instalación de Composer ==="
        echo "Timestamp: $PROVISION_TIMESTAMP"
        echo "Pasos totales: $total_steps"
        echo "Pasos fallidos: $failed_steps"
        echo "Composer: $(composer --version)"
        echo "PHP: $(php -v | head -n1)"
        echo "Fecha finalización: $(date)"
        echo "Estado: $([ $failed_steps -eq 0 ] && echo 'Exitoso' || echo 'Con advertencias')"
    } > "${PROVISION_DIR}/meta/composer/installation_summary.txt"

    # 7. Mostrar resultado final
    log_info ""
    if [ "$failed_steps" -eq 0 ]; then
        log_success "Configuración completada exitosamente"
        return 0
    else
        log_warning "Configuración completada con advertencias ($failed_steps fallos)"
        return 1
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

    # 3. Ejecutar script
    main
    exit_code=$?

    exit $exit_code
fi