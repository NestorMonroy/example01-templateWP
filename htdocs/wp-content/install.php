<?php
/**
 * Instala el sitio.
 *
 * Ejecuta las funciones requeridas para configurar y poblar la base de datos,
 * incluyendo el usuario administrador principal y las opciones iniciales.
 *
 * @since 2.1.0
 *
 * @param string $blog_title    Título del blog.
 * @param string $user_name     Nombre de usuario.
 * @param string $user_email    Correo electrónico del usuario.
 * @param bool   $public        Indica si el blog es público.
 * @param string $deprecated    Opcional. No utilizado.
 * @param string $user_password Opcional. Contraseña elegida por el usuario. Por defecto está vacía (contraseña aleatoria).
 * @param string $language      Opcional. Idioma elegido. Por defecto está vacío.
 * @return array Array con las claves 'url', 'user_id', 'password' y 'password_message'.
 */
function wp_install( $blog_title, $user_name, $user_email, $public, $deprecated = '', $user_password = '', $language = '' ) {
	// Verificar argumento obsoleto
	if ( ! empty( $deprecated ) ) {
		_deprecated_argument( __FUNCTION__, '2.6' );
	}

	// Comprobar versión de MySQL y limpiar caché
	wp_check_mysql_version();
	wp_cache_flush();
	make_db_current_silent();
	populate_options();
	populate_roles();

	// Capitalizar título del blog si es necesario
	$blog_title = ($blog_title == 'Wordpress') ? 'WordPress' : $blog_title;
	update_option('blog_name', $blog_title);
	update_option('admin_email', $user_email);
	update_option('blog_public', $public);
	update_option('fresh_site', 1);

	// Cargar idioma desde variable de entorno si no está establecido
	$env_wp_lang = getenv('WP_LANG');
	if ( empty($language) && $env_wp_lang ) {
		$language = $env_wp_lang;
		load_default_textdomain($env_wp_lang);
		$GLOBALS['wp_locale'] = new WP_Locale();
	}
	if ( $language ) {
		update_option('WPLANG', $language);
	}

	// Establecer URL del sitio
	$guessurl = wp_guess_url();
	update_option('siteurl', $guessurl);

	// Establecer flag de pingback por defecto si el blog no es público
	if ( ! $public ) {
		update_option('default_pingback_flag', 0);
	}

	// Crear usuario por defecto o establecer rol si el usuario ya existe
	$user_id = username_exists($user_name);
	$user_password = trim($user_password);

	if ( !$user_id ) {
		if ( empty($user_password) ) {
			$user_password = wp_generate_password(12, false);
			$message = __('<strong><em>¡Toma nota de la contraseña!</em></strong> Es una <em>contraseña aleatoria</em> que se generó solo para ti.');
		} else {
			$message = '<em>' . __('Tu contraseña elegida.') . '</em>';
		}
		$user_id = wp_create_user($user_name, $user_password, $user_email);
		if ( empty($user_password) ) {
			update_user_option($user_id, 'default_password_nag', true, true);
		}
	} else {
		$message = __('El usuario ya existe. Contraseña heredada.');
	}

	// Establecer el rol del usuario como administrador
	$user = new WP_User($user_id);
	$user->set_role('administrator');

	// Instalar configuraciones predeterminadas y limpiar reglas de reescritura
	wp_install_defaults($user_id);
	wp_install_maybe_enable_pretty_permalinks();
	flush_rewrite_rules();

	// Limpiar caché nuevamente
	wp_cache_flush();

	// Activar acción al completar la instalación
	do_action('wp_install', $user);

	return array(
		'url'              => $guessurl,
		'user_id'          => $user_id,
		'password'         => $user_password,
		'password_message' => $message,
	);
}

/**
 * Crea el contenido inicial para un sitio recién instalado.
 *
 * Agrega la categoría "Sin categorizar", la primera página y
 * establece opciones predeterminadas.
 *
 * @since 2.1.0
 *
 * @global wpdb       $wpdb
 * @global WP_Rewrite $wp_rewrite
 * @global string     $table_prefix
 *
 * @param int $user_id ID del usuario.
 */
function wp_install_defaults( $user_id ) {
	global $wpdb, $wp_rewrite, $table_prefix;

	// Crear categoría predeterminada
	$cat_name = __('Uncategorized');
	$cat_slug = sanitize_title(_x('Uncategorized', 'Default category slug'));

	// Verificar y agregar la categoría si es necesario
	// Como global_terms_enabled() siempre devuelve false, eliminamos la condición
	$cat_id = 1; // Valor predeterminado
	// Lógica para términos locales
	$cat_id = $wpdb->get_var($wpdb->prepare("SELECT cat_ID FROM {$wpdb->terms} WHERE slug = %s", $cat_slug));
	if ($cat_id === null) {
		$wpdb->insert($wpdb->terms, [
			'term_id'    => 0,
			'name'       => $cat_name,
			'slug'       => $cat_slug,
			'term_group' => 0,
		]);
		$cat_id = $wpdb->insert_id;
	}
	update_option('default_category', $cat_id);


	// Insertar en términos y taxonomía
	$wpdb->insert($wpdb->terms, [
		'term_id'    => $cat_id,
		'name'       => $cat_name,
		'slug'       => $cat_slug,
		'term_group' => 0,
	]);
	$wpdb->insert($wpdb->term_taxonomy, [
		'term_id'     => $cat_id,
		'taxonomy'    => 'category',
		'description' => '',
		'parent'      => 0,
		'count'       => 1,
	]);

	// Contenido de la primera página
	$first_page = is_multisite() ? get_site_option('first_page') : '';
	if (empty($first_page)) {
		$first_page = first_page();
	}

	// Crear primera página
	$now = current_time('mysql');
	$now_gmt = current_time('mysql', 1);
	$first_post_guid = get_option('home') . '/?page_id=1';

	$wpdb->insert($wpdb->posts, [
		'id'                    => 1,
		'post_author'           => $user_id,
		'post_date'             => $now,
		'post_date_gmt'         => $now_gmt,
		'post_content'          => $first_page,
		'comment_status'        => 'closed',
		'post_title'            => page_title(),
		'post_name'             => __('start-wordpress'),
		'post_modified'         => $now,
		'post_modified_gmt'     => $now_gmt,
		'guid'                  => $first_post_guid,
		'post_type'             => 'page',
	]);
	$wpdb->insert($wpdb->postmeta, [
		'post_id'    => 1,
		'meta_key'   => '_wp_page_template',
		'meta_value' => 'default',
	]);

	// Crear página de Política de Privacidad
	$privacy_policy_content = is_multisite() ? get_site_option('default_privacy_policy_content') : WP_Privacy_Policy_Content::get_default_content();
	if (!empty($privacy_policy_content)) {
		$privacy_policy_guid = get_option('home') . '/?page_id=2';
		$wpdb->insert($wpdb->posts, [
			'id'                    => 2,
			'post_author'           => $user_id,
			'post_date'             => $now,
			'post_date_gmt'         => $now_gmt,
			'post_content'          => $privacy_policy_content,
			'comment_status'        => 'closed',
			'post_title'            => __('Privacy Policy'),
			'post_name'             => __('privacy-policy'),
			'post_modified'         => $now,
			'post_modified_gmt'     => $now_gmt,
			'guid'                  => $privacy_policy_guid,
			'post_type'             => 'page',
			'post_status'           => 'draft',
		]);
		$wpdb->insert($wpdb->postmeta, [
			'post_id'    => 2,
			'meta_key'   => '_wp_page_template',
			'meta_value' => 'default',
		]);
		update_option('wp_page_for_privacy_policy', 2);
	}

	// Configurar opciones adicionales
	update_option('blogdescription', '');
	update_option('timezone_string', timezone_string());
	update_option('date_format', date_format_custom());
	update_option('time_format', time_format());
	update_option('show_on_front', 'page');
	update_option('page_on_front', 1);
	update_option('default_comment_status', 0);
	update_option('permalink_structure', '/%postname%/');

	// Activar plugins automáticamente si existen
	install_activate_plugins();
}



/** * Funciones auxiliares para devolver contenido y opciones específicas del idioma */
/**
 * Genera el título de la página según el idioma configurado.
 *
 * Esta función devuelve el título de la página de bienvenida
 * dependiendo del idioma configurado en WordPress o en las variables de entorno.
 *
 * @return string El título de la página.
 */
function page_title() {
	// Obtener el idioma configurado en el entorno
	$env_wp_lang = getenv('WP_LANG');
	$locale = get_locale();

	// Definir los títulos según el idioma
	$page_titles = [
		'es_MX' => 'Bienvenido',     // Español (México)
		'en_US' => 'Welcome',        // Inglés (EE. UU.)
	];
	// Obtener el título correspondiente o un título por defecto
	return $page_titles[$locale] ?? $page_titles[$env_wp_lang] ?? 'Welcome';
}

/**
 * Genera la primera página de bienvenida según el idioma configurado.
 *
 * Esta función devuelve contenido HTML para la página de inicio,
 * dependiendo del idioma configurado en WordPress o en las variables de entorno.
 *
 * @return string El contenido HTML de la primera página.
 */
function first_page() {
	// Obtener el idioma configurado en el entorno
	$env_wp_lang = getenv('WP_LANG');
	$locale = get_locale();

	// Definir los mensajes de bienvenida según el idioma
	$welcome_messages = [
		'es_MX' => '<p>¡Bienvenido a tu nueva instalación de WordPress! Estamos muy contentos de que hayas decidido confiar en nosotros para alojar tu sitio web.</p>',
		'en_US' => '<p>Welcome to your brand-new WordPress installation! We are excited that you have chosen us to host your website.</p>',
	];

	// Contenido por defecto para otros idiomas
	$default_message = '<p>Welcome to your brand-new WordPress installation! We hope you have chosen to host your website with us.</p>';

	// Obtener el mensaje correspondiente o el mensaje por defecto
	$first_page_message = $welcome_messages[$locale] ?? $welcome_messages[$env_wp_lang] ?? $default_message;

	// Generar el contenido HTML
	ob_start();
	?>
	<!-- wp:image {"align":"right","width":266,"height":266,"linkDestination":"custom"} -->
	<div class="wp-block-image">
		<figure class="alignright is-resized">
			<a role="menuitem" class="x-nav-link x-nav-link--logo x-link" href="https://wordpress.com/es/">
				<svg class="x-icon x-icon--logo" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 170 36" role="presentation" aria-label="Logotipo de WordPress.com"><path d="M52.84 12.9c1.08 0 2 .24 2.8.71.78.47 1.4 1.14 1.82 1.99.44.85.65 1.84.65 2.97 0 1.13-.21 2.12-.65 2.97a4.78 4.78 0 0 1-1.83 1.97 5.3 5.3 0 0 1-2.79.7c-1.07 0-2-.23-2.79-.7a4.77 4.77 0 0 1-1.83-1.97 6.44 6.44 0 0 1-.64-2.97c0-1.13.21-2.13.64-2.97a4.77 4.77 0 0 1 1.83-1.99c.79-.47 1.72-.7 2.8-.7ZM31.37 9.4l2.65 10.73h.13L36.97 9.4h2.6l2.83 10.74h.13L45.17 9.4h2.85L43.9 24h-2.62l-2.94-10.25h-.11L35.28 24h-2.62L28.52 9.4h2.85Zm21.49 5.55c-.6 0-1.1.16-1.49.49a2.9 2.9 0 0 0-.88 1.3 5.4 5.4 0 0 0-.29 1.82c0 .67.1 1.27.3 1.81.18.54.48.97.87 1.3.4.32.9.48 1.49.48.58 0 1.07-.16 1.46-.48.39-.33.68-.76.88-1.3a5.4 5.4 0 0 0 .29-1.8c0-.68-.1-1.29-.3-1.83a2.88 2.88 0 0 0-.87-1.3c-.4-.33-.87-.49-1.46-.49ZM64.7 12.9a2.75 2.75 0 0 0-2.7 1.98h-.12v-1.83h-2.5v10.96h2.58v-6.44a2.27 2.27 0 0 1 1.2-2.07c.39-.2.81-.3 1.28-.3a5.55 5.55 0 0 1 1.2.14v-2.37a8.44 8.44 0 0 0-.93-.07Zm8.95 1.96h-.1a4.93 4.93 0 0 0-.57-.85c-.24-.3-.57-.56-.99-.78a3.44 3.44 0 0 0-1.59-.32 4.24 4.24 0 0 0-3.93 2.55 7.1 7.1 0 0 0-.6 3.08c0 1.22.2 2.22.59 3.06a4.16 4.16 0 0 0 3.94 2.59 3.16 3.16 0 0 0 2.57-1.07c.25-.3.44-.58.58-.84h.15V24h2.55V9.4h-2.6v5.46Zm-.25 5.53c-.2.53-.5.95-.88 1.24-.38.3-.85.45-1.4.45-.55 0-1.04-.15-1.43-.46-.4-.3-.69-.73-.88-1.26-.2-.54-.3-1.15-.3-1.83 0-.69.1-1.28.3-1.81.19-.53.48-.94.87-1.24.38-.3.87-.45 1.44-.45.58 0 1.03.15 1.42.43.38.3.67.7.87 1.22.2.53.3 1.14.3 1.85 0 .7-.1 1.33-.3 1.86Zm13.24-10.36a5.87 5.87 0 0 0-2.84-.63h-5.5V24h2.66v-4.93h2.8c1.13 0 2.08-.2 2.86-.63a4.23 4.23 0 0 0 1.75-1.71c.4-.73.6-1.56.6-2.5s-.2-1.75-.6-2.48a4.22 4.22 0 0 0-1.73-1.72Zm-.68 5.58c-.2.4-.52.71-.93.94-.43.23-.96.34-1.62.34h-2.45v-5.28h2.43c.67 0 1.21.11 1.63.33.42.22.74.53.94.92.2.4.3.85.3 1.37 0 .53-.1.98-.3 1.38Zm9.39-2.71a2.75 2.75 0 0 0-2.71 1.98h-.12v-1.83h-2.51v10.96h2.59v-6.44a2.27 2.27 0 0 1 1.2-2.07c.38-.2.8-.3 1.28-.3a5.55 5.55 0 0 1 1.2.14v-2.37a8.44 8.44 0 0 0-.93-.07Zm9.81 1.33c-.47-.45-1-.78-1.6-1a5.68 5.68 0 0 0-4.66.4 4.87 4.87 0 0 0-1.82 2 6.49 6.49 0 0 0-.65 2.96c0 1.13.22 2.14.65 2.99a4.62 4.62 0 0 0 1.84 1.95c.8.46 1.75.69 2.85.69.85 0 1.61-.13 2.28-.39a4.2 4.2 0 0 0 1.63-1.1c.43-.47.72-1.02.87-1.66l-2.42-.27a2 2 0 0 1-.5.78 2.56 2.56 0 0 1-1.82.63 2.9 2.9 0 0 1-1.48-.36 2.46 2.46 0 0 1-.98-1.04 3.5 3.5 0 0 1-.35-1.57h7.66v-.8c0-.96-.13-1.78-.4-2.48a4.71 4.71 0 0 0-1.1-1.72Zm-6.15 3.26c.03-.43.13-.83.33-1.2a2.57 2.57 0 0 1 2.34-1.37 2.34 2.34 0 0 1 2.18 1.25c.2.38.31.82.32 1.32h-5.17Zm14.65.27-1.87-.4c-.56-.13-.96-.3-1.2-.5a.94.94 0 0 1-.36-.77c0-.37.18-.67.54-.9.37-.24.82-.36 1.36-.36.4 0 .74.07 1.02.2.27.13.5.3.66.5.16.21.28.44.35.67l2.36-.25a3.45 3.45 0 0 0-1.38-2.22 5.03 5.03 0 0 0-3.05-.82 6.2 6.2 0 0 0-2.32.4 3.6 3.6 0 0 0-1.57 1.16 2.8 2.8 0 0 0-.55 1.76c0 .8.25 1.46.75 1.98s1.29.89 2.34 1.1l1.88.4c.5.1.88.26 1.12.47.24.2.36.46.36.78 0 .37-.19.68-.56.93-.38.25-.87.38-1.49.38a2.5 2.5 0 0 1-1.45-.38 1.77 1.77 0 0 1-.73-1.12l-2.53.24c.16 1 .65 1.8 1.47 2.36.82.56 1.9.84 3.25.84.91 0 1.72-.15 2.43-.44.7-.3 1.26-.7 1.66-1.23.4-.53.6-1.13.6-1.82 0-.79-.26-1.42-.77-1.9a4.76 4.76 0 0 0-2.32-1.07Zm10.13 0-1.88-.4c-.56-.13-.96-.3-1.2-.5a.94.94 0 0 1-.35-.77c0-.37.17-.67.54-.9a2.4 2.4 0 0 1 1.36-.36c.4 0 .73.07 1.01.2a1.8 1.8 0 0 1 1.01 1.17l2.36-.25a3.45 3.45 0 0 0-1.38-2.22 5.03 5.03 0 0 0-3.04-.82 6.1 6.1 0 0 0-2.32.4 3.6 3.6 0 0 0-1.57 1.16 2.8 2.8 0 0 0-.56 1.76c0 .8.25 1.46.76 1.98.5.52 1.28.89 2.34 1.1l1.87.4c.5.1.88.26 1.12.47.24.2.36.46.36.78 0 .37-.18.68-.56.93-.38.25-.87.38-1.49.38a2.5 2.5 0 0 1-1.45-.38 1.77 1.77 0 0 1-.73-1.12l-2.53.24c.16 1 .65 1.8 1.47 2.36.82.56 1.9.84 3.25.84a6.3 6.3 0 0 0 2.43-.44c.71-.3 1.26-.7 1.66-1.23.4-.53.6-1.13.6-1.82 0-.79-.25-1.42-.76-1.9a4.76 4.76 0 0 0-2.32-1.07Zm5.85 3.28a1.55 1.55 0 0 0-1.58 1.55c0 .44.15.8.46 1.11.3.3.68.46 1.12.46.28 0 .54-.07.77-.21.24-.14.43-.33.58-.57a1.5 1.5 0 0 0-.25-1.89c-.32-.3-.68-.45-1.1-.45ZM136 15.4c.4-.28.87-.42 1.4-.42.62 0 1.12.18 1.5.53.37.35.61.8.71 1.32h2.48a4.07 4.07 0 0 0-.7-2.07 4.07 4.07 0 0 0-1.65-1.37 5.52 5.52 0 0 0-2.38-.5 4.83 4.83 0 0 0-4.61 2.71 6.47 6.47 0 0 0-.64 2.96c0 1.11.2 2.08.63 2.93a4.77 4.77 0 0 0 1.81 2 5.3 5.3 0 0 0 2.83.72 5.4 5.4 0 0 0 2.4-.5 4.04 4.04 0 0 0 2.3-3.46h-2.47c-.08.4-.22.73-.42 1-.2.28-.46.5-.76.64s-.65.21-1.03.21c-.54 0-1-.14-1.4-.43-.4-.28-.71-.7-.94-1.23a5.03 5.03 0 0 1-.32-1.92c0-.75.1-1.37.33-1.9.22-.53.53-.93.93-1.22Zm14.8-1.8a5.34 5.34 0 0 0-2.79-.7c-1.07 0-2 .23-2.8.7a4.77 4.77 0 0 0-1.82 1.99 6.49 6.49 0 0 0-.65 2.97c0 1.13.22 2.12.65 2.97.43.84 1.04 1.5 1.83 1.97s1.72.7 2.79.7 2-.23 2.8-.7a4.78 4.78 0 0 0 1.82-1.97 6.5 6.5 0 0 0 .65-2.97 6.5 6.5 0 0 0-.65-2.97 4.77 4.77 0 0 0-1.83-1.99Zm-.44 6.76c-.19.54-.48.97-.88 1.3-.39.32-.87.48-1.46.48a2.3 2.3 0 0 1-1.48-.48c-.4-.33-.69-.76-.88-1.3-.2-.54-.3-1.14-.3-1.8 0-.68.1-1.29.3-1.83.2-.54.49-.98.88-1.3.4-.33.89-.49 1.48-.49.6 0 1.07.16 1.46.49.4.32.69.76.88 1.3.2.54.3 1.15.3 1.82 0 .67-.1 1.27-.3 1.81Zm18.68-6.5a3.36 3.36 0 0 0-2.47-.96c-.8 0-1.49.18-2.07.54-.58.37-1 .85-1.23 1.46h-.12a2.85 2.85 0 0 0-1.08-1.47 3.2 3.2 0 0 0-1.89-.54 3.3 3.3 0 0 0-1.9.54c-.53.35-.9.84-1.14 1.47h-.12v-1.87h-2.48V24h2.6v-6.66c0-.46.08-.85.26-1.2.18-.33.43-.6.73-.78.31-.2.65-.28 1.02-.28.55 0 1 .17 1.34.5.34.34.5.8.5 1.36V24h2.55v-6.83c0-.62.17-1.12.52-1.51.35-.39.84-.58 1.47-.58a2 2 0 0 1 1.33.47c.36.32.54.82.54 1.5V24h2.6v-7.35c0-1.23-.32-2.16-.96-2.8v.01ZM11.47 5.33c6.32 0 11.46 5.12 11.46 11.42a11.46 11.46 0 0 1-22.93 0c0-6.3 5.14-11.42 11.47-11.42Zm.18 12.32-3.1 8.95a10.38 10.38 0 0 0 6.34-.16.9.9 0 0 1-.07-.15l-3.17-8.64Zm-9.6-5.08A10.26 10.26 0 0 0 6.97 26Zm18.46-.75c.05.33.07.68.07 1.06 0 1.04-.2 2.21-.78 3.68l-3.15 9.06a10.26 10.26 0 0 0 3.86-13.8ZM11.47 6.5c-3.6 0-6.77 1.84-8.62 4.63A23.92 23.92 0 0 0 6.26 11c.56-.03.62.78.07.85 0 0-.56.06-1.18.1L8.9 23.06l2.26-6.74-1.6-4.39c-.56-.03-1.09-.1-1.09-.1-.55-.03-.49-.87.07-.84 0 0 1.7.13 2.71.13C12.33 11.13 14 11 14 11c.55-.03.62.78.07.85 0 0-.56.06-1.18.1l3.72 11.04 1.03-3.43a9.5 9.5 0 0 0 .79-3.32 5.4 5.4 0 0 0-.85-2.83c-.53-.85-1.02-1.56-1.02-2.4 0-.95.72-1.83 1.74-1.83h.13a10.28 10.28 0 0 0-6.96-2.69Z"></path></svg>
			</a>
		</figure>
	</div>
	<!-- /wp:image -->

	<?php echo $first_page_message; ?>

	<?php
	return ob_get_clean();
}


/**
 * Devuelve la cadena de zona horaria basada en el idioma actual.
 *
 * Esta función determina la zona horaria a utilizar en función
 * del idioma configurado en WordPress o en las variables de entorno.
 *
 * @return string La cadena de la zona horaria correspondiente.
 */
function timezone_string() {
	// Obtener el idioma configurado en el entorno
	$env_wp_lang = getenv('WP_LANG');

	// Definir la zona horaria según el idioma
	$locales_zones = [
		'es_MX' => 'America/Mexico_City', // Español (México)
		'en_US' => 'America/New_York', // Inglés (EE. UU.)
		// Agrega más idiomas y zonas horarias según sea necesario
	];

	// Priorizar el idioma del entorno sobre el idioma de WordPress
	$locale = $env_wp_lang ?: get_locale();

	// Devolver la zona horaria correspondiente
	return $locales_zones[$locale] ?? '';
}



/*
 * Función para obtener el formato de fecha según la configuración regional.
 *
 * Esta función devuelve el formato de fecha basado en el idioma del sitio,
 * ajustando el formato para idiomas específicos cuando sea necesario.
 *
 * @return string El formato de fecha en función del idioma configurado.
 *
 * @uses getenv() Recupera el valor de una variable de entorno.
 * @uses get_locale() Obtiene el locale actual de WordPress.
 * Y: Año en cuatro dígitos (ej. 2024) - y: Año en dos dígitos (ej. 24).
 * m: Mes en dos dígitos (ej. 01 a 12) - n: Mes en un dígito (ej. 1 a 12)
 * F: Nombre completo del mes (ej. octubre) - M: Nombre abreviado del mes (ej. oct)
 * d: Día del mes en dos dígitos (ej. 01 a 31) -
 * d: Día del mes en dos dígitos (ej. 01 a 31) - j: Día del mes en un dígito (ej. 1 a 31).
 * D: Nombre abreviado del día de la semana (ej. lun) - l (minúscula): Nombre completo del día de la semana (ej. lunes).
 * H: Hora en formato 24 horas (ej. 00 a 23) - h: Hora en formato 12 horas (ej. 01 a 12).
 * i: Minutos en dos dígitos (ej. 00 a 59) - s: Segundos en dos dígitos (ej. 00 a 59).
 * a: am o pm en minúsculas. - A: AM o PM en mayúsculas.
 * Y-m-d (año-mes-día)
 * j.n.Y (día.mes.año)
 */
function date_format_custom() {
	// Obtener el idioma configurado en el entorno de WordPress
	$env_wp_lang = getenv('WP_LANG');

	// Definir los formatos de fecha según el idioma
	$formats = [
		'es_MX' => 'F j, Y',    // Formato para México (mes día, año)
		'en_US' => 'Y-m-d',    // Formato para EE. UU. (año-mes-día)
	];

	// Obtener el locale actual
	$current_locale = get_locale();

	// Determinar el formato de fecha
	// Formato por defecto
	return $formats[$current_locale] ?? $formats[$env_wp_lang] ?? 'F j, Y';
}


/*
 * Función para obtener el formato de hora según la configuración regional.
 *
 * Esta función devuelve el formato de hora basado en el idioma del sitio,
 * ajustando el formato para idiomas específicos cuando sea necesario.
 *
 * @return string El formato de hora en función del idioma configurado.
 *
 * @uses getenv() Recupera el valor de una variable de entorno.
 * @uses get_locale() Obtiene el locale actual de WordPress.
 */
function time_format() {
	// Obtener el idioma configurado en el entorno de WordPress
	$env_wp_lang = getenv('WP_LANG');

	// Definir los formatos de hora según el idioma
	$formats = [
		'es_MX' => 'H:i', // Formato para México (24 horas)
		'en_US' => 'h:i A', // Formato para EE. UU. (12 horas con AM/PM)
	];

	// Obtener el locale actual
	$current_locale = get_locale();

	return $formats[$current_locale] ?? $formats[$env_wp_lang] ?? 'H:i';
}




/*
 * Helper que activa algunos plugins útiles
 *
 * Esta función verifica una lista predefinida de plugins para activar al momento de la instalación
 * y los activa si ya están instalados.
 *
 * @return void
 *
 * @global array $all_plugins Un arreglo de todos los plugins instalados.
 *
 * @uses get_plugins() Recupera la lista de todos los plugins instalados.
 * @uses defined() Verifica si una constante está definida.
 * @uses explode() Divide una cadena usando un delimitador específico.
 * @uses include_once() Incluye un archivo una vez.
 * @uses do_action() Llama a las funciones enganchadas a una acción específica.
 * @uses update_option() Actualiza una opción específica en la base de datos.
 */
function install_activate_plugins() {
	// Obtener la lista de todos los plugins instalados
	$all_plugins = get_plugins();

	// Activar automáticamente estos plugins al instalar
	// Puedes sobrescribir los predeterminados usando WP_AUTO_ACTIVATE_PLUGINS en tu wp-config.php
	if (defined('WP_AUTO_ACTIVATE_PLUGINS')) {
		$plugins = explode(',', WP_AUTO_ACTIVATE_PLUGINS);
	} else {
		$plugins = array();
	}

	// Activar plugins si se pueden encontrar entre los plugins instalados
	foreach ($all_plugins as $plugin_path => $data) {
		$plugin_name = explode('/', $plugin_path)[0]; // obtener el nombre de la carpeta del plugin
		if (in_array($plugin_name, $plugins)) { // Si el plugin está instalado, activarlo
			// Realizar la activación
			include_once(WP_PLUGIN_DIR . '/' . $plugin_path);
			do_action('activate_plugin', $plugin_path);
			do_action('activate_' . $plugin_path);
			$current[] = $plugin_path;
			sort($current);
			update_option('active_plugins', $current);
			do_action('activated_plugin', $plugin_path);
		}
	}
}
