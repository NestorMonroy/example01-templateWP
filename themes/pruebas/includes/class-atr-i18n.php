<?php

/**
 * Clase ATR_i18n
 *
 * Esta clase es responsable de manejar la internacionalización del tema,
 * incluyendo la carga de traducciones y la configuración de cadenas de texto
 * para diferentes idiomas. Facilita la adaptación del tema a diversos entornos
 * lingüísticos, asegurando que las cadenas se muestren correctamente según la
 * configuración del usuario o del sitio.
 *
 * @package    ATR THEME
 * @subpackage ATR THEME/includes
 * @since      1.0.0
 *
 * Propiedades:
 * @var string $textdomain Dominio de texto del tema.
 */
class ATR_i18n {
    /**
     * @var string $textdomain Dominio de texto del tema.
     */
    protected $textdomain;

    /**
     * Constructor que inicializa el dominio de texto.
     *
     * @since 1.0.0
     */
    public function __construct() {
        $this->textdomain = "pruebas"; // Dominio de texto del tema.
    }

    /**
     * Carga el dominio de texto del tema para la internacionalización.
     *
     * Este método configura el dominio de texto del tema y carga
     * los archivos de traducción desde el directorio especificado.
     * Además, se aplica un filtro para determinar la localización
     * correcta en función del entorno (administración o frontend).
     *
     * @since 1.0.0
     *
     * @return void
     *
     * @example
     * $i18n->load_theme_textdomain();
     */
    public function load_theme_textdomain() {
        // Carga el dominio de texto del tema desde el directorio 'lang'.
        load_theme_textdomain($this->textdomain, ATR_DIR_PATH . 'lang');

        // Determina la localización a utilizar, aplicando un filtro para modificarla si es necesario.
        $locate = apply_filters('theme_locale', is_admin() ? get_user_locale() : get_locale(), $this->textdomain);

        // Carga el archivo de traducción correspondiente a la localización.
        load_textdomain($this->textdomain, get_theme_file_path("lang/{$this->textdomain}-$locate.mo"));
    }
}
