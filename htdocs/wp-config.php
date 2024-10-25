<?php
###############################################################################
##### No coloques información sensible (como contraseñas) en este archivo. #####
##### Utiliza un archivo .env separado que sobreescriba los valores predeterminados. #####
###############################################################################

/**
 * Configuración de la base de datos
 */
define('DB_NAME', 'wordpress'); // Cambia según sea necesario
define('DB_USER', 'wordpress'); // Cambia según sea necesario
define('DB_PASSWORD', 'admin123'); // Cambia según sea necesario
define('DB_HOST', '127.0.0.1:3306'); // Cambia según sea necesario
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_swedish_ci');
$table_prefix = 'wp_';

/**
 * Directorio de contenido
 */
define('WP_CONTENT_DIR', dirname(__DIR__) . '/htdocs/wp-content');

/**
 * No permitir ningún otro método de escritura que no sea directo
 */
define('FS_METHOD', 'direct');

/**
 * Claves y sales únicas de autenticación
 * Genera claves únicas desde https://api.wordpress.org/secret-key/1.1/salt/
 */
define('AUTH_KEY',         'pon tu clave aquí');
define('SECURE_AUTH_KEY',  'pon tu clave aquí');
define('LOGGED_IN_KEY',    'pon tu clave aquí');
define('NONCE_KEY',        'pon tu clave aquí');
define('AUTH_SALT',        'pon tu clave aquí');
define('SECURE_AUTH_SALT', 'pon tu clave aquí');
define('LOGGED_IN_SALT',   'pon tu clave aquí');
define('NONCE_SALT',       'pon tu clave aquí');

/**
 * Forzar HTTPS al acceder a la página de login y al área de administración
 */
define('FORCE_SSL_ADMIN', true);

/**
 * Desactivar actualizaciones automáticas
 */
define('AUTOMATIC_UPDATER_DISABLED', true);

/**
 * Desactivar el editor de archivos para mayor seguridad
 */
define('DISALLOW_FILE_EDIT', true);

/**
 * Limitar el número de revisiones de publicaciones
 */
define('WP_POST_REVISIONS', 30);

/**
 * Configuración de depuración
 */
if (defined('WP_ENV') && WP_ENV === 'production') {
	define('WP_DEBUG', false);
	define('WP_DEBUG_DISPLAY', false);
	define('WP_DEBUG_LOG', false);
} else {
	define('WP_DEBUG', true);
	define('WP_DEBUG_DISPLAY', true);
	define('WP_DEBUG_LOG', '/data/log/php-error.log');
}

/**
 * Ruta absoluta al directorio de WordPress
 */
if (!defined('ABSPATH')) {
	define('ABSPATH', dirname(__DIR__) . '/htdocs/wordpress/');
}

require_once ABSPATH . 'wp-settings.php';
