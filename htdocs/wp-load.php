<?php
/*
 * Este archivo se utiliza para instalar y configurar WordPress en un entorno
 * donde el directorio wp-content se encuentra fuera del núcleo de WordPress.
 *
 * Esto se hace para evitar que se sobrescriba durante actualizaciones o
 * instalaciones de nuevas versiones de WordPress.
 *
 * Se requiere wp-load.php desde la ubicación correcta para asegurarse de que
 * todas las funciones de WordPress estén disponibles.
 */

// Requiere wp-load.php desde la ubicación donde realmente se encuentra.
require_once dirname(__FILE__) . '/wordpress/wp-load.php';
