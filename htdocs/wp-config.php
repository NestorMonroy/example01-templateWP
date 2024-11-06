<?php
/**
 * Configuración básica de WordPress.
 *
 * Este archivo contiene las siguientes configuraciones:
 * * Ajustes de la base de datos
 * * Claves secretas
 * * Prefijo de tablas
 * * ABSPATH
 */

// Cargar Composer autoload si existe
if (file_exists(dirname(__DIR__) . '/vendor/autoload.php')) {
	require_once dirname(__DIR__) . '/vendor/autoload.php';
}

// Cargar variables de entorno
if (file_exists(dirname(__DIR__) . '/.env')) {
	$dotenv = Dotenv\Dotenv::createUnsafeImmutable(dirname(__DIR__));
	$dotenv->load();
}

/**
 * Configuración de la base de datos
 */
define('DB_NAME', getenv('DB_NAME'));
define('DB_USER', getenv('DB_USER'));
define('DB_PASSWORD', getenv('DB_PASSWORD'));
define('DB_HOST', getenv('DB_HOST') ? getenv('DB_HOST') : '127.0.0.1:3306');
define('DB_CHARSET', getenv('DB_CHARSET') ? getenv('DB_CHARSET') : 'utf8mb4');
define('DB_COLLATE', getenv('DB_COLLATE') ? getenv('DB_COLLATE') : 'utf8mb4_swedish_ci');
$table_prefix = getenv('DB_PREFIX') ? getenv('DB_PREFIX') : 'wp_';

/**
 * Configuración de URLs
 */
define('WP_HOME', getenv('WP_HOME'));
define('WP_SITEURL', getenv('WP_SITEURL'));

/**
 * Directorio de contenido personalizado
 */
define('CONTENT_DIR', '/wp-content');
define('WP_CONTENT_DIR', dirname(__DIR__) . '/htdocs' . CONTENT_DIR);
// define('WP_CONTENT_URL', CONTENT_DIR);

/**
 * Método de sistema de archivos
 */
define('FS_METHOD', 'direct');

/**
 * Claves únicas de autenticación y semillas
 */
define('AUTH_KEY',         getenv('AUTH_KEY'));
define('SECURE_AUTH_KEY',  getenv('SECURE_AUTH_KEY'));
define('LOGGED_IN_KEY',    getenv('LOGGED_IN_KEY'));
define('NONCE_KEY',        getenv('NONCE_KEY'));
define('AUTH_SALT',        getenv('AUTH_SALT'));
define('SECURE_AUTH_SALT', getenv('SECURE_AUTH_SALT'));
define('LOGGED_IN_SALT',   getenv('LOGGED_IN_SALT'));
define('NONCE_SALT',       getenv('NONCE_SALT'));

/**
 * Configuraciones de seguridad
 */
define('FORCE_SSL_ADMIN', true);
define('AUTOMATIC_UPDATER_DISABLED', true);
define('DISALLOW_FILE_EDIT', true);

/**
 * Optimizaciones
 */
define('WP_POST_REVISIONS', 30);
define('PLL_COOKIE', false);
define('WPML_CACHE_PATH_ROOT', dirname(__DIR__) . '/htdocs/wp-content/cache/wpml/');

/**
 * Configuración de sesiones
 */
define('COOKIEHASH', getenv('CONTAINER'));

/**
 * Configuración de Debug
 */
if ('production' === getenv('WP_ENV')) {
	define('WP_DEBUG', false);
	define('WP_DEBUG_DISPLAY', false);
	define('WP_DEBUG_LOG', false);
	define('SCRIPT_DEBUG', false);
} else {
	define('WP_DEBUG', true);
	define('WP_DEBUG_DISPLAY', true);
	define('WP_DEBUG_LOG', '/data/log/php-error.log');
	define('SCRIPT_DEBUG', true);
	define('WP_DEVELOPMENT_MODE', 'all');
}

/**
 * Reparación de base de datos
 */
define('WP_ALLOW_REPAIR', true);

/**
 * Configuración de logs de PHP
 */
ini_set('log_errors', 'On');
ini_set('error_log', '/data/log/php-error.log');

/**
 * Variables personalizadas adicionales
 */
define('WP_ENVIRONMENT_TYPE', getenv('WP_ENV'));
define('WP_CACHE', false);

/* ¡Eso es todo, deja de editar! */

/** Ruta absoluta al directorio de WordPress. */
if (!defined('ABSPATH')) {
	define('ABSPATH', dirname(__DIR__) . '/htdocs/wordpress/');
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';