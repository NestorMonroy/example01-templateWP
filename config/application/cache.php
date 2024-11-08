<?php
// Configuración de caché
return [
	'enabled' => env('CACHE_ENABLED', true),
	'driver' => env('CACHE_DRIVER', 'redis'),
	'redis' => [
		'host' => env('REDIS_HOST', '127.0.0.1'),
		'port' => env('REDIS_PORT', 6379),
		'password' => env('REDIS_PASSWORD', null),
	]
];