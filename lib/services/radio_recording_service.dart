import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

class RadioRecordingService {
  final String directoryName;
  final bool includeVideo;

  FFmpegSession? _session;
  File? _outputFile;

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
          ? const ['.mp4', '.ts', '.mkv']
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
    final ext = _recordingExtension();
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
        if (message.isNotEmpty) {
          await AppLogger.log('Radio recording ffmpeg: $message');
        }
      },
    );
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
    }
    _session = null;
    _outputFile = null;
    return file;
  }

  Future<void> _waitForFile(File file) async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      if (await file.exists() && await file.length() > 0) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  String _recordingExtension() {
    if (includeVideo) {
      return '.mp4';
    }
    return '.m4a';
  }

  List<String> _recordingArguments({
    required String streamUrl,
    required String outputPath,
  }) {
    if (includeVideo) {
      return [
        '-y',
        '-i',
        streamUrl,
        '-c',
        'copy',
        outputPath,
      ];
    }
    return [
      '-y',
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
