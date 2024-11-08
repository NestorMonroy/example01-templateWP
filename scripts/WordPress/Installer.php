<?php
// scripts/WordPress/Installer.php
namespace WordPress;

class Installer
{
	/**
	 * Crea el symlink para wp-content
	 */
	public static function symlinkWPContent()
	{
		$wpContentTarget = 'htdocs/wordpress/wp-content';
		$wpContentLink = 'htdocs/wp-content';

		echo "Configurando wp-content...\n";

		// Remover wp-content original si existe
		if (is_dir($wpContentTarget) && !is_link($wpContentTarget)) {
			self::removeDirectory($wpContentTarget);
		}

		// Crear directorio wp-content si no existe
		if (!is_dir($wpContentLink)) {
			mkdir($wpContentLink, 0755, true);
			echo "Directorio wp-content creado\n";
		}

		// Crear el symlink
		if (!is_link($wpContentTarget)) {
			@unlink($wpContentTarget);
			symlink('../wp-content', $wpContentTarget);
			echo "Symlink wp-content creado\n";
		}

		// Crear subdirectorios necesarios
		$directories = [
			"$wpContentLink/plugins",
			"$wpContentLink/themes",
			"$wpContentLink/mu-plugins",
			"$wpContentLink/uploads",
			"$wpContentLink/languages",
			"$wpContentLink/upgrade"
		];

		foreach ($directories as $dir) {
			if (!is_dir($dir)) {
				mkdir($dir, 0755, true);
				echo "Directorio $dir creado\n";
			}
		}
	}

	/**
	 * Configura permisos iniciales
	 */
	public static function setupPermissions()
	{
		echo "Configurando permisos...\n";

		$paths = [
			'htdocs/wp-content/uploads' => 0775,
			'htdocs/wp-content/upgrade' => 0775,
			'htdocs/wp-content/languages' => 0775
		];

		foreach ($paths as $path => $mode) {
			if (is_dir($path)) {
				chmod($path, $mode);
				echo "Permisos establecidos para $path\n";
			}
		}
	}

	/**
	 * Crea el archivo .env si no existe
	 */
	public static function createEnvFile()
	{
		if (!file_exists('.env') && file_exists('.env.example')) {
			copy('.env.example', '.env');
			echo "Archivo .env creado\n";
		}
	}

	/**
	 * Configura archivos de ambiente
	 */
	public static function setupEnvironment()
	{
		// Crear directorios de configuración si no existen
		$configDirs = [
			'config/environments',
			'config/application'
		];

		foreach ($configDirs as $dir) {
			if (!is_dir($dir)) {
				mkdir($dir, 0755, true);
				echo "Directorio $dir creado\n";
			}
		}
	}

	/**
	 * Elimina un directorio y su contenido
	 */
	private static function removeDirectory($dir)
	{
		if (!is_dir($dir)) {
			return;
		}

		$files = array_diff(scandir($dir), ['.', '..']);
		foreach ($files as $file) {
			$path = "$dir/$file";
			is_dir($path) ? self::removeDirectory($path) : unlink($path);
		}
		rmdir($dir);
	}
}