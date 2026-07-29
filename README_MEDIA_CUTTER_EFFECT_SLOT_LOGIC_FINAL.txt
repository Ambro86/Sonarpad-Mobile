Media Cutter - logica finale slot effetti audio

Modifica richiesta:
- All'apertura degli effetti deve apparire solo lo slot vuoto Effetto audio 1.
- Dopo aver impostato Effetto audio 1, deve apparire Effetto audio 2 vuoto.
- Toccando uno slot pieno, per esempio Effetto audio 1, si modifica solo quello slot.
- La modifica di uno slot pieno non deve mai creare automaticamente uno slot successivo ulteriore.
- Lo slot successivo appare solo quando viene riempito lo slot vuoto corrente.

Esempi attesi:
1) Nessun effetto:
   Effetto audio 1

2) Effetto audio 1 = Echo leggero:
   Effetto audio 1 Echo leggero
   Effetto audio 2

3) Modifico Effetto audio 1 da Echo leggero a Elicottero:
   Effetto audio 1 Elicottero
   Effetto audio 2
   Non compare Effetto audio 3.

4) Imposto Effetto audio 2:
   Effetto audio 1 Elicottero
   Effetto audio 2 Tunnel
   Effetto audio 3

File modificato:
- lib/screens/media_cutter_screen.dart

Nota:
Non sono state toccate esportazione, FFmpeg, taglio guidato, taglio avanzato o riproduzione.
