# 96 RADIO – app ufficiale

*Missione Bella Musica* · FM 95.9 Cagliari · in streaming in tutto il mondo

App Flutter (iPhone, poi Android) della radio:

- play/pausa della diretta (StreamingPulse)
- copertina e titolo del brano in onda, presi da studio96.it ogni 20 secondi
- musica a schermo spento, con copertina e comandi sulla schermata di blocco
- menu verso le sezioni del sito e i social

## Dove cambiare le cose

Link, colori, indirizzo dello stream: tutto in `lib/config.dart`.

## Compilazione

La fa Codemagic con il file `codemagic.yaml`:

- workflow "iPhone -> TestFlight"
- workflow "Android -> AAB" (prepara la parte Android con `scripts/android_setup.py`;
  la chiave di firma si chiama `chiave_android_96radio` su Codemagic)
Bundle ID: `it.radio.studio96` · versione `8.0.0`.
