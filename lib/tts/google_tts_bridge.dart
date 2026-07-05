import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../utils/app_logger.dart';

class GoogleTtsVoicePackage {
  const GoogleTtsVoicePackage({
    required this.id,
    required this.fileId,
    required this.url,
    required this.sha256Checksum,
    required this.compressedSize,
    required this.speakers,
  });

  final String id;
  final String fileId;
  final String url;
  final String sha256Checksum;
  final int compressedSize;
  final List<GoogleTtsSpeaker> speakers;

  String get fileName => '$id.zvoice';

  String get language {
    final match =
        RegExp(r'^([a-z]{2,3})-([a-z]{2})(?:-|$)', caseSensitive: false)
            .firstMatch(id);
    if (match == null) return id;
    return '${match.group(1)!.toLowerCase()}-${match.group(2)!.toUpperCase()}';
  }

  Map<String, Object?> toRuntimeJson() => {
        'id': id,
        'fileId': fileId,
        'url': '/$fileName',
        'sha256Checksum': sha256Checksum,
        'compressedSize': compressedSize,
        'speakers': speakers.map((speaker) => speaker.toJson()).toList(),
        'remote': false,
      };
}

class GoogleTtsSpeaker {
  const GoogleTtsSpeaker({
    required this.id,
    required this.packageId,
    required this.language,
    required this.speaker,
    required this.name,
    required this.gender,
    required this.highQuality,
  });

  final String id;
  final String packageId;
  final String language;
  final String speaker;
  final String name;
  final String gender;
  final bool highQuality;

  Map<String, Object?> toJson() => {
        'speaker': speaker,
        'name': name,
        'gender': gender,
      };
}

class GoogleTtsCatalog {
  GoogleTtsCatalog(this.packages)
      : speakers = [
          for (final package in packages)
            for (final speaker in package.speakers) speaker,
        ];

  final List<GoogleTtsVoicePackage> packages;
  final List<GoogleTtsSpeaker> speakers;

  static Future<GoogleTtsCatalog> load() async {
    final raw =
        await rootBundle.loadString('assets/data/google_tts_voices.json');
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Catalogo Google TTS non valido.');
    }
    final packages = <GoogleTtsVoicePackage>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final id = item['id']?.toString() ?? '';
      final fileId = item['fileId']?.toString() ?? '';
      final url = item['url']?.toString() ?? '';
      if (id.isEmpty || fileId.isEmpty || url.isEmpty) continue;
      final rawSpeakers = item['speakers'];
      final speakers = <GoogleTtsSpeaker>[];
      if (rawSpeakers is List) {
        for (final speakerItem in rawSpeakers) {
          if (speakerItem is! Map) continue;
          final speakerCode = speakerItem['speaker']?.toString() ?? '';
          final name = speakerItem['name']?.toString() ?? speakerCode;
          speakers.add(
            GoogleTtsSpeaker(
              id: '$id:${speakerCode.isEmpty ? name : speakerCode}',
              packageId: id,
              language: _languageFromPackageId(id),
              speaker: speakerCode,
              name: name,
              gender: speakerItem['gender']?.toString() ?? '',
              highQuality: id.contains('seanet') || name.contains('Natural'),
            ),
          );
        }
      }
      packages.add(
        GoogleTtsVoicePackage(
          id: id,
          fileId: fileId,
          url: url,
          sha256Checksum: item['sha256Checksum']?.toString() ?? '',
          compressedSize: int.tryParse('${item['compressedSize'] ?? 0}') ?? 0,
          speakers: speakers,
        ),
      );
    }
    packages.sort((a, b) {
      final languageCompare = a.language.compareTo(b.language);
      return languageCompare == 0 ? a.id.compareTo(b.id) : languageCompare;
    });
    return GoogleTtsCatalog(packages);
  }

  GoogleTtsSpeaker speakerForVoice(String voiceId) {
    return speakers.firstWhere(
      (speaker) => speaker.id == voiceId,
      orElse: () => speakers.firstWhere(
        (speaker) => speaker.language == 'it-IT',
        orElse: () => speakers.first,
      ),
    );
  }

  GoogleTtsVoicePackage packageForVoice(String voiceId) {
    final speaker = speakerForVoice(voiceId);
    return packages.firstWhere((package) => package.id == speaker.packageId);
  }

  String runtimeJsonForInstalledPackages(Set<String> installedPackageIds) {
    final runtimePackages = packages
        .where((package) => installedPackageIds.contains(package.id))
        .map((package) => package.toRuntimeJson())
        .toList();
    return jsonEncode(runtimePackages);
  }

  static String _languageFromPackageId(String id) {
    final match =
        RegExp(r'^([a-z]{2,3})-([a-z]{2})(?:-|$)', caseSensitive: false)
            .firstMatch(id);
    if (match == null) return id;
    return '${match.group(1)!.toLowerCase()}-${match.group(2)!.toUpperCase()}';
  }
}

class GoogleTtsBridge {
  GoogleTtsBridge._();

  static final GoogleTtsBridge instance = GoogleTtsBridge._();

  GoogleTtsCatalog? _catalog;
  Directory? _voiceDir;
  Directory? _runtimeDir;
  HttpServer? _server;
  Uri? _serverBaseUri;
  WebViewController? _controller;
  Completer<void>? _readyCompleter;
  Completer<Uint8List>? _activeSynthesis;
  String? _activeSessionId;
  final List<int> _activePcmBytes = [];

  bool get isRuntimeAttached => _controller != null;

  Future<GoogleTtsCatalog> loadCatalog() async {
    return _catalog ??= await GoogleTtsCatalog.load();
  }

  Future<Directory> voiceDir() async {
    if (_voiceDir != null) return _voiceDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'google_tts_voices'));
    await dir.create(recursive: true);
    return _voiceDir = dir;
  }

  Future<File> packageFile(GoogleTtsVoicePackage package) async {
    final dir = await voiceDir();
    return File(p.join(dir.path, package.fileName));
  }

  Future<bool> isPackageInstalled(GoogleTtsVoicePackage package) async {
    final file = await packageFile(package);
    if (!await file.exists()) return false;
    if (package.compressedSize > 0 &&
        await file.length() != package.compressedSize) {
      return false;
    }
    if (package.sha256Checksum.isEmpty) return true;
    final digest = await _sha256File(file);
    return digest.toLowerCase() == package.sha256Checksum.toLowerCase();
  }

  Future<File> downloadPackage(
    GoogleTtsVoicePackage package, {
    void Function(double progress)? onProgress,
  }) async {
    final target = await packageFile(package);
    if (await isPackageInstalled(package)) {
      await AppLogger.log(
          'Google TTS: package already installed id=${package.id}');
      onProgress?.call(1);
      return target;
    }
    await AppLogger.log(
        'Google TTS: package download start id=${package.id} url=${package.url}');
    final tmp = File('${target.path}.download');
    if (await tmp.exists()) await tmp.delete();

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(package.url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Sonarpad Google TTS');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download Google TTS fallito: HTTP ${response.statusCode}',
          uri: Uri.parse(package.url),
        );
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : package.compressedSize;
      var downloaded = 0;
      final sink = tmp.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (total > 0) onProgress?.call((downloaded / total).clamp(0, 0.99));
      }
      await sink.close();
    } finally {
      client.close(force: true);
    }

    if (package.compressedSize > 0 &&
        await tmp.length() != package.compressedSize) {
      await tmp.delete();
      throw Exception(
          'Dimensione pacchetto Google TTS non valida per ${package.id}.');
    }
    if (package.sha256Checksum.isNotEmpty) {
      final digest = await _sha256File(tmp);
      if (digest.toLowerCase() != package.sha256Checksum.toLowerCase()) {
        await tmp.delete();
        throw Exception(
            'Checksum pacchetto Google TTS non valido per ${package.id}.');
      }
    }
    if (await target.exists()) await target.delete();
    await tmp.rename(target.path);
    onProgress?.call(1);
    await AppLogger.log(
        'Google TTS: package download complete id=${package.id} bytes=${await target.length()}');
    return target;
  }

  Future<File> installPackageBytes(
    GoogleTtsVoicePackage package,
    List<int> bytes,
  ) async {
    if (package.compressedSize > 0 && bytes.length != package.compressedSize) {
      throw Exception(
          'Dimensione pacchetto Google TTS non valida per ${package.id}.');
    }
    if (package.sha256Checksum.isNotEmpty) {
      final digest = sha256.convert(bytes).toString();
      if (digest.toLowerCase() != package.sha256Checksum.toLowerCase()) {
        throw Exception(
            'Checksum pacchetto Google TTS non valido per ${package.id}.');
      }
    }
    final target = await packageFile(package);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  Future<File> speakToFile({
    required String text,
    required String voiceId,
    double speed = 1.0,
    double pitch = 1.0,
  }) async {
    await AppLogger.log(
        'Google TTS: speak start voice=$voiceId chars=${text.length} speed=$speed pitch=$pitch');
    final catalog = await loadCatalog();
    final speaker = catalog.speakerForVoice(voiceId);
    final package = catalog.packageForVoice(voiceId);
    await AppLogger.log(
        'Google TTS: selected package=${package.id} speaker=${speaker.name}');
    await downloadPackage(package);
    await AppLogger.log('Google TTS: waiting runtime');
    await _ensureRuntimeReady();
    await AppLogger.log('Google TTS: runtime ready, synth start');
    final pcm = await _synthesizePcm(
      text: text,
      speaker: speaker,
      speed: speed,
      pitch: pitch,
    );
    final tempDir = await getTemporaryDirectory();
    final output = File(
      p.join(
        tempDir.path,
        'sonarpad_google_tts_${DateTime.now().millisecondsSinceEpoch}.wav',
      ),
    );
    await output.writeAsBytes(_wavBytesFromPcm(pcm, sampleRate: 24000));
    final size = await output.length();
    if (size < 512) {
      throw Exception('File Google TTS troppo piccolo: $size byte');
    }
    await AppLogger.log(
        'Google TTS: speak complete wavBytes=$size pcmBytes=${pcm.length}');
    return output;
  }

  Future<void> attachWebViewController(WebViewController controller) async {
    if (_controller == controller && _readyCompleter?.isCompleted == true) {
      return;
    }
    await AppLogger.log('Google TTS: attach WebView start');
    _controller = controller;
    _readyCompleter = Completer<void>();
    final serverBase = await _ensureServer();
    await AppLogger.log('Google TTS: runtime server $serverBase');
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setOnConsoleMessage((message) {
      unawaited(AppLogger.log(
          'Google TTS WebView console [${message.level.name}]: ${message.message}'));
    });
    await controller.addJavaScriptChannel(
      'googleTtsForNvdaBridge',
      onMessageReceived: (message) => _handleRuntimeMessage(message.message),
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (url) {
          unawaited(AppLogger.log('Google TTS: WebView page finished $url'));
          unawaited(_waitForRuntimeReady());
        },
        onWebResourceError: (error) {
          unawaited(AppLogger.log(
              'Google TTS: WebView resource error code=${error.errorCode} type=${error.errorType} ${error.description}'));
          if (_readyCompleter case final completer?
              when !completer.isCompleted) {
            completer.completeError(error.description);
          }
        },
      ),
    );
    await controller.loadRequest(serverBase);
  }

  Future<void> disposeRuntime() async {
    _controller = null;
    _readyCompleter = null;
    await _server?.close(force: true);
    _server = null;
    _serverBaseUri = null;
  }

  Future<void> _ensureRuntimeReady() async {
    if (_readyCompleter == null) {
      await AppLogger.log('Google TTS: runtime missing WebView host');
      throw StateError(
          'Runtime Google TTS non inizializzato: host WebView assente.');
    }
    await _readyCompleter!.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw TimeoutException('Runtime Google TTS non pronto.'),
    );
  }

  Future<Uint8List> _synthesizePcm({
    required String text,
    required GoogleTtsSpeaker speaker,
    required double speed,
    required double pitch,
  }) async {
    if (_activeSynthesis != null) {
      throw StateError('Una sintesi Google TTS e gia in corso.');
    }
    final controller = _controller;
    if (controller == null) {
      throw StateError('Runtime Google TTS non inizializzato.');
    }
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _activeSessionId = sessionId;
    _activePcmBytes.clear();
    final completer = Completer<Uint8List>();
    _activeSynthesis = completer;
    final payload = {
      'sessionId': sessionId,
      'text': text,
      'voiceName': speaker.name,
      'lang': speaker.language,
      'rate': speed.clamp(0.5, 2.0),
      'pitch': pitch.clamp(0.5, 2.0),
      'volume': 1,
      'outputGain': 1,
    };
    await controller.runJavaScript(
      'window.googleTtsForNvdaSpeak(${jsonEncode(payload)});',
    );
    try {
      return await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw TimeoutException('Timeout sintesi Google TTS.'),
      );
    } finally {
      _activeSynthesis = null;
      _activeSessionId = null;
      _activePcmBytes.clear();
    }
  }

  Future<Uri> _ensureServer() async {
    if (_serverBaseUri != null) return _serverBaseUri!;
    _runtimeDir = await _prepareRuntimeDirectory();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) => unawaited(_handleRequest(request)));
    await AppLogger.log('Google TTS: local server listening port=${_server!.port}');
    return _serverBaseUri = Uri.parse('http://127.0.0.1:${_server!.port}/');
  }

  Future<Directory> _prepareRuntimeDirectory() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'google_tts_runtime'));
    final engineDir = Directory(p.join(dir.path, 'engine'));
    await engineDir.create(recursive: true);
    await AppLogger.log('Google TTS: prepare runtime dir=${dir.path}');
    await _copyAsset('assets/google_tts/bridgeHarness.js',
        File(p.join(dir.path, 'bridgeHarness.js')));
    await _copyAsset(
      'assets/google_tts/engine/bindings_main.js',
      File(p.join(engineDir.path, 'bindings_main.js')),
    );
    await _copyAsset(
      'assets/google_tts/engine/bindings_main.wasm',
      File(p.join(engineDir.path, 'bindings_main.wasm')),
    );
    await _copyAsset(
      'assets/google_tts/engine/offscreen_compiled.js',
      File(p.join(engineDir.path, 'offscreen_compiled.js')),
    );
    await _copyAsset(
      'assets/google_tts/engine/streaming_worklet_processor.js',
      File(p.join(engineDir.path, 'streaming_worklet_processor.js')),
    );
    await File(p.join(dir.path, 'index.html')).writeAsString('''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="/bridgeHarness.js"></script>
  <script src="/engine/bindings_main.js"></script>
  <script src="/engine/offscreen_compiled.js"></script>
</head>
<body></body>
</html>
''');
    return dir;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path == '/' ? '/index.html' : request.uri.path;
      request.response.headers
        ..set('Cross-Origin-Opener-Policy', 'same-origin')
        ..set('Cross-Origin-Embedder-Policy', 'require-corp')
        ..set('Cross-Origin-Resource-Policy', 'same-origin');

      if (path == '/voices.json') {
        final catalog = await loadCatalog();
        final installed = <String>{};
        for (final package in catalog.packages) {
          if (await isPackageInstalled(package)) installed.add(package.id);
        }
        request.response.headers.contentType = ContentType.json;
        request.response
            .write(catalog.runtimeJsonForInstalledPackages(installed));
        await request.response.close();
        return;
      }

      final voiceMatch = RegExp(r'^/([^/]+\.zvoice)$').firstMatch(path);
      if (voiceMatch != null) {
        final file =
            File(p.join((await voiceDir()).path, voiceMatch.group(1)!));
        await _sendFile(request, file, ContentType.binary);
        return;
      }

      final root = _runtimeDir;
      if (root == null) throw StateError('Runtime non preparato.');
      final file = File(p.join(root.path, path.replaceFirst('/', '')));
      final contentType = switch (p.extension(file.path).toLowerCase()) {
        '.html' => ContentType.html,
        '.js' => ContentType('application', 'javascript', charset: 'utf-8'),
        '.wasm' => ContentType('application', 'wasm'),
        _ => ContentType.binary,
      };
      await _sendFile(request, file, contentType);
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(error.toString());
      await request.response.close();
    }
  }

  Future<void> _sendFile(
    HttpRequest request,
    File file,
    ContentType contentType,
  ) async {
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    request.response.headers.contentType = contentType;
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  Future<void> _waitForRuntimeReady() async {
    final controller = _controller;
    final completer = _readyCompleter;
    if (controller == null || completer == null || completer.isCompleted) {
      return;
    }
    for (var i = 0; i < 200; i++) {
      try {
        final result = await controller.runJavaScriptReturningResult('''
typeof window.googleTtsForNvdaSpeak === "function" &&
typeof window.googleTtsForNvdaStop === "function"
''');
        if (result == true || result.toString() == 'true') {
          await AppLogger.log('Google TTS: runtime functions detected');
          completer.complete();
          return;
        }
      } catch (error) {
        if (i == 0 || i == 20 || i == 60) {
          await AppLogger.log('Google TTS: runtime probe failed $error');
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!completer.isCompleted) {
      await AppLogger.log('Google TTS: runtime load timeout');
      completer.completeError('Runtime Google TTS non caricato.');
    }
  }

  void _handleRuntimeMessage(String raw) {
    unawaited(AppLogger.log('Google TTS: runtime message ${raw.length} chars'));
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    if (decoded['sessionId'] != _activeSessionId) return;
    final type = decoded['type']?.toString();
    if (type == 'audio') {
      final data = decoded['data']?.toString() ?? '';
      if (data.isNotEmpty) {
        _activePcmBytes.addAll(base64Decode(data));
      }
    } else if (type == 'done') {
      _activeSynthesis?.complete(Uint8List.fromList(_activePcmBytes));
    } else if (type == 'error') {
      _activeSynthesis?.completeError(
        Exception(decoded['message']?.toString() ?? 'Errore Google TTS'),
      );
    }
  }

  Future<void> _copyAsset(String assetPath, File target) async {
    final data = await rootBundle.load(assetPath);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(data.buffer.asUint8List());
  }

  Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  List<int> _wavBytesFromPcm(Uint8List pcm, {required int sampleRate}) {
    final dataLength = pcm.length;
    final fileLength = 36 + dataLength;
    final bytes = BytesBuilder();
    void ascii(String value) => bytes.add(asciiCodec.encode(value));
    void u16(int value) {
      final data = ByteData(2)..setUint16(0, value, Endian.little);
      bytes.add(data.buffer.asUint8List());
    }

    void u32(int value) {
      final data = ByteData(4)..setUint32(0, value, Endian.little);
      bytes.add(data.buffer.asUint8List());
    }

    ascii('RIFF');
    u32(fileLength);
    ascii('WAVE');
    ascii('fmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(sampleRate);
    u32(sampleRate * 2);
    u16(2);
    u16(16);
    ascii('data');
    u32(dataLength);
    bytes.add(pcm);
    return bytes.toBytes();
  }
}

const asciiCodec = AsciiCodec();

class GoogleTtsRuntimeHost extends StatefulWidget {
  const GoogleTtsRuntimeHost({
    super.key,
    this.bridge,
  });

  final GoogleTtsBridge? bridge;

  @override
  State<GoogleTtsRuntimeHost> createState() => _GoogleTtsRuntimeHostState();
}

class _GoogleTtsRuntimeHostState extends State<GoogleTtsRuntimeHost> {
  WebViewController? _controller;

  GoogleTtsBridge get _bridge => widget.bridge ?? GoogleTtsBridge.instance;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS || Platform.isAndroid) {
      final controller = WebViewController();
      _controller = controller;
      unawaited(_bridge.attachWebViewController(controller));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: SizedBox(
            width: 1,
            height: 1,
            child: WebViewWidget(controller: controller),
          ),
        ),
      ),
    );
  }
}
