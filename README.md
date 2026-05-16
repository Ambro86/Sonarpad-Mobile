# Sonarpad Mobile Starter

Starter Flutter accessibile per Sonarpad Mobile: notizie Google News RSS, podcast RSS con ricerca, importazione Wikipedia ed Edge TTS via Rust FFI.

## Prova su Windows

```powershell
cd C:\src\sonarpad_mobile_starter
flutter create . --platforms=windows
flutter pub get
flutter run -d windows
```

## Podcast

La schermata Podcast ora permette due cose:

1. cercare podcast per nome usando i risultati pubblici di Apple/iTunes Search;
2. aggiungere manualmente un URL RSS, se già lo conosci.

Toccando un risultato della ricerca, l'app salva l'iscrizione e carica gli episodi dal feed RSS.

## Edge TTS Rust su Windows

Se premi "Leggi con Edge TTS" e non senti nulla, controlla prima lo stato mostrato nella schermata articolo. La versione aggiornata mostra:

- se la DLL Rust non è stata caricata;
- quale percorso DLL ha provato;
- dove è stato creato il file MP3;
- quanti byte pesa il file audio.

Compila la DLL Rust:

```powershell
cd C:\src\sonarpad_mobile_starter\rust\sonarpad_tts
cargo build --release
```

Poi copia la DLL nella cartella dove Flutter esegue l'app Windows:

```powershell
copy .\target\release\sonarpad_tts.dll C:\src\sonarpad_mobile_starter\build\windows\x64\runner\Debug\
```

Poi riavvia:

```powershell
cd C:\src\sonarpad_mobile_starter
flutter run -d windows
```

Se usi una build release di Flutter, la DLL va copiata in:

```text
build\windows\x64\runner\Release\
```

## iOS

Da Windows puoi sviluppare e testare la logica Flutter, ma non puoi compilare la versione iOS finale. Per iOS serve macOS con Xcode.
