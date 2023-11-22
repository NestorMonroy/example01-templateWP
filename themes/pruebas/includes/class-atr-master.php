<?php
/*Gestion de las acciones dentro de admin y public*/
class ATR_MASTER{
    protected $cargador;
    protected $theme_name;
    protected $version;

    public function __construct(){
		//Es el nombre que se pasa a las classes admin y public
        $this -> theme_name = 'ATR_Pruebas';
        $this -> version = '1.0.0';
        $this -> cargar_dependencias();
		$this -> cargar_instancias();
		$this -> set_idiomas();
		$this -> definir_admin_hooks();
		$this -> definir_public_hooks();

    }

    private function cargar_dependencias(){
		/**
		 * La clase responsable de iterar las acciones y filtros del nucleo del tema
		 */
	    require_once ATR_DIR_PATH.'includes/class-atr-cargador.php';
	    /**
	     * La clase responsable de definir la funcinalidad de la internalizacion del tema
	     */
	    require_once ATR_DIR_PATH.'includes/class-atr-i18n.php';
	    /**
	     * La clase responsable de registrar menus y submenus en el area de administracion tema
	     */
	    require_once ATR_DIR_PATH.'includes/class-atr-build-menupage.php';
		/**
	     * La clase responsable de definir todas las acciones en el area de administracion
	     */
	    require_once ATR_DIR_PATH.'admin/class-atr-admin.php';
		/**
	     * La clase responsable de definir todas las acciones en el area del lado del cliente/publico
	     */
	    require_once ATR_DIR_PATH.'public/class-atr-public.php';
    }

	private function set_idiomas(){
		$atr_i18n = new ATR_i18n();
		$this -> cargador -> add_action('after_setup_theme', $atr_i18n, 'load_theme_textdomain');
	}

	private function cargar_instancias(){
		/*
		 * Cree una instancia del cargador que se utilizara para registrar los hooks con WP
		 */

		$this -> cargador = new ATR_Cargador;
		$this -> atr_admin = new ATR_Admin($this -> get_theme_name(), $this -> get_version());
		$this -> atr_public = new ATR_Public($this -> get_theme_name(), $this -> get_version());
	}


	private function definir_admin_hooks(){

	}
	private function definir_public_hooks(){
		$this -> cargador -> add_action('wp_enqueue_scripts', $this -> atr_public, 'enqueue_styles');
		$this -> cargador -> add_action('wp_enqueue_scripts', $this -> atr_public, 'enqueue_scripts');

	}

	public function get_theme_name(){
		return $this -> theme_name;
	}
	public function get_version(){
		return $this -> version;
	}

	public function get_cargador(){
		return $this -> cargador;
	}

	public function run(){
		$this ->cargador -> run();
	}

}
