import 'dart:convert';

bool isTicketOneOrigin(String? url) {
  final uri = Uri.tryParse(url ?? '');
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'www.ticketone.it' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443);
}

/// Runs inside the authenticated WebView. Cookies (including HttpOnly cookies)
/// and XSRF tokens stay there; Dart receives only a minimal, read-only summary.
String ticketOneSessionScript(String requestId) =>
    '''
(() => {
  if (location.origin !== 'https://www.ticketone.it' || window.top !== window) return;
  const requestId = ${jsonEncode(requestId)};
  const send = data => TicketOneSession.postMessage(JSON.stringify({requestId, ...data}));
  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 8000);
  (async () => {
    try {
      const r = await fetch('/api/shoppingCart?ignoreDataLayer=true&affiliate=ITT', {
        method: 'GET', credentials: 'same-origin', cache: 'no-store',
        headers: {'Accept': 'application/json'}, signal: abort.signal
      });
      if (!r.ok) { send({status: 'http', http: r.status}); return; }
      if (!(r.headers.get('content-type') || '').includes('application/json')) {
        send({status: 'unexpected'}); return;
      }
      const d = await r.json();
      if (!d || d.page !== 'shoppingcart' || !d.order) {
        send({status: 'unexpected'}); return;
      }
      const authenticated = Number(d.customer?.customerId) > 0;
      const count = d.order.numberOfTickets;
      const amountMilli = d.order.totalAmountInt;
      if (!Number.isSafeInteger(count) || count < 0 ||
          !Number.isSafeInteger(amountMilli) || amountMilli < 0) {
        send({status: 'unexpected'}); return;
      }
      send({status: 'ok', authenticated, count, amountMilli});
    } catch (_) { send({status: 'unavailable'}); }
    finally { clearTimeout(timeout); }
  })();
})();
''';

class TicketOneCart {
  const TicketOneCart(this.authenticated, this.count, this.amountMilli);
  final bool authenticated;
  final int count, amountMilli;

  static TicketOneCart? parse(Map<String, dynamic> value) {
    final count = value['count'], amountMilli = value['amountMilli'];
    if (value['status'] != 'ok' ||
        value['authenticated'] is! bool ||
        count is! int ||
        count < 0 ||
        amountMilli is! int ||
        amountMilli < 0) {
      return null;
    }
    return TicketOneCart(value['authenticated'] as bool, count, amountMilli);
  }
}
