# Nederlands – controllo integrazione dopo fase 3

L'audit aggiuntivo ha identificato e corretto mancanze non rilevate contando le 1.685 stringhe ARB.

**Corretto:** riconoscimento `nl` da parte del delegate Flutter, scelta `nl` in entrambe le liste del dizionario Wiktionary, Paesi Bassi in entrambi i selettori dei percorsi ORS, nomi dei paesi nella lingua olandese, lingua predefinita `nl-NL` per progetti di audiodescrizione IA importati, lingua `dutch` nelle radio della comunità, Wikipedia e Gutenberg, parametri regionali SonarTube, SonarMusic, TMDB e geocodifica meteo.

**Precedentemente integrato e confermato da revisione del sorgente:** paese `nl` e lingua dell'interfaccia per podcast, filtri radio `nl`, selezione `nl` per le audiodescrizioni IA, prompt in olandese, Edge TTS `nl-NL`, localizzazione delle istruzioni dei percorsi, calendario `nl.json`.

**Non ancora completo:** il modulo di ricerca viaggi Omio utilizza `travel_translations.dart`, in cui manca ancora il catalogo `nl` (quindi ricade sulle stringhe inglesi); i cataloghi delle notizie NL sono iniziali e usano Google News anziché un elenco esteso di editori olandesi. Possono inoltre esistere altre stringhe hard-coded o risposte di servizi esterni fuori dagli ARB.

**Verifiche:** controlli statici e integrità ZIP eseguiti. Non è possibile garantire compilazione Flutter o test di integrazione reali senza Flutter/Dart SDK. Il file `test/dutch_service_integration_contract_test.dart` può essere eseguito con `flutter test` una volta disponibile Flutter.

**Aggiornamento successivo:** i changelog delle versioni 0.2.0–0.5.3 sono stati tradotti dall’inglese in `nl` e collegati al parser. La sezione relativa ai changelog fra i punti mancanti qui sopra è quindi stata risolta; vedi `DUTCH_CHANGELOG_COMPLETE.md`.


## Verifica locale prima del commit — 1 novembre 2026

Verificati tutti i 1.685 messaggi ARB e rigenerate le localizzazioni con `flutter gen-l10n`. Rigenerati anche i dati del calendario dal JSON tramite il generatore del progetto. Completato il catalogo `nl` della ricerca viaggi (il limite indicato sopra è quindi risolto) e aggiunte le istruzioni disabilità dei sette nuovi mercati in olandese. Aggiornati i test del changelog per riconoscere `wachtwoord` e la nuova voce sulla lingua olandese, inserita nella versione 0.5.3 in tutte le 14 varianti.

Restano i limiti editoriali del catalogo notizie iniziale e possibili testi di fornitori esterni o istruzioni specialistiche precedenti che ricadono in inglese. Non è stata effettuata una prova VoiceOver su iPhone né una verifica reale di tutti i servizi esterni.

Suite finale: 2.503 test superati, 45 test opzionali esclusi. Nessun test disabilitato per aggiungere la lingua.
