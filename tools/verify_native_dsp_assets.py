from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / 'assets' / 'audio' / 'effect_sources'
ASSETS = [
    'choir_bed.mp3', 'guitar_carrier.mp3', 'organ_carrier.mp3',
    'old_radio_static.mp3', 'rain_thunder.mp3', 'jungle_ambience.mp3',
    'crowd_ambience.mp3', 'slot_machines.mp3', 'traffic_ambience.mp3',
    'crickets.mp3', 'sleigh_bells.mp3', 'applause.mp3',
]
errors = []
for name in ASSETS:
    path = ASSET_DIR / name
    if not path.is_file() or path.stat().st_size < 10_000:
        errors.append(f'asset mancante o troppo piccolo: {path}')
        continue
    head = path.read_bytes()[:3]
    if head != b'ID3' and not (len(head) >= 2 and head[0] == 0xFF and head[1] & 0xE0 == 0xE0):
        errors.append(f'asset non riconosciuto come MP3: {path}')

pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
if 'assets/audio/effect_sources/' not in pubspec:
    errors.append('pubspec.yaml non include assets/audio/effect_sources/')

screen = (ROOT / 'lib/screens/media_cutter_screen.dart').read_text(encoding='utf-8')
for name in ASSETS:
    if name not in screen:
        errors.append(f'mapping Dart mancante: {name}')
for token in ('_ensureNativeDspAssetPcmPath', 'assetPath: assetPath', 'fallback=procedural'):
    if token not in screen:
        errors.append(f'contratto Media Cutter mancante: {token}')

ffi = (ROOT / 'packages/sonarpad_audio_dsp/lib/sonarpad_audio_dsp.dart').read_text(encoding='utf-8')
if 'String? assetPath' not in ffi or 'Pointer<Utf8> assetPath' not in ffi:
    errors.append('wrapper FFI privo del percorso asset opzionale')

cpp = (ROOT / 'packages/sonarpad_audio_dsp/src/sonarpad_audio_dsp.cpp').read_text(encoding='utf-8')
for token in ('class AssetLoop', 'chorusWithAsset', 'ambienceAsset', 'const char* asset_path'):
    if token not in cpp:
        errors.append(f'contratto C++ mancante: {token}')

if errors:
    print('\n'.join(f'ERRORE: {e}' for e in errors), file=sys.stderr)
    raise SystemExit(1)
print(f'OK: {len(ASSETS)} asset DSP e integrazione FFI verificati.')
