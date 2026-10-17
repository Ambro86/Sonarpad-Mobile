import 'dart:convert';
import 'package:http/http.dart' as http;

enum TvNativeStreamFormat { hls, dash }

/// Classifies redirects/PHP endpoints without downloading the whole stream.
class TvNativeStream {
  static TvNativeStreamFormat? fromUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return TvNativeStreamFormat.hls;
    if (path.endsWith('.mpd')) return TvNativeStreamFormat.dash;
    return null;
  }

  static bool supported(
    TvNativeStreamFormat? format, {
    required bool android,
  }) =>
      format == TvNativeStreamFormat.hls ||
      (android && format == TvNativeStreamFormat.dash);

  static Future<TvNativeStreamFormat?> detect(
    String url, {
    required Map<String, String> headers,
    http.Client? client,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return null;
    final known = fromUrl(url);
    if (known != null) return known;
    final transport = client ?? http.Client();
    Future<TvNativeStreamFormat?> probe() async {
      final request = http.Request('GET', uri)..headers.addAll(headers);
      final response = await transport.send(request);
      if (response.statusCode != 200 && response.statusCode != 206) return null;
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk.take(8192 - bytes.length));
        final text = utf8
            .decode(bytes, allowMalformed: true)
            .replaceFirst('\uFEFF', '')
            .trimLeft();
        if (text.startsWith('#EXTM3U')) return TvNativeStreamFormat.hls;
        if (RegExp(r'<MPD(?:\s|>)').hasMatch(text)) {
          return TvNativeStreamFormat.dash;
        }
        if (bytes.length >= 8192) return null;
      }
      return null;
    }

    try {
      return await probe().timeout(timeout);
    } catch (_) {
      return null; // An inconclusive probe leaves playback to MediaKit.
    } finally {
      if (client == null) transport.close();
    }
  }
}
