#!/usr/bin/env bash
# Pre-hook: Estructura de Directorios del Sistema
#
# Este hook establece la estructura completa de directorios para el sistema,
# incluyendo permisos, ownership y enlaces simbólicos necesarios.
#
# Depende de los siguientes helpers:
# - filesystem.sh: Para operaciones de archivos y directorios
# - environment.sh: Para gestión del entorno
# - system.sh: Para información del sistema
# - error.sh: Para manejo consistente de errores
# - config.sh: Para variables de configuración
#
# Pasos de estructuración:
# 1. Validación del contexto de ejecución y ambiente
# 2. Verificación de espacio y requisitos para directorios
# 3. Creación de estructura base del sistema
# 4. Establecimiento de permisos y ownership
# 5. Creación de enlaces simbólicos
# 6. Documentación de la estructura creada

# 1. Validación del contexto de ejecución
if [ -z "$PROVISION_DIR" ]; then
    echo "Error: Este script debe ser ejecutado a través del sistema de provisión"
    exit 1
fi

# Obtener el directorio base de provisión
HOOKS_BASE="${PROVISION_DIR}/hooks"

# Importar helpers necesarios
load_helpers "environment.sh" "filesystem.sh" "system.sh" "error.sh" "logging.sh"

# 1. Función para validar el ambiente
validate_directory_env() {
    log_info "PASO 1: Validación del Ambiente"
    log_info "---------------------------------------"

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

    # 1.3 Verificar variables requeridas
    log_info "Verificando variables de configuración..."
    local required_vars=(
        "WORDPRESS_PATH"
        "PROJECT_DIR"
        "LOGS_DIR"
        "TEMP_DIR"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            error_handle "Variable requerida no definida: $var" ${ERROR_CODES["INVALID_CONFIG"]}
            return 1
        fi
    done

    log_success "Validación del ambiente completada exitosamente"
    return 0
}

# 2. Función para verificar espacio y requisitos
verify_directory_requirements() {
    log_info "PASO 2: Verificación de Espacio y Requisitos"
    log_info "-------------------------------------------"

    # 2.1 Calcular espacio total requerido
    local total_required=0
    for dir in "${!DIRECTORY_SPACE_REQUIREMENTS[@]}"; do
        total_required=$((total_required + DIRECTORY_SPACE_REQUIREMENTS[$dir]))
    done

    # 2.2 Agregar margen de seguridad (20%)
    total_required=$((total_required + (total_required * 20 / 100)))
    log_info "Espacio total requerido: ${total_required}MB"

    # 2.3 Verificar espacio disponible en cada punto de montaje
    for base_dir in "$WORDPRESS_PATH" "$LOGS_DIR" "$PROJECT_DIR"; do
        local available_space
        available_space=$(get_free_space_mb "$(dirname "$base_dir")")

        log_info "Verificando espacio en $(dirname "$base_dir"): ${available_space}MB disponibles"

        if [ "$available_space" -lt "$total_required" ]; then
            error_handle "Espacio insuficiente en $(dirname "$base_dir")" ${ERROR_CODES["DISK_FULL"]}
            return 1
        fi
    done

    log_success "Verificación de requisitos completada"
    return 0
}

# 3. Función para crear estructura base
create_directory_structure() {
    log_info "PASO 3: Creación de Estructura Base"
    log_info "---------------------------------"

    local failed_dirs=0

    # 3.1 Crear directorios base
    for dir in "${!DIRECTORY_STRUCTURE[@]}"; do
        local path="${DIRECTORY_STRUCTURE[$dir]}"
        local perms_config="${DIRECTORY_PERMISSIONS[$path]}"

        # Extraer permisos y ownership
        IFS=':' read -r perms owner group <<< "$perms_config"

        log_info "Creando directorio: $path"
        if ! ensure_directory "$path" "$perms" "$owner" "$group"; then
            log_error "Error creando directorio: $path"
            ((failed_dirs++))
            continue
        fi
    done

    if [ $failed_dirs -gt 0 ]; then
        error_handle "Falló la creación de $failed_dirs directorios" ${ERROR_CODES["GENERAL_ERROR"]}
        return 1
    fi

    log_success "Estructura base creada exitosamente"
    return 0
}

# 4. Función para establecer permisos y ownership
set_directory_permissions() {
    log_info "PASO 4: Establecimiento de Permisos y Ownership"
    log_info "--------------------------------------------"

    local failed_perms=0
    local total_perms=0

    # 4.1 Verificar y establecer permisos para cada directorio registrado
    log_info "Estableciendo permisos y ownership..."

    for dir_path in "${!DIRECTORY_PERMISSIONS[@]}"; do
        local perms_config="${DIRECTORY_PERMISSIONS[$dir_path]}"
        ((total_perms++))

        # Extraer configuración
        IFS=':' read -r perms owner group <<< "$perms_config"

        log_info "- Configurando $dir_path"
        log_info "  Permisos: $perms, Usuario: $owner, Grupo: $group"

        # 4.2 Verificar existencia del directorio
        if [ ! -d "$dir_path" ]; then
            log_error "Directorio no encontrado: $dir_path"
            ((failed_perms++))
            continue
        }

        # 4.3 Verificar existencia de usuario y grupo
        if ! id -u "$owner" >/dev/null 2>&1; then
            log_error "Usuario no existe: $owner"
            ((failed_perms++))
            continue
        }

        if ! getent group "$group" >/dev/null 2>&1; then
            log_error "Grupo no existe: $group"
            ((failed_perms++))
            continue
        }

        # 4.4 Establecer permisos y ownership
        if ! chmod "$perms" "$dir_path"; then
            log_error "Error estableciendo permisos $perms en: $dir_path"
            ((failed_perms++))
            continue
        }

        if ! chown "$owner:$group" "$dir_path"; then
            log_error "Error estableciendo ownership $owner:$group en: $dir_path"
            ((failed_perms++))
            continue
        }

        # 4.5 Verificar permisos establecidos
        local current_perms
        current_perms=$(stat -c "%a" "$dir_path")
        if [ "$current_perms" != "$perms" ]; then
            log_error "Permisos incorrectos en $dir_path: $current_perms (esperado: $perms)"
            ((failed_perms++))
            continue
        }

        local current_owner
        current_owner=$(stat -c "%U" "$dir_path")
        local current_group
        current_group=$(stat -c "%G" "$dir_path")
        if [ "$current_owner" != "$owner" ] || [ "$current_group" != "$group" ]; then
            log_error "Ownership incorrecto en $dir_path: $current_owner:$current_group (esperado: $owner:$group)"
            ((failed_perms++))
            continue
        }

        log_success "  Permisos establecidos correctamente"
    done

    # 4.6 Mostrar resumen
    if [ $failed_perms -gt 0 ]; then
        log_error "Falló la configuración de $failed_perms de $total_perms permisos"
        return 1
    fi

    log_success "Permisos y ownership establecidos correctamente ($total_perms directorios)"
    return 0
}

# 5. Función para crear enlaces simbólicos
create_directory_symlinks() {
    log_info "PASO 5: Creación de Enlaces Simbólicos"
    log_info "-------------------------------------"

    local failed_links=0
    local total_links=0

    # 5.1 Procesar cada enlace configurado
    for source in "${!REQUIRED_SYMLINKS[@]}"; do
        local target="${REQUIRED_SYMLINKS[$source]}"
        ((total_links++))

        log_info "- Procesando enlace:"
        log_info "  Origen: $source"
        log_info "  Destino: $target"

        # 5.2 Verificar existencia del directorio origen
        if [ ! -e "$source" ]; then
            log_error "Origen no existe: $source"
            ((failed_links++))
            continue
        }

        # 5.3 Verificar directorio padre del destino
        local target_parent
        target_parent=$(dirname "$target")
        if [ ! -d "$target_parent" ]; then
            log_info "  Creando directorio padre: $target_parent"
            if ! ensure_directory "$target_parent" "755" "root" "root"; then
                log_error "Error creando directorio padre: $target_parent"
                ((failed_links++))
                continue
            fi
        }

        # 5.4 Manejar enlace existente
        if [ -e "$target" ] || [ -L "$target" ]; then
            log_info "  Destino existente, realizando backup"
            local backup_path="${target}.backup.$(date +%Y%m%d%H%M%S)"

            if ! mv "$target" "$backup_path"; then
                log_error "Error creando backup de: $target"
                ((failed_links++))
                continue
            fi
            log_success "  Backup creado: $backup_path"
        fi

        # 5.5 Crear enlace simbólico
        log_info "  Creando enlace simbólico"
        if ! ln -s "$source" "$target"; then
            log_error "Error creando enlace: $target -> $source"
            ((failed_links++))
            continue
        }

        # 5.6 Verificar enlace creado
        if ! is_symlink "$target" "$source"; then
            log_error "Verificación de enlace falló: $target -> $source"
            ((failed_links++))
            continue
        }

        log_success "  Enlace creado exitosamente"
    done

    # 5.7 Mostrar resumen
    if [ $failed_links -gt 0 ]; then
        log_error "Falló la creación de $failed_links de $total_links enlaces"
        return 1
    fi

    log_success "Enlaces simbólicos creados correctamente ($total_links enlaces)"
    return 0
}
# 6. Función para documentar la estructura creada
document_directory_structure() {
    log_info "PASO 6: Documentación de la Estructura"
    log_info "------------------------------------"

    # 6.1 Preparar directorio de documentación
    local doc_dir="${PROVISION_DIR}/docs/directory_structure"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local doc_file="${doc_dir}/structure_${timestamp}.txt"

    log_info "Preparando documentación en: $doc_dir"
    if ! ensure_directory "$doc_dir" "755" "root" "root"; then
        log_error "Error creando directorio de documentación"
        return 1
    }

    # 6.2 Documentar estructura de directorios
    {
        echo "=== Estructura de Directorios ==="
        echo "Fecha: $(date)"
        echo "Timestamp: $timestamp"
        echo ""

        echo "--- Directorios Base ---"
        for dir_name in "${!DIRECTORY_STRUCTURE[@]}"; do
            local dir_path="${DIRECTORY_STRUCTURE[$dir_name]}"
            local perms_config="${DIRECTORY_PERMISSIONS[$dir_path]}"
            local space_req="${DIRECTORY_SPACE_REQUIREMENTS[$dir_name]:-N/A}"

            echo "Directorio: $dir_name"
            echo "  Ruta: $dir_path"
            if [ -d "$dir_path" ]; then
                local current_perms
                current_perms=$(stat -c "%a" "$dir_path")
                local current_owner
                current_owner=$(stat -c "%U:%G" "$dir_path")
                local current_size
                current_size=$(du -sh "$dir_path" 2>/dev/null | cut -f1)

                echo "  Estado: Existe"
                echo "  Permisos: $current_perms"
                echo "  Owner: $current_owner"
                echo "  Tamaño: $current_size"
            else
                echo "  Estado: No existe"
            fi
            echo "  Configuración: $perms_config"
            echo "  Espacio requerido: ${space_req}MB"
            echo ""
        done

        echo "--- Enlaces Simbólicos ---"
        for source in "${!REQUIRED_SYMLINKS[@]}"; do
            local target="${REQUIRED_SYMLINKS[$source]}"
            echo "Enlace:"
            echo "  Origen: $source"
            echo "  Destino: $target"
            if is_symlink "$target" "$source"; then
                echo "  Estado: Válido"
            else
                echo "  Estado: Inválido o no existe"
            fi
            echo ""
        done

        echo "--- Resumen de Espacio ---"
        echo "Espacio total requerido: $((
            $(for size in "${DIRECTORY_SPACE_REQUIREMENTS[@]}"; do echo "$size"; done | paste -sd+ -)
        ))MB"

        # Agregar resumen de permisos únicos
        echo ""
        echo "--- Resumen de Permisos ---"
        for dir_path in "${!DIRECTORY_PERMISSIONS[@]}"; do
            local perms_config="${DIRECTORY_PERMISSIONS[$dir_path]}"
            echo "$dir_path: $perms_config"
        done

    } > "$doc_file"

    # 6.3 Verificar documentación generada
    if [ ! -f "$doc_file" ]; then
        log_error "Error: No se pudo generar la documentación"
        return 1
    }

    local doc_size
    doc_size=$(wc -l < "$doc_file")
    if [ "$doc_size" -lt 10 ]; then
        log_error "Error: Documentación generada está incompleta"
        return 1
    }

    # 6.4 Crear enlace a la última documentación
    local latest_link="${doc_dir}/latest.txt"
    if ! ln -sf "$doc_file" "$latest_link"; then
        log_warning "No se pudo crear enlace a la última documentación"
    fi

    log_success "Documentación generada exitosamente: $doc_file"
    return 0
}

# Función principal del hook
main() {
    log_header "Pre-Hook: Estructura de Directorios del Sistema"
    log_info "=============================================="

    # 1. Establecer el paso actual de provisión
    export PROVISION_STEP="directory_structure"

    # 2. Definir pasos de la estructuración
    local -A directory_steps=(
        ["validate_directory_env"]="Validación del Ambiente"
        ["verify_directory_requirements"]="Verificación de Requisitos"
        ["create_directory_structure"]="Creación de Estructura Base"
        ["set_directory_permissions"]="Establecimiento de Permisos"
        ["create_directory_symlinks"]="Creación de Enlaces Simbólicos"
        ["document_directory_structure"]="Documentación de la Estructura"
    )

    # 3. Inicializar contadores
    local total_steps=${#directory_steps[@]}
    local current_step=0
    local failed_steps=0

    # 4. Registrar inicio del proceso
    log_info "Iniciando estructuración de directorios"
    log_info "- Total de pasos: $total_steps"
    log_info "- Timestamp: $(date +%Y%m%d_%H%M%S)"

    # 5. Ejecutar cada paso
    for step_func in "${!directory_steps[@]}"; do
        ((current_step++))
        local step_name="${directory_steps[$step_func]}"

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
        save_provision_state "directory_step_${current_step}_completed"

        # 5.4 Mostrar progreso
        local percent=$((current_step * 100 / total_steps))
        log_progress "$current_step" "$total_steps" "$step_name completado"
    done

    # 6. Verificación final
    log_info ""
    log_info "Realizando verificación final..."

    # 6.1 Verificar estructura completa
    local verification_errors=0

    # Verificar directorios
    for dir_path in "${!DIRECTORY_PERMISSIONS[@]}"; do
        if [ ! -d "$dir_path" ]; then
            log_error "Directorio faltante: $dir_path"
            ((verification_errors++))
        fi
    done

    # Verificar enlaces simbólicos
    for source in "${!REQUIRED_SYMLINKS[@]}"; do
        local target="${REQUIRED_SYMLINKS[$source]}"
        if ! is_symlink "$target" "$source"; then
            log_error "Enlace simbólico inválido: $target -> $source"
            ((verification_errors++))
        fi
    done

    # 7. Mostrar resultado final
    log_info ""
    if [ "$failed_steps" -eq 0 ] && [ "$verification_errors" -eq 0 ]; then
        log_success "Estructuración de directorios completada exitosamente"
        log_info "- Pasos completados: $total_steps"
        return 0
    else
        log_warning "Estructuración completada con advertencias"
        log_info "- Pasos fallidos: $failed_steps"
        log_info "- Errores de verificación: $verification_errors"
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

    # 4. Salir con el código de error apropiado
    exit $exit_code
fi