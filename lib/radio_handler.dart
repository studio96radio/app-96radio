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

  RadioHandler() {
    mediaItem.add(_creaMediaItem('', null));
    _player.playbackEventStream.listen(
      (_) => _aggiornaStato(),
      onError: (Object e, StackTrace st) => _gestisciErrore(),
    );
    _player.playingStream.listen((_) => _aggiornaStato());
    aggiornaInfo();
    _timer = Timer.periodic(Radio96.intervalloAggiornamento, (_) => aggiornaInfo());
  }

  bool get staSuonando => _player.playing;

  @override
  Future<void> play() async {
    erroreConnessione = false;
    try {
      if (_player.processingState == ProcessingState.idle) {
        // Ogni volta riparte dalla diretta "fresca", senza ritardi accumulati.
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(Radio96.streamUrl)),
          preload: true,
        );
      }
      // Non si attende: per just_audio il Future di play() termina solo alla pausa.
      unawaited(_player.play());
      unawaited(aggiornaInfo());
    } catch (_) {
      _gestisciErrore();
    }
  }

  /// Per una diretta "pausa" significa fermare lo stream:
  /// alla ripresa si riascolta la diretta in tempo reale.
  @override
  Future<void> pause() => _player.stop();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Android: quando l'app viene chiusa dalle app recenti (scorrendola via),
  /// la diretta si ferma e la notifica sparisce. Senza questo, su alcuni
  /// telefoni (es. Realme) la musica continuava a suonare.
  @override
  Future<void> onTaskRemoved() => stop();

  Future<void> alterna() => _player.playing ? pause() : play();

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
