import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

class RadioRecordingService {
  static const _ffmpegUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  final String directoryName;
  final bool includeVideo;

  FFmpegSession? _session;
  File? _outputFile;
  int _ffmpegLogLines = 0;

  RadioRecordingService({
    this.directoryName = 'Radio Registrazioni',
    this.includeVideo = false,
  });

  bool get isRecording => _session != null;
  File? get outputFile => _outputFile;

  Future<Directory> recordingsDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, directoryName));
  }

  Future<List<File>> listRecordings() async {
    final dir = await recordingsDirectory();
    await AppLogger.log(
      'Radio recording: list directory="${dir.path}" includeVideo=$includeVideo',
    );
    if (!await dir.exists()) {
      await AppLogger.log('Radio recording: list directory missing');
      return const [];
    }

    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) {
        await AppLogger.log('Radio recording: ignored non-file "${entity.path}"');
        continue;
      }
      final ext = p.extension(entity.path).toLowerCase();
      final allowed = includeVideo
          ? const ['.mp4', '.ts', '.mkv', '.m4a']
          : const ['.mp3', '.m4a', '.aac'];
      if (allowed.contains(ext)) {
        await AppLogger.log(
          'Radio recording: found file="${entity.path}" size=${await entity.length()}',
        );
        files.add(entity);
      } else {
        await AppLogger.log(
          'Radio recording: ignored file="${entity.path}" extension="$ext"',
        );
      }
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    await AppLogger.log('Radio recording: list count=${files.length}');
    return files;
  }

  Future<File> start({
    required String stationName,
    required String streamUrl,
  }) async {
    if (_session != null) {
      throw StateError('Registrazione gia in corso.');
    }

    final dir = await recordingsDirectory();
    await dir.create(recursive: true);
    final ext = _recordingExtension(streamUrl);
    final file = File(p.join(
      dir.path,
      '${_safeFileName(stationName)} - ${_timestamp()}$ext',
    ));
    final arguments = _recordingArguments(
      streamUrl: streamUrl,
      outputPath: file.path,
    );

    await AppLogger.log(
      'Radio recording: start station="$stationName" output="${file.path}"',
    );
    await AppLogger.log('Radio recording: ffmpeg args=${arguments.join(' ')}');
    _outputFile = file;
    _ffmpegLogLines = 0;
    _session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final returnCode = await session.getReturnCode();
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        await AppLogger.log(
          'Radio recording: finished output="${file.path}" '
          'returnCode=${returnCode?.getValue()} exists=$exists size=$size',
        );
      },
      (log) async {
        final message = log.getMessage().trim();
        if (message.isNotEmpty && _shouldLogFfmpegLine(message)) {
          _ffmpegLogLines += 1;
          await AppLogger.log('Radio recording ffmpeg: $message');
        }
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final earlyReturnCode = await _session?.getReturnCode();
    if (earlyReturnCode != null) {
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      await AppLogger.log(
        'Radio recording: early finish output="${file.path}" '
        'returnCode=${earlyReturnCode.getValue()} exists=$exists size=$size',
      );
      if (!exists || size == 0) {
        _session = null;
        _outputFile = null;
        throw Exception('Registrazione non creata dallo stream.');
      }
    }
    return file;
  }

  Future<File?> stop() async {
    final session = _session;
    final file = _outputFile;
    if (session == null) return file;

    await AppLogger.log('Radio recording: stop output="${file?.path}"');
    await FFmpegKit.cancel(session.getSessionId());
    if (file != null) {
      await _waitForFile(file);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      await AppLogger.log(
        'Radio recording: stopped output="${file.path}" exists=$exists size=$size',
      );
      _session = null;
      _outputFile = null;
      if (!exists || size == 0) {
        throw Exception('Registrazione non creata dallo stream.');
      }
      return file;
    }
    _session = null;
    _outputFile = null;
    return null;
  }

  Future<void> _waitForFile(File file) async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      if (await file.exists() && await file.length() > 0) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  String _recordingExtension(String streamUrl) {
    if (includeVideo) {
      if (_isDashStream(streamUrl)) {
        return '.m4a';
      }
      return '.mp4';
    }
    return '.m4a';
  }

  List<String> _recordingArguments({
    required String streamUrl,
    required String outputPath,
  }) {
    if (includeVideo) {
      if (_isDashStream(streamUrl)) {
        return [
          '-y',
          '-user_agent',
          _ffmpegUserAgent,
          '-i',
          streamUrl,
          '-vn',
          '-c:a',
          'aac',
          '-b:a',
          '128k',
          outputPath,
        ];
      }
      return [
        '-y',
        '-user_agent',
        _ffmpegUserAgent,
        '-i',
        streamUrl,
        '-c',
        'copy',
        outputPath,
      ];
    }
    return [
      '-y',
      '-user_agent',
      _ffmpegUserAgent,
      '-i',
      streamUrl,
      '-vn',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      outputPath,
    ];
  }

  bool _isDashStream(String streamUrl) {
    final path = Uri.tryParse(streamUrl)?.path.toLowerCase() ??
        streamUrl.toLowerCase();
    return path.endsWith('.mpd');
  }

  bool _shouldLogFfmpegLine(String message) {
    if (_ffmpegLogLines >= 40) return false;
    final lower = message.toLowerCase();
    return lower.contains('error') ||
        lower.contains('forbidden') ||
        lower.contains('failed') ||
        lower.contains('invalid') ||
        lower.contains('server returned') ||
        lower.contains('not found') ||
        lower.contains('timed out') ||
        lower.contains('unable');
  }

  String _safeFileName(String value) {
    const invalid = '<>:"/\\|?*';
    final buffer = StringBuffer();
    var previousWasSpace = false;
    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final isSpace = char.trim().isEmpty;
      final replacement = invalid.contains(char) || isSpace ? ' ' : char;
      if (replacement == ' ') {
        if (previousWasSpace) continue;
        previousWasSpace = true;
      } else {
        previousWasSpace = false;
      }
      buffer.write(replacement);
    }
    final cleaned = buffer.toString().trim();
    return cleaned.isEmpty ? 'Radio' : cleaned;
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
  }
}
