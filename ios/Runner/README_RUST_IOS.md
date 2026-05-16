# Collegare Rust a Flutter iOS

1. Su macOS installa Rust e i target iOS:

```bash
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
```

2. Esegui:

```bash
./scripts/build_ios_rust.sh
```

3. Apri `ios/Runner.xcworkspace` in Xcode.

4. Trascina `ios/Rust/SonarpadTts.xcframework` dentro il target Runner.

5. In **Build Phases > Link Binary With Libraries**, verifica che `SonarpadTts.xcframework` sia presente.

6. In Flutter, `EdgeTtsBridge` usa `DynamicLibrary.process()` su iOS e cerca le funzioni:

- `sonarpad_edge_tts_to_file`
- `sonarpad_string_free`

Nota: su iOS reale va verificata la connessione WebSocket verso Edge TTS. Edge TTS non è API ufficiale.
