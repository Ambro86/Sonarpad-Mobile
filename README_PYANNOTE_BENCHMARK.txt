SONARPAD MOBILE - PYANNOTE BENCHMARK 10 MINUTI

1. Estrarre questo ZIP sopra la cartella principale di sonarpad_mobile_starter.
2. Da prompt, nella cartella principale del progetto, eseguire:

   python tools\apply_pyannote_benchmark_setup.py

3. Poi verificare:

   flutter analyze lib

4. Il nuovo pulsante si trova in:
   Audiodescrizioni Sonarpad > Test pyannote mobile

   Pulsante: Benchmark pyannote: primi 10 minuti

Il benchmark usa solo i primi 600 secondi del film e NON modifica la pipeline di produzione.
Prova CPU con più batch/thread/livelli di ottimizzazione, CoreML e configurazioni aggressive con step 1.5/2/2.5 secondi.
Ogni configurazione viene confrontata con il riferimento CPU batch 32 / 4 thread / step 1.0.

Nel log cercare:
PYANNOTE[BENCH][RESULT]
PYANNOTE[BENCH][SUMMARY]

Per ogni configurazione vengono registrati: tempo sessione, tempo inferenza, tempo totale, speedup, hash frame, exact match, numero frame diversi, primo frame diverso, delta massimo speaker-count, secondi protetti, delta secondi protetti e IoU temporale degli intervalli.

CoreML: viene usato il CoreML Execution Provider di ONNX Runtime. Non è Google ML Kit.
