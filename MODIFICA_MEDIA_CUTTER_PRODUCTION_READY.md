# Media Cutter: hardening per la produzione

La pipeline di esportazione del Media Cutter è stata resa difensiva contro file apparentemente riusciti ma privi di tracce, di durata errata o corrotti nei punti di unione.

## Modifiche principali

- FFprobe rileva le tracce reali invece di dedurre il tipo soltanto dall’estensione.
- Nei file con più tracce viene scelta quella contrassegnata come predefinita, con ripiego sulla prima traccia valida.
- Le immagini di copertina `attached_pic` non trasformano un file audio in un falso video.
- Sono gestiti correttamente video senza audio e contenitori MP4/M4A con solo audio.
- Le mappe FFmpeg delle tracce attese non sono più facoltative.
- Tutti i segmenti audio sono normalizzati a AAC/44,1 kHz/stereo nei video e a parametri coerenti negli audio, evitando incompatibilità tra parti con effetti differenti.
- I video sono normalizzati a MPEG-4, `yuv420p` e timescale stabile per l’unione.
- Se la concatenazione con `-c copy` non supera la verifica, Sonarpad ripete automaticamente l’unione ricodificando.
- Ogni segmento viene controllato con FFprobe per tracce e durata.
- Il file finale viene controllato per:
  - dimensione non nulla;
  - presenza delle tracce attese;
  - durata compatibile con il montaggio;
  - decodifica reale all’inizio e alla fine;
  - decodifica attorno ai punti di giunzione, fino a 24 punti campionati.
- Il risultato viene scritto in un file nascosto temporaneo nella cartella di destinazione e pubblicato soltanto dopo la verifica con una rinomina atomica.
- In caso di errore o annullamento, i file temporanei vengono rimossi. Vengono inoltre ripuliti i residui più vecchi di 24 ore lasciati da eventuali arresti improvvisi dell’app.
- Sonarpad controlla che il file sorgente non sia cambiato durante l’esportazione.
- Segmenti sovrapposti, fuori dalla durata sorgente o più brevi di un fotogramma vengono rifiutati con un errore esplicito.
- Gli effetti audio su un video realmente muto vengono ignorati in sicurezza; l’anteprima riproduce il video senza tentare filtri impossibili.
- Il ripiego nella cartella interna dell’app viene usato soltanto per errori di scrittura, non per mascherare errori di codifica o validazione.

## Prove eseguite

Sono stati generati e verificati con FFmpeg/FFprobe:

1. video con audio;
2. video privo di audio;
3. file audio M4A con copertina allegata;
4. due segmenti video con filtri audio differenti uniti con stream copy;
5. filtro audio complesso con split/amix seguito da un secondo effetto;
6. effetto subacqueo con sorgente di bolle e filtro complesso;
7. decodifica di inizio, fine e punto di giunzione del risultato.

Tutti i risultati di prova contengono le tracce previste e una durata coerente.
