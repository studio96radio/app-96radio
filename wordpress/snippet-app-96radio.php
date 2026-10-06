<?php
/**
 * App 96 RADIO - pannello impostazioni + indirizzo per l'app.
 *
 * Da incollare in Code Snippets su studio96.it ("Esegui ovunque").
 * - Bacheca > "App 96 RADIO": streaming, colori, sfondo, avviso, menu, social.
 * - L'app legge tutto da: https://www.studio96.it/?rest_route=/s96/v1/app-config
 */

/** Valori di partenza: gli stessi dell'app 8.0.0. */
function s96_app_predefiniti() {
	return array(
		'stream'          => 'https://de1.streamingpulse.com/ssl/9073',
		'colori'          => array(
			'sfondo1' => '#16162a',
			'sfondo2' => '#3b0f45',
			'sfondo3' => '#b0003a',
			'accento' => '#c2185b',
		),
		'sfondo_immagine' => '',
		'avviso'          => array( 'testo' => '', 'link' => '' ),
		'menu'            => array(
			array( 'titolo' => 'Notizie', 'url' => 'https://www.studio96.it/home-2/home-2-2/', 'icona' => 'notizie' ),
			array( 'titolo' => 'Podcast', 'url' => 'https://www.studio96.it/home-2/podcast/', 'icona' => 'podcast' ),
			array( 'titolo' => 'Musica', 'url' => 'https://www.studio96.it/podcast-3/', 'icona' => 'musica' ),
			array( 'titolo' => '96 Sport', 'url' => 'https://www.studio96.it/category/96-sport/', 'icona' => 'sport' ),
			array( 'titolo' => 'Studio96 Informazione', 'url' => 'https://www.studio96informazione.it/', 'icona' => 'articolo' ),
			array( 'titolo' => 'Contatti', 'url' => 'https://www.studio96.it/contatti/', 'icona' => 'contatti' ),
		),
		'social'          => array(
			array( 'nome' => 'sito', 'url' => 'https://www.studio96.it/' ),
			array( 'nome' => 'facebook', 'url' => 'https://www.facebook.com/STUDIO96RADIO' ),
			array( 'nome' => 'instagram', 'url' => 'https://www.instagram.com/96_RADIO' ),
			array( 'nome' => 'x', 'url' => 'https://x.com/RadioNovesei96' ),
			array( 'nome' => 'whatsapp', 'url' => 'https://whatsapp.com/channel/0029VaEtA443GJOzg9epMv0A' ),
		),
	);
}

/** Icone disponibili per il menu (chiave => descrizione). */
function s96_app_icone() {
	return array(
		'notizie'    => 'Giornale (notizie)',
		'articolo'   => 'Articolo',
		'podcast'    => 'Podcast',
		'musica'     => 'Musica',
		'radio'      => 'Radio',
		'sport'      => 'Sport (pallone)',
		'eventi'     => 'Calendario (eventi)',
		'classifica' => 'Classifica',
		'video'      => 'Video',
		'foto'       => 'Foto',
		'stella'     => 'Stella',
		'info'       => 'Informazioni',
		'contatti'   => 'Busta (contatti)',
		'link'       => 'Link generico',
	);
}

/** Social disponibili, nell'ordine in cui compaiono nell'app. */
function s96_app_social_disponibili() {
	return array(
		'sito'      => 'Sito 96 RADIO (logo 96)',
		'facebook'  => 'Facebook',
		'instagram' => 'Instagram',
		'x'         => 'X (Twitter)',
		'whatsapp'  => 'WhatsApp',
		'tiktok'    => 'TikTok',
		'youtube'   => 'YouTube',
		'telegram'  => 'Telegram',
		'spotify'   => 'Spotify',
	);
}

/** Impostazioni attuali (quelle salvate, oppure i valori di partenza). */
function s96_app_impostazioni() {
	$salvate = get_option( 's96_app_config' );
	return is_array( $salvate ) ? $salvate : s96_app_predefiniti();
}

/* ---------- Indirizzo letto dall'app ---------- */

add_action( 'rest_api_init', function () {
	register_rest_route( 's96/v1', '/app-config', array(
		'methods'             => 'GET',
		'permission_callback' => '__return_true',
		'callback'            => function () {
			$risposta = new WP_REST_Response( s96_app_impostazioni() );
			$risposta->header( 'Cache-Control', 'no-cache, no-store, must-revalidate' );
			return $risposta;
		},
	) );
} );

/* ---------- Pannello in Bacheca ---------- */

add_action( 'admin_menu', function () {
	add_menu_page( 'App 96 RADIO', 'App 96 RADIO', 'manage_options', 's96-app', 's96_app_pagina', 'dashicons-smartphone', 3 );
} );

/** Legge il modulo inviato e restituisce le impostazioni pulite. */
function s96_app_leggi_modulo( $p ) {
	$pred = s96_app_predefiniti();

	$stream = isset( $p['stream'] ) ? esc_url_raw( trim( wp_unslash( $p['stream'] ) ), array( 'https' ) ) : '';
	if ( '' === $stream ) {
		$stream = $pred['stream'];
	}

	$colori = array();
	foreach ( $pred['colori'] as $chiave => $valore ) {
		$c                = isset( $p['colori'][ $chiave ] ) ? sanitize_hex_color( wp_unslash( $p['colori'][ $chiave ] ) ) : '';
		$colori[ $chiave ] = $c ? $c : $valore;
	}

	$menu  = array();
	$icone = s96_app_icone();
	if ( ! empty( $p['menu'] ) && is_array( $p['menu'] ) ) {
		foreach ( $p['menu'] as $riga ) {
			$titolo = isset( $riga['titolo'] ) ? sanitize_text_field( wp_unslash( $riga['titolo'] ) ) : '';
			$url    = isset( $riga['url'] ) ? esc_url_raw( trim( wp_unslash( $riga['url'] ) ) ) : '';
			$icona  = isset( $riga['icona'] ) && isset( $icone[ $riga['icona'] ] ) ? $riga['icona'] : 'link';
			if ( '' !== $titolo && '' !== $url ) {
				$menu[] = array( 'titolo' => $titolo, 'url' => $url, 'icona' => $icona );
			}
		}
	}

	$social = array();
	foreach ( array_keys( s96_app_social_disponibili() ) as $nome ) {
		$url = isset( $p['social'][ $nome ] ) ? esc_url_raw( trim( wp_unslash( $p['social'][ $nome ] ) ) ) : '';
		if ( '' !== $url ) {
			$social[] = array( 'nome' => $nome, 'url' => $url );
		}
	}

	return array(
		'stream'          => $stream,
		'colori'          => $colori,
		'sfondo_immagine' => isset( $p['sfondo_immagine'] ) ? esc_url_raw( trim( wp_unslash( $p['sfondo_immagine'] ) ) ) : '',
		'avviso'          => array(
			'testo' => isset( $p['avviso_testo'] ) ? sanitize_text_field( wp_unslash( $p['avviso_testo'] ) ) : '',
			'link'  => isset( $p['avviso_link'] ) ? esc_url_raw( trim( wp_unslash( $p['avviso_link'] ) ) ) : '',
		),
		'menu'            => $menu ? $menu : $pred['menu'],
		'social'          => $social,
	);
}

function s96_app_pagina() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$messaggio = '';
	if ( isset( $_POST['s96_app_salva'] ) && check_admin_referer( 's96_app' ) ) {
		update_option( 's96_app_config', s96_app_leggi_modulo( $_POST ), false );
		$messaggio = 'Impostazioni salvate. Gli ascoltatori le vedranno alla prossima apertura dell\'app.';
	} elseif ( isset( $_POST['s96_app_ripristina'] ) && check_admin_referer( 's96_app' ) ) {
		delete_option( 's96_app_config' );
		$messaggio = 'Ripristinati i valori di partenza.';
	}

	$c     = s96_app_impostazioni();
	$icone = s96_app_icone();
	$menu  = $c['menu'];
	while ( count( $menu ) < 10 ) {
		$menu[] = array( 'titolo' => '', 'url' => '', 'icona' => 'link' );
	}
	$social_attuali = array();
	foreach ( $c['social'] as $s ) {
		$social_attuali[ $s['nome'] ] = $s['url'];
	}
	$etichette_colori = array(
		'sfondo1' => 'Sfondo in alto a sinistra',
		'sfondo2' => 'Sfondo al centro',
		'sfondo3' => 'Sfondo in basso a destra',
		'accento' => 'Pulsante play e icone del menu',
	);
	?>
	<div class="wrap">
		<h1><span class="dashicons dashicons-smartphone" style="font-size:28px;width:28px;height:28px;margin-right:6px"></span>App 96 RADIO</h1>
		<p>Le modifiche valgono per iPhone e Android e arrivano agli ascoltatori alla <strong>prossima apertura dell'app</strong>, senza aggiornare l'app sugli store.</p>
		<?php if ( $messaggio ) : ?>
			<div class="notice notice-success is-dismissible"><p><?php echo esc_html( $messaggio ); ?></p></div>
		<?php endif; ?>

		<form method="post">
			<?php wp_nonce_field( 's96_app' ); ?>

			<h2>Streaming</h2>
			<table class="form-table" role="presentation">
				<tr>
					<th scope="row"><label for="s96-stream">Indirizzo dello streaming</label></th>
					<td>
						<input type="url" id="s96-stream" name="stream" class="large-text code" value="<?php echo esc_attr( $c['stream'] ); ?>" required>
						<p class="description">Deve iniziare con https://. Attenzione: se è sbagliato, la radio nell'app non parte. Dopo averlo cambiato, prova subito l'app.</p>
					</td>
				</tr>
			</table>

			<h2>Aspetto</h2>
			<table class="form-table" role="presentation">
				<?php foreach ( $etichette_colori as $chiave => $etichetta ) : ?>
					<tr>
						<th scope="row"><?php echo esc_html( $etichetta ); ?></th>
						<td><input type="color" name="colori[<?php echo esc_attr( $chiave ); ?>]" value="<?php echo esc_attr( $c['colori'][ $chiave ] ); ?>"></td>
					</tr>
				<?php endforeach; ?>
				<tr>
					<th scope="row"><label for="s96-sfondo">Immagine di sfondo (facoltativa)</label></th>
					<td>
						<input type="url" id="s96-sfondo" name="sfondo_immagine" class="large-text code" value="<?php echo esc_attr( $c['sfondo_immagine'] ); ?>" placeholder="https://www.studio96.it/wp-content/uploads/...">
						<p class="description">Copia l'indirizzo dell'immagine dalla Libreria media (pulsante "Copia URL"). Viene mostrata sfumata sopra i colori. Lascia vuoto per i soli colori. Meglio un'immagine verticale, sotto i 300 KB.</p>
					</td>
				</tr>
			</table>

			<h2>Avviso in evidenza (facoltativo)</h2>
			<table class="form-table" role="presentation">
				<tr>
					<th scope="row"><label for="s96-avviso">Testo</label></th>
					<td>
						<input type="text" id="s96-avviso" name="avviso_testo" class="large-text" maxlength="120" value="<?php echo esc_attr( $c['avviso']['testo'] ); ?>" placeholder="Es. Stasera alle 21 in diretta dal Poetto!">
						<p class="description">Compare sotto il titolo dell'app. Lascia vuoto per nasconderlo.</p>
					</td>
				</tr>
				<tr>
					<th scope="row"><label for="s96-avviso-link">Link (facoltativo)</label></th>
					<td><input type="url" id="s96-avviso-link" name="avviso_link" class="large-text code" value="<?php echo esc_attr( $c['avviso']['link'] ); ?>"></td>
				</tr>
			</table>

			<h2>Menu</h2>
			<p>Le voci compaiono nell'ordine della tabella. Per togliere una voce, svuota il titolo. Per aggiungerne una, usa una riga vuota.</p>
			<table class="widefat striped" style="max-width:1000px">
				<thead><tr><th style="width:40px">#</th><th>Titolo</th><th>Link</th><th style="width:200px">Icona</th></tr></thead>
				<tbody>
				<?php foreach ( $menu as $i => $voce ) : ?>
					<tr>
						<td><?php echo (int) $i + 1; ?></td>
						<td><input type="text" name="menu[<?php echo (int) $i; ?>][titolo]" class="regular-text" style="width:100%" value="<?php echo esc_attr( $voce['titolo'] ); ?>"></td>
						<td><input type="url" name="menu[<?php echo (int) $i; ?>][url]" class="code" style="width:100%" value="<?php echo esc_attr( $voce['url'] ); ?>"></td>
						<td>
							<select name="menu[<?php echo (int) $i; ?>][icona]">
								<?php foreach ( $icone as $chiave => $nome ) : ?>
									<option value="<?php echo esc_attr( $chiave ); ?>" <?php selected( $voce['icona'], $chiave ); ?>><?php echo esc_html( $nome ); ?></option>
								<?php endforeach; ?>
							</select>
						</td>
					</tr>
				<?php endforeach; ?>
				</tbody>
			</table>

			<h2>Social (icone in basso)</h2>
			<p>Lascia vuoto il campo di un social per nasconderlo dall'app.</p>
			<table class="form-table" role="presentation">
				<?php foreach ( s96_app_social_disponibili() as $nome => $etichetta ) : ?>
					<tr>
						<th scope="row"><?php echo esc_html( $etichetta ); ?></th>
						<td><input type="url" name="social[<?php echo esc_attr( $nome ); ?>]" class="large-text code" value="<?php echo esc_attr( isset( $social_attuali[ $nome ] ) ? $social_attuali[ $nome ] : '' ); ?>"></td>
					</tr>
				<?php endforeach; ?>
			</table>

			<p class="submit">
				<button type="submit" name="s96_app_salva" value="1" class="button button-primary button-hero">Salva le impostazioni dell'app</button>
				&nbsp;
				<button type="submit" name="s96_app_ripristina" value="1" class="button" onclick="return confirm('Ripristinare tutte le impostazioni di partenza?');">Ripristina valori di partenza</button>
			</p>
		</form>
	</div>
	<?php
}
