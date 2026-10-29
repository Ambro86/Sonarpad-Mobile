/// Like travel strings, use English as fallback outside the Italian catalogue UI.
class TicketOneStrings {
  TicketOneStrings(this.locale);
  final String locale;
  String t(String key) =>
      (locale.split(RegExp('[-_]')).first == 'it' ? _it[key] : _en[key])!;
  static const _it = {
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
        'La sessione rimane nel browser di Sonarpad. Posti, dati e pagamento si completano sul sito TicketOne. Nessun pagamento automatico.',
    'empty': 'Il carrello è vuoto.',
  };
  static const _en = {
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
        'Your session stays in Sonarpad’s browser. Complete seats, details and payment on TicketOne. No automatic payment.',
    'empty': 'Your cart is empty.',
  };
}
