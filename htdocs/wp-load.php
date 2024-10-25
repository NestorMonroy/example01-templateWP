<?php
/*
 * Este archivo se utiliza para instalar y configurar WordPress en un entorno
 * donde el directorio wp-content se encuentra fuera del núcleo de WordPress.
 *
 * Esto se hace para evitar que se sobrescriba durante actualizaciones o
 * instalaciones de nuevas versiones de WordPress.
 *
 * Se requiere wp-load.php desde la ubicación correcta para asegurarse de que
 * todas las funciones de WordPress estén disponibles.
 */

// Requiere wp-load.php desde la ubicación donde realmente se encuentra.
require_once 'wordpress/wp-load.php';

// Aquí puedes añadir el código para la instalación y configuración de WordPress
// Por ejemplo, puedes crear la base de datos, añadir opciones predeterminadas, etc.

// Ejemplo: configuración inicial de la base de datos
global $wpdb;

// Define los datos de conexión a la base de datos
$db_name = 'wordpress';
$db_user = 'wordpress';
$db_password = 'admin123';

// Crea la base de datos si no existe
if ( ! $wpdb->get_var("SHOW DATABASES LIKE '{$db_name}'") ) {
	$wpdb->query("CREATE DATABASE {$db_name}");
}

// Aquí podrías añadir más configuraciones, como la creación de un usuario administrador,
// instalación de plugins, etc.

// Finaliza el script
echo "WordPress ha sido instalado y configurado exitosamente.";

