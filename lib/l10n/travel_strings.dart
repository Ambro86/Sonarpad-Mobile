import 'package:sealed_countries/sealed_countries.dart';
import 'travel_translations.dart';

class TravelStrings {
  TravelStrings(this.locale, {this.deviceCountry});
  final String? deviceCountry;
  final String locale;
  String get language => locale.split(RegExp('[-_]')).first.toLowerCase();
  String get _catalogue =>
      locale.replaceAll('-', '_').toLowerCase() == 'pt_br' ? 'pt_BR' : language;
  static Iterable<String> get keys => _en.keys;
  String t(String key) =>
      (language == 'it' ? _it[key] : travelTranslations[_catalogue]?[key]) ??
      _en[key] ??
      key;
  String get _languageCountry => _catalogue == 'pt_BR'
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
  static const supportedCurrencies = [
    'EUR',
    'USD',
    'GBP',
    'CHF',
    'CAD',
    'AUD',
    'NZD',
    'SEK',
    'NOK',
    'DKK',
    'PLN',
    'CZK',
    'HUF',
    'RON',
    'BGN',
    'BRL',
    'MXN',
  ];
  static final _countries = {for (final c in WorldCountry.list) c.codeShort: c};
  String get defaultCountry {
    final device = deviceCountry?.trim().toUpperCase();
    if (_countries.containsKey(device)) return device!;
    final parts = locale.replaceAll('-', '_').split('_');
    final region = parts.length > 1 ? parts.last.toUpperCase() : null;
    return _countries.containsKey(region) ? region! : _languageCountry;
  }

  String get defaultCurrency {
    final currencies = _countries[defaultCountry]?.currencies;
    return currencies
            ?.map((c) => c.code)
            .where(supportedCurrencies.contains)
            .firstOrNull ??
        'EUR';
  }

  String get defaultPhonePrefix =>
      _countries[defaultCountry]?.idd.phoneCode() ?? '+';

  String durationValue(int count, {required bool hours}) {
    final singular = t(hours ? 'durationHour' : 'durationMinute');
    final plural = t(hours ? 'durationHours' : 'durationMinutes');
    String word = count == 1 ? singular : plural;
    if (language == 'cs') {
      word = count == 1
          ? singular
          : (count >= 2 && count <= 4 ? plural : (hours ? 'hodin' : 'minut'));
    } else if (language == 'pl' || language == 'uk') {
      final few =
          count % 10 >= 2 &&
          count % 10 <= 4 &&
          !(count % 100 >= 12 && count % 100 <= 14);
      final one = language == 'pl'
          ? count == 1
          : count % 10 == 1 && count % 100 != 11;
      word = one
          ? singular
          : few
          ? plural
          : language == 'pl'
          ? (hours ? 'godzin' : 'minut')
          : (hours ? 'годин' : 'хвилин');
    } else if (language == 'ro' && count >= 20) {
      word = 'de $plural';
    }
    return '$count $word';
  }

  static const _it = {
    "seatClose": "Chiudi scelta posti",
    "seatBack": "Indietro",
    "seatPosition": "Carrozza {coach}, posto {seat}",

    'seatChoice': 'Scegli o modifica i posti',
    'seatHelp':
        'La scelta è facoltativa. Omio mostra disponibilità e supplemento prima della conferma. Puoi mantenere l’assegnazione casuale. Confermare i posti non acquista il biglietto.',
    'seatSelected': 'selezionato',
    'seatUnavailable':
        'La scelta dei posti non è ancora disponibile in questa schermata. Puoi proseguire sul sito nella stessa prenotazione.',
    'journeyDuration': 'Durata del viaggio',
    'durationHour': 'ora',
    'durationHours': 'ore',
    'durationMinute': 'minuto',
    'durationMinutes': 'minuti',
    'bookingPreparing':
        'Omio sta preparando la prenotazione. Controllo se il checkout è pronto senza reinviare i dati.',
    'bookingStillWaiting':
        'Omio non ha ancora confermato che il checkout è pronto. Puoi ricontrollare oppure continuare con la stessa prenotazione su Omio. Non reinviare i dati.',
    'openSameBooking': 'Continua con la stessa prenotazione su Omio',
    'useDiscountCards': 'Usa carte sconto o fedeltà',
    'discountCards': 'Carte sconto e fedeltà dei passeggeri',
    'noDiscountCard': 'Nessuna carta',
    'noVerifiedCards':
        'Omio non propone carte per questo mezzo e per queste età.',
    'discountCardNotice':
        'Seleziona soltanto carte possedute e valide per il passeggero e la compagnia indicata. Rispetta le condizioni della carta, anche per accompagnatori e gruppi. Le carte fedeltà non garantiscono uno sconto.',
    'searchWithoutCards': 'Cerca senza carte sconto',
    'departureTimeFilter': 'Orario di partenza',
    'time_all': 'Tutto il giorno',
    'time_morning': 'Mattina, 06:00–11:59',
    'time_afternoon': 'Pomeriggio, 12:00–17:59',
    'time_evening': 'Sera, 18:00–23:59',
    'time_night': 'Notte, 00:00–05:59',
    'timeEmpty': 'Nessun viaggio in questa fascia oraria.',
    'showAllDay': 'Mostra tutto il giorno',

    'title': 'Ricerca viaggi',
    'italianOnly':
        'La ricerca viaggi è attualmente disponibile solo con l’interfaccia italiana.',
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
    'emptyField': 'Attenzione! Il campo {field} è vuoto.',
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
    'noProtection': 'Non aggiungere alcuna protezione per il viaggio',
    'noProtectionUnconfirmed':
        'Non ho potuto confermare la scelta senza protezione. Verifica le protezioni su Omio prima di pagare.',
    'paymentChoiceHelp':
        'Scegli un metodo disponibile su Omio. Si aprirà la pagina per verificare il totale, le protezioni e completare il pagamento. Nessun pagamento viene eseguito automaticamente.',
    'paymentCard': 'Carta di credito o debito',
    'paymentUnavailable':
        'Non riesco a leggere i metodi disponibili. Puoi proseguire sulla pagina Omio.',
    'paymentSelectOnSite':
        'Selezione non confermata: verifica il metodo sulla pagina Omio.',
    'paypalSelectedHint':
        'PayPal selezionato. Per proseguire con il pagamento, raggiungi il pulsante PayPal in fondo alla pagina.',
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
    "seatClose": "Close seat selection",
    "seatBack": "Back",
    "seatPosition": "Coach {coach}, seat {seat}",

    'seatChoice': 'Choose or change seats',
    'seatHelp':
        'Seat selection is optional. Omio shows availability and any surcharge before confirmation. You can keep random assignment. Confirming seats does not purchase the ticket.',
    'seatSelected': 'selected',
    'seatUnavailable':
        'Seat selection is not available on this screen yet. You can continue on the website with the same booking.',
    'journeyDuration': 'Journey duration',
    'durationHour': 'hour',
    'durationHours': 'hours',
    'durationMinute': 'minute',
    'durationMinutes': 'minutes',
    'bookingPreparing':
        'Omio is preparing your booking. Checking whether checkout is ready without resubmitting your details.',
    'bookingStillWaiting':
        'Omio has not yet confirmed that checkout is ready. Check again or continue with the same booking on Omio. Do not resubmit your details.',
    'openSameBooking': 'Continue with the same booking on Omio',
    'useDiscountCards': 'Use discount or loyalty cards',
    'discountCards': 'Passenger discount and loyalty cards',
    'noDiscountCard': 'No card',
    'noVerifiedCards':
        'Omio lists no cards for this transport mode and these passenger ages.',
    'discountCardNotice':
        'Select only cards held by and valid for the passenger and the named operator. Follow card conditions, including companion and group requirements. Loyalty cards do not guarantee a discount.',
    'searchWithoutCards': 'Search without discount cards',
    'departureTimeFilter': 'Departure time',
    'time_all': 'All day',
    'time_morning': 'Morning, 06:00–11:59',
    'time_afternoon': 'Afternoon, 12:00–17:59',
    'time_evening': 'Evening, 18:00–23:59',
    'time_night': 'Night, 00:00–05:59',
    'timeEmpty': 'No journeys in this time range.',
    'showAllDay': 'Show all day',

    'italianOnly':
        'Travel search is currently available only with the Italian interface.',
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
    'emptyField': 'Attention! The {field} field is empty.',
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
    'noProtection': 'Do not add any travel protection',
    'noProtectionUnconfirmed':
        'The choice to travel without protection could not be confirmed. Check protection options on Omio before paying.',
    'paymentChoiceHelp':
        'Choose a method available on Omio. The page will open to review the total and protection options and complete payment. No payment is made automatically.',
    'paymentCard': 'Credit or debit card',
    'paymentUnavailable':
        'Payment methods could not be read. You can continue on the Omio page.',
    'paymentSelectOnSite':
        'Selection not confirmed: check the method on the Omio page.',
    'paypalSelectedHint':
        'PayPal selected. To continue with payment, find the PayPal button at the bottom of the page.',
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
