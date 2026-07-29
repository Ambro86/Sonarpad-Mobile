# Effetti DSP con asset audio ibridi

Il Media Cutter usa ora una pipeline ibrida per gli effetti che beneficiano di
una sorgente timbrica o ambientale più ricca:

1. Flutter copia l'MP3 incluso nel bundle nella cache temporanea.
2. FFmpeg lo converte una sola volta in PCM float32 stereo a 44.100 Hz.
3. Il motore C++ riceve sia la voce sia il PCM dell'asset.
4. Il C++ applica vocoder, coro, crossfade del loop e ducking sotto la voce.
5. FFmpeg codifica e rimonta il risultato usando la pipeline production-ready.

Sono coperti Coro, Vecchia radio, Chitarra parlante, Organo parlante, Pioggia e
tuoni, Giungla, Folla, Slot machine, Traffico, Grillo, Campanelli e Applausi.

Gli asset sono originali e pre-renderizzati per questo progetto; non sono stati
incorporati campioni di terze parti. In assenza o in caso di errore di un asset,
il C++ usa automaticamente il precedente generatore procedurale.

La firma FFI è stata portata alla versione 2 e accetta un percorso asset
opzionale. Anteprima ed esportazione passano dalla stessa funzione.
