<?php
/**
 * Dropin para caché de objetos con Redis
 */
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Redis_Object_Cache {
	private static $redis;
	private static $connected = false;

	public static function initialize() {
		if ( ! extension_loaded( 'redis' ) ) {
			return false;
		}

		self::$redis = new Redis();

		try {
			$host = defined( 'WP_REDIS_HOST' ) ? WP_REDIS_HOST : '127.0.0.1';
			$port = defined( 'WP_REDIS_PORT' ) ? WP_REDIS_PORT : 6379;

			self::$connected = self::$redis->connect( $host, $port );

			if ( defined( 'WP_REDIS_PASSWORD' ) ) {
				self::$redis->auth( WP_REDIS_PASSWORD );
			}

			return self::$connected;
		} catch ( Exception $e ) {
			error_log( 'Redis connection error: ' . $e->getMessage() );

			return false;
		}
	}

	public static function get( $key ) {
		if ( ! self::$connected ) {
			return false;
		}

		return self::$redis->get( $key );
	}

	public static function set( $key, $value, $expiration = 0 ) {
		if ( ! self::$connected ) {
			return false;
		}

		return self::$redis->set( $key, $value, $expiration );
	}
}
