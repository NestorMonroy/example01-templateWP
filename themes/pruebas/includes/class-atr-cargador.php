<?php
/**
 * Clase para registrar y gestionar acciones, filtros y shortcodes en WordPress.
 *
 * Esta clase simplifica la gestión de hooks en un tema o plugin de WordPress.
 *
 * Notas sobre versiones:
 * - 1.0.0: Creación de la clase con métodos para registrar acciones, filtros y shortcodes.
 *
 * @since      1.0.0
 * @package    ATR THEME
 * @subpackage ATR THEME/includes
 */
class ATR_Cargador {
    /**
     * @var array $actions Almacena las acciones registradas en WordPress.
     */
    protected $actions;

    /**
     * @var array $filters Almacena los filtros registrados en WordPress.
     */
    protected $filters;

    /**
     * @var array $shortcodes Almacena los shortcodes registrados en WordPress.
     */
    protected $shortcodes;

    /**
     * Constructor de la clase.
     *
     * Inicializa las propiedades de la clase estableciendo arrays vacíos
     * para las acciones, filtros y shortcodes.
     *
     * @since 1.0.0
     */
    public function __construct() {
        $this->actions = [];
        $this->filters = [];
        $this->shortcodes = [];
    }
    /**
     * Registra una nueva acción con WordPress.
     *
     * Este método añade una nueva acción a la colección de acciones a registrar
     * utilizando la función `add_action` de WordPress.
     *
     * @since    1.0.0
     * @access   public
     *
     * @param string $hook           El nombre del hook de acción.
     * @param object $component      Referencia al componente que contiene el callback.
     * @param string $callback       Nombre del método que se ejecutará.
     * @param int    $priority       (Opcional) La prioridad de la acción. Valor por defecto: 10.
     * @param int    $accepted_args   (Opcional) El número de argumentos aceptados. Valor por defecto: 1.
     *
     * @return void    Este método no devuelve ningún valor.
     *
     * Ejemplo de Uso:
     * $cargador->add_action('init', $this, 'mi_funcion');
     */
    public function add_action($hook, $component, $callback, $priority = 10, $accepted_args = 1) {
        $this->actions = $this->add($this->actions, $hook, $component, $callback, $priority, $accepted_args);
    }

    /**
     * Registra un nuevo shortcode con WordPress.

     * @param    string    $hook           El nombre del hook de filtro.
     * @param    object    $component       Referencia al componente que contiene el callback.
     * @param    string    $callback        Nombre del método que se ejecutará.
     * @param    int       $priority        (Opcional) La prioridad del filtro. Valor por defecto: 10.
     * @param    int       $accepted_args    (Opcional) El número de argumentos aceptados. Valor por defecto: 1.
     */

    /**
     * Registra un nuevo filtro con WordPress.
     *
     * Este método añade un nuevo filtro a la colección de filtros a registrar
     * utilizando la función `add_filter` de WordPress.
     *
     * @since    1.0.0
     * @access   public
     *
     * @param string $hook           El nombre del hook de filtro.
     * @param object $component      Referencia al componente que contiene el callback.
     * @param string $callback       Nombre del método que se ejecutará.
     * @param int    $priority       (Opcional) La prioridad del filtro. Valor por defecto: 10.
     * @param int    $accepted_args   (Opcional) El número de argumentos aceptados. Valor por defecto: 1.
     *
     * @return void    Este método no devuelve ningún valor.
     *
     * Ejemplo de Uso:
     * $cargador->add_filter('the_content', $this, 'mi_funcion');
     */
    public function add_filter($hook, $component, $callback, $priority = 10, $accepted_args = 1) {
        $this->filters = $this->add($this->filters, $hook, $component, $callback, $priority, $accepted_args);
    }


    /**
     * Método que recibe todos los hooks y los agrega a la colección.
     *
     * Este método se utiliza internamente para registrar acciones y filtros,
     * manteniendo una colección de hooks que se procesarán en el método `run()`.
     *
     * @since    1.0.0
     * @access   private
     *
     * @param    array     $hooks          Colección de hooks a registrar.
     * @param    string    $hook           El nombre del hook.
     * @param    object    $component       Referencia al componente que contiene el callback.
     * @param    string    $callback        Nombre del método que se ejecutará.
     * @param    int       $priority        La prioridad de la acción o filtro.
     * @param    int       $accepted_args    El número de argumentos aceptados.
     *
     * @return   array                      La colección de hooks actualizada.
     *
     * Ejemplo de Uso:
     * // Este método es privado y se llama internamente, no se utiliza directamente.
     */
    private function add($hooks, $hook, $component, $callback, $priority, $accepted_args) {
        $hooks[] = [
            'hook' => $hook,
            'component' => $component,
            'callback' => $callback,
            'priority' => $priority,
            'accepted_args' => $accepted_args,
        ];

        return $hooks;
    }

    /**
     * Método para registrar hooks de acción de los shortcodes.
     *
     * Este método permite agregar un nuevo shortcode a la colección de shortcodes
     * que se procesarán en el método `run()`.
     *
     * @since    1.0.0
     * @access   public
     *
     * @param    string    $tag            Nombre del shortcode. (Requerido)
     * @param    object    $component       Referencia al componente que define el shortcode. (Requerido)
     * @param    string    $callback        Nombre del método que se ejecutará al procesar el shortcode. (Requerido)
     *
     * @return   void                       No devuelve ningún valor.
     *
     * Ejemplo de Uso:
     * $cargador = new ATR_Cargador();
     * $cargador->add_shortcode('mi_shortcode', $this, 'mi_funcion_shortcode');
     */
    public function add_shortcode($tag, $component, $callback) {
        $this->shortcodes = $this->add_s($this->shortcodes, $tag, $component, $callback);
    }

    /**
     * Método que recibe todos los shortcodes.
     *
     * Este método agrega un shortcode a la colección para su posterior registro.
     *
     * @since    1.0.0
     * @access   private
     *
     * @param    array     $shortcodes     Colección de shortcodes a registrar. (Requerido)
     * @param    string    $tag            Nombre del shortcode. (Requerido)
     * @param    object    $component       Referencia al componente que define el shortcode. (Requerido)
     * @param    string    $callback        Nombre del método que se ejecutará. (Requerido)
     *
     * @return   array                      La colección de shortcodes actualizada.
     */
    private function add_s($shortcodes, $tag, $component, $callback) {
        $shortcodes[] = [
            'tag' => $tag,
            'component' => $component,
            'callback' => $callback,
        ];

        return $shortcodes;
    }

    /**
     * Registra las acciones, filtros y shortcodes con WordPress.
     *
     * Este método itera sobre las colecciones de acciones, filtros y shortcodes
     * y los registra utilizando las funciones correspondientes de WordPress.
     *
     * @since    1.0.0
     * @access   public
     *
     * @return   void    Este método no devuelve ningún valor.
     *
     * Ejemplo de Uso:
     * $cargador = new ATR_Cargador();
     * $cargador->run();
     */
    public function run() {
        foreach ($this->actions as $hook_u) {
            extract($hook_u, EXTR_OVERWRITE);
            add_action($hook, [$component, $callback], $priority, $accepted_args);
        }
        foreach ($this->filters as $hook_u) {
            extract($hook_u, EXTR_OVERWRITE);
            add_filter($hook, [$component, $callback], $priority, $accepted_args);
        }
        foreach ($this->shortcodes as $hook_u) {
            extract($hook_u, EXTR_OVERWRITE);
            add_shortcode($tag, [$component, $callback]);
        }
    }
}
