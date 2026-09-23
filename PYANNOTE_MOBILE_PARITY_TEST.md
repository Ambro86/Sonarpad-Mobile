# Sonarpad — test di parità pyannote Windows/mobile

Questa build mobile include lo stesso file `model.onnx` usato da Sonarpad Windows per la segmentazione vocale pyannote Community-1. Il modello viene verificato prima dell'uso con SHA-256 `6575e57e9375c114545391ffecda0096060df55ae544d40472cdf412d115d35d`.

## Test consigliato

1. In Sonarpad Mobile apri **Audiodescrizioni Sonarpad** e poi **Test pyannote mobile**.
2. Premi **Test rapido pyannote: primi 2 minuti** e scegli un film o un file audio/video.
3. Al termine premi **Condividi WAV canonico e risultato JSON mobile**. Verranno prodotti un WAV PCM16 mono a 16 kHz e un JSON con il risultato mobile.
4. Copia entrambi sul PC Windows. È fondamentale usare su Windows proprio il WAV generato dal telefono: in questo modo il confronto non viene falsato da decoder audio diversi.
5. Nel sorgente Windows apri un prompt nella cartella `bridge\audio_description_runtime` e lancia:

```bat
python tools\export_pyannote_reference.py "C:\percorso\test.canonical.wav" "C:\percorso\test.windows.json"
```

6. Confronta i due JSON:

```bat
python tools\compare_pyannote_parity.py "C:\percorso\test.windows.json" "C:\percorso\test.mobile.json"
```

Il risultato ideale è `RESULT: EXACT PARITY at aggregated-frame level.`. Il comparatore controlla anche SHA-256 del modello, numero di campioni audio, hash dei conteggi di speaker aggregati, primo frame differente, secondi protetti e IoU temporale degli intervalli finali.

## Cosa è stato mantenuto identico a Windows

1. Sample rate 16 kHz, finestra 10 s e passo 1 s.
2. Batch 32, stesso modello ONNX e stesso mapping powerset a 7 classi.
3. 589 frame per finestra, frame duration `0.0619375` e frame step `0.016875`.
4. Aggregazione delle finestre sovrapposte e arrotondamento equivalente a `numpy.rint` (ties-to-even).
5. Conversione dei frame attivi in intervalli e padding finale di 0,25 s.
6. CPU Execution Provider e numero di thread equivalente alla logica Windows: da 1 a 4 in base ai core disponibili.

La pipeline Gemini non è coinvolta in questo test.
