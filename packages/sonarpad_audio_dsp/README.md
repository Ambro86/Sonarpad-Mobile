# Sonarpad Audio DSP

Motore C++ offline per gli effetti vocali e gli ambienti del Media Cutter.
Elabora file PCM float32 interleaved a durata invariata. FFmpeg rimane
responsabile di decodifica, codifica e remux del video.

Il motore usa algoritmi DSP autocontenuti: vocoder a banca di filtri, pitch
shifting a ritardo variabile, chorus multivoce, filtri, delay, saturazione e
generatori procedurali. Non scarica codice o modelli durante la build o a runtime.

La chiamata di elaborazione valida il PCM, impedisce di sovrascrivere il file
di ingresso, rimuove automaticamente le uscite parziali e può essere annullata
tramite `SonarpadAudioDsp.cancelActive()`.
