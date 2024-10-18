<?php

namespace WordPress;

class Installer {
	/**
	 * Elimina completamente el wp-content predeterminado de WordPress y lo reemplaza
	 * con un enlace simbólico a ../wp-content. Esto también elimina el tema y los plugins predeterminados.
	 */
	public static function symlinkWPContent() {
		$root = dirname( __DIR__, 2 ); // Obtiene el directorio raíz del proyecto
		$wp_core_content_folder = "{$root}/htdocs/wordpress/wp-content"; // Ruta del wp-content de WordPress
		$wp_content_folder = "{$root}/htdocs/wp-content"; // Ruta del nuevo wp-content

		// Verificar la existencia de los directorios
		if (!file_exists($wp_core_content_folder)) {
			echo "Error: El directorio wp-content del núcleo no existe: {$wp_core_content_folder}" . PHP_EOL;
			return;
		}

		if (!file_exists($wp_content_folder)) {
			echo "Error: El directorio de destino wp-content no existe: {$wp_content_folder}" . PHP_EOL;
			return;
		}

		// Verificar si el enlace simbólico ya existe
		if (is_link($wp_core_content_folder)) {
			echo "Enlace simbólico ya existe: {$wp_core_content_folder}" . PHP_EOL;
			return;
		}

		// Si el directorio wp-content existe y no es un enlace simbólico, eliminarlo
		if (file_exists($wp_core_content_folder)) {
			self::rrmdir($wp_core_content_folder); // Elimina el directorio wp-content existente
			echo "Directorio wp-content del núcleo eliminado: {$wp_core_content_folder}" . PHP_EOL;
		}

		// Intentar crear el enlace simbólico
		try {
			if (!self::is_windows()) {
				symlink($wp_content_folder, $wp_core_content_folder);
				echo "Enlace simbólico creado: {$wp_core_content_folder} -> {$wp_content_folder}" . PHP_EOL;
			} else {
				echo 'Windows: No se creó el enlace simbólico, pero se eliminó wp-content del núcleo.' . PHP_EOL;
			}
		} catch (\Exception $e) {
			echo "Error al crear el enlace simbólico: " . $e->getMessage() . PHP_EOL;
		}
	}

	/**
	 * Elimina un directorio de forma recursiva
	 *
	 * @param String $dir - ruta al directorio que se va a eliminar
	 */
	public static function rrmdir($dir) {
		// Eliminar primero todos los archivos ocultos
		foreach (glob($dir . '/.*') as $file) {
			if (is_file($file)) {
				unlink($file);
			}
		}
		foreach (glob($dir . '/*') as $file) {
			if (is_dir($file)) {
				self::rrmdir($file);
			} else {
				unlink($file);
			}
		}
		rmdir($dir);
	}

	/**
	 * Verifica si el sistema es Windows
	 *
	 * @return bool
	 */
	private static function is_windows() {
		return strtoupper(substr(PHP_OS, 0, 3)) === 'WIN';
	}
}
