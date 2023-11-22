<?php
/*Gestion de las acciones dentro de admin y public*/
class ATR_MASTER{
    protected $cargador;
    protected $theme_name;
    protected $version;

    public function __construct(){
		//Es el nombre que se pasa a las classes admin y public
        $this -> theme_name = 'ATR_Pruebas';
        $this -> version = '1.0.0';
        $this -> cargar_dependencias();
    }

    private function cargar_dependencias(){

    }

}
