# Correzione Media Cutter: video salvato a 0 secondi

## Diagnosi dal log del 26 luglio 2026

Il taglio era valido:

- file originale: circa 2 minuti e 50 secondi;
- parte mantenuta: da 3,613 secondi a 55,615 secondi;
- durata prevista del risultato: 52,002 secondi;
- FFmpeg terminava con `returnCode=0`.

Il comando di esportazione conteneva però contemporaneamente:

- `-map 0:v:0?`, che seleziona il video;
- `-vn`, che disattiva ed elimina il video.

`-vn` prevaleva sulla mappatura e il file MP4 risultava privo della traccia video. Su iOS questo poteva apparire come video di 0 secondi e senza riproduzione utile, anche se FFmpeg considerava tecnicamente completata l'operazione.

## Modifiche

- `-vn` viene aggiunto soltanto quando il file di origine è realmente audio.
- Nei video vengono conservate sia la prima traccia video sia la prima traccia audio disponibile.
- Gli MP4 usano `-movflags +faststart`, così indice, durata e tracce sono leggibili immediatamente da iOS.
- Dopo ogni segmento video, Sonarpad controlla che il file esista, non sia vuoto e contenga una traccia video decodificabile.
- Se la verifica fallisce, il salvataggio viene interrotto con errore invece di copiare un MP4 difettoso nella cartella finale.
- Aggiornato il changelog 0.3.2 in tutte le lingue disponibili.

## Nuove righe utili nel log

In caso di successo:

```text
Media cutter: export segment created ... expectedVideo=true
Media cutter ffmpeg validate video segment ... completed returnCode=0
Media cutter: export video segment validated ...
```

Il comando di esportazione di un video non deve più contenere `-vn`.
