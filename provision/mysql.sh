#!/bin/bash

# Función para ejecutar comandos de MySQL
execute_mysql_command() {
    command=$1  # Comando de MySQL a ejecutar

    # Ejecutar comando MySQL como root
    mysql -u root -e "$command" || error_exit "Error al ejecutar el comando MySQL: $command."
}

# Función para configurar la base de datos
setup_database() {
    db_name=$1      # Nombre de la base de datos
    db_user=$2      # Nombre de usuario
    db_password=$3  # Contraseña

    # Crear base de datos
    execute_mysql_command "CREATE DATABASE IF NOT EXISTS $db_name;"

    # Crear usuario (si no existe)
    execute_mysql_command "CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';"

    # Otorgar permisos al usuario
    execute_mysql_command "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON $db_name.* TO '$db_user'@'localhost';"

    # Limpiar privilegios
    execute_mysql_command "FLUSH PRIVILEGES;"
}


