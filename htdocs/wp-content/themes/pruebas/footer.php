<?php wp_footer(); ?>
<footer class="footer py-5 gx-0">
	<div class="container">
		<div class="row">
			<div class="col-12 col-md">
				<?php
				if(function_exists('the_custom_logo')){
					the_custom_logo();
				}
				?>
			</div>

			<div class="col-12">
				<div class="title-footer">
					<h4>Redes sociales</h4>
				</div>
				<div class="iconos-redes-sociales">
					<?php
						$args = [
							'theme_location' => 'menu_redes_sociales',
							'menu_class' => 'menu_sociales'
						];
						wp_nav_menu($args);
					?>
				</div>
			</div>
			<div class="col-12">
				<small class="d-block pt-2 mb-3 text-xxl-center text-xl-center text-md-center text-lg-center text-sm-end ">&copy; 2017–<?php echo date_i18n('Y'); ?>  </small>
			</div>
		</div>
	</div>
</footer>
</body>
</html>
