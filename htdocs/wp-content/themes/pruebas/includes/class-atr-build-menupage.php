<?php
/**
 * Registrar todos los menús y submenús de mi theme
 *
 * @since      1.0.0
 *
 * @package    ATR THEME
 * @subpackage ATR THEME/includes
 */

/**
 * Agrega todos los menús y submenús a utilizar en el theme
 * donde los métodos add_menu_page() y add_submenu_page()
 * tienen que ser llamados junto con el gancho
 * de acción 'admin_menu'
 *
 * @since      1.0.0
 * @package    ATR THEME
 * @subpackage ATR THEME/includes
 *
 * @property array $menus
 * @property array $submenus
 */
class ATR_Build_MenuPage {
    /**
     * El array de menús a registrar en WordPress.
     *
     * @since    1.0.0
     * @access   protected
     * @var      array    $menus    Los menús registrados en WordPress para ejecutar cuando se llame.
     */
    protected $menus;

    /**
     * El array de submenús a registrar en WordPress.
     *
     * @since    1.0.0
     * @access   protected
     * @var      array    $submenus    Los submenús registrados en WordPress para ejecutar cuando se llame.
     */
    protected $submenus;

    public function __construct() {
        $this->menus = [];
        $this->submenus = [];
    }

    /**
     * Añade un nuevo menú al array ($this->menus) para registrarlo en WordPress.
     *
     * Este método permite crear un nuevo menú en el panel de administración de WordPress.
     * Los menús se almacenan en un array que se procesará posteriormente para su registro.
     *
     * @since    1.0.0
     * @access   public
     *
     * @param    string    $pageTitle        El texto que se mostrará en las etiquetas de título de la página cuando se selecciona el menú.
     * @param    string    $menuTitle        El texto que se utilizará para el menú.
     * @param    string    $capability       La capacidad necesaria para que este menú se muestre al usuario.
     * @param    string    $menuSlug         El nombre del slug para referirse a este menú (debe ser único para este menú).
     * @param    callable  $functionName     La función que se llamará para emitir el contenido de esta página.
     * @param    string    $iconUrl          (Opcional) La URL del icono que se va a utilizar para este menú. Valor por defecto: ''.
     * @param    int       $position         (Opcional) La posición en el orden de los menús en la barra lateral. Valor por defecto: null.
     *
     * @return void
     *
     * @example
     * $menu_page = new ATR_Build_MenuPage();
     * $menu_page->add_menu_page('Título de Página', 'Título del Menú', 'manage_options', 'mi_slug_menu', 'mi_funcion_menu');
     */
    public function add_menu_page($pageTitle, $menuTitle, $capability, $menuSlug, $functionName, $iconUrl = '', $position = null) {
        $this->menus = $this->add_menu($this->menus, $pageTitle, $menuTitle, $capability, $menuSlug, $functionName, $iconUrl, $position);
    }

    /**
     * Función de utilidad que se utiliza para ir agregando los menús para iterar.
     *
     * Este método se encarga de almacenar la información del menú en un array,
     * que luego se utilizará para registrar todos los menús en WordPress.
     *
     * @since    1.0.0
     * @access   private
     *
     * @param    array     $menus            La colección de menús que se está registrando.
     * @param    string    $pageTitle        El texto que se mostrará en las etiquetas de título de la página cuando se selecciona el menú.
     * @param    string    $menuTitle        El texto que se utilizará para el menú.
     * @param    string    $capability       La capacidad necesaria para que este menú se muestre al usuario.
     * @param    string    $menuSlug         El nombre del slug para referirse a este menú (debe ser único para este menú).
     * @param    callable  $functionName     La función a la que se llama para emitir el contenido de esta página.
     * @param    string    $iconUrl          (Opcional) La URL del icono que se va a utilizar para este menú. Valor por defecto: ''.
     * @param    int       $position         (Opcional) La posición en el orden de los menús en la barra lateral. Valor por defecto: null.
     *
     * @return   array                       La colección de menús actualizada para proceder a iterar y registrarlos en WordPress en el método run().
     *
     * @example
     * $menus = [];
     * $menus = add_menu($menus, 'Título de Página', 'Título del Menú', 'manage_options', 'mi_slug_menu', 'mi_funcion_menu');
     */
    private function add_menu($menus, $pageTitle, $menuTitle, $capability, $menuSlug, $functionName, $iconUrl, $position) {
        $menus[] = [
            'pageTitle' => $pageTitle,
            'menuTitle' => $menuTitle,
            'capability' => $capability,
            'menuSlug' => $menuSlug,
            'functionName' => $functionName,
            'iconUrl' => $iconUrl,
            'position' => $position
        ];

        return $menus;
    }

    /**
     * Añade un nuevo submenú al array ($this->submenus) a iterar para registrarlo en WordPress.
     *
     * Este método se encarga de almacenar la información del submenú en un array,
     * que luego se utilizará para registrar todos los submenús en WordPress.
     *
     * @since    1.0.0
     * @access   public
     *
     * @param    string    $parentSlug       El nombre de slug para el menú principal (o el nombre de archivo de una página de administración de WordPress estándar).
     * @param    string    $pageTitle        El texto que se mostrará en las etiquetas de título de la página cuando se selecciona el submenú.
     * @param    string    $menuTitle        El texto que se utilizará para el submenú.
     * @param    string    $capability       La capacidad necesaria para que este submenú se muestre al usuario.
     * @param    string    $menuSlug         El nombre del slug para referirse a este submenú (debe ser único para este submenú).
     * @param    callable  $functionName     La función a la que se llama para emitir el contenido de esta página.
     *
     * @return   void
     *
     * @example
     * $menu_page->add_submenu_page('parent_slug', 'Título de Página', 'Título del Submenú', 'manage_options', 'mi_slug_submenu', 'mi_funcion_submenu');
     */
    public function add_submenu_page($parentSlug, $pageTitle, $menuTitle, $capability, $menuSlug, $functionName) {
        $this->submenus = $this->add_submenu($this->submenus, $parentSlug, $pageTitle, $menuTitle, $capability, $menuSlug, $functionName);
    }

    /**
     * Función de utilidad que se utiliza para agregar submenús al array para su posterior registro en WordPress.
     *
     * Este método almacena la información de un submenú en un array que será utilizado
     * para registrar todos los submenús cuando se ejecute el método correspondiente.
     *
     * @since    1.0.0
     * @access   private
     *
     * @param    array     $submenus         La colección de submenús que se está registrando.
     * @param    string    $parentSlug       El nombre del slug para el menú principal (o el nombre de archivo de una página de administración de WordPress estándar).
     * @param    string    $pageTitle        El texto que se mostrará en las etiquetas de título de la página cuando se selecciona el submenú.
     * @param    string    $menuTitle        El texto que se utilizará para el submenú.
     * @param    string    $capability       La capacidad necesaria para que este submenú se muestre al usuario.
     * @param    string    $menuSlug         El nombre del slug para referirse a este submenú (debe ser único para este submenú).
     * @param    callable  $functionName     La función a la que se llama para emitir el contenido de esta página.
     *
     * @return   array                       La colección de submenús actualizada para proceder a registrarlos en WordPress en el método run().
     *
     * @example
     * $submenus = $this->add_submenu($submenus, 'parent_slug', 'Título de Página', 'Título del Submenú', 'manage_options', 'mi_slug_submenu', 'mi_funcion_submenu');
     */
    private function add_submenu($submenus, $parentSlug, $pageTitle, $menuTitle, $capability, $menuSlug, $functionName) {
        $submenus[] = [
            'parentSlug' => $parentSlug,
            'pageTitle' => $pageTitle,
            'menuTitle' => $menuTitle,
            'capability' => $capability,
            'menuSlug' => $menuSlug,
            'functionName' => $functionName
        ];

        return $submenus;
    }


    /**
     * Registra los menús y submenús con WordPress.
     *
     * Este método itera sobre las colecciones de menús y submenús
     * almacenadas en las propiedades correspondientes y las registra
     * en WordPress utilizando las funciones nativas `add_menu_page`
     * y `add_submenu_page`.
     *
     * @since    1.0.0
     * @access   public
     *
     * @return   void
     *
     * @example
     * $cargador->run();
     */
    public function run() {
        foreach ($this->menus as $menus) {
            extract($menus, EXTR_OVERWRITE);
            $this->add_menu_page($parentSlug, $pageTitle, $menuTitle, $capability, $menuSlug, $functionName);
        }

        foreach ($this->submenus as $submenus) {
            extract($submenus, EXTR_OVERWRITE);
            $this->add_submenu_page($parentSlug, $pageTitle, $menuTitle, $capability, $menuSlug, $functionName);
        }
    }

}
