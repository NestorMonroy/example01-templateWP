<?php
/**
 * Registra todas las acciones y filtros para el tema
 * */

class ATR_Cargador{
	protected $actions;
	protected $filters;
	protected $shortcodes;

	public function __construct() {
		$this->actions = [];
		$this->filters = [];
		$this->shortcodes = [];
	}

	/**
	 *Metodo que recibe los mismos parametros que el hooks de add_action de WP
	 */
	public function add_action($hook, $component, $callback, $priority = 10, $accepted_args = 1){
		$this ->actions = $this -> add($this ->actions,$hook,$component,$callback,$priority, $accepted_args);
	}

	/**
	 *Metodo que recibe los mismos parametros que el hooks de add_filter de WP
	 */
	public function add_filter($hook, $component, $callback, $priority = 10, $accepted_args = 1){
		$this ->filters = $this -> add($this ->filters,$hook,$component,$callback,$priority, $accepted_args);
	}
	/**
	 *Metodo que recibe todos los hooks
	 */
	private function add($hooks, $hook,$component,$callback,$priority, $accepted_args){
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
	 *Metodo para los hooks de accion de los shortcodes
	 * $tag = nombre del hortcode
	 * $component = referencia a la instancia del objeto, en el que se define el shortcode
	 * $callback = nombre de la definicion del metodo funcion en el componente
	 */
	public function add_shortcode($tag, $component, $callback){
		$this ->shortcodes = $this -> add_s($this ->shortcodes,$tag,$component,$callback);
	}
	/**
	 *Metodo que recibe todos los shortcodes
	 */
	private function add_s($tag,$component,$callback){
		$shortcodes[] = [
			'tag' => $tag,
			'component' => $component,
			'callback' => $callback,

		];

		return $shortcodes;
	}
	/**
	 *el foreach recorre cada una de las acciones
	 */

	public function run(){
		foreach ($this -> actions as $hook_u){
			//extract convierte los indices del arreglo en variables
			extract($hook_u, EXTR_OVERWRITE);
			add_action($hook, [$component, $callback], $priority, $accepted_args);
		}
		foreach ($this -> filters as $hook_u){
			extract($hook_u, EXTR_OVERWRITE);
			add_filter($hook, [$component, $callback], $priority, $accepted_args);
		}
		foreach ($this -> shortcodes as $hook_u){
			extract($shortcode, EXTR_OVERWRITE);
			add_shortcode($tag, [$component, $callback]);
		}
	}
}
