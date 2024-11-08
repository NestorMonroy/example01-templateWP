<?php
namespace App\Cache;

class RedisCache {
	private $redis;

	public function __construct() {
		$this->redis = new \Redis();
		$this->connect();
	}

	private function connect() {
		$config = require config_path('application/cache.php');
		$this->redis->connect(
			$config['redis']['host'],
			$config['redis']['port']
		);
	}
}