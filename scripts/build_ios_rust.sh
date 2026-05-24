#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE="$ROOT/rust/sonarpad_tts"
OUT="$ROOT/ios/Rust"
mkdir -p "$OUT"

rustup target add aarch64-apple-ios aarch64-apple-ios-sim

cd "$CRATE"
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim

DEVICE_LIB="$CRATE/target/aarch64-apple-ios/release/libsonarpad_tts.a"
SIM_LIB="$CRATE/target/aarch64-apple-ios-sim/release/libsonarpad_tts.a"

HEADERS_DIR="$OUT/include"
mkdir -p "$HEADERS_DIR"

cat > "$HEADERS_DIR/module.modulemap" <<'MM'
module SonarpadTts {
  header "sonarpad_tts.h"
  export *
}
MM

cat > "$HEADERS_DIR/sonarpad_tts.h" <<'HH'
char *sonarpad_edge_tts_to_file(const char *text, const char *voice, const char *output_path);
void sonarpad_string_free(char *value);
HH

rm -rf "$OUT/SonarpadTts.xcframework"

xcodebuild -create-xcframework \
  -library "$DEVICE_LIB" -headers "$HEADERS_DIR" \
  -library "$SIM_LIB" -headers "$HEADERS_DIR" \
  -output "$OUT/SonarpadTts.xcframework"

echo "Creato: $OUT/SonarpadTts.xcframework"
echo "Aggiungi l'xcframework al progetto iOS Runner in Xcode."
