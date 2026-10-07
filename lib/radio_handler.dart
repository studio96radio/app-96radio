import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Gestisce la diretta: play/pausa, audio a schermo spento,
/// titolo e copertina sulla schermata di blocco.
class RadioHandler extends BaseAudioHandler {
  // ---- Diario di diagnostica (tenere premuto il pulsante Play) ----
  static final ValueNotifier<List<String>> diario = ValueNotifier<List<String>>([]);
  static const String _chiaveDiario = 'diario_diagnostica';

  static void annota(String testo) {
    final o = DateTime.now();
    String d(int n) => n.toString().padLeft(2, '0');
    final riga = '${d(o.hour)}:${d(o.minute)}:${d(o.second)} $testo';
    final nuovo = [...diario.value, riga];
    diario.value = nuovo.length > 120 ? nuovo.sublist(nuovo.length - 120) : nuovo;
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setStringList(_chiaveDiario, diario.value))
        .catchError((_) => false));
  }

  /// Carica il diario della volta precedente (utile se l'app è stata chiusa
  /// dal telefono) e segna l'inizio di una nuova apertura.
  static Future<void> caricaDiario() async {
    try {
      final p = await SharedPreferences.getInstance();
      diario.value = p.getStringList(_chiaveDiario) ?? [];
    } catch (_) {}
    annota('===== APERTURA APP =====');
  }

  static Future<void> svuotaDiario() async {
    diario.value = [];
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_chiaveDiario);
    } catch (_) {}
  }

  ProcessingState? _ultimoStatoAnnotato;
  bool? _ultimoPlayingAnnotato;
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  String _ultimoTitolo = '';

  /// true se l'ultima connessione allo stream è fallita.
  bool erroreConnessione = false;

  /// true quando l'ascoltatore vuole sentire la radio (ha premuto Play e non
  /// ha messo in pausa). Serve per riconnettersi da soli se la diretta cade.
  bool _vuoleSuonare = false;
  bool _riconnessioneInCorso = false;
  bool _attesaInCorso = false;
  int _tentativi = 0;
  /// Circa 10 minuti di tentativi prima di arrendersi (stream giù a lungo).
  static const int _maxTentativi = 120;

  /// Controllo periodico: se la diretta resta muta (dati che non arrivano,
  /// rete messa a riposo dal telefono) la si ricollega da soli.
  Timer? _sorveglianza;
  DateTime? _mutaDa;

  /// Android: tiene svegli telefono (processore) e Wi-Fi mentre la radio suona
  /// a schermo spento. Senza, alcuni telefoni (es. Oppo) "congelano" l'app e
  /// la diretta resta muta per minuti, o si ferma del tutto.
  static const MethodChannel _rete = MethodChannel('it.radio.studio96/rete');

  RadioHandler() {
    mediaItem.add(_creaMediaItem('', null));
    _player.playbackEventStream.listen(
      (_) => _aggiornaStato(),
      onError: (Object e, StackTrace st) {
        annota('ERRORE lettore: $e');
        _gestisciErrore();
      },
    );
    _player.playingStream.listen((_) => _aggiornaStato());
    // Android: quando il server chiude la connessione la diretta risulta
    // "finita" (completed). Per una radio non deve succedere: si riconnette.
    _player.processingStateStream.listen((stato) {
      if (stato != _ultimoStatoAnnotato) {
        _ultimoStatoAnnotato = stato;
        annota('stato lettore: ${stato.name}');
      }
      if (stato == ProcessingState.completed && _vuoleSuonare) _gestisciErrore();
      if (stato == ProcessingState.ready && _vuoleSuonare) {
        // Diretta ripartita: si torna allo stato normale.
        _tentativi = 0;
        _riconnessioneInCorso = false;
        _aggiornaStato();
      }
    });
    aggiornaInfo();
    _timer = Timer.periodic(Radio96.intervalloAggiornamento, (_) => aggiornaInfo());
    _sorveglianza = Timer.periodic(const Duration(seconds: 5), (_) => _controlla());
  }

  void _controlla() {
    if (_player.playing != _ultimoPlayingAnnotato) {
      _ultimoPlayingAnnotato = _player.playing;
      annota('suona: ${_player.playing}');
    }
    if (!_vuoleSuonare || _attesaInCorso) {
      _mutaDa = null;
      return;
    }
    // In attesa di dati (buffering) o fermo: dopo 15 secondi si ricollega.
    final suonaDavvero =
        _player.playing && _player.processingState == ProcessingState.ready;
    if (suonaDavvero) {
      _mutaDa = null;
      return;
    }
    _mutaDa ??= DateTime.now();
    if (DateTime.now().difference(_mutaDa!) > const Duration(seconds: 15)) {
      _mutaDa = null;
      annota('controllo: diretta muta da 15 s, ricollego');
      _gestisciErrore();
    }
  }

  Future<void> _wifi(bool sveglio) async {
    if (!Platform.isAndroid) return;
    try {
      await _rete.invokeMethod(sveglio ? 'tieniSveglia' : 'rilascia');
      annota(sveglio ? 'telefono e wifi tenuti svegli' : 'telefono e wifi rilasciati');
    } catch (e) {
      annota('ERRORE sveglia: $e');
    }
  }

  /// Android: true se il telefono applica il risparmio batteria a 96 RADIO
  /// (e quindi può fermarla a schermo spento).
  static Future<bool> batteriaOttimizzata() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _rete.invokeMethod<bool>('batteriaOttimizzata') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Android: apre la pagina "Info app" di 96 RADIO (da lì: Batteria).
  static Future<void> apriImpostazioniApp() async {
    if (!Platform.isAndroid) return;
    try {
      await _rete.invokeMethod('apriImpostazioni');
    } catch (_) {}
  }

  bool get staSuonando => _vuoleSuonare;

  @override
  Future<void> play() async {
    annota('PLAY');
    erroreConnessione = false;
    _vuoleSuonare = true;
    _tentativi = 0;
    _mutaDa = null;
    unawaited(_wifi(true));
    await _avvia();
    unawaited(aggiornaInfo());
  }

  /// Collega (o ricollega) la diretta "fresca", senza ritardi accumulati.
  Future<void> _avvia() async {
    try {
      if (_player.processingState == ProcessingState.idle ||
          _player.processingState == ProcessingState.completed) {
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(Radio96.streamUrl)),
          preload: true,
        );
      }
      if (!_vuoleSuonare) return;
      // Non si attende: per just_audio il Future di play() termina solo alla pausa.
      unawaited(_player.play());
    } catch (e) {
      annota('ERRORE avvio: $e');
      _gestisciErrore();
    }
  }

  /// La diretta si è interrotta da sola (rete, server): si riprova dopo una
  /// breve attesa, senza che l'ascoltatore debba premere di nuovo Play.
  Future<void> _riconnetti() async {
    if (_attesaInCorso || !_vuoleSuonare) return;
    _attesaInCorso = true;
    _riconnessioneInCorso = true;
    _tentativi++;
    annota('riconnessione n. $_tentativi');
    // Intanto la notifica resta attiva (Android non deve chiudere il servizio
    // audio) e il pulsante mostra il caricamento.
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.pause, MediaControl.stop],
      processingState: AudioProcessingState.buffering,
      playing: true,
    ));
    // Primi tentativi rapidi, poi ogni 5 secondi.
    final attesa = _tentativi <= 2 ? 1 : (_tentativi <= 4 ? 3 : 5);
    await Future.delayed(Duration(seconds: attesa));
    _attesaInCorso = false;
    if (!_vuoleSuonare) return;
    await _player.stop();
    await _avvia();
  }

  /// Per una diretta "pausa" significa fermare lo stream:
  /// alla ripresa si riascolta la diretta in tempo reale.
  @override
  Future<void> pause({String origine = 'notifica o sistema'}) async {
    annota('PAUSA ($origine)');
    _vuoleSuonare = false;
    _riconnessioneInCorso = false;
    unawaited(_wifi(false));
    await _player.stop();
  }

  @override
  Future<void> stop() async {
    annota('STOP');
    _vuoleSuonare = false;
    _riconnessioneInCorso = false;
    unawaited(_wifi(false));
    await _player.stop();
    await super.stop();
  }

  /// Android: quando l'app viene chiusa dalle app recenti (scorrendola via),
  /// la diretta si ferma e la notifica sparisce. Senza questo, su alcuni
  /// telefoni (es. Realme) la musica continuava a suonare.
  @override
  Future<void> onTaskRemoved() {
    annota('app chiusa dalle recenti');
    return stop();
  }

  /// Pulsante Play/Pausa dentro l'app.
  Future<void> alterna() =>
      _vuoleSuonare ? pause(origine: 'pulsante app') : play();

  /// Tasti di cuffie, auricolari Bluetooth, autoradio: si annotano nel diario
  /// per capire da dove arriva una pausa "misteriosa".
  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    annota('tasto cuffie/bluetooth: ${button.name}');
    if (_vuoleSuonare) {
      await pause(origine: 'tasto cuffie/bluetooth');
    } else {
      await play();
    }
  }

  /// Legge dal sito il brano in onda e, se è cambiato, aggiorna titolo e copertina.
  Future<void> aggiornaInfo() async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final risposta = await http
          .get(Uri.parse('${Radio96.nowPlayingUrl}&t=$t'))
          .timeout(const Duration(seconds: 8));
      if (risposta.statusCode != 200) return;
      final dati = jsonDecode(utf8.decode(risposta.bodyBytes));
      final adesso =
          (dati is Map && dati['now'] != null) ? dati['now'].toString().trim() : '';
      if (adesso.isEmpty || adesso == _ultimoTitolo) return;
      _ultimoTitolo = adesso;
      mediaItem.add(_creaMediaItem(adesso, Uri.parse('${Radio96.coverUrl}?t=$t')));
    } catch (_) {
      // Rete assente o sito lento: si riprova al prossimo giro.
    }
  }

  MediaItem _creaMediaItem(String adesso, Uri? copertina) {
    var artista = Radio96.nome;
    var titolo = adesso.isEmpty ? Radio96.claim : adesso;
    final separatore = adesso.indexOf(' - ');
    if (separatore > 0) {
      artista = adesso.substring(0, separatore).trim();
      titolo = adesso.substring(separatore + 3).trim();
    }
    return MediaItem(
      id: Radio96.streamUrl,
      title: titolo,
      artist: artista,
      album: '${Radio96.nome} · ${Radio96.claim}',
      artUri: copertina,
    );
  }

  void _aggiornaStato() {
    // Durante la riconnessione lo stato lo decide _riconnetti().
    if (_riconnessioneInCorso) return;
    const stati = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    };
    final suona = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      // Play/pausa + "stop" per chiudere la radio direttamente dalla notifica
      controls: [suona ? MediaControl.pause : MediaControl.play, MediaControl.stop],
      androidCompactActionIndices: const [0, 1],
      systemActions: const {},
      processingState: stati[_player.processingState]!,
      playing: suona,
    ));
  }

  void _gestisciErrore() {
    if (_vuoleSuonare && _tentativi < _maxTentativi) {
      _riconnetti();
      return;
    }
    annota('ERRORE: tentativi esauriti, mi fermo');
    _vuoleSuonare = false;
    _riconnessioneInCorso = false;
    unawaited(_wifi(false));
    erroreConnessione = true;
    _player.stop();
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.play],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  Future<void> chiudi() async {
    _timer?.cancel();
    _sorveglianza?.cancel();
    await _wifi(false);
    await _player.dispose();
  }
}
