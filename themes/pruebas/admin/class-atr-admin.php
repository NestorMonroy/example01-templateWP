<?php

class ATR_Admin {
	private $theme_name;
	private $version;
	private $build_menupage;

	/*Gestion de las funciones, de lado de la administracion*/
	function __construct($theme_name, $version){
		$this -> $theme_name = $theme_name;
		$this -> $version = $version;
		$this-> build_menupage = new ATR_Build_Menupage();

	}

	/**
	 * Registra los menús y submenus del theme en el área de administración
	 *
	 * @since    1.0.0
	 * @access   public
	 */
	public function add_menu() {
		//Así agregamos el menú
		$this -> build_menupage -> add_menu_page(
			__('Opciones de reservas','pruebas'),
			__('Opciones de reservas','pruebas'),
			'manage_options',
			'res_options_page',
			[$this, 'controlador_display_menu'],
		);

		//Así agregamos el submenú
		$this -> build_menupage -> add_submenu_page(
			'res_options_page',
			__('Submenu reservas','pruebas'),
			__('Submenu reservas','pruebas'),
			'manage_options',
			'res_submenu_reservas',
			[$this, 'controlador_display_submenu']
		);

		//asi corre la función o método
		$this -> build_menupage -> run();
	}

	/**
	 * Controla las visualizaciones del menú en el área de administración
	 *
	 * @since    1.0.0
	 * @access   public
	 */
	public function controlador_display_menu() {
		require_once ATR_DIR_PATH.'admin/partials/atr-menu-reservas-display.php';
	}

	public function controlador_display_submenu(){
		require_once ATR_DIR_PATH.'admin/partials/atr-submenu-reservas-display.php';
	}
}
