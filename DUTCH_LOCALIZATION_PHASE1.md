# Sonarpad Mobile — Dutch (nl) | Fase 1

Questa è una versione intermedia e **non una traduzione completa**.

La lingua nl è selezionabile nelle impostazioni (entrambe le interfacce), riconosciuta dalla preferenza persistente e dalle impostazioni di sistema su iOS/Android. I nuovi getter sono disponibili in tutte le lingue, con etichetta localizzata. Sono collegati lingua radio, filtro radio per Paesi Bassi, podcast, paese iniziale nei percorsi, Google Nieuws Nederland e la scelta di audiodescrizione con prompt Gemini olandese. iOS espone nl in Info.plist, Xcode e avvisi permessi tradotti.

ARB: 553 voci lavorate (522 testi diversi dall’inglese e 31 termini condivisi o invarianti); 1.131 messaggi non ancora lavorati hanno **fallback inglese esplicito**, non italiano. Il file `lib/l10n/app_nl.arb` contiene l'intero set di chiavi per prevenire messaggi mancanti; `app_localizations_nl.dart` funziona già senza il tool di generazione. In sviluppo si può rigenerare con `flutter gen-l10n`, che userà l'ARB.

Calendario: `assets/calendar/nl.json` include 365 voci santo, 128 citazioni e 5 festività dei Paesi Bassi; nella prima fase sono tradotte direttamente solo 17 voci dei santi e 5 citazioni. Le altre voci sono ancora in inglese per evitare finte traduzioni, come anche il codice Dart del calendario (sincronizzato).

Prossime fasi: traduzione delle restanti 1.131 voci e di tutti i contenuti del calendario; localizzazione dettagliata AI, meteo, documenti, radio, percorsi, servizi dinamici, descrizioni delle versioni e voci esterne; verifica funzionale e test Flutter su iOS/Android. Fonti RSS olandesi aggiuntive, test localizzazione IA e gestione degli output ancora da completare.

Controlli fase 1: validazione statica e JSON; compilazione Flutter non possibile nell'ambiente in cui è stato assemblato questo archivio (SDK Dart/Flutter non installato).
