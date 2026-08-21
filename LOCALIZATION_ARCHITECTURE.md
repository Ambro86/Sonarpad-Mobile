# Architettura delle localizzazioni di Sonarpad

Questa struttura evita che l'aggiunta di una nuova lingua richieda di cercare testi sparsi in decine di file Dart.

## 1. Testi dell'interfaccia

Qualunque testo che una persona può leggere o ascoltare nell'interfaccia deve provenire dagli ARB in `lib/l10n/`. Questo include titoli, pulsanti, tooltip, messaggi VoiceOver/TalkBack, dialoghi, snackbar, messaggi di avanzamento e messaggi d'errore creati dall'app.

Le stringhe con valori dinamici devono usare placeholder ARB. Non si devono costruire frasi traducibili concatenando pezzi localizzati, perché l'ordine grammaticale cambia fra le lingue.

Il nome "Cinese semplificato" e il nome del paese "Cina", per esempio, sono ora vere chiavi ARB e non più uno `switch` scritto a mano in Dart.

## 2. Calendario, santi, citazioni e festività

I dati voluminosi del Calendario non appartengono agli ARB. La fonte modificabile dai traduttori è `assets/calendar/`.

Ogni lingua ha un file JSON autonomo. Ogni file contiene esattamente 365 voci `saints`, 128 voci `quotes` e una mappa `holidays`.

Il file runtime `lib/services/calendar/calendar_localization_data.g.dart` è generato e non va modificato a mano.

Dopo aver modificato un JSON del Calendario eseguire:

```text
python tool/generate_calendar_localizations.py
```

Il generatore rifiuta file incompleti, santi vuoti e serie di citazioni diverse da 128 elementi.

## 3. Errori tecnici

Il codice nuovo non deve introdurre frasi user-facing direttamente nei servizi. Quando possibile il servizio deve restituire un tipo o un codice d'errore e la schermata deve trasformarlo in una stringa ARB.

Il vecchio `localizeTechnicalError` è stato rimosso. Gli errori imprevisti mostrati all'utente usano `technicalErrorGeneric` dall'ARB; il dettaglio tecnico originale deve restare nei log. Gli errori prevedibili devono invece avere una chiave ARB specifica o un errore tipizzato, senza traduttori speciali per singola lingua.

## 4. Dati localizzati lunghi

Dataset come Calendario, grandi cataloghi di categorie o altri elenchi strutturati possono avere un file dati localizzato dedicato, purché esista un validatore di completezza. Le normali etichette dell'interfaccia restano negli ARB.

## 5. Protezione contro nuove stringhe hard-coded

`tool/check_user_facing_strings.py` controlla `lib/screens/` e `lib/widgets/` e confronta le stringhe sospette con `test/fixtures/localization_hardcoded_allowlist.json`.

La baseline rappresenta codice legacy già presente e deve diminuire nel tempo. Una nuova stringa condivisa non deve essere aggiunta alla baseline: va spostata negli ARB.

Il test `test/localization_architecture_contract_test.dart` esegue questo controllo insieme alla verifica dei JSON del Calendario.

## 6. Aggiunta di una nuova lingua

1. Creare il nuovo ARB partendo dal template e tradurre tutte le chiavi.
2. Aggiungere il nome della nuova lingua in tutti gli ARB esistenti.
3. Creare `assets/calendar/<locale>.json` con 365 santi, 128 citazioni e le festività applicabili.
4. Eseguire `python tool/generate_calendar_localizations.py`.
5. Eseguire `flutter gen-l10n` per rigenerare le classi ARB.
6. Aggiungere la localizzazione nativa iOS quando servono descrizioni dei permessi.
7. Configurare soltanto i servizi esterni che richiedono davvero un codice lingua/paese specifico, per esempio TMDB, News, Radio, Podcast o Wikipedia.
8. Eseguire `python tool/check_user_facing_strings.py`, `flutter analyze` e i test di localizzazione.
