import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'radio_handler.dart';
import 'remote_config.dart';

late final RadioHandler radio;
late final SharedPreferences preferenze;

/// Chiave dell'impostazione "Avvio automatico" (attiva di serie).
const String chiaveAvvioAutomatico = 'avvio_automatico';
bool get avvioAutomatico => preferenze.getBool(chiaveAvvioAutomatico) ?? true;

/// Quanto resta visibile, almeno, la schermata di apertura con il logo.
const Duration durataSplash = Duration(seconds: 1);

Future<void> main() async {
  final cronometro = Stopwatch()..start();
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Tiene il logo a schermo finché non si decide di toglierlo.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  preferenze = await SharedPreferences.getInstance();
  // Impostazioni del pannello "App 96 RADIO": prima le ultime salvate...
  ConfigRemota.caricaSalvate(preferenze);
  // ...poi quelle aggiornate dal sito (senza bloccare l'apertura).
  final configAggiornata = ConfigRemota.aggiorna(preferenze);
  final sessione = await AudioSession.instance;
  await sessione.configure(const AudioSessionConfiguration.music());
  radio = await AudioService.init(
    builder: () => RadioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'it.radio.studio96.audio',
      androidNotificationChannelName: '96 RADIO',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const App96());
  // Aspetta al massimo 2 secondi le impostazioni nuove (es. streaming cambiato).
  await configAggiornata.timeout(const Duration(seconds: 2), onTimeout: () {});
  // All'apertura la diretta parte da sola, se l'utente non l'ha disattivato.
  if (avvioAutomatico) radio.play();
  // Il logo resta almeno un secondo, poi compare l'app.
  final resta = durataSplash - cronometro.elapsed;
  if (resta > Duration.zero) await Future<void>.delayed(resta);
  FlutterNativeSplash.remove();
}

class App96 extends StatelessWidget {
  const App96({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ConfigRemota.versione,
      builder: (context, _, __) => _app(),
    );
  }

  Widget _app() {
    return MaterialApp(
      title: Radio96.nome,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Radio96.fucsia,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SchermataDiretta(),
    );
  }
}

class SchermataDiretta extends StatefulWidget {
  const SchermataDiretta({super.key});

  @override
  State<SchermataDiretta> createState() => _SchermataDirettaState();
}

class _SchermataDirettaState extends State<SchermataDiretta>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tornando nell'app, aggiorna subito titolo e copertina.
    if (state == AppLifecycleState.resumed) {
      radio.aggiornaInfo();
      ConfigRemota.aggiorna(preferenze);
    }
  }

  Future<void> _apri(String titolo, String url, {bool esterno = false}) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: esterno ? LaunchMode.externalApplication : LaunchMode.inAppBrowserView,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire $titolo')),
      );
    }
  }

  void _mostraMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Radio96.sfondo1,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            for (final s in Radio96.sezioni)
              ListTile(
                leading: Icon(s.icona, color: Radio96.fucsiaChiaro),
                title: Text(s.titolo),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  _apri(s.titolo, s.url);
                },
              ),
            const Divider(indent: 16, endIndent: 16),
            StatefulBuilder(
              builder: (context, aggiorna) => SwitchListTile(
                secondary:
                    Icon(Icons.play_circle_rounded, color: Radio96.fucsiaChiaro),
                title: const Text('Avvio automatico'),
                subtitle: const Text("La diretta parte all'apertura dell'app"),
                value: avvioAutomatico,
                onChanged: (attivo) async {
                  await preferenze.setBool(chiaveAvvioAutomatico, attivo);
                  aggiorna(() {});
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si ridisegna quando arrivano impostazioni nuove dal pannello.
    return ValueListenableBuilder<int>(
      valueListenable: ConfigRemota.versione,
      builder: (context, _, __) => _schermata(context),
    );
  }

  Widget _schermata(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Radio96.sfondo1, Radio96.sfondo2, Radio96.sfondo3],
            stops: const [0, 0.55, 1],
          ),
          // Immagine di sfondo facoltativa, sfumata sopra i colori
          image: Radio96.sfondoImmagine.isEmpty
              ? null
              : DecorationImage(
                  image: NetworkImage(Radio96.sfondoImmagine),
                  fit: BoxFit.cover,
                  opacity: 0.35,
                  onError: (_, __) {},
                ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, vincoli) {
              final latoCopertina = math.max(
                120.0,
                // lascia spazio a titolo, pulsante e social anche sugli schermi piccoli
                math.min(vincoli.maxWidth - 64, vincoli.maxHeight - 440),
              );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _Intestazione(onMenu: _mostraMenu),
                    if (Radio96.avvisoTesto.isNotEmpty)
                      _Avviso(
                        onTap: Radio96.avvisoLink.isEmpty
                            ? null
                            : () => _apri('il link', Radio96.avvisoLink),
                      ),
                    const Spacer(),
                    _Copertina(lato: latoCopertina),
                    const SizedBox(height: 24),
                    const _InfoBrano(),
                    const SizedBox(height: 24),
                    _PulsantePlay(),
                    const SizedBox(height: 14),
                    Text(
                      Radio96.frequenza,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    _Social(onApri: (c) => _apri(c.titolo, c.url, esterno: true)),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Intestazione extends StatelessWidget {
  final VoidCallback onMenu;
  const _Intestazione({required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Stessa larghezza del pulsante menu, così la scritta resta al centro.
        SizedBox(
          width: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset('assets/logo-white.png', width: 40, height: 40),
          ),
        ),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                Radio96.nome,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                Radio96.claim,
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onMenu,
          icon: const Icon(Icons.menu_rounded, size: 30),
          tooltip: 'Menu',
        ),
      ],
    );
  }
}

/// Avviso in evidenza scritto dal pannello "App 96 RADIO".
class _Avviso extends StatelessWidget {
  final VoidCallback? onTap;
  const _Avviso({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, color: Radio96.fucsiaChiaro),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    Radio96.avvisoTesto,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Copertina extends StatelessWidget {
  final double lato;
  const _Copertina({required this.lato});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: radio.mediaItem,
      builder: (context, snap) {
        final copertina = snap.data?.artUri;
        final logo = Container(
          color: Colors.black26,
          padding: EdgeInsets.all(lato * 0.18),
          child: Image.asset('assets/logo-white.png'),
        );
        return Container(
          width: lato,
          height: lato,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 12)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: copertina == null
              ? logo
              : Image.network(
                  copertina.toString(),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => logo,
                ),
        );
      },
    );
  }
}

class _InfoBrano extends StatelessWidget {
  const _InfoBrano();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: radio.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF1744),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'IN DIRETTA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item?.title ?? Radio96.claim,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              item?.artist ?? Radio96.nome,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        );
      },
    );
  }
}

class _PulsantePlay extends StatelessWidget {
  const _PulsantePlay();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: radio.playbackState,
      builder: (context, snap) {
        final stato = snap.data;
        final suona = stato?.playing ?? false;
        final caricamento = suona &&
            (stato?.processingState == AudioProcessingState.loading ||
                stato?.processingState == AudioProcessingState.buffering);
        return Column(
          children: [
            Material(
              color: Radio96.fucsia,
              shape: const CircleBorder(),
              elevation: 8,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: radio.alterna,
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Center(
                    child: caricamento
                        ? const SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            suona ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 52,
                            color: Colors.white,
                            semanticLabel: suona ? 'Metti in pausa' : 'Ascolta la diretta',
                          ),
                  ),
                ),
              ),
            ),
            if (radio.erroreConnessione && !suona)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Connessione non riuscita: controlla internet e riprova',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Social extends StatelessWidget {
  final void Function(Social) onApri;
  const _Social({required this.onApri});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final s in Radio96.social)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: IconButton.filledTonal(
              onPressed: () => onApri(s),
              icon: s.icona == null
                  ? Image.asset('assets/logo-white.png', width: 22, height: 22)
                  : FaIcon(s.icona, size: 20),
              tooltip: s.titolo,
            ),
          ),
      ],
    );
  }
}
