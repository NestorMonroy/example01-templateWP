<?php
$atr_dir_path = (substr(get_template_directory(),-1) === '/') ? get_template_directory() : get_template_directory().'/';
$atr_dir_uri = (substr(get_template_directory_uri(),-1) === '/') ? get_template_directory_uri() : get_template_directory_uri().'/';

define('ATR_DIR_PATH', $atr_dir_path);
define('ATR_DIR_URI', $atr_dir_uri);

require_once ATR_DIR_PATH.'includes/class-atr-master.php';
function atr_run_master(){
	$atr_master = new ATR_MASTER;
	$atr_master ->run();
}
atr_run_master();

//Crea un nuevo menu dentro de WP
if(!function_exists('res_options_page')){
	function rest_option_page(){
		add_menu_page(
			'Opciones de Reservas',
			'Opciones de Reservas',
			'manage_options',
			'res_options_page_display',
			'res_options_page_display',
			'dashicons-flag',
			'15'
		);
		add_submenu_page(
			'res_options_page_display',
			'Submenu reservas',
			'Submenu reservas',
			'manage_options',
			'res_submenu_reserva',
			'res_submenu_reserva_display',
		);
	}
	add_action('admin_menu', 'rest_option_page');
}

/*function remove_menus(){
	remove_menu_page('res_options_page_display');
}
add_action('admin_menu', 'remove_menus');*/

if(!function_exists('res_options_page_display')){

	function res_options_page_display(){
		?>
			<!-- html -->
		<div class="wrap">
			<h3>Este es el HTML del menu</h3>
		</div>
		<?php

	}
}

if(!function_exists('res_submenu_reserva_display')){

	function res_submenu_reserva_display(){
		?>
			<!-- html -->
		<div class="wrap">
			<h3>Bienvenido a la pagina de submenu</h3>
		</div>
		<?php

	}
}
