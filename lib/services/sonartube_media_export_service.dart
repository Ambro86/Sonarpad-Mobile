import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

import '../utils/app_logger.dart';
import 'app_cache_service.dart';
import 'sonartube_service.dart';

/// Stages a SonarTube video as a local file before the user chooses the final
/// destination. This mirrors Media Cutter and AI audio-description exports:
/// generation happens first, then Sonarpad offers Documents or Share.
class SonarTubeMediaExportService {
  Future<String> export({
    required SonarTubeService service,
    required SonarTubeItem item,
  }) async {
    if (item.kind != SonarTubeItemKind.video) {
      throw ArgumentError('SonarTube media export requires a video item.');
    }
    if (item.isLive) {
      throw StateError('Live SonarTube streams cannot be exported.');
    }

    final media = await service.resolve(item);
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

    final baseName = _safeFileName(media.title.isEmpty ? item.title : media.title);
    final mp4Path = p.join(operationDir.path, '$baseName.mp4');
    final mkvPath = p.join(operationDir.path, '$baseName.mkv');

    try {
      final mp4Args = _ffmpegArgs(
        media: media,
        outputPath: mp4Path,
        mp4: true,
      );
      if (await _run(mp4Args, outputPath: mp4Path, container: 'mp4')) {
        return mp4Path;
      }

      // Some high-quality YouTube combinations use codecs that cannot be
      // remuxed losslessly into MP4. Fall back to Matroska rather than
      // transcoding and degrading quality or wasting battery on mobile.
      final mkvArgs = _ffmpegArgs(
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

  List<String> _ffmpegArgs({
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
