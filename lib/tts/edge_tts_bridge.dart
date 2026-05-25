import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

class EdgeTtsBridge {
  static const String _trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";
  static const String _wssUrlBase =
      "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1";

  bool get isAvailable => true;
  String? get lastLibraryPath => "Puro Dart (Nessuna libreria C)";

  Future<File> speakToFile({
    required String text,
    String voice = 'it-IT-IsabellaNeural',
  }) async {
    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'sonarpad_edge_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );

    // Inizia log (simile al comportamento precedente in Rust per la pagina di log)
    final logFile = File('$outPath.log.txt');
    await logFile.writeAsString('start voice=$voice text_len=${text.length}\n');

    try {
      final audioData = await _downloadAudio(text, voice, logFile);
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
      await logFile.writeAsString('Errore Edge TTS: $e\n',
          mode: FileMode.append);
      throw Exception('Edge TTS error: $e');
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

    // Dividiamo il testo in paragrafi veri e propri (doppi a capo).
    // Questo garantisce che titoli o paragrafi distinti non vengano mai fusi.
    final paragraphs = text.split(RegExp(r'\n{2,}'));

    for (final p in paragraphs) {
      // Normalizziamo tutti gli spazi (inclusi singoli \n) all'interno del paragrafo
      final cleaned = p
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll('...', '…')
          .trim();

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

  Future<List<int>> _downloadAudio(
      String text, String voice, File logFile) async {
    final requestId = const Uuid().v4().replaceAll('-', '');
    final secMsGec = _generateSecMsGec();
    const secMsGecVersion = "1-132.0.2917.39";

    final urlStr =
        "$_wssUrlBase?TrustedClientToken=$_trustedClientToken&ConnectionId=$requestId&Sec-MS-GEC=$secMsGec&Sec-MS-GEC-Version=$secMsGecVersion";

    await logFile.writeAsString('preparo URL websocket Edge TTS\n',
        mode: FileMode.append);

    WebSocket? ws;
    try {
      await logFile.writeAsString('connessione websocket...\n',
          mode: FileMode.append);

      final client = HttpClient();
      client.userAgent =
          "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 Edg/132.0.0.0";

      ws = await WebSocket.connect(urlStr, customClient: client, headers: {
        "Pragma": "no-cache",
        "Cache-Control": "no-cache",
        "Origin": "chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold",
        "Accept-Language": "it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7",
        "Cookie": "muid=${_generateMuid()};"
      }).timeout(const Duration(seconds: 20));

      await logFile.writeAsString('websocket connesso\n',
          mode: FileMode.append);

      final dateString = _getDateString();
      final configMsg =
          "X-Timestamp:$dateString\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}";

      ws.add(configMsg);
      await logFile.writeAsString('speech.config inviato\n',
          mode: FileMode.append);

      final ssml = _mkssml(text, voice);
      final ssmlMsg =
          "X-RequestId:$requestId\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:${dateString}Z\r\nPath:ssml\r\n\r\n$ssml";

      ws.add(ssmlMsg);
      await logFile.writeAsString('SSML inviato\n', mode: FileMode.append);

      final audioData = <int>[];
      final completer = Completer<void>();

      ws.listen((dynamic data) {
        if (data is String) {
          if (data.contains("Path:turn.end")) {
            if (!completer.isCompleted) completer.complete();
          }
        } else if (data is List<int>) {
          final payload = _parseEdgeBinaryAudioPayload(data);
          if (payload != null) {
            audioData.addAll(payload);
          }
        }
      }, onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }, onDone: () {
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future.timeout(const Duration(seconds: 60));
      await logFile.writeAsString('fine ricezione: ${audioData.length} bytes\n',
          mode: FileMode.append);

      return audioData;
    } finally {
      await ws?.close();
    }
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

  String _mkssml(String text, String voice) {
    final langParts = voice.split('-');
    final lang =
        langParts.length >= 2 ? "${langParts[0]}-${langParts[1]}" : "it-IT";
    final sanitizedText = _escapeXml(_sanitizeText(text));
    return "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='$lang'><voice name='$voice'><prosody pitch='+0Hz' rate='+0%' volume='+0%'>$sanitizedText</prosody></voice></speak>";
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

  List<int>? _parseEdgeBinaryAudioPayload(List<int> data) {
    if (data.length < 2) return null;

    final beLen = (data[0] << 8) | data[1];
    final leLen = (data[1] << 8) | data[0];

    int headerLen = 0;
    if (beLen > 0 && data.length >= beLen + 2) {
      headerLen = beLen;
    } else if (leLen > 0 && data.length >= leLen + 2) {
      headerLen = leLen;
    } else {
      return null;
    }

    final headerText =
        utf8.decode(data.sublist(2, 2 + headerLen), allowMalformed: true);
    final payload = data.sublist(2 + headerLen);

    if (headerText.toLowerCase().contains("path:audio")) {
      if (payload.isNotEmpty) {
        return payload;
      }
    }
    return null;
  }
}
