import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

import 'media_join_service.dart';

typedef MediaSplitProbe = Future<MediaJoinItemInfo> Function(String path);

class DocumentMediaSplitService {
  DocumentMediaSplitService({
    MediaSplitProbe? probe,
    Future<bool> Function(List<String>)? execute,
  }) : probe = probe ?? MediaJoinService().probe,
       _execute = execute ?? _executeKit;

  final MediaSplitProbe probe;
  final Future<bool> Function(List<String>) _execute;

  static Future<bool> _executeKit(List<String> args) async {
    final session = await FFmpegKit.executeWithArguments(args);
    return ReturnCode.isSuccess(await session.getReturnCode());
  }

  static int maxParts(MediaJoinItemInfo info) {
    final fps = info.frameRate;
    if (info.hasVideo && fps != null && fps > 0) {
      return math.max(
        1,
        (info.duration.inMicroseconds / 1000000 * fps).floor(),
      );
    }
    return math.max(1, info.duration.inMilliseconds);
  }

  /// [work] is private to this split. The caller removes it on success or failure.
  Future<List<File>> split(
    MediaJoinItemInfo input,
    int count,
    Directory work,
    String extension,
  ) async {
    if (count < 1 || count > maxParts(input)) throw RangeError.value(count);
    if (count == 1) return [File(input.path)];
    final partSeconds = input.duration.inMicroseconds / 1000000 / count;
    final boundaries = [
      for (var i = 1; i < count; i++) (partSeconds * i).toStringAsFixed(6),
    ].join(',');
    for (final copy in [true, false]) {
      if (!copy) {
        await Directory(p.join(work.path, 'copy')).delete(recursive: true);
      }
      final dir = await Directory(
        p.join(work.path, copy ? 'copy' : 'encode'),
      ).create();
      final args = [
        '-y',
        '-i',
        input.path,
        if (copy) ...['-map', '0'] else ...['-map', '0:V?', '-map', '0:a?'],
        if (copy) ...[
          '-c',
          'copy',
        ] else if (input.hasVideo) ...[
          if ([
            'mp4',
            'm4v',
            'mov',
            'mkv',
            'avi',
            '3gp',
          ].contains(extension)) ...[
            '-c:v',
            'mpeg4',
            '-q:v',
            '4',
          ],
          '-force_key_frames',
          boundaries,
        ],
        '-f',
        'segment',
        '-reference_stream',
        input.hasVideo ? 'V:0' : 'a:0',
        '-segment_times',
        boundaries,
        if (!copy && input.hasVideo) ...[
          '-segment_time_delta',
          (0.5 / (input.frameRate ?? 25)).toStringAsFixed(6),
        ],
        '-reset_timestamps',
        '1',
        p.join(dir.path, '%09d.$extension'),
      ];
      if (!await _execute(args)) continue;
      final files = await dir
          .list()
          .where((entry) => entry is File)
          .cast<File>()
          .toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      if (files.length != count) continue;
      var valid = true;
      // Container rounding and encoder padding can add or remove a few frames.
      final tolerance = math.max(0.15, 2 / (input.frameRate ?? 25));
      for (final file in files) {
        try {
          final info = await probe(file.path);
          final seconds = info.duration.inMicroseconds / 1000000;
          if (info.hasAudio != input.hasAudio ||
              info.hasVideo != input.hasVideo ||
              seconds <= 0 ||
              (seconds - partSeconds).abs() > tolerance) {
            valid = false;
            break;
          }
        } catch (_) {
          valid = false;
          break;
        }
      }
      if (valid) return files;
    }
    throw StateError('media_split_failed');
  }
}
