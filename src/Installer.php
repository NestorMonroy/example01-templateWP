<?php
namespace App;

class Installer {
	public static function createDropins() {
		$dropins = [
			'advanced-cache.php',
			'object-cache.php',
			'db.php'
		];

		foreach ($dropins as $dropin) {
			$source = "config/dropins/{$dropin}";
			$dest = "htdocs/wp-content/{$dropin}";

			if (file_exists($source)) {
				copy($source, $dest);
				chmod($dest, 0644);
			}
		}
	}
}
