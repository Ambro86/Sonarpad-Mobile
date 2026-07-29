# Asset audio ibridi del Media Cutter

Questa cartella contiene asset audio originali pre-renderizzati appositamente
per Sonarpad. Non incorpora registrazioni o campioni audio di terze parti.

Gli MP3 non sostituiscono il motore DSP: vengono convertiti una sola volta in
PCM float32 nella cache temporanea dell'app e usati dal C++ come portanti o
fondali. Il DSP applica loop con crossfade, ducking sotto la voce, filtri e
limitazione. Se un asset non può essere caricato, resta disponibile il fallback
procedurale integrato nel motore.

## Portanti e fondali vocali

- `choir_bed.mp3`: fondale di vocali senza parole per il Coro.
- `guitar_carrier.mp3`: portante armonica per Chitarra parlante.
- `organ_carrier.mp3`: portante armonica per Organo parlante.
- `old_radio_static.mp3`: fruscio e crepitii per Vecchia radio.

## Ambienti

- `rain_thunder.mp3`: Pioggia e tuoni.
- `jungle_ambience.mp3`: Giungla.
- `crowd_ambience.mp3`: Folla.
- `slot_machines.mp3`: Slot machine.
- `traffic_ambience.mp3`: Traffico.
- `crickets.mp3`: Grillo.
- `sleigh_bells.mp3`: Campanelli.
- `applause.mp3`: Applausi.

Gli asset aggiungono complessivamente circa 3 MB al progetto.
