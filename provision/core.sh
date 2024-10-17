# Incluir el archivo utils.sh
source /vagrant/provision/utils.sh
source /vagrant/provision/apache.sh
source /vagrant/provision/mysql.sh
source /vagrant/provision/wordpress.sh

# Actualizar la lista de paquetes y luego actualizar todos los paquetes instalados
update
apt_packages_upgrade

# Lista de paquetes a instalar
PACKAGES=(
    apache2
    ghostscript
    libapache2-mod-php
    mysql-server
    php
    php-bcmath
    php-curl
    php-imagick
    php-intl
    php-json
    php-mbstring
    php-mysql
    php-xml
    php-zip
)

# Lista de directorios a crear
DIRECTORIES=(
    /srv/www
    /srv/backup
    /usr/share/adminer
)

# URL de WordPress
WORDPRESS_URL="https://wordpress.org/latest.tar.gz"
WORDPRESS_DESTINATION="/srv/www"
WORDPRESS_USER="www-data"
WORDPRESS_USER_FILE_CONF="/vagrant/provision/conf/wordpress.conf"
WORDPRESS_CONF="/etc/apache2/sites-available/wordpress.conf"

# URL de Adminer
ADMINER_URL="https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1-en.php"
ADMINER_DESTINATION="/usr/share/adminer"
ADMINER_USER_FILE_CONF="/vagrant/provision/conf/adminer.conf"
ADMINER_CONF="/etc/apache2/conf-available/adminer.conf"

# Lista de sitios a habilitar/deshabilitar
SITES_TO_ENABLE=(
    wordpress
)

SITES_TO_DISABLE=(
    000-default
)

# Lista de módulos a habilitar
MODULES_TO_ENABLE=(
    rewrite
    ssl
)

# Variables para la base de datos
db_name="wordpress"
db_user="wordpress"
db_password="admin123"
wp_directory="/srv/www/wordpress"

# Instalar todos los paquetes
for package in "${PACKAGES[@]}"; do
    install_package "$package"
done

# Crear los directorios necesarios
create_directories "${DIRECTORIES[@]}"

# Asignar permisos
set_permissions "www-data" /srv/www

# Instalar WordPress
install_archive "$WORDPRESS_URL" "$WORDPRESS_DESTINATION" "$WORDPRESS_USER"

# Copiar archivo de configuración de WordPress
copy_config_file "$WORDPRESS_USER_FILE_CONF" "$WORDPRESS_CONF"

# Instalar Adminer
download_file "$ADMINER_URL" "$ADMINER_DESTINATION"

# Habilitar sitios
enable_sites "${SITES_TO_ENABLE[@]}"

# Deshabilitar sitios predeterminados
disable_sites "${SITES_TO_DISABLE[@]}"

# Habilitar módulos necesarios
enable_modules "${MODULES_TO_ENABLE[@]}"

# Recargar Apache para aplicar cambios
reload_apache

# Configurar la base de datos de WordPress
setup_database "$db_name" "$db_user" "$db_password"

# Configurar WordPress
configure_wordpress "$wp_directory" "$db_name" "$db_user" "$db_password"

# Copiar archivo de configuración de Adminer
copy_config_file "$ADMINER_USER_FILE_CONF" "$ADMINER_CONF"

execute_apache_command "a2enconf adminer" "a2enmod rewrite"

# Recargar Apache para aplicar cambios
reload_apache