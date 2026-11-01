# Sonarpad Mobile — Nederlandse versiegeschiedenis

La traduzione olandese è stata aggiunta a `assets/changelog.json` usando **esclusivamente le voci inglesi** come fonte.

## Versioni presenti nel sorgente

La cronologia nel progetto include nove versioni: `0.2.0` (7 giugno 2026), `0.2.1`, `0.3.0`, `0.3.1`, `0.4.0`, `0.5.0`, `0.5.1`, `0.5.2`, `0.5.3` (27 ottobre 2026). Non risultano nel file inglese versioni precedenti alla `0.2.0` né successive alla `0.5.3`; non sono state inventate altre note.

Tutte le **163 voci generali** in inglese sono ora accompagnate da una voce in olandese (`nl`), oltre alle **2 note esclusive iOS** e **1 nota esclusiva Android** della versione `0.4.0`. Totale **166 descrizioni tradotte**. Per ogni versione, data, ordine, numero di voci e distinzione fra piattaforme sono conservati.

In `lib/services/changelog_service.dart`, `nl` è stato aggiunto ai due elenchi espliciti delle lingue lette dal JSON, sia per le note generali sia per le varianti `ios` e `android`. Prima di questa correzione la schermata ricadeva sull'inglese anche con il campo `nl` presente nel JSON.

Le sezioni `it_extra` non sono state tradotte né rese pubbliche: sono note speciali italiane che il codice mostra solo con accesso extra autorizzato, e non fanno parte del changelog inglese di riferimento.

I dati originali delle altre lingue non sono stati intenzionalmente modificati. Il progetto comprende anche le correzioni di integrazione della localizzazione olandese già presenti nell'archivio di partenza.

## Verifica

Controllati con uno script i nomi delle versioni, il numero delle voci tradotte, la presenza dei campi `nl`, l'assenza di voci vuote o duplicate, la presenza delle note specifiche per iOS e Android e il riconoscimento di `nl` nel parser Dart. Aggiunto `test/dutch_changelog_contract_test.dart` per una verifica eseguibile con Flutter.

**Non è stato possibile eseguire Flutter o una prova su telefono:** gli SDK Flutter/Dart non sono installati nell'ambiente. Rimane inoltre fuori dall'ambito di questa modifica il modulo separato delle traduzioni di Omio, come segnalato nel precedente audit.
