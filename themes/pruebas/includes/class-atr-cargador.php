<?php
/**
 * Clase ATR_Cargador
 *
 * Descripción General:
 * Esta clase registra todas las acciones y filtros para el tema de WordPress,
 * permitiendo una gestión más fácil y organizada de los hooks. Facilita el
 * registro de shortcodes y mejora la mantenibilidad del código.
 *
 * Estructura de la Clase:
 * - Propiedades:
 *   - array $actions: Colección de acciones registradas.
 *   - array $filters: Colección de filtros registrados.
 *   - array $shortcodes: Colección de shortcodes registrados.
 *
 * - Métodos:
 *   - void add_action(string $hook, object $component, string $callback, int $priority = 10, int $accepted_args = 1)
 *     Registra una acción con el hook de WordPress.
 *
 *   - void add_filter(string $hook, object $component, string $callback, int $priority = 10, int $accepted_args = 1)
 *     Registra un filtro con el hook de WordPress.
 *
 *   - void add_shortcode(string $tag, object $component, string $callback)
 *     Registra un shortcode.
 *
 * Notas sobre Versiones:
 * - Versión 1.0.0: Creación inicial de la clase.
 * - Versión 1.1.0: Mejora en la gestión de shortcodes.
 *
 * Ejemplos de Uso:
 * ```php
 * $cargador = new ATR_Cargador();
 * $cargador->add_action('init', $this, 'mi_funcion_init');
 * $cargador->add_filter('the_content', $this, 'mi_funcion_filter_content');
 * $cargador->add_shortcode('mi_shortcode', $this, 'mi_funcion_shortcode');
 * $cargador->run();
 * ```
 *
 * Parámetros y Tipos de Datos:
 * - add_action:
 *   - $hook (string): El nombre del hook.
 *   - $component (object): La instancia del componente.
 *   - $callback (string): El método a ejecutar.
 *   - $priority (int, opcional): La prioridad de la acción. Por defecto: 10.
 *   - $accepted_args (int, opcional): Número de argumentos aceptados. Por defecto: 1.
 *
 * - add_filter:
 *   - $hook (string): El nombre del hook.
 *   - $component (object): La instancia del componente.
 *   - $callback (string): El método a ejecutar.
 *   - $priority (int, opcional): La prioridad del filtro. Por defecto: 10.
 *   - $accepted_args (int, opcional): Número de argumentos aceptados. Por defecto: 1.
 *
 * - add_shortcode:
 *   - $tag (string): El nombre del shortcode.
 *   - $component (object): La instancia del componente.
 *   - $callback (string): El método a ejecutar.
 *
 * Valores de Retorno:
 * - Los métodos no devuelven ningún valor.
 *
 * Notas de Implementación:
 * - Dependencias: Esta clase depende de la funcionalidad de WordPress.
 * - Requisitos: Debe ejecutarse dentro del contexto de un tema o plugin de WordPress.
 *
 */
class ATR_Cargador {
    /**
     * @var array $actions
     * Almacena una colección de acciones registradas que se ejecutarán en los hooks de WordPress.
     */
    protected $actions;

    /**
     * @var array $filters
     * Almacena una colección de filtros registrados que se ejecutarán en los hooks de WordPress.
     */
    protected $filters;

    /**
     * @var array $shortcodes
     * Almacena una colección de shortcodes registrados que se pueden utilizar en el contenido de WordPress.
     */
    protected $shortcodes;

    /**
     * Constructor de la clase ATR_Cargador.
     *
     * Inicializa las colecciones de acciones, filtros y shortcodes como arrays vacíos.
     */
    public function __construct() {
        $this->actions = [];
        $this->filters = [];
        $this->shortcodes = [];
    }
    /**
     * Método que recibe los mismos parámetros que el hook de add_action de WP.
     *
     * @param string $hook El nombre del hook al que se desea enganchar.
     * @param object $component La instancia del componente donde se define el callback.
     * @param string $callback El nombre del método que se ejecutará.
     * @param int $priority (Opcional) La prioridad del hook. Valor por defecto: 10.
     * @param int $accepted_args (Opcional) El número de argumentos que acepta el callback. Valor por defecto: 1.
     */
    public function add_action($hook, $component, $callback, $priority = 10, $accepted_args = 1) {
        $this->actions = $this->add($this->actions, $hook, $component, $callback, $priority, $accepted_args);
    }

    /**
     * Método que recibe los mismos parámetros que el hook de add_filter de WP.
     *
     * @param string $hook El nombre del hook al que se desea enganchar.
     * @param object $component La instancia del componente donde se define el callback.
     * @param string $callback El nombre del método que se ejecutará.
     * @param int $priority (Opcional) La prioridad del hook. Valor por defecto: 10.
     * @param int $accepted_args (Opcional) El número de argumentos que acepta el callback. Valor por defecto: 1.
     */
    public function add_filter($hook, $component, $callback, $priority = 10, $accepted_args = 1) {
        $this->filters = $this->add($this->filters, $hook, $component, $callback, $priority, $accepted_args);
    }

    /**
     * Método que recibe todos los hooks.
     *
     * @param array $hooks La colección de hooks a registrar.
     * @param string $hook El nombre del hook.
     * @param object $component La instancia del componente donde se define el callback.
     * @param string $callback El nombre del método que se ejecutará.
     * @param int $priority La prioridad del hook.
     * @param int $accepted_args El número de argumentos que acepta el callback.
     * @return array La colección de hooks actualizada.
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
     * Método para los hooks de acción de los shortcodes.
     *
     * @param string $tag El nombre del shortcode.
     * @param object $component La instancia del objeto donde se define el shortcode.
     * @param string $callback El nombre del método que se ejecutará.
     */
    public function add_shortcode($tag, $component, $callback) {
        $this->shortcodes = $this->add_s($this->shortcodes, $tag, $component, $callback);
    }

    /**
     * Método que recibe todos los shortcodes.
     *
     * @param string $tag El nombre del shortcode.
     * @param object $component La instancia del objeto donde se define el shortcode.
     * @param string $callback El nombre del método que se ejecutará.
     * @return array La colección de shortcodes actualizada.
     */
    private function add_s($tag, $component, $callback) {
        $shortcodes[] = [
            'tag' => $tag,
            'component' => $component,
            'callback' => $callback,
        ];

        return $shortcodes;
    }

    /**
     * Ejecuta todos los hooks registrados.
     *
     * Recorre cada una de las acciones, filtros y shortcodes registrados
     * y los añade a WordPress.
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
