<?php

/**
 * Clase para manejar la internacionalización del tema.
 *
 * Esta clase es responsable de cargar las traducciones del tema
 * y permitir que las cadenas de texto sean localizadas en diferentes
 * idiomas según las configuraciones del usuario o del sitio.
 *
 * @package ATR THEME
 * @since 1.0.0
 */
class ATR_i18n {

    /**
     * Carga el dominio de texto del tema para la internacionalización.
     *
     * Este método configura el dominio de texto del tema y carga
     * los archivos de traducción desde el directorio especificado.
     * Además, se aplica un filtro para determinar la localización
     * correcta en función del entorno (administración o frontend).
     *
     * @since 1.0.0
     */
    public function load_theme_textdomain() {
        $textdomain = "pruebas"; // Dominio de texto del tema.

        // Carga el dominio de texto del tema desde el directorio 'lang'.
        load_theme_textdomain($textdomain, ATR_DIR_PATH . 'lang');

        // Determina la localización a utilizar, aplicando un filtro para modificarla si es necesario.
        $locate = apply_filters('theme_locale', is_admin() ? get_user_locale() : get_locale(), $textdomain);

        // Carga el archivo de traducción correspondiente a la localización.
        load_textdomain($textdomain, get_theme_file_path("lang/$textdomain-$locate.mo"));
    }
}

/**
 * Notas sobre versiones
 *
 * - 1.0.0: Creación de la clase y el método `load_theme_textdomain`.
 */

/**
 * Ejemplo de uso:
 *
 * $i18n = new ATR_i18n();
 * $i18n->load_theme_textdomain();
 */

/**
 * Parámetros y tipos de datos:
 *
 * - `load_theme_textdomain`: No acepta parámetros.
 *
 * Valores de retorno:
 *
 * - No devuelve ningún valor. El método tiene efectos secundarios al cargar traducciones.
 */

/**
 * Notas de implementación:
 *
 * - **Dependencias**: Esta clase depende de las funciones de WordPress para la carga de traducciones.
 * - **Requisitos**: El directorio 'lang' debe contener los archivos de traducción (.mo) correspondientes.
 */

/**
 * Licencia y autores:
 *
 * - **Créditos**: Desarrollado por [Tu Nombre o Organización].
 * - **Licencia**: Este código se distribuye bajo la Licencia GPL-2.0 o posterior.
 */
