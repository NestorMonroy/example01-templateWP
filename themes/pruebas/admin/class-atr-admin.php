<?php

class ATR_Admin {
	private $theme_name;
	private $version;

	/*Gestion de las funciones, de lado de la administracion*/
	function __construct($theme_name, $version){
		$this -> $theme_name = $theme_name;
		$this -> $version = $version;

	}
}
