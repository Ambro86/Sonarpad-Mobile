# Sonarpad Sync — PHP e SQLite

Backend separato dalle audiodescrizioni, con la stessa organizzazione del
progetto `sonarpad_app`: `public/`, `src/`, `private/`, `data/`.
Non servono MySQL, account database, Composer o servizi esterni.
PHP 8.2+ con `pdo_sqlite` e `zlib`; il database viene creato alla prima richiesta.

Endpoint Sonarpad: **https://sonarpad.com/synk/index.php**.

## Installazione su sonarpad.com/synk/

Usare la stessa disposizione del backend audiodescrizioni, con applicazione
privata fuori dalla cartella pubblica:

```
cartella-del-sito/
  sonarpad_sync/          # questa applicazione, privata
  httpdocs/              # oppure public_html: la cartella pubblica del sito
    synk/
      index.php          # copiare da deploy/synk/index.php
      .htaccess          # copiare da deploy/synk/.htaccess
```

Il piccolo `index.php` cerca automaticamente `sonarpad_sync` due livelli sopra
`synk`. Se la disposizione del proprio hosting è diversa, adattare soltanto
quel `require`; non spostare il database sotto la cartella pubblica.
Verifica: `https://sonarpad.com/synk/index.php?action=health`.
Anche `https://sonarpad.com/synk/` restituisce lo stato del servizio.

## Log diagnostici con pulizia automatica

Il server registra `data/sync.log`: identificativo della richiesta (restituito
anche nell'header `X-Request-ID`), azione, esito HTTP, durata, revisione e conteggi.
Non registra token, codici, IP, nomi dei dispositivi, URL o contenuti delle raccolte.
Le risposte health riuscite non generano righe.

Rotazione automatica a **256 KiB**, massimo **tre archivi gzip livello 9**
più il piccolo file attivo non compresso (scrivibile normalmente). Anche i vecchi
archivi vengono convertiti in gzip. Alla successiva scrittura vengono eliminati
i file con contenuti più vecchi di **5 giorni**, compreso il file attivo anche se
continua a ricevere poche righe. Un vecchio config.php con 7 giorni viene limitato
a 5. Senza richieste la pulizia attende il prossimo accesso; per una scadenza
esatta anche senza traffico occorre una chiamata pianificata che produca un log.
Dimensioni e numero archivi restano limitati (circa 1 MiB massimo, normalmente
molto meno grazie a gzip). Lock e scrittura atomica proteggono la rotazione.
Un problema dei log non interrompe la sincronizzazione.

## Compressione, deduplica e aggiornamento

La scelta del formato è **adattiva**, sempre con JSON minificati e gzip livello 9:

- Una copia intera condivisa quando i dispositivi sono allineati o quando i dati
  sono piccoli e dividerli aggiungerebbe soprattutto riferimenti.
- Raccolte compresse separatamente quando condividere radio, notizie, TV, podcast,
  SonarTube o preferenze invariati tra più revisioni risulta più conveniente.
- Rivalutazione al cambio dei riferimenti dei dispositivi: al riallineamento si
  può tornare alla copia intera, raccogliendo solo stati e raccolte non più usati.

Il confronto usa dimensioni gzip effettive, costi stimati di righe/indici e una
soglia minima di 256 byte per evitare conversioni inutili. Le raccolte condivise
con altri stati/utenti sono considerate e conservate. Il confronto non è una
misura esatta delle pagine SQLite: lo spazio fisico dipende anche dal database.
L’analisi è limitata a 8 MiB di JSON per gruppo per contenere memoria e lavoro
su una richiesta PHP; oltre questo limite resta valido il formato già presente.
Le richieste senza modifiche ai riferimenti non ricomprimono ogni volta i dati.

Hash SHA-256 verificano raccolte e stato ricostruito. Ordine degli elenchi, valori,
revisioni e risposte dei retry rimangono invariati durante ogni conversione.
Autorizzazioni separate per gruppo. Nessuna eliminazione degli utenti inattivi.
Protocollo v1 invariato: **non serve aggiornare i client**.

Per aggiornare il backend esistente caricare insieme la cartella `src/` completa
(incluso il nuovo `Storage.php`), `public/index.php`, `private/config.example.php`
e, facoltativamente, `compact.php`. Conservare **data/** e l’eventuale
**private/config.php** esistenti. Il wrapper pubblico `synk` non cambia.
La migrazione parte automaticamente, in piccoli blocchi transazionali di due
utenti e due risposte per richiesta. Le righe non ancora migrate restano leggibili;
sequenze, revisioni e retry rimangono validi. Anche i gruppi delle precedenti versioni gzip vengono rivalutati, due per
richiesta, mantenendo hash e riferimenti. Tutti i formati precedenti rimangono
leggibili; la conversione avviene solo se stimata conveniente. Dopo la migrazione non ripristinare
il vecchio codice privo del supporto agli snapshot compressi.

SQLite riutilizza le pagine liberate, ma il file già esistente non si restringe
subito. Per restituire lo spazio al filesystem eseguire, facoltativamente e in
un momento di poco traffico, dalla cartella privata:

```
php compact.php
```

Questo comando completa la migrazione, esegue VACUUM e tronca il WAL. È solo CLI,
non invocabile via web; richiede spazio temporaneo per la compattazione e può
occupare brevemente il lock di scrittura. Non cancella utenti. La sincronizzazione
non richiede questo comando: le pagine liberate sono comunque riutilizzabili.
Health espone `storage_encoding: gzip-9`, `storage_deduplication: true` e
`storage_layout: adaptive-v3` e `log_retention_days: 5` dopo l’aggiornamento.

### Misura locale riproducibile

`php -d extension=pdo_sqlite tests/storage_benchmark.php` e la variante con
`--different-revisions`: 100 utenti sintetici, 3 dispositivi ciascuno, 300
preferiti/link per utente. La variante cambia solo la città del meteo tra le
risposte conservate dai dispositivi. Dati diversi tra utenti, quindi il confronto
non beneficia di raccolte comuni a più utenti. Misure SQLite dopo VACUUM,
comprensive di indici e metadati, confrontate sullo stesso schema:

| Scenario | Copia intera gzip | Formato adattivo | Differenza |
| --- | ---: | ---: | ---: |
| Dispositivi allineati | 864.256 byte | 864.256 byte | 0% |
| Tre revisioni diverse del meteo | 2.125.824 byte | 1.679.360 byte | -21,00% |

Nel primo caso il formato adattivo evita il sovraccosto della precedente versione
sempre suddivisa per raccolta (circa 1,27 MB). Nel secondo conserva il beneficio
delle raccolte condivise. Rispetto al database originale non compresso (21,7 MB)
le riduzioni sono rispettivamente circa 96% e 92%. Estrapolazione a 1.000 utenti
dello stesso scenario: circa 8,6 MB allineati o 16,8 MB con tre revisioni diverse.
Non sono quote né previsioni garantite: quantità, lunghezza e ripetitività dei
contenuti cambiano il risultato; log, backup e WAL sono separati da queste misure.

Test di regressione: `tests/adaptive_storage_test.php` verifica allineamento,
divergenza, ritorno alla copia unica, replay esatto, migrazione da collections-v2
e scelta della copia intera per dati piccoli. `tests/collection_storage_test.php` verifica riuso delle
raccolte, retry dopo modifiche parziali, isolamento fra utenti, rimozione dei soli
riferimenti inutilizzati e migrazione dalla prima versione gzip.

Il backend non genera backup completi periodici. Eventuali backup del pannello
hosting/servizi esterni hanno una conservazione separata: questa versione non
li cancella e non ne modifica le impostazioni.

## Installazione

1. Caricare la cartella `sonarpad_sync` sul server.
2. Esporre **soltanto `public/`** tramite un dominio/sottodominio HTTPS, oppure
   collocare `src/`, `data/` e `private/` fuori dalla cartella pubblica e adattare
   il percorso `require_once` del front controller. Non esporre il database.
3. Rendere `data/` scrivibile da PHP. La configurazione predefinita funziona
   senza creare `config.php`. Per cambiarla, copiare `private/config.example.php`
   in `private/config.php` e modificare solo la copia.
4. Aprire `https://HOST/index.php?action=health`: deve rispondere `ok: true`.

Non sono necessarie regole di riscrittura URL. `.htaccess` è una protezione
aggiuntiva Apache: su Nginx configurare la document root esclusivamente su
`public/`. In HTTPS dietro proxy, configurare il web server perché esponga
correttamente `HTTPS=on`; il servizio non si fida di header inoltrati dal client.

Database distinto `data/sync.sqlite`. Aggiornando il codice, conservare `data/`
e l'eventuale `private/config.php`. Fare backup SQLite coerenti (API backup o
servizio fermo includendo WAL), non copiare solo il file principale mentre scrive.

## Funzionamento e protocollo v1

Tutte le operazioni, salvo health, sono POST JSON a `index.php?action=AZIONE`
con `Authorization: Bearer TOKEN`. Il client genera TOKEN come 32 byte casuali
crittografici codificati in 64 caratteri esadecimali e lo conserva **prima** di
richiedere `create` o `join`, nell'archivio protetto del dispositivo.
Il server conserva solo il relativo SHA-256.

- `create`: `{ "device_name": "PC di Mario" }`, crea un gruppo vuoto.
- `code`: `{}`, genera un codice di otto cifre, monouso, valido dieci minuti;
  invalida l'invito precedente, non i dispositivi collegati.
- `join`: `{ "code": "12345678", "device_name": "iPhone" }`, collega il nuovo
  dispositivo senza sostituire i dati locali. Ritentare con lo stesso token
  dopo timeout non consuma un altro codice o crea un altro gruppo.
- `state`: `{}`, restituisce stato, revisione, gruppo, dispositivo e sequenza.
- `sync`: `{ "schema_version": 1, "sequence": 1, "baseline": {}, "state": {} }`.
  `baseline` è l'ultima copia locale sincronizzata; `state` è quella attuale.
  Al primo collegamento baseline è vuota, anche se `join` restituisce dati.
  Ogni raccolta è una lista ordinata di `{ "id": "identità stabile", "data": {...} }`.
  Raccolte: `radio`, `news_sources`, `news_folders`, `news_articles`, `tv`,
  `podcasts`, `sonartube`. Omettere le raccolte non supportate; non inviarle vuote.
  La risposta contiene l'intero stato unificato. La sequenza parte da 1 e cresce
  di uno per dispositivo. Ripetere la stessa richiesta dopo un timeout restituisce
  la risposta originale; riusare una sequenza con contenuto diverso viene rifiutato.
- `devices`: `{}`, elenco nomi e ultimo accesso dei dispositivi del gruppo.
- `revoke`: `{ "device_id": "..." }`, revoca un dispositivo dello stesso gruppo.
- `disconnect`: `{}`, scollega il chiamante. L'ultimo scollegamento elimina il gruppo.
- `delete`: `{ "confirm_group_id": "..." }`, cancella gruppo e autorizzazioni.

Il client deve serializzare le proprie richieste, conservare il corpo della
richiesta pendente per ritentarlo identico e applicare la risposta in modo
recuperabile prima di aggiornare baseline/sequenza. Le modifiche locali fatte
durante la richiesta vanno conservate e inviate al giro successivo. Non mettere
token o codici nei log. Scollegare non deve cancellare le raccolte locali.

La fusione preserva aggiunte indipendenti e campi non modificati, applica
cancellazioni esplicite e fa prevalere una cancellazione remota su una modifica
offline dello stesso elemento. Modifiche concorrenti allo stesso campo: vince
l'ultima elaborata dal server. Un nuovo dispositivo unisce i propri elementi.
Le raccolte sconosciute al client restano sul server.

Limiti: 10 dispositivi per gruppo, 5.000 elementi per raccolta, richiesta 2 MiB,
stato totale 4 MiB, 20 tentativi creazione/collegamento per IP all'ora e 600 altre
richieste. Sono trasferiti metadati/preferiti, non file audio/video o credenziali di altri servizi. L’attivazione Sonarpad è inclusa nelle preferenze.
Trasporto HTTPS; **non è crittografia end-to-end**: il gestore del server può
leggere le raccolte. Non è previsto recupero se si perdono tutti i dispositivi.

## Verifica locale

`php tests/run.php`

`php tests/log_test.php` verifica limite di spazio, rotazione, scadenza e assenza
di dati riservati.

`python tests/http_test.py` verifica inoltre il front controller HTTP e una
vera installazione SQLite temporanea: autenticazione, collegamento, richieste
di due client, retry e inaccessibilità dei percorsi privati. Il server HTTP PHP
di sviluppo è seriale; questo test non è una prova di carico del proprio hosting.

Se l'estensione locale è installata ma disabilitata:
`php -d extension=pdo_sqlite tests/run.php`.
I test usano un database in memoria: non toccano dati reali.
Per test HTTP locali, configurare `require_https => false` nella sola copia
locale e usare `php -S 127.0.0.1:8097 -t public`.

Questo pacchetto è il backend: l'integrazione delle app e l'installazione sul
server vanno completate prima che la funzione sia disponibile agli utenti.

## Preferenze dei moduli

La raccolta `preferences` sincronizza valori compatti con limiti dedicati e precedenza ai valori già nel cloud al primo collegamento. Vedere [inventario e aggiornamento](PREFERENZE.md). È inclusa l’attivazione Sonarpad; sono esclusi le altre credenziali, percorsi, cronologie e contenuti multimediali.
