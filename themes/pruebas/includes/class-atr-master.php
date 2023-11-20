<?php
class ATR_MASTER{
    protected $cargador;
    protected $theme_name;
    protected $version;

    public function __construct(){
        $this ->theme_name = 'ATR_Pruebas';
        $this ->version = '1.0.0';
        $this->cargar_dependencias();
    }

    private function cargar_dependencias(){

    }


}
