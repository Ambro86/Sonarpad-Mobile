# Sonarpad – Localizare română, faza 1 (PARȚIALĂ)

Această arhivă este **faza 1** a localizării românești și nu reprezintă încă traducerea integrală finală.

## Inclus în faza 1

1. Limba `Română` poate fi selectată din setări și poate fi detectată automat din limba dispozitivului.
2. Structura ARB română conține toate cheile existente în localizarea italiană, pentru a evita chei lipsă la compilare.
3. Interfața principală, setările, știrile, SonarTube, playerul, podcasturile, calendarul, vremea și rutele au un prim bloc consistent de traduceri românești.
4. Google News este configurat pentru România (`hl=ro`, `gl=RO`, `ceid=RO:ro`) și sunt incluse surse românești precum Digi24, Știrile ProTV, HotNews, AGERPRES, G4Media, Libertatea, Adevărul, Observator News, Profit.ro și Recorder.
5. Changelog-ul are traducere română pentru toate versiunile și toate intrările existente.
6. Calendarul român conține 365 de intrări de sfinți/sărbători, sărbători legale românești și toate cele 128 de citate traduse în română.
7. Podcasturile, radioul, rutele, Wikipedia, Gutenberg și TMDB folosesc valori implicite românești când limba aplicației este română.
8. iOS include `ro` în localizările bundle-ului și texte românești pentru permisiunile sistemului.
9. Backend-ul surselor comunitare de știri acceptă limba română.
10. Este inclus un test contractual dedicat fazei 1 a localizării românești.

## De completat în faza 2

1. Traducerea manuală a tuturor mesajelor secundare care în această fază folosesc încă fallback-ul englez.
2. Media Cutter și toate mesajele avansate ale efectelor audio.
3. Fluxurile complete de audiodescriere IA și mesajele de diagnostic/eroare mai rare.
4. Documente, biblioteci, radio/TV și alte ecrane secundare, inclusiv textele mai puțin frecvente.
5. Revizuire editorială completă a celor 365 de nume de sfinți/sărbători conform uzului românesc; în faza 1 baza zilnică este completă, dar o parte dintre nume provine din normalizarea bazei italiene.
6. Control final pe un dispozitiv iOS cu VoiceOver și revizie lingvistică de către un vorbitor nativ.
