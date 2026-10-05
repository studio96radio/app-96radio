import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Tutti i dati della radio in un unico posto: per cambiare un link
/// o un colore basta modificare questo file.
class Radio96 {
  static const String nome = '96 RADIO';
  static const String claim = 'Missione Bella Musica';
  static const String frequenza = 'FM 95.9 Cagliari e in streaming in tutto il mondo';

  /// Flusso audio della diretta (StreamingPulse).
  static const String streamUrl = 'https://de1.streamingpulse.com/ssl/9073';

  /// Titolo del brano in onda: risponde con {"now": "ARTISTA - TITOLO"}.
  static const String nowPlayingUrl =
      'https://www.studio96.it/?rest_route=/s96/v1/nowplaying';

  /// Copertina del brano in onda (aggiornata dalla regia a ogni brano).
  static const String coverUrl = 'https://www.studio96.it/pictures/OnAir.jpg';

  /// Ogni quanto aggiornare titolo e copertina.
  static const Duration intervalloAggiornamento = Duration(seconds: 20);

  // Colori della radio (gli stessi del sito)
  static const Color fucsia = Color(0xFFC2185B);
  static const Color fucsiaChiaro = Color(0xFFD81B60);
  static const Color sfondo1 = Color(0xFF16162A);
  static const Color sfondo2 = Color(0xFF3B0F45);
  static const Color sfondo3 = Color(0xFFB0003A);

  /// Sezioni del sito (si aprono dentro l'app).
  static const List<Collegamento> sezioni = [
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
  static const List<Social> social = [
    Social.logo('96 RADIO', 'https://www.studio96.it/'),
    Social('Facebook', FontAwesomeIcons.facebook,
        'https://www.facebook.com/STUDIO96RADIO'),
    Social('Instagram', FontAwesomeIcons.instagram,
        'https://www.instagram.com/96_RADIO'),
    Social('X', FontAwesomeIcons.xTwitter, 'https://x.com/RadioNovesei96'),
    Social('WhatsApp', FontAwesomeIcons.whatsapp,
        'https://whatsapp.com/channel/0029VaEtA443GJOzg9epMv0A'),
  ];
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
