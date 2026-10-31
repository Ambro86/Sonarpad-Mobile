/// Like travel strings, use English as fallback outside the Italian catalogue UI.
class TicketOneStrings {
  TicketOneStrings(this.locale);
  final String locale;
  String t(String key) =>
      (locale.split(RegExp('[-_]')).first == 'it' ? _it[key] : _en[key])!;
  static int? otpDigitIndex(String label) {
    const digits = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth'];
    final match = RegExp(
      r'^(first|second|third|fourth|fifth|sixth) digit$',
      caseSensitive: false,
    ).firstMatch(label.trim());
    if (match == null) return null;
    return digits.indexOf(match[1]!.toLowerCase());
  }

  String fieldLabel(String label) {
    final index = otpDigitIndex(label);
    if (index == null) return label;
    final number = index + 1;
    return locale.split(RegExp('[-_]')).first == 'it'
        ? 'Cifra $number'
        : 'Digit $number';
  }

  static const _it = {
    'disabilityContactInstructions': 'Leggi le istruzioni ufficiali',
    'disabilityContactEmail': 'Scrivi un’email',
    'disabilityChooseOrganiser': 'Scegli organizzatore o struttura',
    'disabilityChooseHelp':
        'Scegli soltanto l’organizzatore indicato per il concerto o la struttura che lo ospita. Non tutti gli eventi seguono la stessa procedura. Le istruzioni ufficiali indicano requisiti e contatti: verifica artista, luogo e data prima di inviare una richiesta.',
    'disabilityTitle': 'Accesso per persone con disabilità',
    'disabilityHelp':
        'Le richieste di posti riservati e di accesso con accompagnatore sono gestite dall’organizzatore dell’evento. Consulta le istruzioni prima di acquistare un biglietto ordinario.',
    'disabilityOrganiser': 'Organizzatore indicato da TicketOne',
    'disabilityUnknownOrganiser':
        'L’organizzatore non è ancora stato letto. Lo trovi nelle informazioni della pagina del concerto.',
    'disabilityConditions':
        'Le condizioni dipendono dall’evento e dalle esigenze di accesso, anche per persone cieche o ipovedenti. Non tutte le richieste riguardano la carrozzina. Verifica direttamente requisiti, documenti, accompagnatore, prezzi e disponibilità: Sonarpad non determina il diritto all’agevolazione.',
    'disabilityVivoHelp':
        'Vivo Concerti indica info@vivoconcerti.com per informazioni sull’accesso. Il pulsante email apre una bozza: sarai tu a scriverla e inviarla.',
    'disabilityOfficialInstructions':
        'Leggi le istruzioni ufficiali di Vivo Concerti',
    'disabilityWriteOrganiser': 'Scrivi a Vivo Concerti',
    'disabilityCalendarHelp':
        'Mani Amiche pubblica un calendario di accrediti che comprende eventi di Vivo Concerti. Cerca lo stesso artista, città e data: il collegamento non conferma che il tuo evento sia presente o che vi siano posti. Il modulo ufficiale può richiedere certificato, dati dell’accompagnatore e verifica CAPTCHA.',
    'disabilityCalendar': 'Apri il calendario accrediti di Mani Amiche',
    'disabilityDirectory': 'Apri informazioni e contatti ufficiali TicketOne',
    'disabilityReadOrganiser':
        'Leggi l’organizzatore sulla pagina del concerto',
    'disabilityRequestNotice':
        'Una richiesta di accredito non equivale a una prenotazione confermata. Attendi la risposta del servizio competente. Sonarpad non invia richieste o documenti automaticamente.',

    'concertWelcomeTitle': 'Benvenuti nella ricerca concerti ed eventi',
    'concertWelcome1':
        'Benvenuti nella ricerca concerti ed eventi di Sonarpad. Con questa funzione potete cercare concerti, sport e altri eventi e proseguire con l’acquisto dei biglietti tramite TicketOne o il servizio indicato per l’evento.',
    'concertWelcome2':
        'L’autore, coerentemente con lo spirito di servizio di Sonarpad, non percepisce commissioni sui vostri acquisti e non utilizza codici di affiliazione.',
    'concertWelcome3':
        'Sonarpad mostra i prezzi restituiti dal servizio, senza aggiungere maggiorazioni. Prezzi e disponibilità possono cambiare: prima di pagare, controllate su TicketOne o sul servizio di vendita il totale definitivo, comprese eventuali commissioni e servizi aggiuntivi.',
    'concertWelcome4':
        'Sonarpad è un facilitatore: presenta la ricerca e la compilazione dei dati nel modo più semplice e accessibile possibile. Non vende i biglietti e non gestisce gli acquisti. Per assistenza dopo l’acquisto, modifiche, cancellazioni o rimborsi, rivolgetevi a TicketOne, al venditore o all’organizzatore indicato nella conferma dell’acquisto, secondo le condizioni del biglietto.',
    'concertWelcome5':
        'Premendo Accetta confermate di aver letto queste informazioni. La scelta sarà ricordata su questo dispositivo. Premendo Rifiuta uscirete dalla ricerca concerti ed eventi.',
    'accept': 'Accetta',
    'decline': 'Rifiuta',
    'welcomeSaveError':
        'Non è stato possibile salvare la scelta. Riprova con Accetta.',
    'otpHeading': 'Codice monouso',
    'otpComplete': 'Codice completo: tutte le sei cifre sono inserite.',
    'ticketsUnavailable': 'Biglietti attualmente non disponibili',
    'websiteTitle': 'Pagina TicketOne',
    'accessDenied':
        'Il server TicketOne ha rifiutato questa richiesta. Non posso confermare che l’operazione sia riuscita. Non invio nuovamente i dati: puoi aprire la pagina TicketOne per verificare.',
    'securityCheck':
        'TicketOne sta effettuando un controllo di sicurezza. Apri la pagina TicketOne per seguirlo o completarlo, poi torna alla modalità accessibile. L’aggiunta al carrello non è ancora confermata; non viene ripetuta automaticamente.',
    'bestSeatHelp':
        'Assegnazione automatica: scegli categoria e quantità. Per i posti numerati, TicketOne assegna i posti disponibili e mostra settore, fila e posto nel carrello, prima del pagamento.',
    'actionUncertain':
        'TicketOne non ha confermato l’esito. Non reinvio i dati: aggiorna la lettura della pagina o apri TicketOne per verificare cosa è successo.',
    'paypalContinue': 'Apri il pulsante PayPal per completare il pagamento',
    'nativeMode': 'Modalità accessibile Sonarpad',
    'nativeUnavailable':
        'Questa parte della pagina non è ancora disponibile in modalità accessibile. Puoi aggiornare la lettura o aprire la pagina TicketOne.',
    'invalidField': 'Controlla il campo:',
    'cookiesFailed':
        'Non è stato possibile chiudere il banner dei cookie. Nessun modulo inviato. Puoi riprovare o aprire TicketOne.',
    'cookieConsent':
        'Premendo un pulsante di invio o continua, Sonarpad accetta tutti i cookie della pagina e invia i dati a TicketOne.',
    'check': 'Verifica accesso TicketOne',
    'signedIn': 'Accesso a TicketOne confermato',
    'signedOut': 'Accedi o completa la registrazione sul sito TicketOne.',
    'continue': 'Continua con il concerto selezionato',
    'cart': 'Carrello TicketOne',
    'tickets': 'Biglietti',
    'total': 'Totale attuale',
    'checkout': 'Continua sul sito TicketOne con questo carrello',
    'site': 'Torna alla pagina TicketOne',
    'unavailable':
        'Non riesco a verificare la sessione. Puoi riprovare o continuare sul sito TicketOne.',
    'help':
        'La sessione rimane nel browser di Sonarpad. I controlli riconosciuti vengono presentati in modalità accessibile; per mappe dei posti e pagamenti può servire la pagina TicketOne. Nessun pagamento automatico.',
    'empty': 'Il carrello è vuoto.',
  };
  static const _en = {
    'disabilityContactInstructions': 'Read official instructions',
    'disabilityContactEmail': 'Write an email',
    'disabilityChooseOrganiser': 'Choose organiser or venue',
    'disabilityChooseHelp':
        'Choose only the organiser listed for your concert or the venue hosting it. Procedures vary by event. Official instructions explain requirements and contacts: check artist, venue and date before sending a request.',
    'disabilityTitle': 'Access for people with disabilities',
    'disabilityHelp':
        'Requests for reserved places and companion access are handled by the event organiser. Read the instructions before purchasing a regular ticket.',
    'disabilityOrganiser': 'Organiser listed by TicketOne',
    'disabilityUnknownOrganiser':
        'The organiser has not been read yet. You can find it in the concert page information.',
    'disabilityConditions':
        'Conditions depend on the event and access needs, including those of blind or partially sighted people. Not all requests concern wheelchairs. Check eligibility, documents, companion arrangements, prices and availability directly: Sonarpad does not decide eligibility.',
    'disabilityVivoHelp':
        'Vivo Concerti lists info@vivoconcerti.com for access enquiries. The email button opens a draft for you to write and send.',
    'disabilityOfficialInstructions':
        'Read the official Vivo Concerti instructions',
    'disabilityWriteOrganiser': 'Write to Vivo Concerti',
    'disabilityCalendarHelp':
        'Mani Amiche publishes an accreditation calendar including Vivo Concerti events. Find the same artist, city and date: this link does not confirm that your event is listed or places are available. The official form may require a certificate, companion details and a CAPTCHA.',
    'disabilityCalendar': 'Open the Mani Amiche accreditation calendar',
    'disabilityDirectory': 'Open official TicketOne information and contacts',
    'disabilityReadOrganiser': 'Read the organiser on the concert page',
    'disabilityRequestNotice':
        'An accreditation request is not a confirmed reservation. Wait for a reply from the responsible service. Sonarpad does not automatically send requests or documents.',

    'concertWelcomeTitle': 'Welcome to concert and event search',
    'concertWelcome1':
        'Welcome to Sonarpad concert and event search. You can find concerts and continue purchasing tickets through TicketOne or the service listed for the event.',
    'concertWelcome2':
        'In keeping with Sonarpad’s spirit of service, its author receives no commission on your purchases and uses no affiliate codes.',
    'concertWelcome3':
        'Sonarpad displays the prices returned by the service without adding markups. Prices and availability can change: before paying, check the final total on TicketOne or the ticket seller’s service, including any fees and optional extras.',
    'concertWelcome4':
        'Sonarpad is a facilitator: it makes searching and entering information as simple and accessible as possible. It does not sell tickets or manage purchases. For assistance, changes, cancellations or refunds after purchasing, contact TicketOne, the seller or the organiser named in your purchase confirmation, according to the ticket conditions.',
    'concertWelcome5':
        'By selecting Accept, you confirm that you have read this information. Your choice will be remembered on this device. Decline exits concert and event search.',
    'accept': 'Accept',
    'decline': 'Decline',
    'welcomeSaveError': 'Unable to save your choice. Please try Accept again.',
    'otpHeading': 'One-time code',
    'otpComplete': 'Code complete: all six digits have been entered.',
    'ticketsUnavailable': 'Tickets currently unavailable',
    'websiteTitle': 'TicketOne page',
    'accessDenied':
        'The TicketOne server denied this request. The operation cannot be confirmed. Your data will not be sent again: open the TicketOne page to check.',
    'securityCheck':
        'TicketOne is performing a security check. Open the TicketOne page to follow or complete it, then return to accessible mode. Adding tickets to the cart is not confirmed yet and will not be retried automatically.',
    'bestSeatHelp':
        'Automatic allocation: choose a category and quantity. For numbered seating, TicketOne assigns available seats and shows the section, row and seat in the cart before payment.',
    'actionUncertain':
        'TicketOne has not confirmed the result. The data will not be resent: refresh the page controls or open TicketOne to check what happened.',
    'paypalContinue': 'Open the PayPal button to complete payment',
    'nativeMode': 'Sonarpad accessible mode',
    'nativeUnavailable':
        'This part of the page is not yet available in accessible mode. Refresh the controls or open the TicketOne page.',
    'invalidField': 'Check this field:',
    'cookiesFailed':
        'Unable to close the cookie banner. No form was submitted. Retry or open TicketOne.',
    'cookieConsent':
        'Pressing a submit or continue button accepts all cookies on the page and sends the data to TicketOne.',
    'check': 'Check TicketOne sign-in',
    'signedIn': 'Signed in to TicketOne',
    'signedOut': 'Sign in or complete registration on the TicketOne website.',
    'continue': 'Continue with the selected concert',
    'cart': 'TicketOne cart',
    'tickets': 'Tickets',
    'total': 'Current total',
    'checkout': 'Continue on TicketOne with this cart',
    'site': 'Return to the TicketOne page',
    'unavailable':
        'Unable to verify the session. Retry or continue on TicketOne.',
    'help':
        'Your session stays in Sonarpad’s browser. Recognized controls are shown in accessible mode; seat maps and payment may require the TicketOne page. No automatic payment.',
    'empty': 'Your cart is empty.',
  };
}
