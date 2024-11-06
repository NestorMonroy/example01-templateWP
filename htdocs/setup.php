<?php

// Asegurarnos de que estamos ejecutando desde la línea de comandos
if (PHP_SAPI !== 'cli') {
	die('Este script solo puede ejecutarse desde la línea de comandos');
}

// Cargar el script de instalación
require_once 'install.php';

try {
	// Configurar variables de entorno (opcional)
	putenv('WP_LANG=es_MX');

	// Ejecutar la instalación
	$installation = wp_install(
		'Mi Sitio WordPress',      // Título del sitio
		'admin',                   // Nombre de usuario administrador
		'admin@example.com',       // Email del administrador
		true,                      // Sitio público
		'',                        // Deprecated
		'contraseña_segura_123',   // Contraseña del administrador
		'es_MX'                    // Idioma
	);

	// Mostrar resultados de la instalación
	echo "¡Instalación completada!\n";
	echo "URL del sitio: " . $installation['url'] . "\n";
	echo "ID del usuario: " . $installation['user_id'] . "\n";
	echo "Mensaje de contraseña: " . $installation['password_message'] . "\n";

} catch (Exception $e) {
	echo "Error durante la instalación: " . $e->getMessage() . "\n";
	exit(1);
}
