#!/usr/bin/env bash
# Cargador de módulos helpers
#
# Este script gestiona la carga de módulos helper basado en dependencias.
# Los módulos se cargan solo cuando son necesarios y en el orden correcto.

# Definir la ruta base de los helpers
HELPER_DIR="$(dirname "${BASH_SOURCE[0]}")/helpers"

# Verificar que estamos ejecutando como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

# Registro de módulos cargados
declare -A LOADED_MODULES

# Definir dependencias de módulos
declare -A MODULE_DEPS=(
    # Módulos base
    ["colors.sh"]=""                                    # Sin dependencias
    ["logging.sh"]="colors.sh"                          # Requiere colors
    ["error.sh"]="colors.sh logging.sh"                 # Requiere logging

    # Módulos de sistema
    ["system.sh"]="logging.sh error.sh"                 # Funciones básicas del sistema
    ["sysconfig.sh"]="logging.sh error.sh system.sh"    # Configuración del sistema
    ["services.sh"]="logging.sh error.sh"               # Gestión de servicios
    ["packages.sh"]="logging.sh error.sh system.sh"     # Gestión de paquetes

    # Módulos de archivos y red
    ["filesystem.sh"]="logging.sh error.sh"             # Sistema de archivos
    ["network.sh"]="logging.sh error.sh"                # Funciones de red

    # Módulos de provisión
    ["environment.sh"]="logging.sh error.sh filesystem.sh"  # Entorno de provisión
    ["hooks.sh"]="logging.sh error.sh environment.sh"       # Sistema de hooks
)

# Función para cargar un módulo y sus dependencias
load_module() {
    local module="$1"
    local module_path="${HELPER_DIR}/${module}"

    # Si ya está cargado, salir
    if [[ "${LOADED_MODULES[$module]}" == "1" ]]; then
        return 0
    fi

    # Verificar existencia del módulo
    if [ ! -f "$module_path" ]; then
        echo "Error: Módulo no encontrado: $module_path"
        return 1
    fi

    # Cargar dependencias primero
    if [[ -n "${MODULE_DEPS[$module]}" ]]; then
        for dep in ${MODULE_DEPS[$module]}; do
            load_module "$dep"
        done
    fi

    # Cargar el módulo
    source "$module_path"
    LOADED_MODULES[$module]=1
    echo "Módulo cargado: $module"
}

# Función para cargar módulos específicos
load_helpers() {
    local modules=("$@")

    # Si no se especifican módulos, cargar todos
    if [ ${#modules[@]} -eq 0 ]; then
        modules=(
            "colors.sh"       # Colores para output
            "logging.sh"      # Sistema de logging
            "error.sh"        # Manejo de errores
            "system.sh"       # Funciones del sistema
            "sysconfig.sh"    # Configuración del sistema
            "services.sh"     # Gestión de servicios
            "packages.sh"     # Gestión de paquetes
            "filesystem.sh"   # Sistema de archivos
            "network.sh"      # Funciones de red
            "environment.sh"  # Entorno de provisión
            "hooks.sh"        # Sistema de hooks
        )
    fi

    # Cargar los módulos solicitados
    for module in "${modules[@]}"; do
        load_module "$module"
    done
}

# Ejemplos de uso:
# 1. Cargar todos los módulos:
#    source helpers.sh
#    load_helpers
#
# 2. Cargar solo módulos específicos:
#    source helpers.sh
#    load_helpers "logging.sh" "system.sh"
#
# 3. Cargar módulos de provisión:
#    source helpers.sh
#    load_helpers "environment.sh" "hooks.sh"
#
# 4. Cargar módulos de sistema:
#    source helpers.sh
#    load_helpers "system.sh" "sysconfig.sh" "services.sh"