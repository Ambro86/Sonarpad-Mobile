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
    'otpHeading': 'Codice monouso',
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
    'otpHeading': 'One-time code',
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
