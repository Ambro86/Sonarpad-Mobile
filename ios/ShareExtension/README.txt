Condivisione video verso Sonarpad

Foto/Fotocamera -> Condividi -> Sonarpad importa un video alla volta.
L'estensione mostra la conferma; l'utente apre poi Sonarpad e sceglie
Apri video oppure Crea audiodescrizione. La stessa scelta viene proposta
per i video ricevuti da altre app su Android.

Configurazione Apple per la prima distribuzione:
1. Registrare l'App Group group.com.ambro86.sonarpad.
2. Abilitarlo per com.ambro86.sonarpad e per il nuovo App ID
   com.ambro86.sonarpad.ShareExtension, nello stesso team Apple.
3. Rigenerare il profilo App Store dell'app e creare quello dell'estensione.
4. Aggiornare IOS_PROVISION_PROFILE_BASE64 e aggiungere il secret GitHub
   IOS_SHARE_PROVISION_PROFILE_BASE64 con il profilo dell'estensione in base64.
   Il workflow TestFlight installa entrambi e verifica l'App Group.

Xcode include gia target, dipendenza, incorporamento, entitlements e risorse.
Per compilazioni locali assegnare lo stesso team ai due target.
Anche una firma alternativa deve mantenere un App Group accessibile a entrambi.

Verifiche su dispositivo:
- Condividere un MOV da Foto con Sonarpad chiuso, aprire Sonarpad e riprodurlo.
- Ripetere con Sonarpad in background e scegliere Crea audiodescrizione:
  il campo sorgente deve contenere il video condiviso.
- Provare Annulla, file con spazi e %, video iCloud e file grandi.
- Verificare VoiceOver: annuncio dell'esito e pulsante Fine nell'estensione;
  titolo e tre azioni nel dialogo dell'app.
- Android: scegliere un video dalla galleria in Documenti e Crea
  audiodescrizione; annullare; selezionare piu video in Documenti.
- Android: condividere due video con lo stesso nome e verificare che
  ciascuno conservi il proprio contenuto; controllare le azioni con TalkBack.

I video vengono copiati come file, senza caricarli interamente in memoria.
L'app vede soltanto importazioni completate. Il file condiviso resta valido
anche dopo la chiusura di Foto e per i progetti di audiodescrizione salvati.
