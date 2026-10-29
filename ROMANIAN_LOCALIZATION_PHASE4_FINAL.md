# Romanian localization — Phase 4 FINAL

Questa fase completa la localizzazione rumena di Sonarpad Mobile iniziata nelle fasi 1–3.

## Stato finale

- 1269/1269 chiavi ARB rumene presenti e allineate con l'inglese.
- Tutti i placeholder ICU verificati e conservati.
- 1269 override presenti in `AppLocalizationsRo`.
- Le sole stringhe ancora identiche all'inglese sono 50 termini intenzionalmente invariati: marchi, formati, unità, nomi propri e termini internazionali (ad esempio Sonarpad, SonarTube, Wikipedia, PDF, EPUB, Google Maps, Celsius/Fahrenheit, Pop/Rock/Jazz).
- Nessuna frase inglese residua rilevata nell'ARB rumeno mediante l'audit finale delle parole comuni.
- Calendario rumeno: 365 giorni, 12 festività e 128 citazioni.
- Changelog rumeno completo.

## SonarTube in rumeno

Quando la lingua dell'app è rumena (inclusa la selezione automatica da un dispositivo configurato in rumeno):

- `SonarTubeService` usa `hl=ro` e `gl=RO`.
- Le chiamate InnerTube dirette usano contesto client rumeno e regione Romania.
- Il fallback PHP riceve sempre `hl=ro` e `gl=RO`; i parametri del chiamante non possono sovrascrivere accidentalmente la locale attiva.
- Il backend PHP costruisce `Accept-Language` dalla locale richiesta (per il rumeno: `ro-RO,ro;q=0.9,en;q=0.7`).
- Ricerca, navigazione canali/playlist, metadati e commenti mantengono la locale rumena.
- La locale viene impostata in `didChangeDependencies`, quindi è disponibile prima della prima ricerca automatica.
- I principali errori interni SonarTube che potevano emergere all'utente non ricadono più in italiano quando la locale è rumena.

## Altri servizi verificati

- Notizie / Google News: Romania e lingua rumena, fonti rumene.
- Podcast: Romania e 111 categorie localizzate.
- Radio: Romania, lingua `romanian`, comunità e Radio Browser.
- Percorsi: Romania/ROU, geocodifica e risposte localizzate in rumeno.
- Meteo: lingua rumena e descrizioni meteo rumene.
- Wikipedia: `ro`.
- Gutenberg: filtro lingua rumena.
- TMDB/cinema: `ro-RO`.
- Audiodescrizione con IA: lingua rumena, prompt rumeni, locale TTS `ro-RO`.
- TTS Edge: `ro-RO-AlinaNeural` e `ro-RO-EmilNeural`, incluse nel fallback locale.
- Nomi dei paesi: localizzazione `ro`.
- Paywall lettore notizie: messaggio rumeno.

## Servizi esclusivamente italiani

La logica di visibilità non è stata modificata. RaiPlay, RaiPlay Sound, LA7 Play, TV italiane, Audiodescrizioni e Audiodescrizioni Sonarpad continuano a essere mostrate solo quando `isItalian == true`, come prima della traduzione rumena. Il test di regressione introdotto nella fase 3 rimane presente.

## Verifiche finali

Sono stati verificati staticamente:

- validità JSON/ARB;
- parità delle 1269 chiavi;
- parità dei placeholder ICU;
- 1269 override Dart rumeni;
- struttura lessicale/bilanciamento dei Dart modificati;
- sintassi PHP di `server/youtube_resolve.php`;
- assenza di file Dart di produzione multilingua con supporto alle altre lingue ma senza `ro`;
- preservazione byte-per-byte dei file che controllano la visibilità dei servizi solo italiani rispetto alla fase 3.

È incluso `test/romanian_localization_phase4_contract_test.dart` per il contratto finale rumeno, compreso SonarTube `ro/RO`, TTS e servizi solo italiani.

In questo ambiente non sono disponibili gli eseguibili Flutter/Dart, quindi `flutter analyze` e `flutter test` devono essere eseguiti nel normale ambiente di sviluppo/CI del progetto.
