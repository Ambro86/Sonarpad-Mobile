import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

import '../utils/app_logger.dart';
import 'app_cache_service.dart';
import 'sonartube_service.dart';

/// Stages SonarTube media as a local file before the user chooses the final
/// destination. The normal [export] method preserves the historical behaviour
/// used by AI audio descriptions (lossless MP4 first, then MKV fallback), while
/// [exportMp4] and [exportMp3] guarantee the format explicitly chosen by the
/// user in the Save media flow.
class SonarTubeMediaExportService {
  Future<String> export({
    required SonarTubeService service,
    required SonarTubeItem item,
  }) async {
    _validate(item);

    final media = await service.resolve(item);
    final operationDir = await _createOperationDirectory();
    final baseName = _safeFileName(media.title.isEmpty ? item.title : media.title);
    final mp4Path = p.join(operationDir.path, '$baseName.mp4');
    final mkvPath = p.join(operationDir.path, '$baseName.mkv');

    try {
      final mp4Args = _remuxArgs(
        media: media,
        outputPath: mp4Path,
        mp4: true,
      );
      if (await _run(mp4Args, outputPath: mp4Path, container: 'mp4')) {
        return mp4Path;
      }

      // The AI-audiodescription source path keeps the original lossless
      // fallback: some high-quality YouTube codec combinations cannot be
      // remuxed directly into MP4.
      final mkvArgs = _remuxArgs(
        media: media,
        outputPath: mkvPath,
        mp4: false,
      );
      if (await _run(mkvArgs, outputPath: mkvPath, container: 'mkv')) {
        return mkvPath;
      }

      throw const FileSystemException('Unable to create SonarTube media file');
    } catch (_) {
      await _deleteDirectory(operationDir);
      rethrow;
    }
  }

  /// Exports a real MP4. It first tries a lossless remux; if YouTube provides
  /// codecs that MP4 cannot contain, FFmpeg transcodes video/audio to codecs
  /// already used by Sonarpad's Convert Media feature.
  Future<String> exportMp4({
    required SonarTubeService service,
    required SonarTubeItem item,
  }) async {
    _validate(item);

    final media = await service.resolve(item);
    final operationDir = await _createOperationDirectory();
    final baseName = _safeFileName(media.title.isEmpty ? item.title : media.title);
    final outputPath = p.join(operationDir.path, '$baseName.mp4');

    try {
      final remuxArgs = _remuxArgs(
        media: media,
        outputPath: outputPath,
        mp4: true,
      );
      if (await _run(remuxArgs, outputPath: outputPath, container: 'mp4-copy')) {
        return outputPath;
      }

      final transcodeArgs = _mp4TranscodeArgs(
        media: media,
        outputPath: outputPath,
      );
      if (await _run(
        transcodeArgs,
        outputPath: outputPath,
        container: 'mp4-transcode',
      )) {
        return outputPath;
      }

      throw const FileSystemException('Unable to create SonarTube MP4 file');
    } catch (_) {
      await _deleteDirectory(operationDir);
      rethrow;
    }
  }

  /// Converts the resolved SonarTube audio stream to a 192 kbps MP3 with
  /// FFmpeg/libmp3lame.
  Future<String> exportMp3({
    required SonarTubeService service,
    required SonarTubeItem item,
  }) async {
    _validate(item);

    final media = await service.resolve(item);
    final operationDir = await _createOperationDirectory();
    final baseName = _safeFileName(media.title.isEmpty ? item.title : media.title);
    final outputPath = p.join(operationDir.path, '$baseName.mp3');

    try {
      final args = <String>[
        '-y',
        '-i',
        media.audioUrl,
        '-map',
        '0:a:0',
        '-vn',
        '-c:a',
        'libmp3lame',
        '-b:a',
        '192k',
        outputPath,
      ];
      if (await _run(args, outputPath: outputPath, container: 'mp3')) {
        return outputPath;
      }
      throw const FileSystemException('Unable to create SonarTube MP3 file');
    } catch (_) {
      await _deleteDirectory(operationDir);
      rethrow;
    }
  }

  void _validate(SonarTubeItem item) {
    if (item.kind != SonarTubeItemKind.video) {
      throw ArgumentError.value(item.kind);
    }
    if (item.isLive) {
      throw StateError(item.id);
    }
  }

  Future<Directory> _createOperationDirectory() async {
    final exportsDir = await AppCacheService.directory(
      AppCacheService.mediaExportsFolder,
    );
    final operationDir = Directory(
      p.join(
        exportsDir.path,
        'sonartube_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await operationDir.create(recursive: true);
    return operationDir;
  }

  List<String> _remuxArgs({
    required SonarTubeResolvedMedia media,
    required String outputPath,
    required bool mp4,
  }) {
    final videoUrl = media.videoUrl?.trim();
    final audioUrl = media.audioUrl.trim();
    final args = <String>['-y'];

    if (videoUrl != null && videoUrl.isNotEmpty) {
      args.addAll([
        '-i',
        videoUrl,
        '-i',
        audioUrl,
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
        '-c',
        'copy',
        '-shortest',
      ]);
    } else {
      // The normal resolver path prefers a progressive YouTube stream that
      // already contains both video and audio. Optional maps also keep the
      // export robust if YouTube returns a playable audio-only stream.
      args.addAll([
        '-i',
        audioUrl,
        '-map',
        '0:v:0?',
        '-map',
        '0:a:0?',
        '-c',
        'copy',
      ]);
    }

    if (mp4) {
      args.addAll(['-movflags', '+faststart']);
    }
    args.add(outputPath);
    return args;
  }

  List<String> _mp4TranscodeArgs({
    required SonarTubeResolvedMedia media,
    required String outputPath,
  }) {
    final videoUrl = media.videoUrl?.trim();
    final audioUrl = media.audioUrl.trim();
    final args = <String>['-y'];

    if (videoUrl != null && videoUrl.isNotEmpty) {
      args.addAll([
        '-i',
        videoUrl,
        '-i',
        audioUrl,
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
      ]);
    } else {
      args.addAll([
        '-i',
        audioUrl,
        '-map',
        '0:v:0?',
        '-map',
        '0:a:0?',
      ]);
    }

    args.addAll([
      '-c:v',
      'mpeg4',
      '-q:v',
      '4',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      if (videoUrl != null && videoUrl.isNotEmpty) '-shortest',
      '-movflags',
      '+faststart',
      outputPath,
    ]);
    return args;
  }

  Future<bool> _run(
    List<String> args, {
    required String outputPath,
    required String container,
  }) async {
    await AppLogger.log(
      'SonarTube save media: ffmpeg $container start output="$outputPath"',
    );
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString() ?? '';
      await AppLogger.log(
        'SonarTube save media: ffmpeg $container failed '
        'returnCode=${returnCode?.getValue()} logs="${_compact(logs)}"',
      );
      final failed = File(outputPath);
      if (await failed.exists()) {
        try {
          await failed.delete();
        } catch (_) {}
      }
      return false;
    }

    final output = File(outputPath);
    if (!await output.exists() || await output.length() <= 0) {
      await AppLogger.log(
        'SonarTube save media: ffmpeg $container produced no usable output',
      );
      return false;
    }
    await AppLogger.log(
      'SonarTube save media: ffmpeg $container completed '
      'bytes=${await output.length()}',
    );
    return true;
  }

  Future<void> cleanup(String filePath) async {
    try {
      final file = File(filePath);
      final parent = file.parent;
      if (await file.exists()) await file.delete();
      if (await parent.exists()) await parent.delete(recursive: true);
    } catch (error) {
      await AppLogger.log(
        'SonarTube save media: cleanup failed path="$filePath" error=$error',
      );
    }
  }

  String _safeFileName(String value) {
    var safe = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safe.isEmpty) safe = 'SonarTube';
    if (safe.length > 120) safe = safe.substring(0, 120).trim();
    return safe;
  }

  String _compact(String value) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 900) return singleLine;
    return '${singleLine.substring(0, 900)}…';
  }

  Future<void> _deleteDirectory(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {}
  }
}
