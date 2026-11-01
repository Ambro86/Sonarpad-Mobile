# Sonarpad Mobile – Nederlands (nl) – Fase 3

Questo ZIP **contiene il progetto intero**, comprese tutte le modifiche delle fasi 1 e 2. Non è una patch.

## Traduzioni d'interfaccia

- `lib/l10n/app_nl.arb`: copertura completa delle **1.685 chiavi** presenti in inglese; in questa fase sono state affrontate tutte le 767 chiavi che avevano mantenuto il valore inglese.
- **1.598 stringhe** hanno ora un valore diverso dall'inglese; le **87 rimaste identiche** sono nomi di servizi, sigle, unità, termini o testi tecnici che si scrivono ugualmente anche in olandese (non sono chiavi mancanti).
- `lib/l10n/app_localizations_nl.dart`: classe Dart aggiornata con 1.598 override, compresi i metodi con parametri e le due frasi con plurale singolare/plurale, mentre le altre ereditano il valore inglese quando questo è già adatto anche all'olandese.
- Tradotte le aree prima incomplete: Media Cutter (taglio guidato e avanzato, tracce, effetti), fusione file, SonarMusic e SonarTube, protezione documenti e PDF, configurazione della home, notizie/community, cinema e concerti, registrazioni, podcast e tutte le categorie, Pyannote/strumenti diagnostici, nomi dei servizi e messaggi di errore, audiolibri, condivisione e importazione cloud, sintesi, riproduzione e accessibilità.
- Rimangono le integrazioni già incluse nelle fasi precedenti: selezione della lingua e nome localizzato nelle altre lingue, TTS, percorsi, meteo, radio, podcast, IA e generazione audiodescrizioni.

## Calendario

- `assets/calendar/nl.json`: tutti i **365 valori dei santi/ricorrenze** presenti, con 136 ulteriori correzioni terminologiche di nomi, titoli e festività.
- Tutte le **128 citazioni** restano in olandese dalla fase 2, con autore preservato come nel materiale di partenza.
- `lib/services/calendar/calendar_localization_data.g.dart`: mantenuto sincronizzato con i valori dell'asset.
- **Limite dei dati originali**: in più date, la fonte fornita associa voci a siti, istituzioni, edifici, eventi religiosi mobili o persone non riconducibili necessariamente al santo del giorno. Questa fase migliora la resa linguistica senza ricostruire un calendario agiografico affidabile. Le date e le attribuzioni non sono state verificate contro fonti liturgiche o filologiche.

## Verifiche eseguite

Convalida strutturale JSON/ARB, identità delle 1.685 chiavi con l'inglese, controlli di tutti i segnaposto e degli argomenti dei metodi Dart, compatibilità delle firme degli override, verifica di presenza di ogni citazione e ogni nome del calendario nel codice generato e verifica di integrità dell'archivio ZIP.

**Non è stata effettuata una compilazione Flutter né una prova su dispositivi iOS/Android**: nell'ambiente di preparazione non erano presenti gli SDK Flutter e Dart. Prima di pubblicare, effettuare `flutter gen-l10n`, `flutter analyze`, `flutter test` e una prova manuale con VoiceOver/TalkBack. Tali comandi possono rigenerare i file delle localizzazioni dai dati ARB.

Restano inoltre utili una revisione professionale madrelingua, l'audit di stringhe hard-coded residue al di fuori del sistema ARB e il controllo delle traduzioni dinamiche prodotte o ricevute da servizi esterni (non sempre dipendono dalla lingua dell'interfaccia).
