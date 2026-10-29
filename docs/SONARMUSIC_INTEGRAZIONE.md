# SonarMusic (0.5.1) — integrazione

SonarMusic è una schermata autonoma (`/sonarmusic`) con accessibilità UIKit/Flutter condivisa con SonarTube. SonarTube non è stato modificato e mantiene il proprio resolver.

Il resolver fornito dall’utente è incluso in `server/youtube_music_resolve.php` e va installato sul dominio Sonarpad esattamente come `https://sonarpad.com/api/youtube_music_resolve.php`. Non sovrascrivere `youtube_resolve.php`. Lo stesso header `X-Sonarpad-Route-Token` già usato da SonarTube viene inviato da SonarMusic; assicurarsi che il token configurato sul server corrisponda al valore compilato con `--dart-define=SONARPAD_ROUTE_CLIENT_TOKEN=...` o alla configurazione della build esistente. Non inserire token segreti nel repository pubblico.

Ricerca e apertura di raccolte provano prima la navigazione diretta WEB_REMIX da Dart; il PHP è il fallback. La riproduzione usa prima la risoluzione diretta di SonarTube da Dart e, se non riesce, il resolver Music sul dominio Sonarpad. I collegamenti video mantengono ID pubblici, non URL media temporanei.

Preferiti e cronologia sono distinti da quelli di SonarTube. Il player e la procedura di esportazione MP3/MP4 vengono riutilizzati. L’azione Salva media viene mostrata solo agli utenti con codice abilitante già riconosciuto da RecordingFeatureAccess. I contenuti musicali non sono scaricati automaticamente in background.

La funzione lavora con API YouTube Music non ufficiali. I risultati e la disponibilità degli stream dipendono dal servizio remoto; alcuni contenuti e alcune pagine potrebbero non essere disponibili. Verificare i termini della piattaforma prima della distribuzione pubblica.

Test inclusi: `flutter test test/sonarmusic_service_test.dart`. Prima della pubblicazione: `flutter analyze` e test VoiceOver su iPhone, apertura brani, album, playlist, cambio traccia, pulsanti secondari e salvataggio media autorizzato. La presente consegna non include il collaudo su dispositivo.
