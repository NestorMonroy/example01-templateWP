<?php

// Mostrar un mensaje inicial para verificar que el script se está ejecutando
echo "Ejecutando el instalador de WordPress..." . PHP_EOL;

require_once 'Installer.php'; // Ajusta esta ruta si es necesario

use WordPress\Installer;

try {
	// Intentar ejecutar la función principal
	Installer::symlinkWPContent();
} catch (Exception $e) {
	// Capturar cualquier error general y mostrarlo
	echo "Error: " . $e->getMessage() . PHP_EOL;
}
