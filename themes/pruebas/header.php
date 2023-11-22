<!doctype html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta http-equiv="X-UA-Compatible" content="ie=edge">
	<title>Header-Normal</title>
	<?php wp_head(); ?>
</head>
<body style="background-color: rgba(163, 33, 33, 0.1);">
<nav class="navbar navbar-expand-md bg-dark sticky-top border-bottom" data-bs-theme="dark">
	<div class="container">
		<a class="navbar-brand d-md-none" href="#">
			<svg class="bi" width="24" height="24">
				<use xlink:href="#aperture" />
			</svg>
			Aperture
		</a>
		<button class="navbar-toggler" type="button" data-bs-toggle="offcanvas" data-bs-target="#offcanvas"
				aria-controls="#offcanvas" aria-label="Toggle navigation">
			<span class="navbar-toggler-icon"></span>
		</button>
		<div class="offcanvas offcanvas-end" tabindex="-1" id="#offcanvas" aria-labelledby="#offcanvasLabel">
			<div class="offcanvas-header">
				<h5 class="offcanvas-title" id="#offcanvasLabel">Aperture</h5>
				<button type="button" class="btn-close" data-bs-dismiss="offcanvas" aria-label="Close"></button>
			</div>
			<div class="offcanvas-body">
				<ul class="navbar-nav flex-grow-1 justify-content-between">
					<li class="nav-item"><a class="nav-link" href="#">
							<svg class="bi" width="24" height="24">
								<use xlink:href="#aperture" />
							</svg>
						</a></li>
					<li class="nav-item"><a class="nav-link" href="#">Tour</a></li>
					<li class="nav-item"><a class="nav-link" href="#">Product</a></li>
					<li class="nav-item"><a class="nav-link" href="#">Features</a></li>
					<li class="nav-item"><a class="nav-link" href="#">Enterprise</a></li>
					<li class="nav-item"><a class="nav-link" href="#">Support</a></li>
					<li class="nav-item"><a class="nav-link" href="#">Pricing</a></li>
					<li class="nav-item"><a class="nav-link" href="#">
							<svg class="bi" width="24" height="24">
								<use xlink:href="#cart" />
							</svg>
						</a></li>
				</ul>
			</div>
		</div>
	</div>
</nav>


</body>
