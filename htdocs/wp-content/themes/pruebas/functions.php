<?php
/**
 * Define la ruta absoluta al directorio del tema.
 *
 * Esta variable se asegura de que la ruta siempre termine con una barra diagonal.
 *
 */
$atr_dir_path = rtrim(get_template_directory(), '/') . '/';

/**
 * Define la URI al directorio del tema.
 *
 * Esta variable se asegura de que la URI siempre termine con una barra diagonal.
 *
 */
$atr_dir_uri = (substr(get_template_directory_uri(), -1) === '/') ? get_template_directory_uri() : get_template_directory_uri() . '/';

define('ATR_DIR_PATH', $atr_dir_path);
define('ATR_DIR_URI', $atr_dir_uri);

/**
 * Inicializa la clase ATR_MASTER y ejecuta su función principal.
 *
 * Descripción Breve: Esta función crea una instancia de la clase ATR_MASTER y ejecuta su método run.
 *
 * @return void
 *
 * @throws Exception Lanza una excepción si la inicialización falla.
 *
 * @example
 * atr_run_master();
 */
function atr_run_master() {
    if (class_exists('ATR_MASTER')) {
        try {
            $atr_master = new ATR_MASTER();
            $atr_master->run();
        } catch (Exception $e) {
            // Manejo de errores: puedes registrar el error o mostrar un mensaje
            error_log('Error al ejecutar ATR_MASTER: ' . $e->getMessage());
        }
    } else {
        // Registro de un error si la clase no existe
        error_log('La clase ATR_MASTER no está definida.');
    }
}

// Llama a la función atr_run_master
try {
    atr_run_master();
} catch (Exception $e) {
    error_log('No existe la función');
}

/**
 * Crea un nuevo menú de opciones en el panel de administración de WordPress.
 *
 * Descripción Breve: Esta función añade un menú y un submenú en el panel de administración.
 *
 * @return void
 *
 * @example
 * res_options_page();
 */
if (!function_exists('res_options_page')) {
    function res_options_page() {
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
            'res_submenu_reserva_display'
        );
    }
    add_action('admin_menu', 'res_options_page');
}

/**
 * Muestra la página de opciones para reservas.
 *
 * Descripción Breve: Esta función genera el HTML para la página de opciones de reservas.
 *
 * @return void
 *
 * @example
 * res_options_page_display();
 */
if (!function_exists('res_options_page_display')) {
    function res_options_page_display() {
        ?>
        <div class="wrap">
            <h3>Este es el HTML del menú</h3>
        </div>
        <?php
    }
}

/**
 * Muestra la página del submenu para reservas.
 *
 * Descripción Breve: Esta función genera el HTML para la página del submenu de reservas.
 *
 * @return void
 *
 * @example
 * res_submenu_reserva_display();
 */
if (!function_exists('res_submenu_reserva_display')) {
    function res_submenu_reserva_display() {
        ?>
        <div class="wrap">
            <h3>Bienvenido a la página de submenu</h3>
        </div>
        <?php
    }
}
