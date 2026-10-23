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
    'continue': 'Continua su Omio',
    'handoff': 'Riepilogo del viaggio',
    'handoffInfo':
        'Continua crea una prenotazione temporanea. Su Omio compilerai i dati dei passeggeri e controllerai il totale, comprese eventuali commissioni. Nessun pagamento automatico.',
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
    'continue': 'Continue on Omio',
    'handoff': 'Journey summary',
    'handoffInfo':
        'Continue creates a temporary reservation. Complete passenger details and check the final total, including any fees, on Omio. No automatic payment.',
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
