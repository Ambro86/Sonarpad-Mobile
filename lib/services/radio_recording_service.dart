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
    if (!await dir.exists()) return const [];

    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      final allowed = includeVideo
          ? const ['.mp4', '.ts', '.mkv']
          : const ['.mp3', '.m4a', '.aac'];
      if (allowed.contains(ext)) {
        files.add(entity);
      }
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
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
    final arguments = [
      '-y',
      '-i',
      streamUrl,
      if (!includeVideo) '-vn',
      '-c',
      'copy',
      file.path,
    ];

    await AppLogger.log(
      'Radio recording: start station="$stationName" output="${file.path}"',
    );
    _outputFile = file;
    _session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final returnCode = await session.getReturnCode();
        await AppLogger.log(
          'Radio recording: finished output="${file.path}" '
          'returnCode=${returnCode?.getValue()}',
        );
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
    _session = null;
    _outputFile = null;
    return file;
  }

  String _recordingExtension(String streamUrl) {
    final path = Uri.tryParse(streamUrl)?.path.toLowerCase() ??
        streamUrl.toLowerCase();
    if (includeVideo) {
      return '.mp4';
    }
    if (path.endsWith('.m3u8')) return '.m4a';
    if (path.endsWith('.aac')) return '.aac';
    return '.mp3';
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
