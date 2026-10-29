# Sonarpad Mobile — audit fallback audiodescrizione Windows → iOS/Android

Data: 25 settembre 2026

Sorgente di riferimento Windows: `rustnotepad_source(2).zip` fornito da Ambrogio Riili.

Obiettivo: non semplificare i recuperi maturati sul modulo Windows. Ogni fallback applicabile al runtime mobile deve essere presente nella pipeline reale e deve avere almeno un test dedicato. I test puri sono concentrati in `test/audio_description_fallbacks_test.dart`; i test di cablaggio/regressione della pipeline reale sono in `test/audio_description_pipeline_contract_test.dart`.

## Configurazione Pyannote di produzione

La pipeline mobile conserva la configurazione verificata in parità con Windows:

- finestra 10 s;
- step 1 s;
- batch 32;
- CPU, 4 thread;
- graph optimization `ALL`;
- padding 0,25 s.

Non vengono portate in produzione le varianti step 2/2,5: il benchmark multi-spezzone ha dimostrato che possono perdere parlato reale. CoreML e XNNPACK non sostituiscono la CPU perché nei benchmark effettuati erano più lenti.

## Matrice dei fallback applicabili

| Area | Fallback Windows | Mobile | Test mobile |
| --- | --- | --- | --- |
| HTTP | retry indefinito su 5xx/429 temporanei, timeout e rete | Portato, cancel-aware, delay fisso | `HTTP and transport classification`; contract retry |
| HTTP | `INVALID_ARGUMENT` permanente non nascosto da errori transienti | Portato | `400 INVALID_ARGUMENT is never hidden...` |
| Credito | `prepayment credits are depleted` interrompe senza model switch | Portato | test prepayment + contract |
| Quota | switch modello e ripetizione della stessa richiesta | Portato | contract quota/model switch |
| Quota | rifiuto stesso modello anche con prefisso `models/` | Portato tramite normalizzazione ID | test normalizzazione modello + contract |
| Overload | 503 high-demand: prompt al terzo errore, una sola volta, poi retry | Portato | test soglia + contract UI |
| Modelli | migrazione `gemini-3.1-pro` → `gemini-3.1-pro-preview` | Portato | test dedicato |
| Modelli | verifica `supportedGenerationMethods=generateContent`, retry transienti | Portato | test metadata + contract `_validateGeminiModel` |
| Modelli | lista modelli filtra modelli non generativi/embedding | Portato | contract/model helper |
| Sonarpad AI | token sessione scaduto: riattivazione una volta | Portato | contract session reactivation |
| Sonarpad AI | upload diretto client → Google; media non passa dal PHP | Portato | contract transport |
| Sonarpad AI | `upload/complete` / `file_verification_failed` limitato a 3 | Portato | test max attempts + contract |
| Sonarpad AI | delete upload temporaneo dopo utilizzo | Portato | contract upload/delete |
| Gemini media | piccoli chunk inline | Portato | test limiti inline + contract |
| Gemini media | inline fallisce → Files API | Portato | contract |
| Gemini media | Files processing/403 → inline quando dimensione sicura | Portato | contract |
| Gemini media | code 13: reupload fino a 3; processing generico: 1 | Portato | due test dedicati |
| Gemini media | normal → compact MKV → compatibility MP4 | Portato | tre test media stage + contract |
| Gemini media | errori API key/credential/permission/billing/quota NON attivano transcode media | Portato e irrigidito | 5 test negativi + test positivo decode |
| Media | timestamp AVI/MKV danneggiati: `+genpts+discardcorrupt` | Portato | contract FFmpeg prep |
| Media | mux audio temporaneo fallisce → video-only | Portato | contract |
| Media | sorgente senza traccia audio → WAV silenzioso per Pyannote | Portato | contract |
| Durata | MKV/WebM con start-time grande: duration assoluta → span locale | Portato | 4 test dedicati |
| Chunking | film lungo diviso in chunk fisici da massimo 180 s | Portato | contract + costante pipeline |
| Blocco Gemini | `PROHIBITED_CONTENT`: 2 tentativi stessa richiesta | Portato | test dedicati |
| Blocco Gemini | chunk ancora bloccato → fallback indipendente da 60 s | Portato | test minute ranges + contract |
| Blocco Gemini | minuto ancora bloccato → si salta solo quel minuto | Portato | contract |
| JSON | `MALFORMED_RESPONSE`: budget separato di 3 tentativi | Portato | test dedicati |
| JSON | JSON troncato: salvage oggetti completi | Portato | test parser/salvage |
| JSON | JSON non valido/MAX_TOKENS → una richiesta di repair | Portato | test repair + contract |
| Timestamp | timestamp numerici, MM:SS, millisecondi, virgola, HH:MM:SS | Portato | gruppo timestamp |
| Timestamp | typo Gemini `MM:SS:ms` | Portato | test dedicato |
| Timestamp | correzione contestuale `MM:SS:xx` solo nel range locale | Portato | test dentro/fuori finestra |
| Timestamp | relativo al chunk → offset una sola volta | Portato | test relativo |
| Timestamp | timestamp già assoluto → mai doppio offset | Portato | test assoluto |
| Timestamp | piccolo drift al bordo clamp; grande errore scartato | Portato | due test dedicati |
| Evidenza | evidence time sempre dentro l'intervallo accettato | Portato | test clamp evidence |
| Copertura | slot >=3 s mandatory; lunghi silenzi partizionati <=15 s | Portato | test split/word budget |
| Copertura | fino a 3 recovery pass dei mandatory mancanti | Portato | contract |
| Copertura | recovery separato per gap non coperti >=90 s | Portato | test gap + contract |
| Scheduling | durata TTS reale prima del posizionamento | Portato | contract ordine synth/duration/place |
| Scheduling | spostamento verso slot sicuro <=5 s | Portato | test slot + contract |
| Scheduling | mandatory prima degli optional | Portato | contract |
| Pause estese | usa solo short gap 1–3 s | Portato | contract |
| Pause estese | niente anchor alla coda del film senza scena successiva | Portato | test dedicato + contract |
| TTS | output vuoto/silenzioso → retry, cancel-aware | Portato | test signal + contract |
| TTS | voce mancante/non supportata → errore permanente, niente loop infinito | Portato | test permanent TTS |
| TTS/escalation | errori TTS/placement non devono attivare Brief o overlap | Portato: escalation solo per esclusioni `no_safe_space_after_exact_tts` | test positivo/negativo + contract |
| TTS Edge | rimozione silenzio finale: conserva 30 ms, rimuove solo >=60 ms | Portato best-effort prima della misura durata | 4 test dedicati + contract |
| Pronuncia | underscore del dizionario vocale sostituito con spazio | Portato | test dedicato |
| Nessuno spazio | prima del fallback sui dialoghi: nuova analisi isolata in modalità Breve | Portato | contract ordine Brief → overlap + UI |
| Nessuno spazio | se l'utente rifiuta Brief, non si passa automaticamente a overlap | Portato | contract dedicato |
| Nessuno spazio | se il primo giro era già Breve, non si ripete Breve | Portato | contract dedicato |
| Fallback finale | overlap solo dopo consenso esplicito | Portato | contract |
| Fallback finale | usa timing visivo, evita overlap tra due narrazioni, max shift 5 s | Portato | 4 test scheduler + contract |
| Lingua | verifica lingua per ogni descrizione utile | Portato | test language + contract |
| Lingua | correzione descrizione glossary senza cambiare ID/nome | Portato | test + contract |
| Cataloghi | merge conserva ID autorevole e rifiuta match ambigui | Portato | gruppo catalogo |
| Cataloghi | biografie duplicate/corrotte non vengono accumulate | Portato | test dedicato |
| Resume | checkpoint solo dopo chunk accettato | Portato | contract |
| Resume | layout/durata incompatibile invalida resume senza rendere fatale il lavoro | Portato | tre test checkpoint |
| Cancel | retry e TTS verificano cancellazione | Portato | contract cancel-aware |
| Output | ducking -12 dB, MP3 192 kbps, pause estese | Portato | contract output |
| Salvataggio | progetto JSON solo su richiesta; MP3/progetto passano a Condividi/Documenti | Portato | pipeline/UI contract |

## Fallback Windows non copiati alla lettera perché non esistono nel runtime mobile

Questi casi non sono “dimenticati”; sono deliberatamente non applicabili e non devono creare codice morto:

1. **SAPI5 / parallelismo COM / fallback specifici SAPI**: iOS e Android usano il TTS di sistema o Edge, non SAPI5.
2. **DPAPI Windows**: la protezione DPAPI di token/codici è Windows-specifica. Il mobile usa il proprio storage/app sandbox; il token Sonarpad AI resta separato dalla chiave personale.
3. **Fallback finale MP4 → MKV per il video audiodescritto**: il requisito mobile è esportare MP3; non viene prodotto un video finale.
4. **Riparazione della timeline del segment muxer Windows**: Windows genera una serie di segmenti nativi e deve riconciliare durate/start-time misurati. Il mobile estrae ogni chunk fisico direttamente con `-ss/-t`, timestamp rigenerati e `make_zero`; non esiste la stessa timeline del segment muxer. Rimangono invece portati `genpts`, `discardcorrupt`, fallback video-only e normalizzazione durata MKV/WebM, che sono applicabili.
5. **UI Win32 del project editor, focus, BASS preview, menu contestuali**: sono test dell'interfaccia Windows separata dalla creazione. Il mobile salva il progetto ma questa modifica non introduce un clone del project editor Win32.
6. **Distribuzione/cache dell'EXE bridge PyInstaller**: il mobile esegue Dart/FFmpeg/ONNX nativi e non scarica/esegue il worker Windows.

## Test

La modifica porta il solo modulo fallback a:

- **126 test deterministici** in `audio_description_fallbacks_test.dart`;
- **65 test di contratto/cablaggio** in `audio_description_pipeline_contract_test.dart`;
- totale **191 test dedicati** al comportamento/fallback della pipeline mobile, oltre agli altri test già presenti nel progetto.

I test non richiedono una chiamata Gemini reale per verificare le regole deterministiche. Le prove di contratto impediscono che un refactoring lasci una funzione di fallback presente ma non collegata alla pipeline reale.

Lo ZIP Windows conteneva anche molti test esclusivamente Win32/bridge/distribuzione. Nell'ambiente di audit sono stati osservati 347 test Python: due diagnostiche erano estranee alla logica dei fallback dell'audiodescrizione (una relativa alle scorciatoie della project window e una relativa a un test lessicale YouTube). Non sono state usate per giustificare o rimuovere alcun fallback mobile.

## Regola di manutenzione

Ogni nuovo fallback aggiunto in futuro deve avere contemporaneamente:

1. una regola deterministica testabile, quando possibile;
2. almeno un test che attivi il fallback;
3. almeno un test negativo quando esiste il rischio di attivarlo per errore;
4. un test di contratto che dimostri che la pipeline di produzione richiama davvero la regola;
5. nessun cambio alla configurazione Pyannote di produzione senza nuova validazione multi-spezzone.

## Verifica eseguita in questo ambiente

1. Lo ZIP Windows fornito è stato rieseguito con `python bridge/run_audio_description_tests.py`: **347 test** totali, **345 superati**, con **1 failure e 1 error** già estranei alla logica/fallback dell'audiodescrizione mobile (`test_youtube_reuses_selected_list_title_without_extra_probe` e `test_audio_description_windows_block_player_keyboard_shortcuts`).
2. I cinque file Dart modificati/aggiunti per pipeline, fallback e test sono stati sottoposti a controllo lessicale di stringhe/commenti e bilanciamento di `()[]{}`: nessuna anomalia rilevata.
3. È stato verificato che tutte le chiamate private introdotte in `ai_audiodescription_service.dart` e `create_ai_audiodescription_screen.dart` abbiano una definizione corrispondente.
4. Tutti i **12 ARB mobili** sono JSON validi e contengono l'intero set di chiavi `audioDescription*` della lingua base.
5. La schermata **Audiodescrizioni Sonarpad** non contiene più riferimenti a Pyannote/benchmark.
6. In questo ambiente non è installato Flutter/Dart SDK completo, quindi i **191 test Dart** non possono essere eseguiti qui. Sul PC di sviluppo vanno eseguiti almeno:

```bat
flutter analyze lib test
flutter test test\audio_description_fallbacks_test.dart test\audio_description_pipeline_contract_test.dart
```

## Editor progetto audiodescrizione mobile (25/09/2026)

Il mobile ora include **Media -> Modifica progetto audiodescrizione**.

Garanzie portate dal modulo Windows:

1. lettura del formato Windows `sonarpad-audio-description-project` versione 1;
2. compatibilità in lettura con i precedenti progetti mobile `schema/schema_version`;
3. i nuovi progetti mobile vengono scritti nel formato Windows v1;
4. modifica testo transazionale: il nuovo testo viene sintetizzato e misurato prima del salvataggio;
5. per le descrizioni normali la durata viene confrontata con gli intervalli Pyannote salvati e con la descrizione successiva;
6. per le pause estese non viene imposto il limite fisso della pausa normale;
7. eliminazione della descrizione con protezione dell'ultima descrizione rimasta;
8. cambio voce Edge / sistema con verifica preventiva di tutte le descrizioni;
9. riesportazione MP3 senza nuova chiamata Gemini, usando video originale, testo progetto e intervalli salvati;
10. se il percorso del video non esiste più, il mobile permette di riselezionarlo e verifica che la durata sia compatibile con il progetto;
11. export SRT e VTT con i tempi di output del progetto;
12. output finale tramite Condividi oppure Salva in Documenti Sonarpad;
13. wakelock e barra di progresso durante verifica voce e riesportazione;
14. i checkpoint della continuazione di una generazione interrotta restano indipendenti dall'editor progetto.

Compatibilità voce: un progetto Edge mobile è direttamente utilizzabile dal formato Windows. Le voci di sistema iOS/Android non esistono su Windows: il JSON mantiene metadati `mobile_*` completi e usa un contenitore Windows caricabile con voce Edge vuota, così Windows può aprire il progetto e scegliere una voce compatibile senza perdere testo e tempi.
