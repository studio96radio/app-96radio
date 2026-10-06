import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import 'config.dart';

/// Gestisce la diretta: play/pausa, audio a schermo spento,
/// titolo e copertina sulla schermata di blocco.
class RadioHandler extends BaseAudioHandler {
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
  static const int _maxTentativi = 8;

  RadioHandler() {
    mediaItem.add(_creaMediaItem('', null));
    _player.playbackEventStream.listen(
      (_) => _aggiornaStato(),
      onError: (Object e, StackTrace st) => _gestisciErrore(),
    );
    _player.playingStream.listen((_) => _aggiornaStato());
    // Android: quando il server chiude la connessione la diretta risulta
    // "finita" (completed). Per una radio non deve succedere: si riconnette.
    _player.processingStateStream.listen((stato) {
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
  }

  bool get staSuonando => _vuoleSuonare;

  @override
  Future<void> play() async {
    erroreConnessione = false;
    _vuoleSuonare = true;
    _tentativi = 0;
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
    } catch (_) {
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
    // Intanto la notifica resta attiva (Android non deve chiudere il servizio
    // audio) e il pulsante mostra il caricamento.
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.pause, MediaControl.stop],
      processingState: AudioProcessingState.buffering,
      playing: true,
    ));
    await Future.delayed(Duration(seconds: _tentativi < 3 ? 1 : 5));
    _attesaInCorso = false;
    if (!_vuoleSuonare) return;
    await _player.stop();
    await _avvia();
  }

  /// Per una diretta "pausa" significa fermare lo stream:
  /// alla ripresa si riascolta la diretta in tempo reale.
  @override
  Future<void> pause() async {
    _vuoleSuonare = false;
    _riconnessioneInCorso = false;
    await _player.stop();
  }

  @override
  Future<void> stop() async {
    _vuoleSuonare = false;
    _riconnessioneInCorso = false;
    await _player.stop();
    await super.stop();
  }

  /// Android: quando l'app viene chiusa dalle app recenti (scorrendola via),
  /// la diretta si ferma e la notifica sparisce. Senza questo, su alcuni
  /// telefoni (es. Realme) la musica continuava a suonare.
  @override
  Future<void> onTaskRemoved() => stop();

  Future<void> alterna() => _vuoleSuonare ? pause() : play();

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
    _vuoleSuonare = false;
    _riconnessioneInCorso = false;
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
    await _player.dispose();
  }
}
