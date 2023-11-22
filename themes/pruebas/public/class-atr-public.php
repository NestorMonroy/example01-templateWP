<?php

class ATR_Public {
    private $theme_name;
    private $version;

	/*Gestion de las funciones, de lado del tema*/
	function __construct($theme_name, $version){
		$this -> $theme_name = $theme_name;
		$this -> $version = $version;

	}
}
