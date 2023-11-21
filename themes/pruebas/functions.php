<?php

function enqueue_style(){
	wp_enqueue_style(
		'normalize-css',
		get_template_directory_uri().'/public/css/normalize.css',
		array(),
		'8.0.1',
		'all'
	);
    wp_enqueue_style(
        'public-css',
        get_template_directory_uri().'/public/css/atr-public.css',
        array(),
        '1.0.0',
        'all'
    );
	wp_enqueue_style(
		'bootstrap-css',
		get_template_directory_uri().'/helpers/bootstrap-5.3.2/css/bootstrap.min.css',
		array(),
		'5.3.2',
		'all'
	);
}

add_action('wp_enqueue_scripts','wp_enqueue_styles');
