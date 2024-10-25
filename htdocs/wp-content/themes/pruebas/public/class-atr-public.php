<?php

/**
 * Clase ATR_Public
 *
 * Esta clase gestiona las funciones del lado público del tema, incluyendo
 * la carga de estilos y scripts, así como la configuración del menú.
 * Proporciona una interfaz amigable para los usuarios finales, garantizando
 * que los estilos y scripts necesarios estén disponibles y correctamente
 * registrados.
 *
 * @package    Pruebas
 * @subpackage Pruebas/includes
 * @since      1.0.0
 *
 * Propiedades:
 * @var string $theme_name Nombre del tema.
 * @var string $version Versión del tema.
 *
 */
class ATR_Public {
    /**
     * El nombre del tema.
     *
     * @since    1.0.0
     * @access   private
     * @var      string    $theme_name  Nombre o identificador único de este tema.
     */
    private $theme_name; // Nombre del tema

    /**
     * La versión del tema.
     *
     * @since    1.0.0
     * @access   private
     * @var      string    $version     Versión actual de este tema, utilizada para el control de actualizaciones.
     */
    private $version;    // Versión del tema

    /**
     * Constructor de la clase ATR_Public
     *
     * Inicializa el nombre y la versión del tema.
     *
     * @param string $theme_name Nombre del tema.
     * @param string $version    Versión del tema.
     *
     * @since    1.0.0
     */
    function __construct($theme_name, $version) {
        $this->theme_name = $theme_name;
        $this->version = $version;
    }

    /**
     * Encola los estilos necesarios para el tema.
     *
     * Este método carga los archivos CSS requeridos, incluyendo Normalize,
     * Bootstrap y FontAwesome, asegurando que se presenten correctamente
     * en el frontend del sitio.
     *
     * @since    1.0.0
     * @access   public
     *
     * @return void
     *
     * @example
     * $public->enqueue_styles();
     */
    public function enqueue_styles() {
        wp_enqueue_style(
            'normalize-css',
            ATR_DIR_URI . "public/css/normalize.css",
            array(),
            '8.0.1',
            'all'
        );
        wp_enqueue_style(
            'public-css',
            ATR_DIR_URI . "public/css/atr-public.css",
            array(),
            $this->version,
            'all'
        );
        wp_enqueue_style(
            'bootstrap-css',
            ATR_DIR_URI . "helpers/bootstrap-5.3.2/css/bootstrap.min.css",
            array(),
            '5.3.2',
            'all'
        );

        // Archivos FontAwesome
        wp_enqueue_style(
            'fontawesome',
            ATR_DIR_URI . "helpers/fontawesome-5.15.4/css/fontawesome.min.css",
            array(),
            '5.15.4',
            'all'
        );

        wp_enqueue_style(
            'brands',
            ATR_DIR_URI . "helpers/fontawesome-5.15.4/css/brands.min.css",
            array(),
            '5.15.4',
            'all'
        );
    }

    /**
     * Encola los scripts necesarios para el tema.
     *
     * Este método carga los archivos JavaScript requeridos, incluyendo jQuery,
     * Bootstrap y FontAwesome, que son esenciales para la funcionalidad
     * del frontend.
     *
     * @since    1.0.0
     * @access   public
     *
     * @return void
     *
     * @example
     * $public->enqueue_scripts();
     */
    public function enqueue_scripts() {
        wp_enqueue_script(
            'public-js',
            ATR_DIR_URI . 'public/js/atr-public.js',
            ['jquery', 'bootstrap-min'],
            $this->version,
            true
        );
        wp_enqueue_script(
            'bootstrap-min',
            ATR_DIR_URI . 'helpers/bootstrap-5.3.2/js/bootstrap.min.js',
            ['jquery'],
            '5.3.2',
            true
        );

        // Archivos FontAwesome JS
        wp_enqueue_script(
            'fontawesome',
            ATR_DIR_URI . 'helpers/fontawesome-5.15.4/js/fontawesome.min.js',
            array(),
            '5.3.2',
            true
        );
        wp_enqueue_script(
            'brands',
            ATR_DIR_URI . 'helpers/fontawesome-5.15.4/js/brands.min.js',
            array(),
            '5.3.2',
            true
        );
    }

    /**
     * Devuelve el nombre del tema.
     *
     * Este método permite acceder al nombre del tema que fue establecido
     * en el constructor.
     *
     * @return string Nombre del tema.
     *
     * @since 1.0.0
     *
     * @example
     * $theme = new ATR_Public('Mi Tema', '1.0.0');
     * echo $theme->get_theme_name(); // Salida: Mi Tema
     */
    public function get_theme_name() {
        return $this->theme_name;
    }

    /**
     * Devuelve la versión del tema.
     *
     * Este método permite acceder a la versión del tema que fue establecida
     * en el constructor.
     *
     * @return string Versión del tema.
     *
     * @since 1.0.0
     *
     * @example
     * $theme = new ATR_Public('Mi Tema', '1.0.0');
     * echo $theme->get_version(); // Salida: 1.0.0
     */
    public function get_version() {
        return $this->version;
    }


    /**
     * Registra y configura los menús del frontend.
     *
     * Este método registra el menú principal y el menú de redes sociales,
     * así como las propiedades del logo del tema.
     *
     * @since    1.0.0
     * @access   public
     *
     * @return void
     *
     * @example
     * $public->atr_menu_frontend();
     */
    public function atr_menu_frontend() {
        // Registrar Menú
        register_nav_menus([
            'menu_principal' => __('Menú Principal', 'pruebas'),
            'menu_redes_sociales' => __('Menú Redes Sociales', 'pruebas'),
        ]);

        // Configuración del logo
        $logo = [
            'width' => 230,
            'height' => 80,
            'flex-height' => true,
            'flex-width' => true,
            'header-text' => [$this->theme_name, 'Un sitio web de pruebas']
        ];

        add_theme_support('custom-logo', $logo);
    }
}
