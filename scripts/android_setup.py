#!/usr/bin/env python3
"""Prepara la parte Android dell'app 96 RADIO dopo `flutter create`.

Lo lancia Codemagic (workflow "Android -> AAB"). Fa quattro cose:
1. nome dell'app, permessi e servizio audio nel manifest
2. MainActivity compatibile con la musica in background (audio_service)
3. firma dell'app con la chiave caricata su Codemagic
4. nome del pacchetto preso dalla variabile PACCHETTO_ANDROID

Uso: python3 scripts/android_setup.py   (dalla cartella del progetto)
"""
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "android" / "app"
NAMESPACE = "it.radio.studio96"  # resta fisso: e' il "nome interno" del codice
PACCHETTO = os.environ.get("PACCHETTO_ANDROID", NAMESPACE)


def fail(msg):
    sys.exit(f"ERRORE android_setup: {msg}")


# 1. Manifest -----------------------------------------------------------------
manifest = APP / "src" / "main" / "AndroidManifest.xml"
m = manifest.read_text()

PERMESSI = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
"""

SERVIZIO_AUDIO = """        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
"""

# Link esterni (sito, social): Android 11+ vuole sapere quali app si aprono
QUERIES = """        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
"""

if "FOREGROUND_SERVICE_MEDIA_PLAYBACK" not in m:
    m = re.sub(r"(<manifest[^>]*>\n)", r"\1" + PERMESSI.replace("\\", "\\\\"), m, count=1)
m = re.sub(r'android:label="[^"]*"', 'android:label="96 RADIO"', m, count=1)
if "audioservice.AudioService" not in m:
    if "</application>" not in m:
        fail("</application> non trovato nel manifest")
    m = m.replace("</application>", SERVIZIO_AUDIO + "    </application>", 1)
if 'android:scheme="https"' not in m:
    if "<queries>" in m:
        m = m.replace("<queries>\n", "<queries>\n" + QUERIES, 1)
    else:
        m = m.replace("</manifest>", "    <queries>\n" + QUERIES + "    </queries>\n</manifest>", 1)
manifest.write_text(m)

# 2. MainActivity --------------------------------------------------------------
attivita = list((APP / "src" / "main").rglob("MainActivity.kt"))
if not attivita:
    fail("MainActivity.kt non trovata")
for f in attivita:
    t = f.read_text()
    t = t.replace("import io.flutter.embedding.android.FlutterActivity",
                  "import com.ryanheise.audioservice.AudioServiceActivity")
    t = re.sub(r"class MainActivity\s*:\s*FlutterActivity\(\)",
               "class MainActivity : AudioServiceActivity()", t)
    if "AudioServiceActivity()" not in t:
        fail(f"non riesco a modificare {f}")
    f.write_text(t)

# 3 e 4. Firma e nome del pacchetto ---------------------------------------------
gradle = APP / "build.gradle.kts"
g = gradle.read_text()

g = re.sub(r'applicationId = "[^"]*"', f'applicationId = "{PACCHETTO}"', g, count=1)

FIRMA = """    signingConfigs {
        create("release") {
            // Chiave caricata su Codemagic (Code signing identities > Android keystores)
            val ks = System.getenv("CM_KEYSTORE_PATH")
            if (ks != null) {
                storeFile = file(ks)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {"""

if 'create("release")' not in g:
    if "    buildTypes {" not in g:
        fail("blocco buildTypes non trovato in build.gradle.kts")
    g = g.replace("    buildTypes {", FIRMA, 1)
g = g.replace('signingConfig = signingConfigs.getByName("debug")',
              'signingConfig = signingConfigs.getByName("release")')
if 'getByName("release")' not in g:
    fail("firma release non impostata")
gradle.write_text(g)

print(f"Android pronto: pacchetto {PACCHETTO}, firma release, servizio audio.")
