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
set_permissions() {
    # Acepta el propietario y los directorios como argumentos
    owner=$1
    shift
    for dir in "$@"; do
        sudo chown "$owner" "$dir" || error_exit "Error al asignar permisos al directorio $dir."
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