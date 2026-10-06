import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Tutti i dati della radio in un unico posto.
///
/// Streaming, colori, sfondo, avviso, menu e social si possono cambiare
/// senza aggiornare l'app, dal pannello "App 96 RADIO" nel WordPress di
/// studio96.it (vedi remote_config.dart). I valori scritti qui sotto sono
/// quelli di partenza, usati finché l'app non ha letto il pannello.
class Radio96 {
  static const String nome = '96 RADIO';
  static const String claim = 'Missione Bella Musica';
  static const String frequenza = 'FM 95.9 Cagliari e in streaming in tutto il mondo';

  /// Indirizzo del pannello impostazioni (WordPress di studio96.it).
  static const String configUrl =
      'https://www.studio96.it/?rest_route=/s96/v1/app-config';

  /// Flusso audio della diretta (StreamingPulse).
  static String streamUrl = 'https://de1.streamingpulse.com/ssl/9073';

  /// Titolo del brano in onda: risponde con {"now": "ARTISTA - TITOLO"}.
  static const String nowPlayingUrl =
      'https://www.studio96.it/?rest_route=/s96/v1/nowplaying';

  /// Copertina del brano in onda (aggiornata dalla regia a ogni brano).
  static const String coverUrl = 'https://www.studio96.it/pictures/OnAir.jpg';

  /// Ogni quanto aggiornare titolo e copertina.
  static const Duration intervalloAggiornamento = Duration(seconds: 20);

  // Colori della radio (gli stessi del sito)
  static Color fucsia = const Color(0xFFC2185B);
  static Color fucsiaChiaro = const Color(0xFFD81B60);
  static Color sfondo1 = const Color(0xFF16162A);
  static Color sfondo2 = const Color(0xFF3B0F45);
  static Color sfondo3 = const Color(0xFFB0003A);

  /// Immagine di sfondo facoltativa (vuota = solo colori).
  static String sfondoImmagine = '';

  /// Avviso in evidenza facoltativo (vuoto = nascosto).
  static String avvisoTesto = '';
  static String avvisoLink = '';

  /// Sezioni del sito (si aprono dentro l'app).
  static List<Collegamento> sezioni = const [
    Collegamento('Notizie', Icons.newspaper_rounded,
        'https://www.studio96.it/home-2/home-2-2/'),
    Collegamento('Podcast', Icons.podcasts_rounded,
        'https://www.studio96.it/home-2/podcast/'),
    Collegamento('Musica', Icons.library_music_rounded,
        'https://www.studio96.it/podcast-3/'),
    Collegamento('96 Sport', Icons.sports_soccer_rounded,
        'https://www.studio96.it/category/96-sport/'),
    Collegamento('Studio96 Informazione', Icons.article_rounded,
        'https://www.studio96informazione.it/'),
    Collegamento('Contatti', Icons.mail_rounded,
        'https://www.studio96.it/contatti/'),
  ];

  /// Social (si aprono nell'app del social, se installata).
  static List<Social> social = const [
    Social.logo('96 RADIO', 'https://www.studio96.it/'),
    Social('Facebook', FontAwesomeIcons.facebook,
        'https://www.facebook.com/STUDIO96RADIO'),
    Social('Instagram', FontAwesomeIcons.instagram,
        'https://www.instagram.com/96_RADIO'),
    Social('X', FontAwesomeIcons.xTwitter, 'https://x.com/RadioNovesei96'),
    Social('WhatsApp', FontAwesomeIcons.whatsapp,
        'https://whatsapp.com/channel/0029VaEtA443GJOzg9epMv0A'),
  ];

  /// Icone che si possono scegliere dal pannello per le voci del menu.
  static const Map<String, IconData> iconeMenu = {
    'notizie': Icons.newspaper_rounded,
    'articolo': Icons.article_rounded,
    'podcast': Icons.podcasts_rounded,
    'musica': Icons.library_music_rounded,
    'radio': Icons.radio_rounded,
    'sport': Icons.sports_soccer_rounded,
    'eventi': Icons.event_rounded,
    'classifica': Icons.leaderboard_rounded,
    'video': Icons.ondemand_video_rounded,
    'foto': Icons.photo_library_rounded,
    'stella': Icons.star_rounded,
    'info': Icons.info_rounded,
    'contatti': Icons.mail_rounded,
    'link': Icons.link_rounded,
  };

  /// Social che si possono attivare dal pannello ('sito' = logo 96).
  static const Map<String, String> nomiSocial = {
    'sito': '96 RADIO',
    'facebook': 'Facebook',
    'instagram': 'Instagram',
    'x': 'X',
    'whatsapp': 'WhatsApp',
    'tiktok': 'TikTok',
    'youtube': 'YouTube',
    'telegram': 'Telegram',
    'spotify': 'Spotify',
  };

  static const Map<String, FaIconData> iconeSocial = {
    'facebook': FontAwesomeIcons.facebook,
    'instagram': FontAwesomeIcons.instagram,
    'x': FontAwesomeIcons.xTwitter,
    'whatsapp': FontAwesomeIcons.whatsapp,
    'tiktok': FontAwesomeIcons.tiktok,
    'youtube': FontAwesomeIcons.youtube,
    'telegram': FontAwesomeIcons.telegram,
    'spotify': FontAwesomeIcons.spotify,
  };
}

class Collegamento {
  final String titolo;
  final IconData icona;
  final String url;
  const Collegamento(this.titolo, this.icona, this.url);
}

/// Pulsante social con il logo ufficiale (Font Awesome).
/// Se [icona] è nulla, il pulsante mostra il logo 96 della radio.
class Social {
  final String titolo;
  final FaIconData? icona;
  final String url;
  const Social(this.titolo, FaIconData this.icona, this.url);
  const Social.logo(this.titolo, this.url) : icona = null;
}
