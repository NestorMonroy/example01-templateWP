#!/usr/bin/env bash

# Cargar configuración y helpers
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Función para verificar dependencias
check_provision_dependencies() {
    local dependencies=(
        "wget"
        "curl"
        "git"
        "tar"
        "gzip"
        "mysql"
    )

    log_info "Verificando dependencias..."
    install_packages "${dependencies[@]}"
}

# Función para ejecutar pre-hooks
run_provision_pre_hooks() {
    local hooks_dir="${PROVISION_DIR}/hooks/pre"

    if [ -d "$hooks_dir" ]; then
        log_info "Ejecutando pre-hooks..."

        for hook in "$hooks_dir"/*.sh; do
            if [ -f "$hook" ]; then
                log_info "Ejecutando hook: $(basename "$hook")"
                if ! bash "$hook"; then
                    log_error "Hook falló: $(basename "$hook")"
                    return 1
                fi
            fi
        done
    fi
}

# Función para ejecutar post-hooks
run_provision_post_hooks() {
    local hooks_dir="${PROVISION_DIR}/hooks/post"

    if [ -d "$hooks_dir" ]; then
        log_info "Ejecutando post-hooks..."

        for hook in "$hooks_dir"/*.sh; do
            if [ -f "$hook" ]; then
                log_info "Ejecutando hook: $(basename "$hook")"
                if ! bash "$hook"; then
                    log_warning "Hook falló: $(basename "$hook")"
                fi
            fi
        done
    fi
}

# Función principal de provisión
main_provision() {
      log_header "Iniciando Provisión de WordPress"

      # Inicializar entorno de provisión
      init_provision_env || {
          handle_error "Error al inicializar el entorno de provisión"
          exit 1
      }

      # 1. Ejecutar pre-hooks
      log_info "Ejecutando pre-hooks..."
      run_pre_hooks || {
          handle_error "Error en pre-hooks"
          exit 1
      }

      # 2. Instalar y configurar componentes principales
      log_header "Instalación de Componentes Principales"

      # 2.1 Configurar PHP
      log_info "Configurando PHP..."
      source "${PROVISION_DIR}/scripts/setup-php.sh" || {
          handle_error "Error en configuración de PHP"
          exit 1
      }

      # 2.2 Configurar MySQL
      log_info "Configurando MySQL..."
      source "${PROVISION_DIR}/scripts/setup-mysql.sh" || {
          handle_error "Error en configuración de MySQL"
          exit 1
      }

      # 2.3 Instalar y configurar WordPress
      log_info "Instalando WordPress..."
      source "${PROVISION_DIR}/scripts/setup-wordpress.sh" || {
          handle_error "Error en instalación de WordPress"
          exit 1
      }

      # 3. Ejecutar post-hooks
      log_info "Ejecutando post-hooks..."
      run_post_hooks || {
          handle_error "Error en post-hooks"
          exit 1
      }

      # 4. Verificación final
      log_header "Verificación Final"

      # Verificar servicios principales
      local required_services=(php-fpm mysql nginx)
      for service in "${required_services[@]}"; do
          if ! systemctl is-active --quiet "$service"; then
              handle_error "El servicio $service no está activo"
              exit 1
          fi
      }

      # Verificar acceso a WordPress
      if ! curl -sSf "http://localhost" > /dev/null; then
          handle_error "No se puede acceder a WordPress"
          exit 1
      }

      # Verificar permisos finales
      verify_wordpress_permissions || {
          handle_error "Error en permisos finales"
          exit 1
      }

      # 5. Mostrar información final
      log_success "Provisión completada exitosamente"

      cat << EOF

  =============================================
  WordPress instalado correctamente
  =============================================
  URL: http://localhost
  Directorio: ${PROJECT_DIR}
  Base de datos: wordpress
  Usuario WP: admin
  Contraseña WP: Ver .env

  Para acceder:
  1. Agrega la entrada en /etc/hosts
  2. Accede a http://localhost/wp-admin
  3. Las credenciales están en el archivo .env

  Logs: ${LOGS_DIR}/provision_latest.log
  =============================================
EOF

      return 0
    # Inicializar entorno
    init_provision_env

    # Verificar si estamos ejecutando como root
    if [[ $EUID -ne 0 ]]; then
        error_exit "Este script debe ejecutarse como root"
    fi

    # Mostrar información inicial
    log_header "Iniciando Provisión"
    log_info "Fecha: $(date)"
    log_info "Sistema: $(get_system_info)"

    # Verificar requisitos básicos
    check_system_requirements 512 1
    check_internet_connection
    check_disk_space 1000 "/data"

    # Verificar dependencias
    check_provision_dependencies

    # Ejecutar pre-hooks
    run_provision_pre_hooks || {
        log_error "Los pre-hooks fallaron"
        return 1
    }

    # Realizar tareas principales de provisión
    log_header "Tareas Principales de Provisión"

    local scripts=(
        "setup-php.sh"
        "setup-mysql.sh"
        "setup-wordpress.sh"
    )

    for script in "${scripts[@]}"; do
        local script_path="${PROVISION_DIR}/scripts/${script}"
        if [ -f "$script_path" ]; then
            log_info "Ejecutando: $script"
            if ! bash "$script_path"; then
                log_error "Script falló: $script"
                return 1
            fi
        else
            log_error "Script no encontrado: $script"
            return 1
        fi
    done

    # Ejecutar post-hooks
    run_provision_post_hooks

    return 0
}

# Ejecutar provisión
main_provision

# La limpieza se maneja automáticamente a través del trap en config.sh
exit $?