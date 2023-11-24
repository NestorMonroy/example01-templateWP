<?php

class ATR_Public {
    private $theme_name;
    private $version;

	/*Gestion de las funciones, de lado del tema*/
	function __construct($theme_name, $version){
		$this -> theme_name = $theme_name;
		$this -> version = $version;

	}

	public function enqueue_styles(){
		wp_enqueue_style(
			'normalize-css',
			ATR_DIR_URI."public/css/normalize.css",
			array(),
			'8.0.1',
			'all'
		);
		wp_enqueue_style(
			'public-css',
			ATR_DIR_URI."public/css/atr-public.css",
			array(),
			$this ->version,
			'all'
		);
		wp_enqueue_style(
			'bootstrap-css',
			ATR_DIR_URI."helpers/bootstrap-5.3.2/css/bootstrap.min.css",
			array(),
			'5.3.2',
			'all'
		);

		//archivos fontawesome
		wp_enqueue_style(
			'fontawesome',
			ATR_DIR_URI."helpers/fontawesome-5.15.4/css/fontawesome.min.css",
			array(),
			'5.15.4',
			'all'
		);

		//archivos fontawesome
		wp_enqueue_style(
			'brands',
			ATR_DIR_URI."helpers/fontawesome-5.15.4/css/brands.min.css",
			array(),
			'5.15.4',
			'all'
		);
	}

	public function enqueue_scripts(){
		wp_enqueue_script(
			'public-js',
			ATR_DIR_URI.'public/js/atr-public.js',
			['jquery', 'bootstrap-min'],
			$this ->version,
			true
		);
		wp_enqueue_script(
			'bootstrap-min',
			ATR_DIR_URI.'helpers/bootstrap-5.3.2/js/bootstrap.min.js',
			['jquery'],
			'5.3.2',
			true
		);
		//archivos fontawesome js
		wp_enqueue_script(
			'fontawesome',
			ATR_DIR_URI.'helpers/fontawesome-5.15.4/js/fontawesome.min.js',
			array(),
			'5.3.2',
			true
		);
		wp_enqueue_script(
			'brands',
			ATR_DIR_URI.'helpers/fontawesome-5.15.4/js/brands.min.js',
			array(),
			'5.3.2',
			true
		);
	}

	/*
	 * Aqui cargaremos algunas funciones para ajustar el menu del frontend
	 * */
	public function atr_menu_frontend(){
		//registrar Menu
		register_nav_menus([
			'menu_principal' => __('Menú Principal', 'pruebas'),
			'menu_redes_sociales' => __('Menú Redes Sociales', 'pruebas'),
		]);

		//Array para agregar las propiedades al logo
		$logo = [
			'width' => 230,
			'heigth' => 80,
			'flex-heigth' => true,
			'flex-width' => true,
			'header-text' => array('pruebas', 'un sitio web de pruebas')
		];

		add_theme_support('custom-logo', $logo);
	}
}
