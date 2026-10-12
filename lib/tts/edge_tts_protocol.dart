/// WebSocket protocol details shared by the mobile Edge text-to-speech paths.
///
/// The newer read-aloud service is preferred, but the earlier service is kept
/// as a fallback. Never write the full request URL to diagnostic logs because
/// it contains the client key and the time-dependent Sec-MS-GEC signature.
enum EdgeTtsEndpoint { modern, legacy }

class EdgeTtsProtocol {
  EdgeTtsProtocol._();

  static const clientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const modernUrl =
      'wss://api.msedgeservices.com/tts/cognitiveservices/websocket/v1';
  static const legacyUrl =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
  static const modernVersion = '1-155.0.4283.45';
  static const legacyVersion = '1-132.0.2917.39';
  static const modernUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36 Edg/155.0.4283.45';
  static const legacyUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
      'Mobile/15E148 Safari/604.1 Edg/132.0.0.0';

  static String label(EdgeTtsEndpoint endpoint) =>
      endpoint == EdgeTtsEndpoint.modern
          ? 'Edge 155 (api.msedgeservices.com) [PRIMARY]'
          : 'legacy (speech.platform.bing.com) [FALLBACK]';

  static String userAgent(EdgeTtsEndpoint endpoint) =>
      endpoint == EdgeTtsEndpoint.modern ? modernUserAgent : legacyUserAgent;

  static Uri url({
    required EdgeTtsEndpoint endpoint,
    required String connectionId,
    required String signature,
  }) {
    final modern = endpoint == EdgeTtsEndpoint.modern;
    return Uri.parse(modern ? modernUrl : legacyUrl).replace(
      queryParameters: {
        if (modern) 'Ocp-Apim-Subscription-Key': clientToken,
        if (!modern) 'TrustedClientToken': clientToken,
        'ConnectionId': connectionId,
        'Sec-MS-GEC': signature,
        'Sec-MS-GEC-Version': modern ? modernVersion : legacyVersion,
      },
    );
  }
}

/// A synthesis turn is committed only after the explicit turn.end message.
/// Close, EOF and connection resets are NOT successful completion events.
class EdgeTtsTurn {
  bool _ended = false;
  final List<int> _audio = <int>[];

  bool get ended => _ended;
  int get audioBytes => _audio.length;

  void acceptText(String message) {
    if (RegExp(r'^Path:turn\.end\s*$',
            caseSensitive: false, multiLine: true).hasMatch(message)) {
      _ended = true;
    }
  }

  void acceptBinary(List<int> frame) {
    if (_ended || frame.length < 2) return;
    var headerLength = (frame[0] << 8) | frame[1];
    if (headerLength <= 0 || headerLength + 2 > frame.length) {
      // Older read-aloud variants have occasionally used little-endian.
      headerLength = (frame[1] << 8) | frame[0];
    }
    if (headerLength <= 0 || headerLength + 2 > frame.length) {
      return;
    }
    // Edge audio frames carry a two-byte big-endian text header length.
    final header = String.fromCharCodes(frame.sublist(2, headerLength + 2));
    if (!RegExp(r'^Path:audio\s*$',
            caseSensitive: false, multiLine: true).hasMatch(header)) {
      return;
    }
    if (headerLength + 2 < frame.length) {
      _audio.addAll(frame.sublist(headerLength + 2));
    }
  }

  List<int> completedAudio() {
    if (!_ended) {
      throw StateError('Edge connection closed without turn.end; audio incomplete');
    }
    if (_audio.length < 1000) {
      throw StateError('Edge TTS returned empty or incomplete audio');
    }
    return List<int>.of(_audio);
  }
}
