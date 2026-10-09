import 'dart:async';
import 'dart:io';

/// Recupera soltanto il blocco Edge TTS corrente in caso di errore temporaneo.
///
/// Non cambia la sintesi, la suddivisione in blocchi o la riproduzione:
/// [generate] e' la stessa richiesta gia' utilizzata dal chiamante.
class EdgeTtsRetry {
  EdgeTtsRetry._();

  // Come su Windows: attesa progressiva breve, al massimo due secondi.
  // Il numero di tentativi e' limitato su mobile per non restare bloccati
  // indefinitamente quando il servizio remoto non e' disponibile.
  static const delays = <Duration>[
    Duration(milliseconds: 400),
    Duration(milliseconds: 800),
    Duration(milliseconds: 1200),
    Duration(milliseconds: 1600),
    Duration(milliseconds: 2000),
  ];

  static bool isTransient(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is WebSocketException ||
        error is HandshakeException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    if (message.contains('audio_description_cancelled')) return false;

    return const <String>[
      'audio vuoto',
      'empty audio',
      'empty payload',
      'no audio sent',
      'file audio troppo piccolo',
      'timeout',
      'timed out',
      'temporar',
      'connection reset',
      'connection refused',
      'connection aborted',
      'connection closed',
      'failed to connect',
      'forcibly closed',
      'websocket',
      'web socket',
      'network',
      'broken pipe',
      'unexpected eof',
      'closed without',
      'too many requests',
      '403 forbidden',
      '429',
      '500 internal server error',
      '502 bad gateway',
      '503 service unavailable',
      '504 gateway timeout',
    ].any(message.contains);
  }

  /// Ritorna null se Stop, una nuova lettura o la chiusura della pagina
  /// hanno invalidato la sessione. Non ritenta errori permanenti.
  static Future<File?> run({
    required Future<File> Function() generate,
    required bool Function() isActive,
    FutureOr<void> Function(int retry, Duration delay, Object error)? onRetry,
    List<Duration> retryDelays = delays,
  }) async {
    for (var attempt = 0;; attempt++) {
      if (!isActive()) return null;
      try {
        final file = await generate();
        return isActive() ? file : null;
      } catch (error) {
        if (!isActive()) return null;
        if (!isTransient(error) || attempt >= retryDelays.length) rethrow;

        final delay = retryDelays[attempt];
        if (onRetry != null) await onRetry(attempt + 1, delay, error);

        // Brevi intervalli consentono a Stop di terminare anche durante
        // l'attesa, senza richiedere modifiche al player o a EdgeTtsBridge.
        var remaining = delay.inMilliseconds;
        while (remaining > 0 && isActive()) {
          final slice = remaining < 100 ? remaining : 100;
          await Future<void>.delayed(Duration(milliseconds: slice));
          remaining -= slice;
        }
      }
    }
  }
}