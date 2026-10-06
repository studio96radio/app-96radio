import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Impostazioni lette dal pannello "App 96 RADIO" di studio96.it.
///
/// All'apertura l'app usa subito le ultime impostazioni ricevute (salvate
/// sul telefono), poi chiede al sito quelle nuove. Se il sito non risponde
/// restano le ultime buone, o i valori di partenza di config.dart.
class ConfigRemota {
  static const String _chiave = 'config_remota';

  /// Cambia ogni volta che arrivano impostazioni nuove: la schermata si ridisegna.
  static final ValueNotifier<int> versione = ValueNotifier<int>(0);

  /// Applica le impostazioni salvate sul telefono (nessuna attesa di rete).
  static void caricaSalvate(SharedPreferences preferenze) {
    final testo = preferenze.getString(_chiave);
    if (testo == null) return;
    try {
      _applica(jsonDecode(testo));
    } catch (_) {
      // Dati salvati rovinati: si usano i valori di partenza.
    }
  }

  /// Chiede al sito le impostazioni aggiornate e, se valide, le applica e le salva.
  static Future<void> aggiorna(SharedPreferences preferenze) async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final risposta = await http
          .get(Uri.parse('${Radio96.configUrl}&t=$t'))
          .timeout(const Duration(seconds: 8));
      if (risposta.statusCode != 200) return;
      final testo = utf8.decode(risposta.bodyBytes);
      if (_applica(jsonDecode(testo))) {
        await preferenze.setString(_chiave, testo);
        versione.value++;
      }
    } catch (_) {
      // Rete assente o sito lento: restano le impostazioni attuali.
    }
  }

  /// Restituisce true se i dati erano validi e sono stati applicati.
  static bool _applica(Object? dati) {
    if (dati is! Map) return false;

    final stream = dati['stream'];
    if (stream is String && stream.startsWith('https://')) {
      Radio96.streamUrl = stream.trim();
    }

    final colori = dati['colori'];
    if (colori is Map) {
      Radio96.sfondo1 = _colore(colori['sfondo1']) ?? Radio96.sfondo1;
      Radio96.sfondo2 = _colore(colori['sfondo2']) ?? Radio96.sfondo2;
      Radio96.sfondo3 = _colore(colori['sfondo3']) ?? Radio96.sfondo3;
      final accento = _colore(colori['accento']);
      if (accento != null) {
        Radio96.fucsia = accento;
        Radio96.fucsiaChiaro = Color.lerp(accento, Colors.white, 0.12)!;
      }
    }

    final sfondo = dati['sfondo_immagine'];
    Radio96.sfondoImmagine =
        (sfondo is String && sfondo.startsWith('https://')) ? sfondo.trim() : '';

    final avviso = dati['avviso'];
    if (avviso is Map) {
      final testo = avviso['testo'];
      final link = avviso['link'];
      Radio96.avvisoTesto = testo is String ? testo.trim() : '';
      Radio96.avvisoLink =
          (link is String && link.startsWith('http')) ? link.trim() : '';
    }

    final menu = dati['menu'];
    if (menu is List) {
      final voci = <Collegamento>[];
      for (final v in menu) {
        if (v is! Map) continue;
        final titolo = v['titolo'];
        final url = v['url'];
        if (titolo is! String || url is! String) continue;
        if (titolo.trim().isEmpty || !url.startsWith('http')) continue;
        final icona = Radio96.iconeMenu[v['icona']] ?? Icons.link_rounded;
        voci.add(Collegamento(titolo.trim(), icona, url.trim()));
      }
      if (voci.isNotEmpty) Radio96.sezioni = voci;
    }

    final social = dati['social'];
    if (social is List) {
      final pulsanti = <Social>[];
      for (final s in social) {
        if (s is! Map) continue;
        final nome = s['nome'];
        final url = s['url'];
        if (nome is! String || url is! String || !url.startsWith('http')) continue;
        if (nome == 'sito') {
          pulsanti.add(Social.logo(Radio96.nome, url.trim()));
          continue;
        }
        final icona = Radio96.iconeSocial[nome];
        if (icona == null) continue;
        pulsanti.add(Social(Radio96.nomiSocial[nome] ?? nome, icona, url.trim()));
      }
      Radio96.social = pulsanti;
    }
    return true;
  }

  /// Converte "#RRGGBB" in un colore.
  static Color? _colore(Object? valore) {
    if (valore is! String) return null;
    final esadecimale = valore.trim().replaceFirst('#', '');
    if (esadecimale.length != 6) return null;
    final numero = int.tryParse(esadecimale, radix: 16);
    return numero == null ? null : Color(0xFF000000 | numero);
  }
}
