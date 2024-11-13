#!/usr/bin/env bash
# Pre-hook: Verificación y Preparación de Paquetes Requeridos
#
# Este hook verifica y prepara el sistema de paquetes, asegurando que todos los
# paquetes necesarios estén disponibles y correctamente configurados antes de
# continuar con la provisión.
#
# Depende de los siguientes helpers:
# - environment.sh: Para gestión del entorno
# - packages.sh: Para gestión de paquetes
# - system.sh: Para información del sistema
# - error.sh: Para manejo de errores
# - logging.sh: Para logging consistente
# - config.sh: Para variables de configuración

# 1. Validación del contexto de ejecución
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Obtener el directorio base de provisión
HOOKS_BASE="${PROVISION_DIR}/hooks"

# Importar helpers necesarios usando la función de hooks.sh
load_helpers "environment.sh" "packages.sh" "system.sh" "error.sh" "logging.sh"

# 1. Función para validar el entorno de paquetes
validate_packages_env() {
    log_info "PASO 1: Validación del Entorno de Paquetes"
    log_info "----------------------------------------"

    # 1.1 Verificar que estamos como root
    log_info "Verificando permisos de ejecución..."
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        return 1
    }

    # 1.2 Validar inicialización del entorno
    log_info "Verificando inicialización del entorno..."
    if ! validate_provision_env; then
        error_handle "Entorno de provisión no inicializado" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    }

    # 1.3 Verificar sistema de paquetes
    log_info "Verificando sistema de paquetes..."
    if ! validate_package_system; then
        error_handle "Sistema de paquetes no válido" ${ERROR_CODES["INVALID_CONFIG"]}
        return 1
    }

    # 1.4 Verificar espacio disponible para instalación
    log_info "Verificando espacio disponible..."
    # Estimar 1GB para paquetes
    if ! check_disk_space 1000; then
        error_handle "Espacio insuficiente para instalación de paquetes" ${ERROR_CODES["DISK_FULL"]}
        return 1
    }

    # 1.5 Verificar memoria disponible
    log_info "Verificando memoria disponible..."
    local available_memory
    available_memory=$(get_available_memory)
    if [ "$available_memory" -lt "$MIN_MEMORY_MB" ]; then
        error_handle "Memoria insuficiente para instalación de paquetes" ${ERROR_CODES["GENERAL_ERROR"]}
        return 1
    }

    # 1.6 Verificar conectividad a repositorios
    log_info "Verificando conectividad a repositorios..."
    if ! check_required_services; then
        error_handle "No hay conectividad a repositorios necesarios" ${ERROR_CODES["NETWORK_ERROR"]}
        return 1
    }

    log_success "Validación del entorno completada exitosamente"
    return 0
}

# Función principal del hook (por ahora solo con el primer paso)
main() {
    log_header "Pre-Hook: Verificación y Preparación de Paquetes"
    log_info "=============================================="

    # 1. Establecer el paso actual de provisión
    export PROVISION_STEP="required_packages"

    # 2. Definir pasos del proceso
    local -A steps=(
        ["validate_packages_env"]="Validación del Entorno de Paquetes"
    )

    # 3. Inicializar contadores
    local total_steps=${#steps[@]}
    local current_step=0
    local failed_steps=0

    # 4. Ejecutar cada paso
    for step_func in "${!steps[@]}"; do
        ((current_step++))
        local step_name="${steps[$step_func]}"

        log_info ""
        log_info "Paso $current_step de $total_steps: $step_name"
        log_info "----------------------------------------"

        if ! $step_func; then
            ((failed_steps++))
            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                error_handle "Falló el paso: $step_name" ${ERROR_CODES["GENERAL_ERROR"]}
                return 1
            fi
        fi

        # Actualizar estado
        save_provision_state "packages_step_${current_step}_completed"
    done

    # 5. Verificación final
    if [ $failed_steps -eq 0 ]; then
        log_success "Validación inicial completada exitosamente"
        return 0
    else
        log_warning "Proceso completado con advertencias ($failed_steps fallos)"
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
    exit $?
fi

# 2. Función para gestionar fuentes de paquetes
configure_package_sources() {
    log_info "PASO 2: Gestión de Fuentes de Paquetes"
    log_info "-------------------------------------"

    # 2.1 Crear directorio de backup si no existe
    ensure_directory "$SOURCES_BACKUP_DIR"

    # 2.2 Hacer backup del sources.list actual
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    log_info "Creando backup de sources.list..."
    if ! safe_copy "$SOURCES_LIST" "${SOURCES_BACKUP_DIR}/sources.list.${backup_timestamp}" true; then
        error_handle "No se pudo crear backup de sources.list" ${ERROR_CODES["BACKUP_ERROR"]}
        return 1
    fi

    # 2.3 Limpiar sources.list.d
    log_info "Limpiando sources.list.d..."
    if ! safe_remove "/etc/apt/sources.list.d/*.save" false; then
        log_warning "No se pudieron limpiar algunos archivos .save"
    fi

    # 2.4 Verificar e instalar software-properties-common
    if ! is_package_installed "software-properties-common"; then
        log_info "Instalando software-properties-common..."
        if ! install_packages "software-properties-common"; then
            error_handle "No se pudo instalar software-properties-common" ${ERROR_CODES["DEPENDENCY_ERROR"]}
            return 1
        fi
    fi

    # 2.5 Agregar PPAs configurados
    local failed_ppas=0
    for ppa in "${REQUIRED_PPAS[@]}"; do
        log_info "Agregando PPA: $ppa"
        if ! error_retry_command "add_ppa \"$ppa\"" "Agregar $ppa" 3 5; then
            log_error "No se pudo agregar PPA: $ppa"
            ((failed_ppas++))
        fi
    done

    # 2.6 Agregar repositorios externos y sus llaves GPG
    for repo_name in "${!EXTERNAL_REPOS[@]}"; do
        # 2.6.1 Agregar llave GPG si está configurada
        if [ -n "${GPG_KEYS[$repo_name]}" ]; then
            log_info "Agregando llave GPG para $repo_name..."
            if ! add_apt_key "${GPG_KEYS[$repo_name]}" "/etc/apt/trusted.gpg.d/${repo_name}.gpg"; then
                log_error "No se pudo agregar la llave GPG para $repo_name"
                ((failed_ppas++))
                continue
            fi
        fi

        # 2.6.2 Agregar repositorio
        log_info "Agregando repositorio para $repo_name..."
        if ! add_apt_repository "${EXTERNAL_REPOS[$repo_name]}" "${repo_name}.list"; then
            log_error "No se pudo agregar el repositorio de $repo_name"
            ((failed_ppas++))
        fi
    done

    # 2.7 Actualizar lista de paquetes
    log_info "Actualizando lista de paquetes..."
    if ! apt_update; then
        error_handle "Error actualizando lista de paquetes" ${ERROR_CODES["GENERAL_ERROR"]}
        return 1
    fi

    # 2.8 Registrar configuración actual
    {
        echo "=== Configuración de Repositorios ==="
        echo "Fecha: $(date)"
        echo "Sistema operativo: $(get_os_info)"
        echo "PPAs configurados:"
        ls -l /etc/apt/sources.list.d/
        echo "Sources list MD5: $(md5sum $SOURCES_LIST)"
        echo "Backup creado: ${SOURCES_BACKUP_DIR}/sources.list.${backup_timestamp}"
    } > "${PROVISION_DIR}/logs/repository_config.log"

    if [ $failed_ppas -gt 0 ]; then
        log_warning "Algunos repositorios no se pudieron configurar ($failed_ppas fallos)"
        return "$PROVISION_CONTINUE_ON_ERROR"
    fi

    log_success "Configuración de fuentes de paquetes completada"
    return 0
}

# 3. Función para verificar paquetes instalados
verify_installed_packages() {
    log_info "PASO 3: Verificación de Paquetes Instalados"
    log_info "----------------------------------------"

    # 3.1 Preparar archivo de registro
    local verify_log="${PROVISION_DIR}/logs/package_verification_$(date +%Y%m%d_%H%M%S).log"
    local missing_packages=()
    local outdated_packages=()
    local verification_errors=0

    # 3.2 Iniciar registro
    {
        echo "=== Verificación de Paquetes ==="
        echo "Fecha: $(date)"
        echo "Sistema: $(get_os_info)"
        echo "PHP Version Objetivo: ${PHP_VERSION}"
        echo "MySQL Version Objetivo: ${MYSQL_VERSION}"
    } > "$verify_log"

    # 3.3 Función auxiliar para verificar grupo de paquetes
    verify_package_group() {
        local -n packages=$1
        local group_name=$2

        log_info "Verificando $group_name"
        echo -e "\n=== Verificando $group_name ===" >> "$verify_log"

        for package in "${!packages[@]}"; do
            local required_version="${packages[$package]}"
            local status="OK"

            if ! is_package_installed "$package"; then
                missing_packages+=("$package")
                status="NO INSTALADO"
                log_error "Paquete no instalado: $package"
            elif [ "$required_version" != "latest" ]; then
                if ! verify_package_versions "${package}:${required_version}"; then
                    outdated_packages+=("$package")
                    status="VERSION INCORRECTA"
                    log_warning "Versión incorrecta: $package"
                else
                    log_success "Paquete verificado: $package"
                fi
            else
                log_success "Paquete verificado: $package"
            fi

            printf "%-40s | %-15s | %s\n" \
                "$package" "$required_version" "$status" >> "$verify_log"
        done
    }

    # 3.4 Verificar cada grupo de paquetes
    log_info "Verificando paquetes base..."
    verify_package_group REQUIRED_PACKAGES "Paquetes Base"

    log_info "Verificando paquetes PHP..."
    verify_package_group PHP_PACKAGES "Paquetes PHP"

    log_info "Verificando paquetes de Base de Datos..."
    verify_package_group DB_PACKAGES "Paquetes de Base de Datos"

    # 3.5 Verificar dependencias
    log_info "Verificando dependencias..."
    local dep_check
    if ! dep_check=$(apt-get check 2>&1); then
        log_error "Problemas con dependencias detectados"
        echo -e "\n=== Problemas de Dependencias ===" >> "$verify_log"
        echo "$dep_check" >> "$verify_log"
        ((verification_errors++))
    fi

    # 3.6 Verificar paquetes rotos
    log_info "Verificando paquetes rotos..."
    local broken_packages
    if broken_packages=$(dpkg -l | grep '^..R'); then
        log_error "Paquetes rotos detectados"
        echo -e "\n=== Paquetes Rotos ===" >> "$verify_log"
        echo "$broken_packages" >> "$verify_log"
        ((verification_errors++))
    fi

    # 3.7 Generar lista de paquetes para instalación/actualización
    if [ ${#missing_packages[@]} -gt 0 ] || [ ${#outdated_packages[@]} -gt 0 ]; then
        local packages_file="${PROVISION_DIR}/tmp/packages_to_install.txt"
        {
            echo "# Paquetes pendientes de instalación/actualización"
            echo "# Generado: $(date)"
            echo -e "\n# Paquetes faltantes:"
            printf "%s\n" "${missing_packages[@]}"
            echo -e "\n# Paquetes desactualizados:"
            printf "%s\n" "${outdated_packages[@]}"
        } > "$packages_file"
    fi

    # 3.8 Generar resumen
    {
        echo -e "\n=== Resumen de Verificación ==="
        echo "Total paquetes verificados: $((${#REQUIRED_PACKAGES[@]} + ${#PHP_PACKAGES[@]} + ${#DB_PACKAGES[@]}))"
        echo "Paquetes faltantes: ${#missing_packages[@]}"
        echo "Paquetes desactualizados: ${#outdated_packages[@]}"
        echo "Errores de verificación: $verification_errors"

        if [ ${#missing_packages[@]} -gt 0 ]; then
            echo -e "\nPaquetes faltantes:"
            printf "  - %s\n" "${missing_packages[@]}"
        fi

        if [ ${#outdated_packages[@]} -gt 0 ]; then
            echo -e "\nPaquetes desactualizados:"
            printf "  - %s\n" "${outdated_packages[@]}"
        fi
    } >> "$verify_log"

    # 3.9 Salida y control de errores
    if [ ${#missing_packages[@]} -eq 0 ] && \
       [ ${#outdated_packages[@]} -eq 0 ] && \
       [ $verification_errors -eq 0 ]; then
        log_success "Todos los paquetes verificados correctamente"
        return 0
    else
        log_warning "Se encontraron problemas con los paquetes"
        log_error "Paquetes faltantes: ${#missing_packages[@]}"
        log_error "Paquetes desactualizados: ${#outdated_packages[@]}"
        log_error "Errores de verificación: $verification_errors"
        log_info "Detalles completos en: $verify_log"

        # Crear archivo de estado para el siguiente paso
        save_provision_state "packages_need_installation"

        # Retornar según la configuración
        if [ "$PROVISION_CONTINUE_ON_ERROR" = "true" ]; then
            return 0
        fi
        return 1
    fi
}

# 4. Función para instalar paquetes requeridos
install_required_packages() {
    log_info "PASO 4: Instalación de Paquetes Requeridos"
    log_info "-----------------------------------------"

    # 4.1 Preparar entorno
    if ! prepare_package_environment; then
        error_handle "No se pudo preparar el entorno para instalación" ${ERROR_CODES["GENERAL_ERROR"]}
        return 1
    fi

    # 4.2 Verificar archivo de paquetes pendientes
    local packages_file="${PROVISION_DIR}/tmp/packages_to_install.txt"
    if [ ! -f "$packages_file" ]; then
        log_info "No hay paquetes pendientes para instalar"
        return 0
    fi

    # 4.3 Instalación por grupos
    local error_count=0

    # 4.3.1 Paquetes base del sistema
    if [ ${#SYSTEM_PACKAGES[@]} -gt 0 ]; then
        log_info "Instalando paquetes base del sistema..."
        if ! install_package_group "system" "${SYSTEM_PACKAGES[@]}"; then
            log_error "Error en instalación de paquetes base"
            ((error_count++))
            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                return 1
            fi
        fi
    fi

    # 4.3.2 Paquetes web y PHP
    if [ ${#WEB_PACKAGES[@]} -gt 0 ]; then
        log_info "Instalando paquetes web y PHP..."
        if ! install_package_group "web" "${WEB_PACKAGES[@]}"; then
            log_error "Error en instalación de paquetes web"
            ((error_count++))
            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                return 1
            fi
        fi
    fi

    # 4.3.3 Paquetes de base de datos
    if [ ${#DB_PACKAGES[@]} -gt 0 ]; then
        log_info "Instalando paquetes de base de datos..."
        if ! install_package_group "database" "${DB_PACKAGES[@]}"; then
            log_error "Error en instalación de paquetes de base de datos"
            ((error_count++))
            if [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
                return 1
            fi
        fi
    fi

    # 4.4 Limpieza post-instalación
    cleanup_after_install

    # 4.5 Verificar estado final
    if [ $error_count -eq 0 ]; then
        log_success "Instalación de paquetes completada exitosamente"
        rm -f "$packages_file"
        save_provision_state "packages_installation_completed"
        return 0
    else
        log_error "Instalación completada con $error_count errores"
        if [ "$PROVISION_CONTINUE_ON_ERROR" = "true" ]; then
            save_provision_state "packages_installation_completed_with_errors"
            return 0
        fi
        return 1
    fi
}

# 5. Función para configurar paquetes instalados
configure_installed_packages() {
    log_info "PASO 5: Configuración de Paquetes Instalados"
    log_info "----------------------------------------"

    local error_count=0

    # 5.1 Configurar PHP-FPM
    if is_package_installed "php${PHP_VERSION}-fpm"; then
        log_info "Configurando PHP-FPM ${PHP_VERSION}..."
        local php_config_str=""
        for key in "${!PHP_CONFIGURATIONS[@]}"; do
            php_config_str+="${key}=${PHP_CONFIGURATIONS[$key]} "
        done

        if ! configure_installed_packages "php" "$php_config_str"; then
            log_error "Error configurando PHP-FPM"
            ((error_count++))
            [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ] && return 1
        fi
    fi

    # 5.2 Configurar MySQL
    if is_package_installed "mysql-server"; then
        log_info "Configurando MySQL ${MYSQL_VERSION}..."
        local mysql_config_str=""
        for key in "${!MYSQL_CONFIGURATIONS[@]}"; do
            mysql_config_str+="${key}=${MYSQL_CONFIGURATIONS[$key]} "
        done

        if ! configure_installed_packages "mysql" "$mysql_config_str"; then
            log_error "Error configurando MySQL"
            ((error_count++))
            [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ] && return 1
        fi
    fi

    # 5.3 Configurar Nginx
    if is_package_installed "nginx"; then
        log_info "Configurando Nginx..."
        local nginx_config_str=""
        for key in "${!NGINX_CONFIGURATIONS[@]}"; do
            nginx_config_str+="${key}=${NGINX_CONFIGURATIONS[$key]} "
        done

        if ! configure_installed_packages "nginx" "$nginx_config_str"; then
            log_error "Error configurando Nginx"
            ((error_count++))
            [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ] && return 1
        fi
    fi

    # 5.4 Reiniciar servicios
    log_info "Verificando servicios..."
    local restart_errors=0

    for service in "${MANAGED_SERVICES[@]}"; do
        if service_exists "$service" && service_is_running "$service"; then
            log_info "Reiniciando servicio: $service"
            if ! service_control "restart" "$service"; then
                log_error "Error reiniciando servicio: $service"
                ((restart_errors++))
            fi
        fi
    done

    # 5.5 Verificar resultado final
    local total_errors=$((error_count + restart_errors))

    if [ $total_errors -eq 0 ]; then
        log_success "Configuración de paquetes completada exitosamente"
        save_provision_state "packages_configuration_completed"
        return 0
    else
        log_error "Configuración completada con $total_errors errores"
        if [ "$PROVISION_CONTINUE_ON_ERROR" = "true" ]; then
            save_provision_state "packages_configuration_completed_with_errors"
            return 0
        fi
        return 1
    fi
}
# Función para verificación final
verify_final_state() {
    log_header "PASO 6: Verificación Final del Estado"
    log_info "=============================================="

    # 6.1 Verificación de servicios básicos
    log_info "PASO 6.1: Verificación de Servicios"
    log_info "----------------------------------------"

    local verification_errors=0

    # 6.1.1 Verificar estado de cada servicio
    for service in "${!SERVICE_STATES[@]}"; do
        local required_state="${SERVICE_STATES[$service]}"
        log_info "Verificando servicio: $service"

        if ! verify_service_state "$service" "$required_state"; then
            ((verification_errors++))
            [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ] && return 1
        fi
    done

    # 6.2 Verificación de configuraciones
    log_info "PASO 6.2: Verificación de Configuraciones"
    log_info "----------------------------------------"

    # 6.2.1 Verificar configuraciones de cada servicio
    for service in "${!SERVICE_CONFIG_FILES[@]}"; do
        local config_file="${SERVICE_CONFIG_FILES[$service]}"
        log_info "Verificando configuraciones de: $service"

        # Verificar patrones específicos del servicio
        for pattern_key in "${!SERVICE_CONFIG_PATTERNS[@]}"; do
            if [[ $pattern_key == ${service}* ]]; then
                if ! verify_service_config "$config_file" "${SERVICE_CONFIG_PATTERNS[$pattern_key]}"; then
                    ((verification_errors++))
                    [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ] && return 1
                fi
            fi
        done
    done

    # 6.3 Verificación de conectividad
    log_info "PASO 6.3: Verificación de Conectividad"
    log_info "----------------------------------------"

    # 6.3.1 Verificar sockets si está habilitado
    if [ "$VERIFY_SOCKETS" = "true" ]; then
        for service in "${!SERVICE_SOCKETS[@]}"; do
            local socket="${SERVICE_SOCKETS[$service]}"
            log_info "Verificando socket de $service"

            if ! check_socket "$socket" "${SERVICE_TIMEOUTS[socket]}"; then
                ((verification_errors++))
                [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ] && return 1
            fi
        done
    fi

    # 6.3.2 Verificar puertos si está habilitado
    if [ "$VERIFY_PORTS" = "true" ]; then
        for service in "${!SERVICE_PORTS[@]}"; do
            local port="${SERVICE_PORTS[$service]}"
            log_info "Verificando puerto para $service"

            if ! port_is_open "$port"; then
                log_error "Puerto $port no disponible para $service"
                ((verification_errors++))
                [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ] && return 1
            fi
        done
    fi

    # 6.4 Verificación de dependencias
    log_info "PASO 6.4: Verificación de Dependencias"
    log_info "----------------------------------------"

    if [ "$VERIFY_DEPENDENCIES" = "true" ]; then
        for service in "${!SERVICE_DEPENDENCIES[@]}"; do
            local dependencies="${SERVICE_DEPENDENCIES[$service]}"
            [ -z "$dependencies" ] && continue

            log_info "Verificando dependencias de $service"
            if ! check_service_dependencies "$service"; then
                ((verification_errors++))
                [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ] && return 1
            fi
        done
    fi

    # 6.5 Generar reporte final
    log_info "PASO 6.5: Generando Reporte Final"
    log_info "----------------------------------------"

    local verify_log="${PROVISION_DIR}/logs/verification_$(date +%Y%m%d_%H%M%S).log"
    {
        echo "=== Reporte de Verificación Final ==="
        echo "Fecha: $(date)"
        echo "Sistema: $(get_os_info)"
        echo -e "\nEstado de Servicios:"
        for service in "${!SERVICE_STATES[@]}"; do
            echo "- $service: $(service_is_running "$service" && echo "OK" || echo "ERROR")"
        done

        echo -e "\nEstado de Configuraciones:"
        for config in "${!SERVICE_CONFIG_FILES[@]}"; do
            echo "- $config: ${SERVICE_CONFIG_FILES[$config]}"
        done

        echo -e "\nEstado de Conectividad:"
        echo "Sockets verificados: $VERIFY_SOCKETS"
        echo "Puertos verificados: $VERIFY_PORTS"

        echo -e "\nResumen:"
        echo "Total errores: $verification_errors"
        echo "Estado: $([[ $verification_errors -eq 0 ]] && echo "EXITOSO" || echo "CON ERRORES")"
    } > "$verify_log"

    # 6.6 Verificación final
    if [ $verification_errors -eq 0 ]; then
        log_success "Verificación final completada exitosamente"
        save_provision_state "final_verification_completed"
        return 0
    else
        log_error "Verificación final completada con $verification_errors errores"
        log_info "Ver detalles completos en: $verify_log"

        if [ "$PROVISION_CONTINUE_ON_ERROR" = "true" ]; then
            save_provision_state "final_verification_completed_with_errors"
            return 0
        fi
        return 1
    fi
}

# Función para limpieza en caso de fallo
cleanup_failed_verification() {
    if [ "${PROVISION_STEP}" = "cleanup" ]; then
        return 0
    fi
    export PROVISION_STEP="cleanup"

    log_info "Limpiando después de verificación fallida..."

    # Limpiar archivos temporales
    clean_temp_files

    # Asegurar que los servicios estén funcionando
    for service in "${MANAGED_SERVICES[@]}"; do
        if ! service_is_running "$service"; then
            log_warning "Intentando reiniciar servicio: $service"
            service_control "restart" "$service" "Recuperación"
        fi
    done

    # Registrar estado de limpieza
    save_provision_state "verification_cleanup_completed"
}

# Configurar manejador de errores específico
trap 'error_handle "Error en verificación de servicios" $? $LINENO' ERR

# Verificar si el script se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Verificar que somos root
    if ! check_root; then
        error_handle "Este script debe ejecutarse como root" ${ERROR_CODES["PERMISSION_DENIED"]}
        exit 1
    fi

    # Configurar manejo de errores
    set -e
    trap 'error_handle "Error en línea $LINENO" $? $LINENO' ERR

    # Establecer handler específico para verificación
    trap 'error_handle_verification ${ERROR_CODES["VERIFY_ERROR"]} "Error durante la verificación"' ERR

    # Ejecutar script
    main
    exit_code=$?

    # Limpiar si es necesario
    if [ $exit_code -ne 0 ] && [ "$PROVISION_CONTINUE_ON_ERROR" != "true" ]; then
        cleanup_failed_verification
    fi

    exit $exit_code
fi