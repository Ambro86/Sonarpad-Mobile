# Preferenze sincronizzate

Inventario esplicito: 41 preferenze mobile, l’attivazione Sonarpad e una preferenza specifica Mac. I valori non supportati da un client restano sul server e vengono recuperati dai client compatibili.

| Identificatore | Mobile | Windows | Mac |
| --- | --- | --- | --- |
| `activation.code` | Sì | Sì | Sì |
| `sonartube.search_type` | Sì | Sì | Sì |
| `sonarmusic.search_type` | Sì | Sì | Sì |
| `cutter.mode` | Sì | Sì | Sì |
| `cutter.seek_ms` | Sì | Sì | Sì |
| `weather.city` | Sì | Sì | Sì |
| `weather.unit` | Sì | Sì | Sì |
| `radio.language` | Sì | Sì | Sì |
| `radio.country` | Sì | Sì | Sì |
| `radio.genre` | Sì | Sì | Conservata nel cloud |
| `podcast.country` | Sì | Sì | Sì |
| `podcast.category` | Sì | Conservata nel cloud | Conservata nel cloud |
| `news.language` | Sì | Sì, 9 lingue | Sì, 7 lingue |
| `news.local_city` | Sì | Sì | Conservata nel cloud |
| `reader.auto_bookmark` | Sì | Sì | Sì |
| `reader.footnotes` | Sì | Conservata nel cloud | Conservata nel cloud |
| `reader.multiple_bookmarks` | Sì | Conservata nel cloud | Conservata nel cloud |
| `reader.slider_percent` | Sì | Conservata nel cloud | Conservata nel cloud |
| `reader.sleep_minutes` | Sì | Sì | Conservata nel cloud |
| `reader.tts_speed` | Sì | Conservata nel cloud | Conservata nel cloud |
| `reader.tts_pitch` | Sì | Conservata nel cloud | Conservata nel cloud |
| `playback.seek_seconds` | Sì | Sì | Conservata nel cloud |
| `playback.speed_control` | Sì | Conservata nel cloud | Conservata nel cloud |
| `playback.media_speed` | Sì | Conservata nel cloud | Conservata nel cloud |
| `playback.podcast_speed` | Sì | Conservata nel cloud | Conservata nel cloud |
| `playback.sonartube_speed` | Sì | Conservata nel cloud | Conservata nel cloud |
| `playback.audiobook_speed` | Sì | Sì | Conservata nel cloud |
| `sonartube.autoplay` | Sì | Conservata nel cloud | Conservata nel cloud |
| `sonartube.channel_sort` | Sì | Conservata nel cloud | Conservata nel cloud |
| `sonartube.player_actions` | Sì | Conservata nel cloud | Conservata nel cloud |
| `video.enabled` | Sì | Conservata nel cloud | Conservata nel cloud |
| `video.portrait` | Sì | Conservata nel cloud | Conservata nel cloud |
| `tv.audio_description` | Sì | Conservata nel cloud | Sì |
| `calendar.hide_saints` | Sì | Conservata nel cloud | Conservata nel cloud |
| `home.grouping` | Sì | Conservata nel cloud | Conservata nel cloud |
| `home.hidden` | Sì | Conservata nel cloud | Conservata nel cloud |
| `home.order` | Sì | Conservata nel cloud | Conservata nel cloud |
| `converter.format` | Sì | Sì | Sì |
| `converter.bitrate` | Sì | Sì | Sì |
| `converter.wav_depth` | Sì | Sì | Sì |
| `converter.ogg_quality` | Sì | Sì | Sì |
| `converter.flac_compression` | Sì | Sì | Sì |
| `mac.playback.seek_seconds` | Conservata nel cloud | Conservata nel cloud | Sì |

## Memorizzazione e applicazione

- Tipo di taglio ricordato su Windows e mobile; Mac lo conservava già. Città meteo ricordata anche su Mac.
- Le impostazioni si applicano alla successiva apertura del modulo; la schermata Impostazioni mobile ricarica i valori al ritorno dal cloud.
- Scelte raccolte/preferenze separate. Una richiesta in sospeso mantiene le categorie iniziali finché non viene completata.
- Primo collegamento: una preferenza già presente nel cloud prevale sui valori iniziali del nuovo dispositivo. Successivamente vengono trasferite le modifiche rispetto alla sincronizzazione precedente.
- Solo valori compatti: fino a 128 preferenze, 2 KB per valore e 32 KB complessivi per la raccolta preferences. Metadati e registri di recupero delle richieste occupano spazio aggiuntivo.
- Esclusi password, altri codici privati, token, percorsi locali, cronologie, cache, file multimediali e sovrascrittura degli originali. Nessuna copia dei contenuti nella raccolta delle preferenze.
- Lo slider Video di SonarTube mobile usa il filtro di ricerca già disponibile; le altre posizioni del selettore restano invariate.

## Aggiornamento PHP

Ricaricare `src/Merge.php` e `public/index.php` nella cartella privata `sonarpad_sync`. Non cambiano configurazione e database. La cartella pubblica `synk` resta valida. Le cartelle pronte per il caricamento contengono già questi aggiornamenti.

Verifica dopo il caricamento: `https://sonarpad.com/synk/index.php?action=health` deve includere `preferences` in `collections` e `preferences_max_bytes: 32768`.

## Verifica desktop del 4 novembre 2026

- Filtri radio lingua/nazione salvati su entrambi i desktop, genere su Windows. Mac non offre il corrispondente filtro di ricerca per genere.
- Salvati gli otto intervalli di spostamento del taglio (1, 5, 10, 30, 60, 120, 300 e 600 secondi). Windows riusa lo stesso percorso di spostamento esistente.
- Conversione: formato, bitrate, profondità WAV, qualità OGG e compressione FLAC ricordati anche chiudendo senza convertire. Riutilizzati i convertitori esistenti, comprese le finestre di conversione cartella. Destinazioni locali escluse dal cloud.
- Mac: scelta Celsius/Fahrenheit con conversione dei soli valori visualizzati; scelta della nazione nella ricerca podcast, usata anche dal catalogo. Entrambe salvate e sincronizzate.
- Collegati i campi già persistenti: timer lettura e intervallo di avanzamento Windows, segnalibri automatici e preferenza audiodescrizione TV Mac.
- Lingua notizie: usati solo i valori già offerti da ciascun desktop. Conservate le fonti personali della lingua precedente; le fonti cloud della nuova lingua vengono applicate nella stessa sincronizzazione. Su Windows le vecchie fonti restano nella loro raccolta linguistica.
- Interfaccia home, orientamento video, slider del lettore, ordine azioni SonarTube, filtro santi e altre opzioni senza controllo desktop equivalente rimangono specifiche mobile. Velocità/tono TTS desktop hanno scale e motori differenti: i salvataggi locali esistenti non vengono sostituiti con numeri incompatibili.
- Prova online superata: health, gruppo isolato, collegamento secondo dispositivo, preferenze, precedenza iniziale cloud, modifica e retry identico. Gruppo di prova eliminato.
- Test Windows: protocollo, conversione preferenze, serializzazione impostazioni e cambio lingua senza perdere fonti. Build/runtime nativi Mac richiedono macOS.

Per queste aggiunte client non occorre ricaricare PHP: il backend pubblicato accetta già la raccolta preferences.

## Sincronizzazione automatica

Non richiede modifiche PHP o un nuovo caricamento. I client riusano sync, la sequenza e il journal esistenti; non creano collegamenti senza una scelta dell’utente.

- Controllo locale ogni 10 secondi; richieste distanziate di almeno 30 secondi per raggruppare le modifiche. Controllo remoto ogni 3 minuti, anche senza modifiche locali.
- Apertura dell’app: controllo dei dispositivi già collegati. Mobile: pausa dei controlli quando l’app non è attiva e ripresa al ritorno in primo piano, rispettando le attese dopo gli errori.
- Rete asincrona/mobile o su thread dedicato/desktop, timeout 30 secondi. Un’unica operazione alla volta, condivisa con la sincronizzazione manuale.
- Errori automatici solo nei log; nessuna finestra, annuncio o spostamento del focus. Retry dopo 30, 60, 120, 240 e poi 300 secondi. Journal conservato e modifiche locali successive riapplicate prima del checkpoint.
- Stato nella schermata cloud: sincronizzazione in corso, modifiche in attesa, attesa con tentativo automatico oppure tutto sincronizzato, con data/ora locale dell’ultimo successo. Se entrambe le categorie sono escluse, sincronizzazione automatica disattivata.

L’attivazione Sonarpad è l’unica eccezione esplicita ai codici privati: viene validata localmente prima di esportarla e applicarla, trasferita via HTTPS e conservata nell’archivio privato compresso del gruppo (la compressione non è cifratura). Non è registrata nei log. Un codice assente o non valido non cancella quello locale; un codice locale già valido è preservato. Il trasferimento segue l’opzione delle preferenze e non modifica lingua o modalità sviluppatore. Non richiede aggiornamenti del backend.
