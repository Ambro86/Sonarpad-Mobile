import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import 'edge_tts_protocol.dart';

class EdgeTtsBridge {
  HttpClient? _activeClient;
  WebSocket? _activeSocket;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _activeClient?.close(force: true);
    unawaited(_activeSocket?.close());
  }

  void _checkCancelled() {
    if (_cancelled) throw StateError('AUDIO_DESCRIPTION_CANCELLED');
  }

  static const String _trustedClientToken = EdgeTtsProtocol.clientToken;

  bool get isAvailable => true;
  String? get lastLibraryPath => "Puro Dart (Nessuna libreria C)";

  Future<File> speakToFile({
    required String text,
    String voice = 'it-IT-IsabellaNeural',
    double? speed,
    double? pitch,
  }) async {
    _checkCancelled();
    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'sonarpad_edge_tts_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.mp3',
    );

    // Inizia log (simile al comportamento precedente in Rust per la pagina di log)
    final logFile = File('$outPath.log.txt');
    await logFile.writeAsString('start voice=$voice text_len=${text.length}\n');

    // Recupera impostazioni velocità e tono. Quando il chiamante passa
    // valori espliciti, per esempio dal pulsante "Test voce" delle
    // impostazioni, usiamo quelli subito senza aspettare il salvataggio.
    final prefs = await SharedPreferences.getInstance();
    final effectiveSpeed = (speed ?? prefs.getDouble('sonarpad_tts_speed') ?? 1.0)
        .clamp(0.5, 2.0)
        .toDouble();
    final effectivePitch = (pitch ?? prefs.getDouble('sonarpad_tts_pitch') ?? 1.0)
        .clamp(0.5, 2.0)
        .toDouble();

    await logFile.writeAsString(
      'params speed=$effectiveSpeed pitch=$effectivePitch\n',
      mode: FileMode.append,
    );

    final ratePercent = ((effectiveSpeed - 1.0) * 100).round();
    final rateStr = ratePercent >= 0 ? '+$ratePercent%' : '$ratePercent%';

    final pitchPercent = ((effectivePitch - 1.0) * 100).round();
    final pitchStr = pitchPercent >= 0 ? '+$pitchPercent%' : '$pitchPercent%';

    try {
      final audioData =
          await _downloadAudio(text, voice, rateStr, pitchStr, logFile);
      _checkCancelled();
      if (audioData.isEmpty) {
        throw Exception("Edge TTS ha restituito audio vuoto");
      }
      final file = File(outPath);
      await file.writeAsBytes(audioData);

      final size = await file.length();
      if (size < 1000) {
        throw Exception('File audio troppo piccolo o vuoto: $size byte');
      }
      return file;
    } catch (e) {
      _checkCancelled();
      final safe = _safeError(e);
      await logFile.writeAsString('Errore Edge TTS: $safe\n',
          mode: FileMode.append);
      throw Exception('Edge TTS error: $safe');
    }
  }

  Future<List<File>> speakToChunkFiles({
    required String text,
    String voice = 'it-IT-IsabellaNeural',
    int maxChunkChars = 650,
    void Function(int index, int total, File file)? onChunkReady,
  }) async {
    final chunks = splitTextForStreaming(text, maxChunkChars: maxChunkChars);
    final files = <File>[];
    for (var i = 0; i < chunks.length; i++) {
      final file = await speakToFile(text: chunks[i], voice: voice);
      files.add(file);
      onChunkReady?.call(i, chunks.length, file);
    }
    return files;
  }

  List<String> splitTextForStreaming(String text, {int maxChunkChars = 650}) {
    final chunks = <String>[];

    // Normalizziamo \r\n in \n per evitare problemi su Windows
    final normalizedText = text.replaceAll('\r\n', '\n');

    // Dividiamo il testo in paragrafi veri e propri (doppi a capo).
    // Questo garantisce che titoli o paragrafi distinti non vengano mai fusi.
    final paragraphs = normalizedText.split(RegExp(r'\n{2,}'));

    for (final p in paragraphs) {
      // Normalizziamo tutti gli spazi (inclusi singoli \n) all'interno del paragrafo
      final cleaned =
          p.replaceAll(RegExp(r'\s+'), ' ').replaceAll('...', '…').trim();

      if (cleaned.isEmpty) continue;

      final sentenceMatches =
          RegExp(r'[^.!?。！？]+[.!?。！？]?').allMatches(cleaned);
      final sentences = sentenceMatches
          .map((m) => m.group(0)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      final buffer = StringBuffer();

      void flush() {
        final value = buffer.toString().trim();
        if (value.isNotEmpty) chunks.add(value);
        buffer.clear();
      }

      for (final sentence in sentences) {
        if (sentence.length > maxChunkChars) {
          flush();
          var start = 0;
          while (start < sentence.length) {
            var end = start + maxChunkChars;
            if (end >= sentence.length) {
              chunks.add(sentence.substring(start).trim());
              break;
            }
            final cut = sentence.lastIndexOf(' ', end);
            if (cut > start + 80) end = cut;
            chunks.add(sentence.substring(start, end).trim());
            start = end;
          }
        } else {
          if (buffer.length + sentence.length > maxChunkChars) {
            flush();
          }
          buffer.write(sentence);
          buffer.write(' ');
        }
      }

      // Forza il flush alla fine del paragrafo: i titoli restano separati!
      flush();
    }

    return chunks;
  }

  // Try the current service first, then the previous service if needed.
  // The caller's existing retry loop controls further attempts and Stop:
  // the bridge must never spin forever after its reading session has ended.
  Future<List<int>> _downloadAudio(String text, String voice, String rateStr,
      String pitchStr, File logFile) async {
    Object? lastError;
    Object? rateLimitedError;
    for (final endpoint in EdgeTtsEndpoint.values) {
      _checkCancelled();
      try {
        return await _downloadEndpointAudio(
            text, voice, rateStr, pitchStr, logFile, endpoint);
      } catch (error) {
        _checkCancelled();
        lastError = error;
        if (error.toString().contains('429')) rateLimitedError = error;
        final label = EdgeTtsProtocol.label(endpoint);
        await _logEdge(logFile,
            'Edge TTS: endpoint=$label failed: ${_safeError(error)}');
        if (!_isTemporaryError(error)) rethrow;
      }
    }
    // If either server asks us to slow down, preserve HTTP 429 so the
    // caller uses a longer retry delay instead of hammering both servers.
    throw rateLimitedError ??
        lastError ??
        StateError('Edge TTS: no endpoint available');
  }

  Future<List<int>> _downloadEndpointAudio(
      String text,
      String voice,
      String rateStr,
      String pitchStr,
      File logFile,
      EdgeTtsEndpoint endpoint) async {
    final requestId = const Uuid().v4().replaceAll('-', '');
    final url = EdgeTtsProtocol.url(
      endpoint: endpoint,
      connectionId: requestId,
      signature: _generateSecMsGec(),
    );
    final label = EdgeTtsProtocol.label(endpoint);
    WebSocket? ws;
    HttpClient? client;
    try {
      _checkCancelled();
      client = HttpClient()..userAgent = EdgeTtsProtocol.userAgent(endpoint);
      _activeClient = client;
      // Never log the URL or query parameters: they contain authentication.
      await _logEdge(logFile, 'Edge TTS: connecting endpoint=$label');
      ws = await WebSocket.connect(
        url.toString(),
        customClient: client,
        headers: {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'Accept-Language': 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
          'Cookie': 'muid=${_generateMuid()};',
        },
      ).timeout(const Duration(seconds: 20));
      _activeSocket = ws;
      _checkCancelled();
      await _logEdge(logFile,
          'Edge TTS: WebSocket connected (HTTP 101), endpoint=$label');

      final dateString = _getDateString();
      final configMsg =
          'X-Timestamp:$dateString\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n'
          '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}';
      ws.add(configMsg);
      final ssml = _mkssml(text, voice, rateStr, pitchStr);
      ws.add('X-RequestId:$requestId\r\nContent-Type:application/ssml+xml\r\n'
          'X-Timestamp:${dateString}Z\r\nPath:ssml\r\n\r\n$ssml');

      final turn = EdgeTtsTurn();
      final completed = Completer<void>();
      final subscription = ws.listen((dynamic data) {
        if (data is String) {
          turn.acceptText(data);
          if (turn.ended && !completed.isCompleted) completed.complete();
        } else if (data is List<int>) {
          turn.acceptBinary(data);
        }
      }, onError: (Object error, StackTrace stack) {
        if (!completed.isCompleted) completed.completeError(error, stack);
      }, onDone: () {
        if (!completed.isCompleted) {
          completed.completeError(
              StateError('Edge connection closed without turn.end'));
        }
      }, cancelOnError: true);

      try {
        await completed.future.timeout(const Duration(seconds: 60));
        _checkCancelled();
        final audio = turn.completedAudio();
        await _logEdge(logFile,
            'Edge TTS: SYNTHESIS SUCCEEDED, endpoint=$label '
            'audio_bytes=${audio.length} path=mobile');
        return audio;
      } finally {
        await subscription.cancel();
      }
    } finally {
      if (ws != null) {
        try {
          await ws.close().timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
      if (identical(_activeSocket, ws)) _activeSocket = null;
      client?.close(force: true);
      if (identical(_activeClient, client)) _activeClient = null;
    }
  }

  Future<void> _logEdge(File logFile, String message) async {
    // The app diagnostics include the selected endpoint, but never its key.
    await AppLogger.log(message);
    await logFile.writeAsString('$message\n', mode: FileMode.append);
  }

  String _safeError(Object error) {
    // Do not log an exception's full URL or any query-string credentials.
    final raw = error.toString();
    final scrubbed = raw.replaceAll(
        RegExp(r'(wss?://|https?://)\S+', caseSensitive: false), '[url omitted]');
    return scrubbed.length > 240 ? scrubbed.substring(0, 240) : scrubbed;
  }

  bool _isTemporaryError(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is HttpException ||
        error is WebSocketException ||
        error is HandshakeException) {
      return true;
    }
    final e = error.toString().toLowerCase();
    return const [
      '403', '429', '500', '502', '503', '504', 'timeout',
      'connection', 'socket', 'network', 'websocket', 'reset',
      'broken pipe', 'turn.end', 'empty audio', 'incomplete audio',
      'eof', 'audio vuoto',
    ].any(e.contains);
  }

  String _generateSecMsGec() {
    const winEpoch = 11644473600;
    final ticks =
        (DateTime.now().toUtc().millisecondsSinceEpoch / 1000).truncate() +
            winEpoch;
    final roundedTicks = (ticks - (ticks % 300)) * 10000000;
    final strToHash = "$roundedTicks$_trustedClientToken";
    final bytes = utf8.encode(strToHash);
    final digest = sha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  String _generateMuid() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  String _getDateString() {
    final now = DateTime.now().toUtc();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    final day = now.day.toString().padLeft(2, '0');
    final year = now.year.toString();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    return "$weekday $month $day $year $hour:$minute:$second GMT+0000 (Coordinated Universal Time)";
  }

  String _mkssml(String text, String voice, String rateStr, String pitchStr) {
    final langParts = voice.split('-');
    final lang =
        langParts.length >= 2 ? "${langParts[0]}-${langParts[1]}" : "it-IT";
    final sanitizedText = _escapeXml(_sanitizeText(text));
    return "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='$lang'><voice name='$voice'><prosody pitch='$pitchStr' rate='$rateStr' volume='+0%'>$sanitizedText</prosody></voice></speak>";
  }

  String _sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

}
