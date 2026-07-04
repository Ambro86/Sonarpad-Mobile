# Pocket TTS iOS — integrazione Sonarpad

Questa cartella collega Pocket TTS a Sonarpad senza rompere Android e senza obbligare tutti gli utenti a scaricare il modello.

## Idea generale

- `PocketTTS.xcframework` deve essere collegato in fase di build iOS.
- Il modello `kyutai-pocket-ios` resta scaricabile dall'utente dalle impostazioni, quindi non aumenta il peso iniziale dell'app.
- Android non carica nulla e resta sicuro.

## Come abilitarlo nei workflow GitHub

Per attivare il collegamento nativo iOS:

1. Vai su GitHub, repository Sonarpad.
2. Apri `Settings` > `Secrets and variables` > `Actions` > `Variables`.
3. Crea o modifica la variabile:

```text
SONARPAD_ENABLE_POCKET_TTS_IOS=true
```

Con questa variabile attiva, i workflow iOS fanno automaticamente:

1. download da:

```text
https://github.com/UnaMentis/pocket-tts-ios/releases/download/v0.4.1/PocketTTS-v0.4.1.zip
```

2. verifica SHA256;
3. estrazione di `PocketTTS.xcframework`;
4. copia di `pocket_tts_ios.swift`;
5. aggiunta di framework e binding al target `Runner`;
6. target iOS portato a `17.0`, necessario per Pocket TTS iOS.

Se la variabile manca o è diversa da `true`, i workflow preparano solo un bridge stub: la build resta normale e Pocket TTS non appare come disponibile.

## File principali

- `install_pocket_tts_ios.sh`: scarica ed estrae la release Pocket TTS iOS solo se abilitata.
- `patch_ios_project.rb`: patcha `Runner.xcodeproj`, registra i canali Flutter e collega il framework quando presente.
- `SonarpadPocketTtsBridge.swift`: generato nello step di build dentro `ios/Runner`.

## Nota importante su iOS 17

Il progetto `pocket-tts-ios` dichiara iOS 17+ per la release nativa. Quando Pocket TTS è attivato, il workflow imposta quindi `IPHONEOS_DEPLOYMENT_TARGET=17.0`. Se vuoi mantenere supporto iOS 15.5/16 per tutti, lascia Pocket TTS disattivato nella build pubblica o usa una build separata.

## Cosa resta scaricabile dall'utente

Il modello resta gestito da Flutter con `PocketTtsModelService`:

- scarica `PocketTTS-v0.4.1.zip` su richiesta;
- verifica lo SHA256;
- estrae solo `kyutai-pocket-ios`;
- lo salva in Application Support;
- lo esclude dal backup iCloud quando il bridge iOS è presente.

## Log di debug

La parte Flutter salva i log Pocket TTS nel log applicazione già visibile da Impostazioni > Visualizza log.
Durante i test i log includono download, checksum, estrazione modello, disponibilità bridge, lingua/voce scelte, sintesi dei chunk e dettagli sugli errori.
Il bridge Swift stampa anche diagnostica nativa con `NSLog`, utile nei log di Xcode/TestFlight, ma i log principali per Ambrogio restano quelli di AppLogger.
