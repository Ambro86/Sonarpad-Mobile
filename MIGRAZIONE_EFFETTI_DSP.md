# Migrazione degli effetti sperimentali al DSP nativo

Questa versione non copia la vecchia schermata sperimentale sopra il Media
Cutter attivo. Conserva invece l'interfaccia e la pipeline di esportazione
production-ready e aggiunge un motore C++ condiviso da iOS e Android.

FFmpeg continua a occuparsi di:

- decodifica dei file sorgenti;
- taglio e ricomposizione delle tracce;
- codifica AAC e remux del video;
- verifiche finali di durata, tracce e decodificabilità.

Il pacchetto `packages/sonarpad_audio_dsp` elabora PCM float32 e realizza gli
effetti che richiedono un vero DSP: vocoder a banca di filtri, coro multivoce,
pitch shifting, modulazione, filtri, saturazione, rumori, portanti e ambienti ibridi basati su DSP e asset audio originali. Anteprima ed esportazione usano esattamente lo stesso motore.

## Catalogo percettivo

I 55 nomi dell'archivio sperimentale sono stati ricondotti a effetti che
abbiano una personalità sonora riconoscibile. Le varianti quasi identiche non
sono mostrate come voci separate: l'intensità dello stesso effetto ne controlla
la forza.

| Vecchi effetti sperimentali | Effetto mantenuto |
|---|---|
| Helium, Slow Helium, Higher | Intonazione alta |
| Fast Helium, Faster, Fastest | Scoiattolo |
| Bright Voice Alt | Voce brillante |
| Turtle, Slower, Slowest, Snail | Tartaruga |
| Lower | Intonazione bassa |
| Deep Voice | Voce scura |
| Echo | Eco |
| Backwards | Al contrario |
| Haunting, Scary Place | Infestato |
| Robot | Robot |
| Robot 2 | Super robot |
| Choir | Coro nativo |
| Guitar | Chitarra parlante con vocoder |
| Mosquito | Zanzara |
| One Of Many | Una voce in molte |
| Organ | Organo parlante con vocoder |
| Warped | Deformato |
| Fan, Helicopter | Elicottero |
| Swirling | Vortice stereo |
| Bathroom | Bagno |
| Canyon | Cattedrale / grande canyon |
| Fuzz | Distorsione |
| Old Telephone | Telefono |
| Underwater | Sott'acqua |
| Gramophone | Vecchia radio |
| Vader | Voce oscura cinematografica |
| Metallic | Metallico |
| Megaphone | Megafono |
| Songbird | Uccellino |
| Alien, Alien 2 | Alieno |
| Exterminator | Exterminator |
| Rain And Thunder | Pioggia e tuoni |
| Jungle | Giungla |
| Crowd | Folla |
| Slot Machines | Slot machine |
| Traffic | Traffico |
| Spaceship | Astronave |
| Cricket | Grillo |
| Siren | Sirena |
| Sleigh Bells | Campanelli |
| DJ | DJ e scratch |
| Applause | Applausi |
| Bad Melody | Melodia stonata |
| Bad Harmony | Armonia dissonante |
| Warm Voice | Voce calda |

## Effetti rifatti

- **Coro:** più copie ritardate e modulate, non il solo filtro `chorus` di
  FFmpeg; un fondale di vocali senza parole aggiunge profondità senza coprire
  la voce.
- **Chitarra parlante e organo parlante:** vocoder a banca di filtri; la voce
  pilota una portante audio dedicata invece di essere semplicemente mescolata
  con un file musicale.
- **Robot e Super robot:** vocoder, portanti armoniche, ring modulation e
  diffusione stereo.
- **Vecchia radio:** banda vocale, saturazione, wow/flutter e DSP, arricchiti
  da un fondale originale di fruscio e crepitii.
- **Una voce in molte:** più copie con intonazione, ritardo e panorama diversi.

## Compatibilità e sicurezza

- stesso C++ su Android e iPhone tramite Dart Native Assets;
- nessun download o modello a runtime;
- elaborazione offline e durata PCM invariata;
- file intermedi eliminati al termine;
- il risultato finale resta sottoposto ai controlli production-ready già
  presenti nel Media Cutter.


## Asset audio ibridi

Coro, chitarra, organo, vecchia radio e gli ambienti realistici possono usare
gli MP3 in `assets/audio/effect_sources/`. Gli asset vengono convertiti in PCM
una sola volta e messi in loop con crossfade; il loro volume viene abbassato
automaticamente quando la voce è presente. Il fallback procedurale resta
sempre disponibile.
