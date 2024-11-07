#!/bin/bash

# Función para mostrar un mensaje de error y salir
error_exit() {
    echo "$1" 1>&2
    exit 1
}

# Actualizar la lista de paquetes
update() {
    echo "Actualizando la lista de paquetes..."
    if ! sudo apt-get update; then
        error_exit "Error al actualizar la lista de paquetes"
    fi
}

# Función para actualizar todos los paquetes instalados a través de apt
apt_packages_upgrade() {
    echo "Actualizando paquetes instalados..."
    if ! sudo apt-get upgrade -y; then
        error_exit "Error al actualizar los paquetes instalados"
    fi
}

# Función para instalar un paquete si no está ya instalado
install_package() {
    package_name=$1
    if ! dpkg -l | grep -qw "$package_name"; then
        echo "Instalando $package_name..."
        if ! sudo apt-get install -y "$package_name"; then
            error_exit "Error al instalar $package_name"
        fi
    else
        echo "$package_name ya está instalado."
    fi
}

# Función para crear varios directorios
create_directories() {
    for dir in "$@"; do
        # Crear el directorio si no existe
        sudo mkdir -p "$dir" || error_exit "Error al crear el directorio $dir."
    done
}

# Función para asignar permisos a directorios
set_permissions_dir() {
    # Acepta el propietario como argumento
    owner=$1
    shift  # Mueve para dejar solo los directorios

    for dir in "$@"; do
        # Cambiar propietario recursivamente
        sudo chown -R "$owner" "$dir" || error_exit "Error al asignar permisos al directorio $dir."
    done
}

set_permissions() {
    # Acepta el propietario y los permisos como argumentos
    owner=$1
    permissions=$2
    shift 2  # Mueve dos posiciones para dejar solo los directorios

    for dir in "$@"; do
        # Cambiar propietario recursivamente
        sudo chown -R "$owner" "$dir" || error_exit "Error al asignar permisos al directorio $dir."

        # Cambiar permisos si se especificaron
        if [[ -n "$permissions" ]]; then
            sudo chmod "$permissions" "$dir" || error_exit "Error al establecer permisos en el directorio $dir."
        fi
    done
}


install_archive() {
    local url=$1
    local destination=$2
    local user=${3:-}  # Si no se proporciona, user será una cadena vacía

    # Descargar y extraer el archivo con o sin usuario
    if [ -n "$user" ]; then
        # Si se proporciona un usuario, usar sudo -u
        curl "$url" | sudo -u "$user" tar zx -C "$destination" || error_exit "Error al descargar o extraer el archivo desde $url en $destination."
    else
        # Si no se proporciona un usuario, ejecutar como el usuario actual
        curl "$url" | tar zx -C "$destination" || error_exit "Error al descargar o extraer el archivo desde $url en $destination."
    fi
}

download_file() {
    local url=$1
    local dest_dir=$2
    local file_name=$(basename "$url")
    local dest_file="$dest_dir/$file_name"

    # Verificar si el directorio de destino existe
    if [[ ! -d "$dest_dir" ]]; then
        error_exit "Error: El directorio '$dest_dir' no existe."
    fi

    # Comprobar si el archivo no existe
    if [[ ! -f "$dest_file" ]]; then
        # Descargar el archivo
        wget -O "$dest_file" "$url" || error_exit "Error al descargar el archivo desde $url."
    else
        echo "El archivo '$dest_file' ya existe. No es necesario volver a descargarlo."
    fi
}

copy_config_file() {
    local source_file=$1
    local dest_file=$2

    # Verificar si el archivo de origen existe
    if [[ ! -f "$source_file" ]]; then
        echo "Error: El archivo de origen '$source_file' no existe."
        exit 1
    fi

    # Copiar archivo de configuración
    sudo cp "$source_file" "$dest_file" || error_exit "Error al copiar el archivo de configuración de $source_file a $dest_file."
}

#!/bin/bash
# provision/scripts/helpers.sh

# Colores para los mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Definir directorios base
WORDPRESS_DIR="/data/wordpress"
PROVISION_DIR="$WORDPRESS_DIR/provision"
SCRIPTS_DIR="$PROVISION_DIR/scripts"
CONFIG_DIR="$PROVISION_DIR/config"

# Función para imprimir mensajes
log() {
    echo -e "${GREEN}[PROVISION]:${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]:${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]:${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]:${NC} $1"
}

# Función para verificar si un comando fue exitoso
check_error() {
    if [ $? -ne 0 ]; then
        error "$1"
        exit 1
    fi
}

# Función para verificar si un directorio existe
check_directory() {
    if [ ! -d "$1" ]; then
        error "Directorio no encontrado: $1"
        exit 1
    fi
}

# Función para verificar si un archivo existe
check_file() {
    if [ ! -f "$1" ]; then
        error "Archivo no encontrado: $1"
        exit 1
    fi
}

# Función para verificar si un programa está instalado
check_program() {
    if ! command -v "$1" &> /dev/null; then
        error "Programa no encontrado: $1"
        exit 1
    fi
}

# Función para crear directorios si no existen
ensure_directory() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        check_error "No se pudo crear el directorio: $1"
    fi
}

# Función para copiar archivos con verificación
safe_copy() {
    if [ ! -f "$1" ]; then
        error "Archivo fuente no encontrado: $1"
        exit 1
    fi
    cp "$1" "$2"
    check_error "No se pudo copiar el archivo: $1 -> $2"
}

# Función para establecer permisos
set_permissions() {
    local path="$1"
    local perms="$2"
    local owner="$3"
    local group="$4"

    chmod "$perms" "$path"
    check_error "No se pudieron establecer los permisos en: $path"

    chown "$owner:$group" "$path"
    check_error "No se pudo cambiar el propietario en: $path"
}

# Función para verificar servicios
check_service() {
    if ! systemctl is-active --quiet "$1"; then
        error "El servicio $1 no está activo"
        exit 1
    fi
}

# Función para recargar servicios de manera segura
reload_service() {
    systemctl reload "$1"
    check_error "No se pudo recargar el servicio: $1"
}

# Función para reiniciar servicios de manera segura
restart_service() {
    systemctl restart "$1"
    check_error "No se pudo reiniciar el servicio: $1"
}

# Función para verificar puerto en uso
check_port() {
    if netstat -tuln | grep -q ":$1 "; then
        warning "El puerto $1 ya está en uso"
    fi
}

# Función para mostrar el progreso
show_progress() {
    echo -e "${BLUE}-->${NC} $1"
}

# Función para leer configuración
get_config() {
    local config_file="$WORDPRESS_DIR/config.yml"
    if [ ! -f "$config_file" ]; then
        error "Archivo de configuración no encontrado: $config_file"
        exit 1
    fi
    # Aquí podrías implementar la lógica para leer el archivo YAML
    # Por ahora, es un placeholder
}

# Función para respaldar archivos antes de modificarlos
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d%H%M%S)"
        check_error "No se pudo crear respaldo de: $file"
    fi
}

# Exportar variables de entorno comunes
export DEBIAN_FRONTEND=noninteractive
export WORDPRESS_DIR PROVISION_DIR SCRIPTS_DIR CONFIG_DIR

# Verificar que estamos ejecutando como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root"
   exit 1
fi