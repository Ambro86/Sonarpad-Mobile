import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../tts/edge_tts_bridge.dart';
import '../utils/app_logger.dart';
import 'app_settings_service.dart';
import 'voice_dictionary_service.dart';

typedef AudiobookExportProgressCallback = FutureOr<void> Function(
  AudiobookExportProgress progress,
);

class AudiobookExportProgress {
  const AudiobookExportProgress({
    required this.stage,
    required this.current,
    required this.total,
    this.value,
  });

  final AudiobookExportProgressStage stage;
  final int current;
  final int total;
  final double? value;
}

enum AudiobookExportProgressStage {
  preparing,
  generating,
  converting,
  finalizing,
}

/// Esporta un documento testuale come audiolibro usando il motore TTS scelto
/// nelle impostazioni di Sonarpad.
///
/// - Edge TTS: genera direttamente MP3 per ogni blocco e poi unisce/ricodifica.
/// - TTS di sistema: prova a usare synthesizeToFile di flutter_tts; i file
///   temporanei vengono poi convertiti in MP3/M4B con FFmpeg.
///
/// Tutti i passaggi sono scritti nel log impostazioni tramite [AppLogger].
class AudiobookExportService {
  AudiobookExportService({
    AppSettingsService? settings,
    EdgeTtsBridge? edgeTts,
    FlutterTts? flutterTts,
    VoiceDictionaryService? voiceDictionary,
  })  : _settings = settings ?? AppSettingsService(),
        _edgeTts = edgeTts ?? EdgeTtsBridge(),
        _flutterTts = flutterTts ?? FlutterTts(),
        _voiceDictionary = voiceDictionary ?? VoiceDictionaryService();

  final AppSettingsService _settings;
  final EdgeTtsBridge _edgeTts;
  final FlutterTts _flutterTts;
  final VoiceDictionaryService _voiceDictionary;

  static const int _maxChunkChars = 650;
  static const int _bitrateKbps = 64;

  Future<File> export({
    required String text,
    required String title,
    required String outputDirectory,
    required AudiobookExportFormat format,
    AudiobookExportProgressCallback? onProgress,
  }) async {
    final cleanTitle = _safeBaseName(title);
    final extension = format.extension;
    final output = File(p.join(outputDirectory, '${cleanTitle}_audiobook.$extension'));

    await AppLogger.log(
      'Audiobook export: start title="$cleanTitle" format=${format.name} '
      'textLength=${text.length} output="${output.path}"',
    );

    final normalizedText = _normalizeText(text);
    if (normalizedText.trim().isEmpty) {
      await AppLogger.log('Audiobook export: abort, no exportable text');
      throw Exception('Nessun testo esportabile per l\'audiolibro.');
    }

    final chunks = _edgeTts.splitTextForStreaming(
      normalizedText,
      maxChunkChars: _maxChunkChars,
    );
    if (chunks.isEmpty) {
      await AppLogger.log('Audiobook export: abort, split produced zero chunks');
      throw Exception('Nessun blocco audio generabile.');
    }

    final engine = await _settings.loadTtsEngine();
    final speed = await _settings.loadTtsSpeed();
    final pitch = await _settings.loadTtsPitch();
    final dictionaryEntries = await _voiceDictionary.loadEntries();
    await AppLogger.log(
      'Audiobook export: settings engine=$engine speed=$speed pitch=$pitch '
      'chunks=${chunks.length} maxChunkChars=$_maxChunkChars',
    );
    await _notifyProgress(
      onProgress,
      AudiobookExportProgress(
        stage: AudiobookExportProgressStage.preparing,
        current: 0,
        total: chunks.length,
        value: 0,
      ),
    );

    final tempDir = await _createTempDirectory();
    final generatedFiles = <File>[];
    try {
      if (engine == 'system') {
        generatedFiles.addAll(
          await _generateSystemChunks(
            chunks: chunks,
            dictionaryEntries: dictionaryEntries,
            tempDir: tempDir,
            speed: speed,
            pitch: pitch,
            onProgress: onProgress,
          ),
        );
      } else {
        generatedFiles.addAll(
          await _generateEdgeChunks(
            chunks: chunks,
            dictionaryEntries: dictionaryEntries,
            tempDir: tempDir,
            onProgress: onProgress,
          ),
        );
      }

      await AppLogger.log(
        'Audiobook export: generatedFiles=${generatedFiles.length}, merge start',
      );
      await _mergeAudioFiles(
        inputFiles: generatedFiles,
        output: output,
        title: cleanTitle,
        format: format,
        onProgress: onProgress,
      );

      await _notifyProgress(
        onProgress,
        AudiobookExportProgress(
          stage: AudiobookExportProgressStage.finalizing,
          current: chunks.length,
          total: chunks.length,
          value: 1,
        ),
      );

      final exists = await output.exists();
      final size = exists ? await output.length() : 0;
      await AppLogger.log(
        'Audiobook export: completed output="${output.path}" exists=$exists bytes=$size',
      );
      if (!exists || size < 1024) {
        throw Exception('File audiolibro non creato o troppo piccolo: $size byte');
      }
      return output;
    } catch (error, stack) {
      await AppLogger.log('Audiobook export: ERROR $error');
      await AppLogger.log('Audiobook export: stack ${_compact(stack.toString())}');
      rethrow;
    } finally {
      try {
        await tempDir.delete(recursive: true);
        await AppLogger.log('Audiobook export: temp deleted "${tempDir.path}"');
      } catch (error) {
        await AppLogger.log('Audiobook export: temp delete failed $error');
      }
    }
  }

  Future<List<File>> _generateEdgeChunks({
    required List<String> chunks,
    required List<VoiceDictionaryEntry> dictionaryEntries,
    required Directory tempDir,
    AudiobookExportProgressCallback? onProgress,
  }) async {
    final voice = await _settings.loadTtsVoice();
    await AppLogger.log('Audiobook export Edge: voice=$voice');
    final files = <File>[];

    for (var i = 0; i < chunks.length; i++) {
      await _notifyProgress(
        onProgress,
        AudiobookExportProgress(
          stage: AudiobookExportProgressStage.generating,
          current: i,
          total: chunks.length,
          value: chunks.isEmpty ? null : (i / chunks.length) * 0.85,
        ),
      );
      final textToSpeak = _voiceDictionary.applyToText(chunks[i], dictionaryEntries);
      await AppLogger.log(
        'Audiobook export Edge: chunk ${i + 1}/${chunks.length} textLength=${textToSpeak.length}',
      );
      final file = await _edgeTts.speakToFile(text: textToSpeak, voice: voice);
      final target = File(p.join(tempDir.path, 'chunk_${i.toString().padLeft(5, '0')}.mp3'));
      await file.copy(target.path);
      final size = await target.length();
      await AppLogger.log(
        'Audiobook export Edge: chunk ${i + 1}/${chunks.length} file="${target.path}" bytes=$size',
      );
      files.add(target);
      await _notifyProgress(
        onProgress,
        AudiobookExportProgress(
          stage: AudiobookExportProgressStage.generating,
          current: i + 1,
          total: chunks.length,
          value: ((i + 1) / chunks.length) * 0.85,
        ),
      );
    }

    return files;
  }

  Future<List<File>> _generateSystemChunks({
    required List<String> chunks,
    required List<VoiceDictionaryEntry> dictionaryEntries,
    required Directory tempDir,
    required double speed,
    required double pitch,
    AudiobookExportProgressCallback? onProgress,
  }) async {
    final language = await _settings.loadSystemTtsLanguage();
    final voice = await _settings.loadSystemTtsVoice();
    await AppLogger.log(
      'Audiobook export system: configure language=$language voice=${voice ?? 'default'} '
      'speed=$speed pitch=$pitch platform=${Platform.operatingSystem}',
    );

    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setSpeechRate(speed * 0.5);
    await _flutterTts.setPitch(pitch);
    await _flutterTts.setVolume(1.0);
    if (voice != null && voice.trim().isNotEmpty) {
      await _flutterTts.setVoice({'name': voice, 'locale': language});
    } else {
      await _flutterTts.setLanguage(language);
    }

    final files = <File>[];
    final tempExtension = Platform.isIOS ? 'caf' : 'wav';

    for (var i = 0; i < chunks.length; i++) {
      await _notifyProgress(
        onProgress,
        AudiobookExportProgress(
          stage: AudiobookExportProgressStage.generating,
          current: i,
          total: chunks.length,
          value: chunks.isEmpty ? null : (i / chunks.length) * 0.85,
        ),
      );
      final textToSpeak = _voiceDictionary.applyToText(chunks[i], dictionaryEntries);
      final path = p.join(
        tempDir.path,
        'system_chunk_${i.toString().padLeft(5, '0')}.$tempExtension',
      );
      final file = File(path);
      if (await file.exists()) await file.delete();

      await AppLogger.log(
        'Audiobook export system: synth chunk ${i + 1}/${chunks.length} '
        'textLength=${textToSpeak.length} path="$path"',
      );
      await _synthesizeSystemChunkToFile(textToSpeak, file);

      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      await AppLogger.log(
        'Audiobook export system: chunk ${i + 1}/${chunks.length} exists=$exists bytes=$size',
      );
      if (!exists || size < 512) {
        throw Exception(
          'La voce di sistema non ha generato un file audio valido per il blocco ${i + 1}: $size byte',
        );
      }
      files.add(file);
      await _notifyProgress(
        onProgress,
        AudiobookExportProgress(
          stage: AudiobookExportProgressStage.generating,
          current: i + 1,
          total: chunks.length,
          value: ((i + 1) / chunks.length) * 0.85,
        ),
      );
    }

    return files;
  }

  Future<void> _synthesizeSystemChunkToFile(String text, File output) async {
    final completer = Completer<void>();
    Object? ttsError;

    _flutterTts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _flutterTts.setErrorHandler((message) {
      ttsError = message;
      if (!completer.isCompleted) completer.complete();
    });

    try {
      final result = await _flutterTts.synthesizeToFile(text, output.path, true);
      await AppLogger.log(
        'Audiobook export system: synthesizeToFile returned ${result ?? "null"}',
      );

      if (ttsError != null) {
        throw Exception(ttsError);
      }

      // Alcune implementazioni completano la Future solo dopo la scrittura,
      // altre inviano anche il completion handler. Aspettiamo il file in modo
      // esplicito per coprire entrambi i casi.
      await _waitForFile(output, timeout: const Duration(seconds: 90));
      if (ttsError != null) {
        throw Exception(ttsError);
      }

      if (!completer.isCompleted) {
        // Non tutti i motori inviano completion per synthesizeToFile: se il file
        // esiste ed è non vuoto, consideriamo riuscita la sintesi.
        completer.complete();
      }
      await completer.future.timeout(const Duration(seconds: 5));
    } catch (error) {
      final message = ttsError ?? error;
      await AppLogger.log('Audiobook export system: synthesize failed $message');
      throw Exception(
        'Esportazione con voce di sistema non riuscita. Dettagli: $message',
      );
    }
  }

  Future<void> _waitForFile(File file, {required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    var lastSize = 0;
    var stableChecks = 0;

    while (DateTime.now().isBefore(deadline)) {
      if (await file.exists()) {
        final size = await file.length();
        if (size > 512 && size == lastSize) {
          stableChecks += 1;
          if (stableChecks >= 2) return;
        } else {
          stableChecks = 0;
        }
        lastSize = size;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }
    throw TimeoutException('Timeout durante la creazione del file TTS di sistema');
  }

  Future<void> _mergeAudioFiles({
    required List<File> inputFiles,
    required File output,
    required String title,
    required AudiobookExportFormat format,
    AudiobookExportProgressCallback? onProgress,
  }) async {
    if (inputFiles.isEmpty) {
      throw Exception('Nessun file audio da unire.');
    }
    if (await output.exists()) await output.delete();

    final listFile = File(p.join(p.dirname(inputFiles.first.path), 'concat_list.txt'));
    await listFile.writeAsString(
      inputFiles.map((file) => "file '${_escapeConcatPath(file.path)}'").join('\n'),
      flush: true,
    );

    final args = [
      '-y',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      listFile.path,
      '-vn',
      '-metadata',
      'title=$title',
      if (format == AudiobookExportFormat.mp3) ...[
        '-c:a',
        'libmp3lame',
        '-b:a',
        '${_bitrateKbps}k',
      ] else ...[
        '-c:a',
        'aac',
        '-b:a',
        '${_bitrateKbps}k',
        '-movflags',
        '+faststart',
        '-f',
        'mp4',
      ],
      output.path,
    ];

    await _notifyProgress(
      onProgress,
      AudiobookExportProgress(
        stage: AudiobookExportProgressStage.converting,
        current: inputFiles.length,
        total: inputFiles.length,
        value: null,
      ),
    );
    await AppLogger.log('Audiobook export ffmpeg: args=${args.map(_quoteLogArg).join(" ")}');
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    final logs = await session.getAllLogsAsString() ?? '';
    if (!ReturnCode.isSuccess(returnCode)) {
      await AppLogger.log(
        'Audiobook export ffmpeg: failed returnCode=${returnCode?.getValue()} logs="${_compact(logs)}"',
      );
      throw Exception(
        logs.trim().isEmpty ? 'FFmpeg returnCode=${returnCode?.getValue()}' : logs,
      );
    }
    await AppLogger.log(
      'Audiobook export ffmpeg: success returnCode=${returnCode?.getValue()} logs="${_compact(logs)}"',
    );
  }

  Future<void> _notifyProgress(
    AudiobookExportProgressCallback? callback,
    AudiobookExportProgress progress,
  ) async {
    if (callback == null) return;
    await callback(progress);
  }

  Future<Directory> _createTempDirectory() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(
      p.join(base.path, 'sonarpad_audiobook_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await dir.create(recursive: true);
    await AppLogger.log('Audiobook export: temp="${dir.path}"');
    return dir;
  }

  String _normalizeText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\u200B', '')
        .replaceAll('\uFEFF', '')
        .trim();
  }

  String _safeBaseName(String value) {
    final cleaned = value
        .replaceAll('/', ' ')
        .replaceAll('\\', ' ')
        .replaceAll(':', ' ')
        .replaceAll('*', ' ')
        .replaceAll('?', ' ')
        .replaceAll('"', ' ')
        .replaceAll('<', ' ')
        .replaceAll('>', ' ')
        .replaceAll('|', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    return cleaned.isEmpty ? 'Documento' : cleaned;
  }

  String _escapeConcatPath(String path) => path.replaceAll("'", "'\\''");

  String _quoteLogArg(String value) {
    if (value.isEmpty) return '""';
    if (!value.contains(RegExp(r'\s'))) return value;
    return '"${value.replaceAll('"', '\\"')}"';
  }

  String _compact(String value) {
    final oneLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= 1500) return oneLine;
    return '${oneLine.substring(0, 1500)}...';
  }
}

enum AudiobookExportFormat {
  mp3('mp3'),
  m4b('m4b');

  const AudiobookExportFormat(this.extension);
  final String extension;
}
