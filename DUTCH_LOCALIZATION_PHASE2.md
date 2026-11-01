# Sonarpad Mobile – Nederlands (nl) – Fase 2

Archivio **completo** del progetto Flutter: prosegue la fase 1 e non è una patch separata.

## Traduzioni eseguite

- Nuove/aggiornate in questa fase: **433 chiavi ARB**. Alcune chiavi contenevano già un valore olandese o termini internazionali.
- Totale attuale: **918 stringhe con valore olandese distinto dall'inglese su 1.685 messaggi**. Restano **767 messaggi con fallback inglese** (questo include termini che in alcune lingue restano identici, per esempio marchi o sigle). Non considerare questa fase una localizzazione completa.
- Aree principali lavorate: creazione audiodescrizioni con Gemini e Sonarpad AI, selezione modelli, crediti, fallback su dialoghi, cataloghi personaggi, ripresa delle lavorazioni, editor dei progetti, sintesi e mix; meteo (condizioni e qualità dell'aria), percorsi e messaggi di rete, radio e programmazione registrazioni, podcast/registratore, dizionario online, documenti e accessibilità, Edge TTS, Dropbox e messaggi di errore.
- Calendario: **128/128 citazioni** olandesi (comprese le prime cinque già tradotte nella fase 1), mantenendo gli autori. Le **365 voci dei santi** sono presenti; in questa fase sono state adattate **279 voci aggiuntive** attraverso le forme dei nomi, titoli e ricorrenze olandesi. Le altre includono nomi propri o voci da revisionare a mano. Le festività olandesi aggiunte nella prima fase rimangono presenti.

## File principali

- `lib/l10n/app_nl.arb`: tutte le 1.685 chiavi dell'interfaccia, con 918 valori tradotti in modo diverso dall'inglese.
- `lib/l10n/app_localizations_nl.dart`: **835 getter e 83 metodi** olandesi, inclusi i messaggi con parametri, già utilizzabili senza rigenerare le localizzazioni; gli altri metodi ereditano il fallback inglese.
- `assets/calendar/nl.json`: dati olandesi del calendario aggiornati.
- `lib/services/calendar/calendar_localization_data.g.dart`: calendario sincronizzato con l'asset.
- Restano tutte le integrazioni della fase 1, incluse selezione lingua, percorsi, radio, podcast, notizie e prompt IA.

## Verifiche e limiti

Validati con Python: struttura ARB/JSON, tutte le chiavi utente, equivalenza dei segnaposto dei messaggi, corrispondenza dei parametri con i metodi generati in inglese, 918 override nella classe olandese, completezza delle 128 citazioni e delle 365 voci dei santi, presenza dei collegamenti `nl` nelle schermate principali. La generazione Flutter e i test su iOS/Android **non sono stati eseguiti**, perché gli SDK Dart e Flutter non sono disponibili nell'ambiente.

Le traduzioni in testo libero non ancora localizzate (767 messaggi, eventuali testi hard-coded e contenuti dinamici di servizi esterni) sono materiale per le prossime fasi. Restano da fare revisione madrelingua, test con TalkBack/VoiceOver, plurali ICU e verifica completa delle descrizioni generate dai servizi remoti.

**Nota:** le citazioni riportano attribuzioni presenti nella fonte originale, che non sono state verificate filologicamente. I nomi di santi/dediche conservano alcuni titoli insoliti già presenti nei dati di partenza, che vanno revisionati nel completamento finale.
