# Sonarpad – Localizare română, faza 2 (PARȚIALĂ)

Această arhivă continuă faza 1 și rămâne **parțială**. Scopul fazei 2 este ca limba română să nu fie doar o traducere de interfață, ci să fie folosită efectiv de serviciile care au propria limbă, țară sau localizare.

## Inclus în faza 2

1. Catalogul ARB român rămâne complet, cu toate cele 1269 de chei; 604 mesaje sunt acum traduse/adaptate față de textul englez de bază.
2. Fluxul complet principal pentru audiodescrierea cu IA este tradus în română: activare Sonarpad AI, cheie Gemini, modele, nivel de detaliu, etape de procesare, cote, retry, fallback, cataloage de personaje, reluare și anulare.
3. Româna (`ro`) este acum limbă de ieșire selectabilă în audiodescrierea IA. Promptul AI folosește explicit limba Romanian, exemple românești și locale TTS implicit `ro-RO`.
4. Editorul proiectelor de audiodescriere are propriul set complet de texte românești.
5. Rutele folosesc limba `ro`, țara România cu codul ORS/ISO3 `ROU` și mesaje de eroare românești pentru geocodificare, rutare, autorizare și adrese negăsite.
6. Radio Browser folosește maparea completă `ro` ↔ `romanian`, România este disponibilă ca țară și româna ca limbă.
7. Adăugarea unui radio în comunitatea Sonarpad include `romanian` și, când aplicația este în română, pornește implicit pe limba română și transmite `ui_language=ro`.
8. Interfața Radio, filtrele, genurile, favoritele, programarea înregistrărilor și mesajele de eroare sunt traduse în română.
9. Podcasturile folosesc România ca țară implicită pentru aplicația română și toate cele 111 categorii Apple Podcasts au acum nume românești.
10. Gutenberg și LibriVox au principalele acțiuni și mesaje traduse în română; Gutenberg include deja filtrul de limbă `ro`.
11. Wikipedia are selecția `ro` și acum returnează și erori de căutare/import în română.
12. Meteo geocodifică în limba română și toate codurile principale Open-Meteo au descrieri românești.
13. Cititorul de articole are fallback-uri românești pentru titlu necunoscut, autor și titlu negăsit.
14. Datele relative din liste folosesc `astăzi`, `ieri`, `alaltăieri`, `mâine`, `poimâine`.
15. Vocea Edge preferată pentru limba română este `ro-RO-AlinaNeural`.
16. Changelog-ul român introdus în faza 1 este acum citit explicit și de parserul ChangelogService, inclusiv secțiunile specifice iOS/Android.
17. Înregistrările radio/TV și stările de înregistrare programată sunt traduse în română.
18. Este inclus `test/romanian_localization_phase2_contract_test.dart`, care verifică legarea românei la serviciile principale.

## De completat în faza 3

1. Eliminarea progresivă a celor aproximativ 665 de mesaje care sunt încă identici cu fallback-ul englez; una parte este legitim identică (nume, unități, mărci), dar multe mesaje secundare trebuie încă traduse.
2. Traducerea completă Media Cutter, inclusiv toate efectele, modurile de tăiere, mesajele de previzualizare și erorile rare.
3. Traducerea integrală a Documentelor, editorului, bibliotecii, selecției de paragrafe, EPUB, indexului și exporturilor.
4. Traducerea completă a TV/RaiPlay/La7, cinema, Internet Archive, AIFA și ecranelor secundare.
5. Revizuirea mesajelor rare de SonarTube, TTS, dicționar vocal și accesibilitate.
6. Revizie editorială completă a celor 365 de nume din calendar conform uzului românesc.
7. Rulare `flutter analyze`, `flutter test` și test manual pe iOS/Android; mediul de generare al acestei arhive nu include Flutter/Dart.
8. Revizie lingvistică finală de către un vorbitor nativ român.
