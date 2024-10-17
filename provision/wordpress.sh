# !/bin/bash

# Función para configurar WordPress
configure_wordpress() {
    wp_dir=$1        # Directorio de WordPress
    db_name=$2       # Nombre de la base de datos
    db_user=$3       # Nombre de usuario
    db_password=$4   # Contraseña

    # Copiar el archivo de configuración de WordPress
    sudo -u www-data cp "$wp_dir/wp-config-sample.php" "$wp_dir/wp-config.php" || error_exit "Error al copiar wp-config-sample.php."

    # Configurar wp-config.php con sed
    sudo -u www-data sed -i "s/database_name_here/$db_name/" "$wp_dir/wp-config.php" || error_exit "Error al configurar el nombre de la base de datos en wp-config.php."
    sudo -u www-data sed -i "s/username_here/$db_user/" "$wp_dir/wp-config.php" || error_exit "Error al configurar el nombre de usuario en wp-config.php."
    sudo -u www-data sed -i "s/password_here/$db_password/" "$wp_dir/wp-config.php" || error_exit "Error al configurar la contraseña en wp-config.php."
}