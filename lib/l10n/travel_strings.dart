/// Travel UI uses Italian and English; other locales use English labels while
/// city names, provider content, dates and country names follow the app locale.
class TravelStrings {
  TravelStrings(this.locale);
  final String locale;
  String get language => locale.split(RegExp('[-_]')).first;
  String t(String key) =>
      (language == 'it' ? _it[key] : _en[key]) ?? _en[key] ?? key;
  String get defaultCountry => locale == 'pt_BR'
      ? 'BR'
      : const {
              'it': 'IT',
              'en': 'GB',
              'fr': 'FR',
              'de': 'DE',
              'es': 'ES',
              'pt': 'PT',
              'pl': 'PL',
              'cs': 'CZ',
              'uk': 'UA',
              'ro': 'RO',
              'tr': 'TR',
              'zh': 'CN',
            }[language] ??
            'IT';
  static const _it = {
    'title': 'Ricerca viaggi',
    'welcomeTitle': 'Benvenuti nella ricerca viaggi',
    'welcome1':
        'Benvenuti nella ricerca viaggi di Sonarpad. Con questa funzione potete cercare viaggi in treno, aereo e pullman e proseguire con l’acquisto sul servizio a cui Sonarpad si appoggia, Omio.',
    'welcome2':
        'L’autore, coerentemente con lo spirito di servizio di Sonarpad, non percepisce commissioni sui vostri acquisti e non utilizza codici di affiliazione.',
    'welcome3':
        'Sonarpad mostra i prezzi restituiti dal servizio, senza aggiungere maggiorazioni. Prezzi e disponibilità possono cambiare: prima di pagare, controllate su Omio il totale definitivo, comprese eventuali commissioni e servizi aggiuntivi.',
    'welcome4':
        'Sonarpad è un facilitatore: presenta la ricerca e la compilazione dei dati nel modo più semplice e accessibile possibile. Non vende i biglietti e non gestisce gli acquisti. Per assistenza dopo l’acquisto, modifiche, cancellazioni o rimborsi, rivolgetevi al servizio o al vettore indicato nella conferma della prenotazione, secondo le condizioni della tariffa acquistata.',
    'welcome5':
        'Premendo Accetta confermate di aver letto queste informazioni. La scelta sarà ricordata su questo dispositivo. Premendo Rifiuta uscirete dalla funzione viaggi.',
    'accept': 'Accetta',
    'decline': 'Rifiuta',
    'welcomeSaveError':
        'Non è stato possibile leggere o salvare la scelta. Riprova con Accetta.',
    'new': 'Cerca un nuovo viaggio',
    'recent': 'Viaggi recenti',
    'currency': 'Valuta',
    'country': 'Paese preferito per i suggerimenti',
    'from': 'Città di partenza',
    'to': 'Città di arrivo',
    'mode': 'Mezzo',
    'train': 'Treno',
    'flight': 'Aereo',
    'bus': 'Pullman',
    'outbound': 'Andata',
    'return': 'Ritorno',
    'roundtrip': 'Andata e ritorno',
    'day': 'Giorno',
    'month': 'Mese',
    'year': 'Anno',
    'passengers': 'Numero di passeggeri',
    'age': 'Età alla partenza del passeggero',
    'search': 'Avvia ricerca',
    'working': 'Ricerca in corso…',
    'passengerLoading': 'Caricamento in corso…',
    'cancelLoading': 'Annulla',
    'filterList': 'Filtra l’elenco per iniziale',
    'filterNoResults': 'Nessun risultato',
    'filterResults': '{count} risultati disponibili',
    'filterRetained': 'Scelta conservata',
    'cancelLoadingHelp':
        'Annulla interrompe l’attesa. I dati già inviati a Omio non vengono ritirati.',
    'chooseFrom': 'Scegli la città di partenza',
    'chooseTo': 'Scegli la città di arrivo',
    'noCity': 'Nessuna città trovata. Modifica il nome e riprova.',
    'invalid':
        'Controlla le città e le date: la partenza non può essere nel passato e il ritorno deve seguire l’andata.',
    'sameCity': 'Scegli due città diverse.',
    'results': 'Risultati',
    'partial':
        'Risultati provvisori. Puoi scegliere un viaggio o aggiornare la ricerca.',
    'empty': 'Nessun viaggio disponibile.',
    'waiting':
        'La ricerca è ancora in corso. Aggiorna per controllare i risultati.',
    'refresh': 'Aggiorna risultati',
    'next': 'Risultati successivi',
    'previous': 'Risultati precedenti',
    'changes': 'Cambi',
    'fares': 'Scegli la tariffa',
    'group': 'Tratta',
    'fare': 'Tariffa',
    'continue': 'Continua per inserire i dati',
    'passengerData': 'Dati dei passeggeri',
    'chooseValue': 'Seleziona un valore',
    'forgetPassenger': 'Cancella i dati passeggero ricordati',
    'passengerForgotten':
        'Dati passeggero ricordati cancellati dal dispositivo.',
    'notProvided': 'Non compilato',
    'passenger': 'Passeggero',
    'nextField': 'Continua',
    'optional': 'Facoltativo',
    'optionalHint':
        'Compila i dati di questo passeggero. Puoi lasciare vuoti i campi facoltativi.',
    'stateChooseCountry':
        'Seleziona prima il paese per caricare le province o gli stati.',
    'required': 'Obbligatorio',
    'skip': 'Salta questo campo',
    'checkData':
        'Controlla i dati prima di inviarli a Omio. Nessun pagamento automatico.',
    'sendData': 'Conferma e invia i dati a Omio',
    'editData': 'Modifica i dati',
    'invalidField': 'Controlla il valore di questo campo.',
    'ageMismatch':
        'La data di nascita non coincide con l’età indicata nella ricerca.',
    'unsupportedForm':
        'Questo campo richiede il sito Omio. Puoi completare lì i dati.',
    'phonePrefix': 'Prefisso internazionale, ad esempio +39',
    'phoneNumber': 'Numero nazionale',
    'phoneCountry': 'Paese del telefono',
    'submitted': 'Dati inviati. Il pagamento va completato da te su Omio.',
    'submitUncertain':
        'Invio non confermato. Controlla su Omio senza inviare nuovamente i dati.',
    'statusRefresh': 'Controlla se il checkout è pronto',
    'openCheckout': 'Apri il checkout Omio',
    'paymentChoice': 'Scegli il metodo di pagamento',
    'paymentChoiceHelp':
        'Scegli un metodo disponibile su Omio. Si aprirà la pagina per verificare il totale, le protezioni e completare il pagamento. Nessun pagamento viene eseguito automaticamente.',
    'paymentCard': 'Carta di credito o debito',
    'paymentUnavailable':
        'Non riesco a leggere i metodi disponibili. Puoi proseguire sulla pagina Omio.',
    'paymentSelectOnSite':
        'Selezione non confermata: verifica il metodo sulla pagina Omio.',
    'paymentOpenSite': 'Apri la pagina Omio completa',
    'omioBrowser': 'Omio',
    'browserLoading': 'Caricamento della pagina Omio',
    'externalBrowser': 'Apri nel browser esterno',
    'webBack': 'Pagina precedente',
    'browserError':
        'Impossibile aprire questa pagina. Se necessario, usa Apri nel browser esterno.',
    'bookingUnavailable':
        'Prenotazione scaduta o non disponibile. Avvia una nuova ricerca.',
    'handoff': 'Riepilogo del viaggio',
    'handoffInfo':
        'Continua crea una prenotazione temporanea e apre i dati dei passeggeri in Sonarpad. Controllerai il totale finale su Omio. Nessun pagamento automatico.',
    'open': 'Apri Omio',
    'bookingError':
        'Non è stato possibile confermare l’esito. Non ripetere la prenotazione: riprova l’apertura solo se il collegamento è disponibile.',
    'error': 'Il servizio non è disponibile. Riprova tra poco.',
    'expired':
        'Sessione scaduta o accesso non autorizzato. Avvia una nuova ricerca.',
    'configuration':
        'Servizio viaggi non configurato in questa versione dell’app.',
    'retry': 'Riprova',
    'noRecent': 'Nessun viaggio recente.',
    'clear': 'Cancella viaggi recenti',
    'recentInfo':
        'Seleziona un viaggio per riaprire il modulo e controllare le date. Prezzi e disponibilità verranno cercati di nuovo.',
    'reference': 'Riferimento assistenza',
    'page': 'Pagina',
    'priceUnavailable': 'Prezzo non disponibile',
    'linkError': 'Impossibile aprire il collegamento Omio. Riprova.',
  };
  static const _en = {
    'title': 'Travel search',
    'welcomeTitle': 'Welcome to travel search',
    'welcome1':
        'Welcome to Sonarpad travel search. You can search for train, flight and bus journeys and proceed with your purchase through Omio, the service used by Sonarpad.',
    'welcome2':
        'In keeping with Sonarpad’s spirit of service, its author receives no commission on your purchases and uses no affiliate codes.',
    'welcome3':
        'Sonarpad displays prices returned by the service without adding a markup. Prices and availability may change: before paying, check the final total on Omio, including any fees and optional services.',
    'welcome4':
        'Sonarpad helps make searching and entering passenger details as simple and accessible as possible. It does not sell tickets or manage purchases. For assistance after purchase, changes, cancellations or refunds, contact the service or carrier identified in your booking confirmation, subject to the conditions of your fare.',
    'welcome5':
        'By selecting Accept, you confirm that you have read this information. Your choice will be remembered on this device. Selecting Decline closes travel search.',
    'accept': 'Accept',
    'decline': 'Decline',
    'welcomeSaveError':
        'Your choice could not be read or saved. Try Accept again.',
    'new': 'Search for a new journey',
    'recent': 'Recent journeys',
    'currency': 'Currency',
    'country': 'Preferred country for suggestions',
    'from': 'Departure city',
    'to': 'Arrival city',
    'mode': 'Transport',
    'train': 'Train',
    'flight': 'Flight',
    'bus': 'Bus',
    'outbound': 'Outbound',
    'return': 'Return',
    'roundtrip': 'Return journey',
    'day': 'Day',
    'month': 'Month',
    'year': 'Year',
    'passengers': 'Number of passengers',
    'age': 'Age at departure for passenger',
    'search': 'Search',
    'working': 'Searching…',
    'passengerLoading': 'Loading…',
    'cancelLoading': 'Cancel',
    'filterList': 'Filter list by first letters',
    'filterNoResults': 'No results',
    'filterResults': '{count} results available',
    'filterRetained': 'Saved selection',
    'cancelLoadingHelp':
        'Cancel stops waiting. Data already sent to Omio is not withdrawn.',
    'chooseFrom': 'Choose departure city',
    'chooseTo': 'Choose arrival city',
    'noCity': 'No city found. Edit the name and try again.',
    'invalid':
        'Check cities and dates: departure cannot be in the past and return must be on or after departure.',
    'sameCity': 'Choose two different cities.',
    'results': 'Results',
    'partial': 'Provisional results. Choose a journey or refresh the search.',
    'empty': 'No journeys available.',
    'waiting': 'Search is still running. Refresh to check the results.',
    'refresh': 'Refresh results',
    'next': 'Next results',
    'previous': 'Previous results',
    'changes': 'Changes',
    'fares': 'Choose fare',
    'group': 'Journey group',
    'fare': 'Fare',
    'continue': 'Continue to enter passenger details',
    'passengerData': 'Passenger details',
    'chooseValue': 'Choose a value',
    'forgetPassenger': 'Forget saved passenger details',
    'passengerForgotten': 'Saved passenger details removed from this device.',
    'notProvided': 'Not provided',
    'passenger': 'Passenger',
    'nextField': 'Continue',
    'optional': 'Optional',
    'optionalHint':
        'Complete this passenger’s details. Optional fields may be left blank.',
    'stateChooseCountry':
        'Select a country first to load its states or provinces.',
    'required': 'Required',
    'skip': 'Skip this field',
    'checkData':
        'Check your details before sending them to Omio. No automatic payment.',
    'sendData': 'Confirm and send details to Omio',
    'editData': 'Edit details',
    'invalidField': 'Check the value of this field.',
    'ageMismatch': 'The birth date does not match the age used for the search.',
    'unsupportedForm':
        'This field requires the Omio website. Complete your details there.',
    'phonePrefix': 'International dialling code, for example +39',
    'phoneNumber': 'National phone number',
    'phoneCountry': 'Phone country',
    'submitted': 'Details sent. Complete payment yourself on Omio.',
    'submitUncertain':
        'Submission could not be confirmed. Check on Omio without sending details again.',
    'statusRefresh': 'Check whether checkout is ready',
    'openCheckout': 'Open Omio checkout',
    'paymentChoice': 'Choose a payment method',
    'paymentChoiceHelp':
        'Choose a method available on Omio. The page will open to review the total and protection options and complete payment. No payment is made automatically.',
    'paymentCard': 'Credit or debit card',
    'paymentUnavailable':
        'Payment methods could not be read. You can continue on the Omio page.',
    'paymentSelectOnSite':
        'Selection not confirmed: check the method on the Omio page.',
    'paymentOpenSite': 'Open the full Omio page',
    'omioBrowser': 'Omio',
    'browserLoading': 'Loading Omio page',
    'externalBrowser': 'Open in external browser',
    'webBack': 'Previous page',
    'browserError':
        'Unable to open this page. If needed, use Open in external browser.',
    'bookingUnavailable': 'Booking expired or unavailable. Start a new search.',
    'handoff': 'Journey summary',
    'handoffInfo':
        'Continue creates a temporary reservation and opens passenger details in Sonarpad. Check the final total on Omio. No automatic payment.',
    'open': 'Open Omio',
    'bookingError':
        'The outcome could not be confirmed. Do not repeat the reservation. Retry opening only if a link is available.',
    'error': 'The service is unavailable. Please try again shortly.',
    'expired': 'Session expired or access denied. Start a new search.',
    'configuration': 'Travel service is not configured in this app build.',
    'retry': 'Retry',
    'noRecent': 'No recent journeys.',
    'clear': 'Clear recent journeys',
    'recentInfo':
        'Select a journey to reopen the form and check dates. Prices and availability will be searched again.',
    'reference': 'Support reference',
    'page': 'Page',
    'priceUnavailable': 'Price unavailable',
    'linkError': 'Unable to open the Omio link. Please try again.',
  };
}
