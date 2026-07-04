#!/usr/bin/env bash
set -euo pipefail

# Scarica e prepara PocketTTS.xcframework per la build iOS.
# Si attiva solo se SONARPAD_ENABLE_POCKET_TTS_IOS=true.

ENABLED="${SONARPAD_ENABLE_POCKET_TTS_IOS:-false}"
# macOS usa ancora /bin/bash 3.2 nei runner GitHub: evita ${VAR,,}, che richiede Bash 4+.
ENABLED_NORMALIZED="$(printf '%s' "$ENABLED" | tr '[:upper:]' '[:lower:]')"
case "$ENABLED_NORMALIZED" in
  true|1|yes|y|on)
    ;;
  *)
    echo "Pocket TTS iOS disattivato: salto download e collegamento framework."
    exit 0
    ;;
esac

if [ ! -d "ios/Runner.xcodeproj" ]; then
  echo "Progetto iOS non trovato. Esegui prima flutter create --platforms=ios --project-name sonarpad ."
  exit 1
fi

URL="https://github.com/UnaMentis/pocket-tts-ios/releases/download/v0.4.1/PocketTTS-v0.4.1.zip"
SHA256="f6d6258ed2d09f39bab7524a04a79fcbe44cc50e5278445ace186a90797179f5"
CACHE_DIR="${RUNNER_TEMP:-/tmp}/sonarpad-pocket-tts-ios-v0.4.1"
ZIP_FILE="$CACHE_DIR/PocketTTS-v0.4.1.zip"
EXTRACT_DIR="$CACHE_DIR/extracted"

rm -rf "$CACHE_DIR"
mkdir -p "$CACHE_DIR" "$EXTRACT_DIR"

echo "Scarico Pocket TTS iOS da GitHub..."
curl -L --fail --retry 3 --retry-delay 2 -o "$ZIP_FILE" "$URL"

ACTUAL_SHA="$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')"
if [ "$ACTUAL_SHA" != "$SHA256" ]; then
  echo "Checksum Pocket TTS non valida. Attesa: $SHA256 - ottenuta: $ACTUAL_SHA"
  exit 1
fi

echo "Estraggo Pocket TTS iOS..."
unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"

FRAMEWORK_PATH="$(find "$EXTRACT_DIR" -type d -name 'PocketTTS.xcframework' | head -n 1 || true)"
BINDING_PATH="$(find "$EXTRACT_DIR" -type f -name 'pocket_tts_ios.swift' | head -n 1 || true)"
if [ -z "$FRAMEWORK_PATH" ]; then
  echo "PocketTTS.xcframework non trovato nello ZIP."
  exit 1
fi
if [ -z "$BINDING_PATH" ]; then
  echo "pocket_tts_ios.swift non trovato nello ZIP."
  exit 1
fi

mkdir -p ios/Frameworks ios/Runner
rm -rf ios/Frameworks/PocketTTS.xcframework
rm -f ios/Runner/pocket_tts_ios.swift ios/Runner/PocketTTS*.swift
rsync -a "$FRAMEWORK_PATH/" ios/Frameworks/PocketTTS.xcframework/
cp "$BINDING_PATH" ios/Runner/pocket_tts_ios.swift

echo "PocketTTS.xcframework copiato in ios/Frameworks/PocketTTS.xcframework"
echo "Binding UniFFI copiato in ios/Runner/pocket_tts_ios.swift"
echo "Nota: non copio PocketTTSSwift.swift perché il bridge Sonarpad usa direttamente il binding UniFFI."
echo "Nota: il modello kyutai-pocket-ios NON viene incluso nell'app; resta scaricabile su richiesta dalle impostazioni."
