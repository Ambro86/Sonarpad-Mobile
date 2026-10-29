# Sonarpad – Localizare română, faza 3 (PARȚIALĂ)

Această arhivă continuă faza 2 și rămâne **parțială**, dar acoperirea interfeței este acum aproape completă.

## Inclus în faza 3

1. Catalogul ARB român rămâne complet cu 1269 de chei, iar 1188 mesaje sunt acum traduse/adaptate față de baza engleză.
2. Biblioteca Documente este tradusă aproape integral: import, foldere, mutare, editor, selecția paragrafelor, căutare, cuprins EPUB, semne de carte, parole, export TXT/PDF/DOCX/EPUB și mesaje de eroare.
3. Media Cutter este tradus aproape integral: mod ghidat și avansat, împărțiri, editarea preciziei, previzualizare, volum, piste suplimentare, export și toate efectele audio principale.
4. Convertirea media este tradusă integral, inclusiv validări, formate și erori.
5. Dicționarul de pronunție, donațiile, Wikipedia, importul RSS/OPML și cititorul de articole au primit traduceri suplimentare.
6. Podcasturile au acum playerul, abonarea, istoricul/cache-ul și acțiunile episodului în română.
7. Cinema și Internet Archive sunt traduse, inclusiv trailerele și sursele externe.
8. Ecranele pentru concerte/evenimente, exportul cărților audio, jurnalele de sistem și raportarea către dezvoltator sunt traduse.
9. Au fost traduse și numeroase mesaje secundare pentru Dropbox, Gutenberg, LibriVox, PoetryDB, înregistrări și accesibilitate.
10. Textele AIFA/parafarmacie și unele texte TV au fost traduse doar pentru completitudinea catalogului; logica de disponibilitate nu a fost modificată.

## Servicii exclusiv italiene – protecție explicită

RaiPlay, RaiPlay Sound, LA7 Play, TV cu cod, Audiodescrizioni/Audiodescrizioni Sonarpad, biblioteca digitală italiană, orari di apertura, ItaliaOnline și AIFA rămân în blocul `if (isItalian)` existent. Limba română nu le face vizibile chiar dacă un cod secret este valid.

Este inclus testul `test/romanian_localization_phase3_contract_test.dart`, care verifică explicit această regulă și verifică și faptul că comportamentul italian rămâne neschimbat.

## De completat în faza 4

1. Revizuirea celor aproximativ 81 de mesaje încă identice cu engleza. Multe sunt intenționat identice (mărci, formate, unități și termeni internaționali), dar grupul de instrumente tehnice Pyannote pentru dezvoltatori trebuie încă tradus.
2. Revizie editorială finală pentru formulări, pluraluri și terminologie românească în tot catalogul.
3. Revizie finală a calendarului celor 365 de zile și a numelor de sfinți/sărbători.
4. Rulare `flutter analyze`, `flutter test` și teste manuale VoiceOver/TalkBack pe dispozitiv; mediul de generare al acestei arhive nu include Flutter/Dart.
5. Revizie lingvistică finală de către un vorbitor nativ român.
