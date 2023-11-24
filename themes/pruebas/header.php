<!doctype html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta http-equiv="X-UA-Compatible" content="ie=edge">
	<title><?php bloginfo('name');?> <?php if(wp_title("",false)){ echo "|" ;} ?> <?php wp_title("") ?> </title>
	<meta name="description" content="<?php bloginfo('description'); ?>">

	<!--favicon.ico -->
	<link rel="shortcut icon" href="<?php echo get_template_directory_uri() ?>/favicon.ico" type="image/x-icon">
	<!-- Etiquetas moviles APP IOS -->
	<meta name="apple-mobile-web-app-capable" content="yes">
	<meta name="apple-mobile-web-app-title" content="pruebas">
	<link rel="apple-touch-icon" href="<?php echo get_template_directory_uri() ?>/apple-touch-icon.jpg" type="image/x-icon">
	<!-- Etiquetas moviles app android-->
	<meta name="mobile-web-app-capable" content="yes">
	<meta name="theme-color" content="#333333">
	<meta name="application-name" content="pruebas">
	<link rel="icon" type="image/png" href="<?php echo get_template_directory_uri(); ?>/icono.png">

	<?php wp_head(); ?>
</head>
<body>
<div class="container-fluid bg-color-container">
	<div class="container">
		<nav class="navbar navbar-expand-lg ">
			<div class="container-fluid">
				<a class="navbar-brand" href="#">
					<?php
					if(function_exists('the_custom_logo')){
						the_custom_logo();
					}
					?>
				</a>
				<button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarCollapse" aria-controls="navbarCollapse" aria-expanded="false" aria-label="Toggle navigation">
					<span class="navbar-toggler-icon"></span>
				</button>
				<?php
				//wp_die(var_dump(get_registered_nav_menus()));
				wp_nav_menu(array(
					'theme_location' => 'menu_principal',
					'container_class' => 'collapse navbar-collapse',
					'container_id' => 'navbarNavDropdown',
					'menu_class' => 'navbar-nav mb-2 mb-md-0',
				));
				?>
				<!--div class="collapse navbar-collapse" id="navbarCollapse">
					<ul class="navbar-nav me-auto mb-2 mb-md-0">
						<li class="nav-item">
							<a class="nav-link active" aria-current="page" href="#">Home</a>
						</li>
						<li class="nav-item">
							<a class="nav-link" href="#">Link</a>
						</li>
						<li class="nav-item">
							<a class="nav-link disabled" aria-disabled="true">Disabled</a>
						</li>
					</ul>
					<form class="d-flex" role="search">
						<input class="form-control me-2" type="search" placeholder="Search" aria-label="Search">
						<button class="btn btn-outline-success" type="submit">Search</button>
					</form>
				</div-->
			</div>
		</nav>
	</div>
</div>
