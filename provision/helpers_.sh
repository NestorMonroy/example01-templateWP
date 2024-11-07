#!/usr/bin/env bash
# Cargador de módulos helpers

# Definir la ruta base de los helpers
HELPER_DIR="$(dirname "${BASH_SOURCE[0]}")/helpers"

# Verificar que estamos ejecutando como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

# Cargar módulos en orden
declare -a MODULES=(
    "colors.sh"     # Colores para output
    "logging.sh"    # Funciones de logging
    "error.sh"      # Manejo de errores
    "system.sh"     # Funciones del sistema
    "network.sh"    # Funciones de red
    "packages.sh"   # Gestión de paquetes
    "filesystem.sh" # Operaciones de archivos
)

# Función para cargar un módulo
load_module() {
    local module="$1"
    local module_path="${HELPER_DIR}/${module}"

    if [ ! -f "$module_path" ]; then
        echo "Error: Módulo no encontrado: $module_path"
        exit 1
    }

    source "$module_path"
}

# Cargar todos los módulos
for module in "${MODULES[@]}"; do
    load_module "$module"
done