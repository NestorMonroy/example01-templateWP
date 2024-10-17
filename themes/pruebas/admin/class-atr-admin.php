<?php

/**
 * Clase ATR_Admin
 *
 * Esta clase gestiona las funciones del área de administración relacionadas con las opciones de reservas del tema.
 * Permite a los administradores gestionar reservas, incluyendo agregar, editar y eliminar, así como configurar
 * la disponibilidad y precios.
 *
 * @package    Pruebas
 * @subpackage Pruebas/includes
 * @since      1.0.0
 *
 * Propiedades:
 * @var string $theme_name Nombre del tema.
 * @var string $version Versión del tema.
 *
 * Ejemplo de uso:
 * $admin = new ATR_Admin('mi_tema', '1.0.0');
 * $admin->add_menu();
 *
 */
class ATR_Admin {
    private $theme_name;          // Nombre del tema
    private $version;             // Versión del tema
    private $build_menupage;      // Instancia de la clase ATR_Build_Menupage

    /**
     * Constructor de la clase ATR_Admin
     *
     * @param string $theme_name Nombre del tema.
     * @param string $version    Versión del tema.
     * @since    1.0.0
     */
    function __construct($theme_name, $version){
        $this->theme_name = $theme_name;
        $this->version = $version;
        $this->build_menupage = new ATR_Build_Menupage();
    }

    /**
     * Registra los menús y submenús del tema en el área de administración.
     *
     * Este método utiliza la instancia de ATR_Build_Menupage para agregar un menú y un submenú.
     *
     * @since    1.0.0
     * @access   public
     */
    public function add_menu() {
        // Agrega el menú principal
        $this->build_menupage->add_menu_page(
            __('Opciones de reservas','pruebas'),
            __('Opciones de reservas','pruebas'),
            'manage_options',
            'res_options_page',
            [$this, 'controlador_display_menu'],
        );

        // Agrega el submenú
        $this->build_menupage->add_submenu_page(
            'res_options_page',
            __('Submenu reservas','pruebas'),
            __('Submenu reservas','pruebas'),
            'manage_options',
            'res_submenu_reservas',
            [$this, 'controlador_display_submenu']
        );

        // Ejecuta la función de construcción del menú
        $this->build_menupage->run();
    }

    /**
     * Controla la visualización del menú en el área de administración.
     *
     * Este método carga la vista del menú de reservas.
     *
     * @since    1.0.0
     * @access   public
     */
    public function controlador_display_menu() {
        require_once ATR_DIR_PATH.'admin/partials/atr-menu-reservas-display.php';
    }

    /**
     * Controla la visualización del submenú en el área de administración.
     *
     * Este método carga la vista del submenú de reservas.
     *
     * @since    1.0.0
     * @access   public
     */
    public function controlador_display_submenu(){
        require_once ATR_DIR_PATH.'admin/partials/atr-submenu-reservas-display.php';
    }
}
