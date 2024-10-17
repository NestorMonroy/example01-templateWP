<?php
/**
 * El archivo que define la clase del cerebro principal del theme
 * Una definición de clase que incluye atributos y funciones que se
 * utilizan tanto del lado del público como del área de administración.
 *
 * @since      1.0.0
 *
 * @package    ATR THEME
 * @subpackage ATR THEME/includes
 */

/**
 * También mantiene el identificador único de este complemento,
 * así como la versión actual del theme.
 *
 * @since      1.0.0
 * @package    ATR THEME
 * @subpackage ATR THEME/includes
 *
 * @property object $cargador
 * @property string $theme_name
 * @property string $version
 */

class ATR_MASTER{
    /**
     * El cargador que es responsable de mantener y registrar
     * todos los ganchos (hooks) que alimentan el theme.
     *
     * @since    1.0.0
     * @access   protected
     * @var      ATR_Cargador    $cargador  Mantiene y registra todos los ganchos (Hooks) del THEME
     */
    protected $cargador;

    /**
     * El identificador único de este THEME
     *
     * @since    1.0.0
     * @access   protected
     * @var      string    $theme_name  El nombre o identificador único de éste theme
     */
    protected $theme_name;

    /**
     * Versión actual del theme
     *
     * @since    1.0.0
     * @access   protected
     * @var      string    $version  La versión actual del theme
     */
    protected $version;

    /**
     * Constructor
     *
     * Define la funcionalidad principal del theme.
     *
     * Establece el nombre y la versión del theme que se puede utilizar en el theme.
     * Cargar las dependencias, carga de instancias, definir la configuración regional (idioma)
     * Establecer los ganchos para el área de administración y
     * el lado público del sitio.
     *
     * @since    1.0.0
     */
    public function __construct(){
        // Es el nombre que se pasa a las clases admin y public
        $this->theme_name = 'ATR_Pruebas';
        $this->version = '1.0.0';
        $this->cargar_dependencias();
        $this->cargar_instancias();
        $this->set_idiomas();
        $this->definir_admin_hooks();
        $this->definir_public_hooks();
    }

    /**
     * Carga las dependencias necesarias para este tema.
     *
     * Este método incluye los archivos requeridos para el funcionamiento
     * del tema, como clases para la gestión de ganchos, internacionalización,
     * administración y funcionalidad del cliente/público.
     *
     * @since    1.0.0
     * @access   private
     *
     * @return void
     *
     * @example
     * $this->cargar_dependencias();
     */
    private function cargar_dependencias() {
        /**
         * La clase responsable de iterar las acciones y filtros del núcleo del tema.
         */
        require_once ATR_DIR_PATH . 'includes/class-atr-cargador.php';

        /**
         * La clase responsable de definir la funcionalidad de la internacionalización del tema.
         */
        require_once ATR_DIR_PATH . 'includes/class-atr-i18n.php';

        /**
         * La clase responsable de registrar menús y submenús en el área de administración.
         */
        require_once ATR_DIR_PATH . 'includes/class-atr-build-menupage.php';

        /**
         * La clase responsable de definir todas las acciones en el área de administración.
         */
        require_once ATR_DIR_PATH . 'admin/class-atr-admin.php';

        /**
         * La clase responsable de definir todas las acciones en el lado del cliente/público.
         */
        require_once ATR_DIR_PATH . 'public/class-atr-public.php';
    }


    /**
     * Define la configuración regional de este tema para la internacionalización.
     *
     * Utiliza la clase ATR_i18n para establecer el dominio y registrar el gancho con WordPress,
     * asegurando que las traducciones estén disponibles y se carguen correctamente.
     *
     * @since    1.0.0
     * @access   private
     *
     * @return void
     *
     * @example
     * $this->set_idiomas();
     */
    private function set_idiomas() {
        $atr_i18n = new ATR_i18n();
        $this->cargador->add_action('after_setup_theme', $atr_i18n, 'load_theme_textdomain');
    }

    /**
     * Carga todas las instancias necesarias para el uso de los archivos de las clases agregadas.
     *
     * Esta función crea instancias de las clases necesarias para gestionar los hooks
     * y la funcionalidad del tema en el área de administración y en el frontend.
     *
     * @since    1.0.0
     * @access   private
     *
     * @return void
     *
     * @example
     * $this->cargar_instancias();
     */
    private function cargar_instancias() {
        /*
         * Crea una instancia del cargador que se utilizará para registrar los hooks con WordPress.
         */
        $this->cargador = new ATR_Cargador;
        $this->atr_admin = new ATR_Admin($this->get_theme_name(), $this->get_version());
        $this->atr_public = new ATR_Public($this->get_theme_name(), $this->get_version());

        error_log("get_theme_name()");
    }


    /**
     * Registra todos los hooks relacionados con la funcionalidad del área de administración del tema.
     *
     * Esta función utiliza el cargador para añadir los hooks necesarios
     * que permiten gestionar el menú de administración del tema.
     *
     * @since    1.0.0
     * @access   private
     *
     * @return void
     *
     * @example
     * $this->definir_admin_hooks();
     */
    private function definir_admin_hooks() {
        $this->cargador->add_action('admin_menu', $this->atr_admin, 'add_menu');
    }

    /**
     * Registra todos los hooks relacionados con la funcionalidad del área de administración del plugin.
     *
     * Esta función utiliza el cargador para añadir los hooks necesarios
     * que permiten gestionar los estilos, scripts y el menú frontend del plugin.
     *
     * @since    1.0.0
     * @access   private
     *
     * @return void
     *
     * @example
     * $this->definir_public_hooks();
     */
    private function definir_public_hooks() {
        $this->cargador->add_action('wp_enqueue_scripts', $this->atr_public, 'enqueue_styles');
        $this->cargador->add_action('wp_enqueue_scripts', $this->atr_public, 'enqueue_scripts');

        // Agregar menú frontend
        $this->cargador->add_action('init', $this->atr_public, 'atr_menu_frontend');
    }


    /**
     * Obtiene el nombre del tema utilizado para identificarlo de forma exclusiva
     * en el contexto de WordPress y para definir la funcionalidad de internacionalización.
     *
     * @since     1.0.0
     * @access    public
     * @return    string    El nombre del tema.
     *
     * @example
     * $nombre_tema = $this->get_theme_name();
     */
    public function get_theme_name() {
        return $this->theme_name;
    }

    /**
     * Obtiene el número de la versión del tema actual.
     *
     * Esta función devuelve el número de versión del tema que se está utilizando,
     * lo que puede ser útil para verificar actualizaciones o para mostrar información
     * al usuario.
     *
     * @since     1.0.0
     * @access    public
     * @return    string    El número de la versión del tema en formato de cadena.
     *
     * @example
     * // Ejemplo de uso para obtener la versión del tema.
     * $version = $this->get_version();
     */
    public function get_version() {
        return $this->version;
    }

    /**
     * Obtiene la referencia al cargador que itera sobre los hooks del tema.
     *
     * Este método proporciona acceso a la instancia del cargador que gestiona
     * la interacción con los ganchos del tema, permitiendo a los desarrolladores
     * trabajar con las funciones de gancho de manera más eficiente.
     *
     * @since     1.0.0
     * @access    public
     * @return    ATR_Cargador    Una instancia del cargador que itera sobre los ganchos del tema.
     *
     * @example
     * // Ejemplo de uso para obtener el cargador de ganchos.
     * $cargador = $this->get_cargador();
     * // Puedes utilizar $cargador para manipular los ganchos del tema.
     */
    public function get_cargador() {
        return $this->cargador;
    }


    /**
     * Ejecuta el cargador para activar todos los ganchos en WordPress.
     *
     * Este método inicia el proceso de ejecución de los ganchos registrados
     * en el cargador. Es fundamental para asegurar que todas las funciones
     * asociadas a los ganchos se ejecuten correctamente, permitiendo la
     * integración del tema con el sistema de hooks de WordPress.
     *
     * @since    1.0.0
     * @access   public
     *
     * @example
     * // Ejemplo de uso para ejecutar los ganchos del cargador.
     * $this->run();
     * // Esto activará todos los ganchos configurados en el cargador.
     */
    public function run() {
        $this->cargador->run();
    }

}
