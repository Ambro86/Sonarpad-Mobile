# Diagnostica del player TV

La revisione `stream-diag-v1` aggiunge lo stato di riconnessione e il comando Riprova, senza modificare i codec, i timeout del player nativo o l'ordine degli stream Rai. Video spento: AD diretta quando disponibile, poi ITA se l'AD non avanza. Video acceso: master. I timer del recupero Rai rimangono a sei secondi.

## Messaggi e Riprova

Durante il recupero automatico il vecchio errore viene sostituito da “Tentativo di riconnessione…”. L'avanzamento della posizione, con player attivo e non in buffering, termina questo stato. Il solo ritorno di `open()` o il solo valore `playing=true` non bastano.

Dopo venti secondi senza avanzamento la UI espone un messaggio con Riprova. Questo è un avviso dell'interfaccia: non interrompe la riproduzione nativa e non aggiunge tentativi automatici. Se lo stream comincia successivamente ad avanzare, il messaggio viene rimosso.

Riprova richiede nuovamente il collegamento Rai al relinker. Le pressioni ripetute sono bloccate mentre il tentativo manuale è in corso. Gli identificatori di richiesta impediscono alle callback precedenti di sovrascrivere lo stato nuovo. La chiusura del player resta sequenziale: non si lascia un vecchio player in riproduzione mentre se ne apre un altro. Se il componente nativo impiega molto a chiudersi, il nuovo tentativo può ancora dover aspettare; questa modifica non promette di risolvere quel blocco.

Il pulsante è presente nella lista accessibile nativa e nelle viste Flutter, anche a schermo intero. Gli stati sono annunciati tramite lo stesso meccanismo VoiceOver/TalkBack usato dall'app. Le scritte sono negli ARB di tutte le tredici localizzazioni.

## Come leggere STREAM_DIAG

Ogni tentativo utente ha un `id` distinto. `stage` distingue AD diretta, ITA, master e recupero. `elapsedMs` o `stageMs` consentono di ricostruire le attese. `manual_retry` nel tentativo precedente e un nuovo `session_start` delimitano Riprova.

`resolver_http_start`, `resolver_http_end` e `resolver_http_error` descrivono le richieste effettive al relinker e al master. Contengono stato HTTP, tempi, dimensione e alcune intestazioni di risposta. Queste misurazioni non aggiungono altre richieste al percorso di apertura ordinario.

`player_open_start`, `player_open_returned` e `first_playback_progress` distinguono l'apertura dall'avanzamento. `buffering`, `native_log` e `player_error` conservano il contesto del componente multimediale. I messaggi nativi sono limitati e non viene abilitato il livello trace globale.

`native_stop_wait_timeout` significa che Sonarpad ha smesso di attendere stop, non che il componente nativo si sia sicuramente fermato. `native_dispose_start` e `native_dispose_end` misurano l'attesa successiva. Durante Riprova, `previousAttempt` collega la chiusura al tentativo precedente.

## Controlli HTTP aggiuntivi

Solo in caso di errore o stallo viene avviato un controllo separato, non atteso dal player. Esamina la playlist usata, un'eventuale variante a banda bassa scelta solo per la diagnosi, un'eventuale inizializzazione e un campione dell'ultimo segmento completo non marcato GAP.

`http_probe_headers` registra stato HTTP, server, intestazioni selezionate, famiglia IPv4/IPv6 quando disponibile e redirect. `http_probe_error` distingue la fase connect, headers o body e conserva l'eventuale codice di sistema. La classificazione DNS/TLS/timeout resta unknown quando non ci sono elementi sufficienti.

Il limite è di due controlli per tentativo, mai contemporanei. Ogni controllo visita al massimo quattro risorse, con fino a quattro redirect HTTP per risorsa; ha un budget complessivo di sedici secondi e un timeout di quattro secondi per le fasi di richiesta. Le playlist vengono lette fino a 128 KiB, i campioni binari fino a 16 KiB. Il client interrompe la lettura anche se il server ignora Range. Uscire dalla schermata o avviare un altro tentativo chiude i socket della diagnostica.

Le query firmate, le credenziali e i token nei percorsi vengono mascherati nei nuovi log e nei log Rai interessati. Non si salvano i contenuti multimediali, i corpi degli errori HTTP, le chiavi di decifratura o le licenze DRM. Il metodo di cifratura può essere annotato, ma le chiavi non vengono richieste. Le risposte Set-Cookie sono conteggiate senza registrarne il valore.

## Limiti dell'interpretazione

Il controllo HTTP usa un client Dart separato, non lo stesso motore di rete di MediaKit e non la sua sessione cookie. Per questo un campione ricevuto conferma soltanto che quella richiesta separata ha ottenuto dati: non conferma decodifica, uscita audio o funzionamento del player. Viceversa, un 403 del controllo non basta a dimostrare che anche il player abbia ricevuto 403.

Il risultato `segment_bytes_received_not_decode_confirmation` è volutamente esplicito. Per attribuire un problema a Rai, alla rete o al player vanno confrontati tempi, stato HTTP effettivo quando disponibile, log nativo e tentativo successivo. La diagnostica non formula automaticamente una colpa del fornitore.

## Verifiche da eseguire

I test `stream_diagnostics_service_test.dart` coprono lo stato di recupero, il mascheramento dei token, il parsing HLS, un server HTTP locale con redirect e Range ignorato, i limiti dei controlli, il timeout e la cancellazione.

Il test `radio_player_retry_diagnostics_contract_test.dart` verifica l'integrazione dei comandi accessibili, le localizzazioni e la conservazione della chiusura sequenziale. Il contratto Rai esistente continua a controllare audio diretto, fallback ITA, master video e attesa di sei secondi.

Eseguire `flutter analyze` e `flutter test test/stream_diagnostics_service_test.dart test/radio_player_retry_diagnostics_contract_test.dart test/radio_player_rai_direct_audio_fallback_contract_test.dart`, quindi provare su dispositivo reale apertura, Riprova, ritorno indietro durante il caricamento e VoiceOver. I test su HTTP locale non sostituiscono la prova iPhone/MediaKit.
