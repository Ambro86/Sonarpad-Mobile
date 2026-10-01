import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';
import 'package:path/path.dart' as p;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utils/app_logger.dart';
import 'app_cache_service.dart';

enum MediaJoinStage {
  preparing,
  normalizing,
  merging,
  verifying,
  completing,
}

enum MediaJoinOutputFormat {
  mp3('mp3', false),
  m4a('m4a', false),
  wav('wav', false),
  flac('flac', false),
  ogg('ogg', false),
  opus('opus', false),
  aac('aac', false),
  wma('wma', false),
  aiff('aiff', false),
  mp4('mp4', true),
  mkv('mkv', true),
  mov('mov', true),
  avi('avi', true),
  wmv('wmv', true),
  mpg('mpg', true),
  flv('flv', true),
  threeGp('3gp', true),
  ts('ts', true);

  const MediaJoinOutputFormat(this.extension, this.isVideo);

  final String extension;
  final bool isVideo;

  String get label => extension.toUpperCase();
}

class MediaJoinProgress {
  const MediaJoinProgress({
    required this.fraction,
    required this.stage,
    this.current = 0,
    this.total = 0,
  });

  final double fraction;
  final MediaJoinStage stage;
  final int current;
  final int total;
}

class MediaJoinCancelled implements Exception {
  const MediaJoinCancelled();
}

class MediaJoinCancellationToken {
  bool _cancelled = false;
  FFmpegSession? _currentSession;
  final Completer<void> _cancelDispatched = Completer<void>();

  bool get isCancelled => _cancelled;
  Future<void> get cancellationDispatched => _cancelDispatched.future;

  void throwIfCancelled() {
    if (_cancelled) throw const MediaJoinCancelled();
  }

  Future<void> cancel() async {
    if (_cancelled) {
      if (!_cancelDispatched.isCompleted) {
        await _cancelDispatched.future;
      }
      return;
    }
    _cancelled = true;
    try {
      await AppLogger.log('Media join: cancellation requested');
      final session = _currentSession;
      if (session != null) {
        try {
          await session.cancel().timeout(const Duration(seconds: 2));
          await AppLogger.log('Media join: active FFmpeg session cancel sent');
        } on TimeoutException {
          await AppLogger.log(
            'Media join: active session cancel timed out; using global cancel',
          );
        } catch (error) {
          await AppLogger.log(
            'Media join: active session cancel failed error=$error',
          );
        }
      }
      try {
        await FFmpegKit.cancel().timeout(const Duration(seconds: 2));
        await AppLogger.log('Media join: global FFmpeg cancel sent');
      } on TimeoutException {
        await AppLogger.log(
          'Media join: global FFmpeg cancel dispatch timed out',
        );
      } catch (error) {
        await AppLogger.log(
          'Media join: global ffmpeg cancel failed error=$error',
        );
      }
    } finally {
      if (!_cancelDispatched.isCompleted) _cancelDispatched.complete();
    }
  }
}

class MediaJoinItemInfo {
  const MediaJoinItemInfo({
    required this.path,
    required this.hasVideo,
    required this.hasAudio,
    required this.duration,
    required this.videoStreamIndex,
    required this.audioStreamIndex,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.frameRate,
  });

  final String path;
  final bool hasVideo;
  final bool hasAudio;
  final Duration duration;
  final int? videoStreamIndex;
  final int? audioStreamIndex;
  final int? width;
  final int? height;
  final int rotationDegrees;
  final double? frameRate;

  int? get displayWidth {
    final value = width;
    if (value == null) return null;
    return rotationDegrees == 90 || rotationDegrees == 270 ? height : value;
  }

  int? get displayHeight {
    final value = height;
    if (value == null) return null;
    return rotationDegrees == 90 || rotationDegrees == 270 ? width : value;
  }

  String get logSummary =>
      'video=$hasVideo audio=$hasAudio duration=${duration.inMilliseconds}ms '
      'videoStream=${videoStreamIndex ?? 'none'} audioStream=${audioStreamIndex ?? 'none'} '
      'coded=${width ?? 0}x${height ?? 0} display=${displayWidth ?? 0}x${displayHeight ?? 0} '
      'rotation=$rotationDegrees fps=${frameRate?.toStringAsFixed(3) ?? 'unknown'}';
}

class MediaJoinResult {
  const MediaJoinResult({
    required this.path,
    required this.hasVideo,
  });

  final String path;
  final bool hasVideo;
}

class MediaJoinService {
  static const supportedExtensions = <String>[
    'mp3',
    'm4a',
    'mp4',
    'aac',
    'mkv',
    'avi',
    'mov',
    'm4v',
    'webm',
    'mpg',
    'mpeg',
    'ts',
    'm2ts',
    'mts',
    'wmv',
    'asf',
    'flv',
    'vob',
    '3gp',
    'flac',
    'ogg',
    'opus',
    'wma',
    'aiff',
    'aif',
    'm4b',
    'wav',
  ];

  Future<MediaJoinItemInfo> probe(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Media file is inaccessible', path);
    }
    if (await file.length() <= 0) {
      throw StateError('Media file is empty.');
    }

    await AppLogger.log('Media join ffprobe start path="$path"');
    final session = await FFprobeKit.getMediaInformation(path);
    final returnCode = await session.getReturnCode();
    final information = session.getMediaInformation();
    final output = await session.getOutput() ?? '';
    if (!ReturnCode.isSuccess(returnCode) || information == null) {
      await AppLogger.log(
        'Media join ffprobe failed returnCode=${returnCode?.getValue()} '
        'output="${_compactLog(output)}" path="$path"',
      );
      throw StateError('The media file could not be analyzed.');
    }

    final streams = information.getStreams();
    final video = _preferredStream(
      streams.where(
        (stream) =>
            stream.getType() == 'video' && !_isAttachedPictureStream(stream),
      ),
    );
    final audio = _preferredStream(
      streams.where((stream) => stream.getType() == 'audio'),
    );
    if (video == null && audio == null) {
      throw StateError('The file contains no usable audio or video stream.');
    }

    final duration = _parseDuration(information.getDuration()) ??
        _parseDuration(video?.getStringProperty('duration')) ??
        _parseDuration(audio?.getStringProperty('duration'));
    if (duration == null || duration <= Duration.zero) {
      throw StateError('The media file has an invalid duration.');
    }

    final result = MediaJoinItemInfo(
      path: path,
      hasVideo: video != null,
      hasAudio: audio != null,
      duration: duration,
      videoStreamIndex: video?.getIndex(),
      audioStreamIndex: audio?.getIndex(),
      width: video?.getWidth(),
      height: video?.getHeight(),
      rotationDegrees: _rotationDegrees(video),
      frameRate: _parseRate(
        video?.getAverageFrameRate() ?? video?.getRealFrameRate(),
      ),
    );
    await AppLogger.log(
      'Media join ffprobe completed ${result.logSummary} path="$path"',
    );
    return result;
  }

  Future<MediaJoinResult> join(
    List<MediaJoinItemInfo> items, {
    required MediaJoinCancellationToken cancellationToken,
    required MediaJoinOutputFormat outputFormat,
    void Function(MediaJoinProgress progress)? onProgress,
  }) async {
    if (items.length < 2) {
      throw ArgumentError('At least two media files are required.');
    }
    cancellationToken.throwIfCancelled();

    final snapshots = <String, FileStat>{};
    for (final item in items) {
      final file = File(item.path);
      if (!await file.exists()) {
        throw FileSystemException('Media file is inaccessible', item.path);
      }
      snapshots[item.path] = await file.stat();
    }

    final hasVideo = items.any((item) => item.hasVideo);
    if (hasVideo != outputFormat.isVideo) {
      throw ArgumentError(
        hasVideo
            ? 'A video or mixed join requires a video output format.'
            : 'An audio-only join requires an audio output format.',
      );
    }
    final expectedDuration = items.fold<Duration>(
      Duration.zero,
      (value, item) => value + item.duration,
    );
    if (expectedDuration <= Duration.zero) {
      throw StateError('The total media duration is invalid.');
    }

    final exportsRoot = await AppCacheService.directory(
      AppCacheService.mediaExportsFolder,
    );
    final operationDir = Directory(
      p.join(
        exportsRoot.path,
        'join_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final workDir = Directory(p.join(operationDir.path, 'work'));
    await workDir.create(recursive: true);

    var success = false;
    var wakelockEnabled = false;
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        try {
          await WakelockPlus.enable();
          wakelockEnabled = true;
          await AppLogger.log('Media join: wakelock enabled');
        } catch (error) {
          await AppLogger.log('Media join: wakelock enable failed error=$error');
        }
      }

      _progress(
        onProgress,
        0.01,
        MediaJoinStage.preparing,
        current: 0,
        total: items.length,
      );
      await AppLogger.log(
        'Media join: start count=${items.length} hasVideo=$hasVideo '
        'outputFormat=${outputFormat.extension} '
        'expectedDurationMs=${expectedDuration.inMilliseconds}',
      );

      final normalized = <String>[];
      late final int targetWidth;
      late final int targetHeight;
      late final double targetFrameRate;
      if (hasVideo) {
        final firstVideo = items.firstWhere((item) => item.hasVideo);
        targetWidth = _evenDimension(firstVideo.displayWidth ?? 1280);
        targetHeight = _evenDimension(firstVideo.displayHeight ?? 720);
        targetFrameRate = _targetFrameRate(firstVideo.frameRate);
        await AppLogger.log(
          'Media join: video target ${targetWidth}x$targetHeight '
          'fps=${targetFrameRate.toStringAsFixed(3)}',
        );
      }

      for (var i = 0; i < items.length; i++) {
        cancellationToken.throwIfCancelled();
        final item = items[i];
        final extension = hasVideo ? '.mp4' : '.wav';
        final output = p.join(
          workDir.path,
          'segment_${i.toString().padLeft(4, '0')}$extension',
        );
        final startFraction = 0.03 + (0.72 * i / items.length);
        final segmentFraction = 0.72 / items.length;
        _progress(
          onProgress,
          startFraction,
          MediaJoinStage.normalizing,
          current: i + 1,
          total: items.length,
        );

        final args = hasVideo
            ? _videoNormalizationArguments(
                item: item,
                output: output,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                targetFrameRate: targetFrameRate,
              )
            : _audioNormalizationArguments(item: item, output: output);

        await _runFfmpeg(
          args,
          'normalize ${i + 1}/${items.length}',
          cancellationToken,
          onStatistics: (statistics) {
            final elapsed = statistics.getTime().clamp(
                  0,
                  item.duration.inMilliseconds,
                );
            final local = item.duration.inMilliseconds <= 0
                ? 0.0
                : elapsed / item.duration.inMilliseconds;
            _progress(
              onProgress,
              startFraction + segmentFraction * local.clamp(0.0, 1.0),
              MediaJoinStage.normalizing,
              current: i + 1,
              total: items.length,
            );
          },
        );
        await _validate(
          path: output,
          expectedVideo: hasVideo,
          expectedAudio: true,
          expectedDuration: item.duration,
          label: 'normalized segment ${i + 1}',
          cancellationToken: cancellationToken,
          deepDecode: false,
        );
        normalized.add(output);
      }

      for (final item in items) {
        cancellationToken.throwIfCancelled();
        final before = snapshots[item.path]!;
        final current = await File(item.path).stat();
        if (current.type != FileSystemEntityType.file ||
            current.size != before.size ||
            current.modified != before.modified) {
          throw StateError('A source media file changed during processing.');
        }
      }

      final listFile = File(p.join(workDir.path, 'concat.txt'));
      await listFile.writeAsString(
        normalized
            .map((path) => "file '${path.replaceAll("'", r"'\\''")}'")
            .join('\n'),
        flush: true,
      );

      final outputExtension = '.${outputFormat.extension}';
      final finalPath = p.join(
        operationDir.path,
        'Sonarpad_joined_${DateTime.now().millisecondsSinceEpoch}$outputExtension',
      );
      final pendingPath = p.join(workDir.path, 'joined.partial$outputExtension');
      _progress(
        onProgress,
        0.78,
        MediaJoinStage.merging,
        current: items.length,
        total: items.length,
      );

      if (hasVideo) {
        final baseVideoPath = outputFormat == MediaJoinOutputFormat.mp4
            ? pendingPath
            : p.join(workDir.path, 'joined_base.mp4');
        await _mergeVideoSegments(
          normalized: normalized,
          listFile: listFile,
          pendingPath: baseVideoPath,
          expectedDuration: expectedDuration,
          cancellationToken: cancellationToken,
          onProgress: onProgress,
          progressStart: 0.78,
          progressSpan: outputFormat == MediaJoinOutputFormat.mp4 ? 0.12 : 0.07,
        );
        if (outputFormat != MediaJoinOutputFormat.mp4) {
          cancellationToken.throwIfCancelled();
          await _transcodeVideoOutput(
            inputPath: baseVideoPath,
            outputPath: pendingPath,
            format: outputFormat,
            expectedDuration: expectedDuration,
            cancellationToken: cancellationToken,
            onProgress: onProgress,
          );
        }
      } else {
        await _mergeAudioSegments(
          listFile: listFile,
          pendingPath: pendingPath,
          format: outputFormat,
          expectedDuration: expectedDuration,
          cancellationToken: cancellationToken,
          onProgress: onProgress,
          itemCount: items.length,
        );
      }

      cancellationToken.throwIfCancelled();
      final junctions = <Duration>[];
      var cursor = Duration.zero;
      for (var i = 0; i < items.length - 1; i++) {
        cursor += items[i].duration;
        junctions.add(cursor);
      }
      _progress(
        onProgress,
        0.94,
        MediaJoinStage.verifying,
        current: items.length,
        total: items.length,
      );
      await _validate(
        path: pendingPath,
        expectedVideo: hasVideo,
        expectedAudio: true,
        expectedDuration: expectedDuration,
        label: 'final joined file',
        cancellationToken: cancellationToken,
        deepDecode: true,
        validationPoints: junctions,
      );

      cancellationToken.throwIfCancelled();
      _progress(
        onProgress,
        0.99,
        MediaJoinStage.completing,
        current: items.length,
        total: items.length,
      );
      await File(pendingPath).rename(finalPath);
      final finalFile = File(finalPath);
      if (!await finalFile.exists() || await finalFile.length() <= 0) {
        throw StateError('The joined media file was not published correctly.');
      }
      success = true;
      _progress(
        onProgress,
        1,
        MediaJoinStage.completing,
        current: items.length,
        total: items.length,
      );
      await AppLogger.log(
        'Media join: completed output="$finalPath" '
        'bytes=${await finalFile.length()} hasVideo=$hasVideo '
        'format=${outputFormat.extension}',
      );
      return MediaJoinResult(path: finalPath, hasVideo: hasVideo);
    } finally {
      cancellationToken._currentSession = null;
      if (wakelockEnabled) {
        try {
          await WakelockPlus.disable();
          await AppLogger.log('Media join: wakelock disabled');
        } catch (error) {
          await AppLogger.log('Media join: wakelock disable failed error=$error');
        }
      }
      try {
        if (await workDir.exists()) await workDir.delete(recursive: true);
      } catch (error) {
        await AppLogger.log(
          'Media join: work cleanup failed path="${workDir.path}" error=$error',
        );
      }
      if (!success) {
        try {
          if (await operationDir.exists()) {
            await operationDir.delete(recursive: true);
          }
        } catch (error) {
          await AppLogger.log(
            'Media join: failed-operation cleanup error=$error',
          );
        }
      }
    }
  }

  List<String> _audioNormalizationArguments({
    required MediaJoinItemInfo item,
    required String output,
  }) {
    return [
      '-y',
      '-fflags',
      '+genpts',
      '-i',
      item.path,
      '-map',
      _streamMap(item, audio: true),
      '-vn',
      '-sn',
      '-dn',
      '-af',
      _audioNormalizationFilter,
      '-t',
      _ffmpegTime(item.duration),
      '-c:a',
      'pcm_s16le',
      '-ar',
      '44100',
      '-ac',
      '2',
      output,
    ];
  }

  List<String> _videoNormalizationArguments({
    required MediaJoinItemInfo item,
    required String output,
    required int targetWidth,
    required int targetHeight,
    required double targetFrameRate,
  }) {
    final fps = targetFrameRate.toStringAsFixed(3);
    final videoFilter =
        'scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease:flags=lanczos,'
        'pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2:color=black,'
        'fps=$fps,setsar=1,format=yuv420p,setpts=PTS-STARTPTS,'
        'tpad=stop_mode=clone:stop_duration=${_ffmpegTime(item.duration)}';
    final args = <String>['-y', '-fflags', '+genpts'];

    if (item.hasVideo) {
      args.addAll(['-i', item.path]);
      if (!item.hasAudio) {
        args.addAll([
          '-f',
          'lavfi',
          '-i',
          'anullsrc=r=44100:cl=stereo',
        ]);
      }
      args.addAll([
        '-map',
        _streamMap(item, audio: false),
        '-map',
        item.hasAudio ? _streamMap(item, audio: true) : '1:a:0',
        '-vf',
        videoFilter,
      ]);
      if (item.hasAudio) {
        args.addAll(['-af', _videoAudioNormalizationFilter]);
      }
    } else {
      args.addAll([
        '-f',
        'lavfi',
        '-i',
        'color=c=black:s=${targetWidth}x$targetHeight:r=$fps',
        '-i',
        item.path,
        '-map',
        '0:v:0',
        '-map',
        _streamMap(item, audio: true, inputIndex: 1),
        '-vf',
        'format=yuv420p,setpts=PTS-STARTPTS',
        '-af',
        _videoAudioNormalizationFilter,
      ]);
    }

    args.addAll([
      '-t',
      _ffmpegTime(item.duration),
      '-c:v',
      'mpeg4',
      '-q:v',
      '4',
      '-pix_fmt',
      'yuv420p',
      '-video_track_timescale',
      '90000',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-ar',
      '44100',
      '-ac',
      '2',
      '-max_muxing_queue_size',
      '2048',
      '-avoid_negative_ts',
      'make_zero',
      '-metadata:s:v:0',
      'rotate=0',
      '-movflags',
      '+faststart',
      output,
    ]);
    return args;
  }

  Future<void> _mergeAudioSegments({
    required File listFile,
    required String pendingPath,
    required MediaJoinOutputFormat format,
    required Duration expectedDuration,
    required MediaJoinCancellationToken cancellationToken,
    required void Function(MediaJoinProgress progress)? onProgress,
    required int itemCount,
  }) async {
    if (format.isVideo) {
      throw ArgumentError('Audio-only join cannot use a video output format.');
    }
    final codecArgs = switch (format) {
      MediaJoinOutputFormat.mp3 => <String>[
          '-c:a', 'libmp3lame', '-b:a', '192k', '-id3v2_version', '3',
        ],
      MediaJoinOutputFormat.m4a => <String>[
          '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart',
        ],
      MediaJoinOutputFormat.wav => <String>[
          '-c:a', 'pcm_s16le',
        ],
      MediaJoinOutputFormat.flac => <String>[
          '-c:a', 'flac',
        ],
      MediaJoinOutputFormat.ogg => <String>[
          '-c:a', 'libvorbis', '-q:a', '5',
        ],
      MediaJoinOutputFormat.opus => <String>[
          '-c:a', 'libopus', '-b:a', '160k',
        ],
      MediaJoinOutputFormat.aac => <String>[
          '-c:a', 'aac', '-b:a', '192k',
        ],
      MediaJoinOutputFormat.wma => <String>[
          '-c:a', 'wmav2', '-b:a', '192k',
        ],
      MediaJoinOutputFormat.aiff => <String>[
          '-c:a', 'pcm_s16be',
        ],
      _ => throw ArgumentError('Unsupported audio output format: $format'),
    };
    await _runFfmpeg(
      <String>[
        '-y',
        '-fflags',
        '+genpts',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        '-map',
        '0:a:0',
        '-vn',
        '-sn',
        '-dn',
        ...codecArgs,
        '-ar',
        '44100',
        '-ac',
        '2',
        pendingPath,
      ],
      'merge audio to ${format.extension}',
      cancellationToken,
      onStatistics: (statistics) {
        final elapsed = statistics.getTime().clamp(
              0,
              expectedDuration.inMilliseconds,
            );
        final local = expectedDuration.inMilliseconds <= 0
            ? 0.0
            : elapsed / expectedDuration.inMilliseconds;
        _progress(
          onProgress,
          0.78 + 0.14 * local.clamp(0.0, 1.0),
          MediaJoinStage.merging,
          current: itemCount,
          total: itemCount,
        );
      },
    );
  }

  Future<void> _transcodeVideoOutput({
    required String inputPath,
    required String outputPath,
    required MediaJoinOutputFormat format,
    required Duration expectedDuration,
    required MediaJoinCancellationToken cancellationToken,
    required void Function(MediaJoinProgress progress)? onProgress,
  }) async {
    if (!format.isVideo || format == MediaJoinOutputFormat.mp4) {
      throw ArgumentError('A non-MP4 video output format is required.');
    }
    final codecArgs = switch (format) {
      MediaJoinOutputFormat.mkv => <String>[
          '-c:v', 'mpeg4', '-q:v', '4', '-pix_fmt', 'yuv420p',
          '-c:a', 'aac', '-b:a', '192k',
        ],
      MediaJoinOutputFormat.mov => <String>[
          '-c:v', 'mpeg4', '-q:v', '4', '-pix_fmt', 'yuv420p',
          '-video_track_timescale', '90000',
          '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart',
        ],
      MediaJoinOutputFormat.avi => <String>[
          '-c:v', 'mpeg4', '-q:v', '4', '-pix_fmt', 'yuv420p',
          '-c:a', 'libmp3lame', '-b:a', '192k',
        ],
      MediaJoinOutputFormat.wmv => <String>[
          '-c:v', 'msmpeg4v3', '-q:v', '4', '-pix_fmt', 'yuv420p',
          '-c:a', 'wmav2', '-b:a', '192k',
        ],
      MediaJoinOutputFormat.mpg => <String>[
          '-c:v', 'mpeg2video', '-q:v', '4', '-pix_fmt', 'yuv420p',
          '-c:a', 'mp2', '-b:a', '192k',
        ],
      MediaJoinOutputFormat.flv => <String>[
          '-c:v', 'flv', '-q:v', '4', '-pix_fmt', 'yuv420p',
          '-c:a', 'libmp3lame', '-b:a', '192k',
        ],
      MediaJoinOutputFormat.threeGp => <String>[
          '-c:v', 'mpeg4', '-q:v', '5', '-pix_fmt', 'yuv420p',
          '-c:a', 'aac', '-b:a', '128k',
        ],
      MediaJoinOutputFormat.ts => <String>[
          '-c:v', 'mpeg2video', '-q:v', '4', '-pix_fmt', 'yuv420p',
          '-c:a', 'aac', '-b:a', '192k',
        ],
      _ => throw ArgumentError('Unsupported video output format: $format'),
    };
    await _runFfmpeg(
      <String>[
        '-y',
        '-fflags',
        '+genpts',
        '-i',
        inputPath,
        '-map',
        '0:v:0',
        '-map',
        '0:a:0',
        ...codecArgs,
        '-ar',
        '44100',
        '-ac',
        '2',
        '-max_muxing_queue_size',
        '2048',
        '-avoid_negative_ts',
        'make_zero',
        '-metadata:s:v:0',
        'rotate=0',
        outputPath,
      ],
      'convert joined video to ${format.extension}',
      cancellationToken,
      onStatistics: (statistics) {
        final elapsed = statistics.getTime().clamp(
              0,
              expectedDuration.inMilliseconds,
            );
        final local = expectedDuration.inMilliseconds <= 0
            ? 0.0
            : elapsed / expectedDuration.inMilliseconds;
        _progress(
          onProgress,
          0.85 + 0.07 * local.clamp(0.0, 1.0),
          MediaJoinStage.merging,
          current: 1,
          total: 1,
        );
      },
    );
  }

  Future<void> _mergeVideoSegments({
    required List<String> normalized,
    required File listFile,
    required String pendingPath,
    required Duration expectedDuration,
    required MediaJoinCancellationToken cancellationToken,
    required void Function(MediaJoinProgress progress)? onProgress,
    double progressStart = 0.78,
    double progressSpan = 0.12,
  }) async {
    final pending = File(pendingPath);
    var needsReencode = false;
    try {
      await _runFfmpeg(
        [
          '-y',
          '-fflags',
          '+genpts',
          '-f',
          'concat',
          '-safe',
          '0',
          '-i',
          listFile.path,
          '-c',
          'copy',
          '-avoid_negative_ts',
          'make_zero',
          '-movflags',
          '+faststart',
          pendingPath,
        ],
        'video concat stream copy',
        cancellationToken,
      );
      await _validate(
        path: pendingPath,
        expectedVideo: true,
        expectedAudio: true,
        expectedDuration: expectedDuration,
        label: 'fast video concat',
        cancellationToken: cancellationToken,
        deepDecode: false,
      );
    } catch (error) {
      if (error is MediaJoinCancelled) rethrow;
      needsReencode = true;
      await AppLogger.log(
        'Media join: video stream-copy concat rejected; re-encoding error=$error',
      );
      if (await pending.exists()) await pending.delete();
    }

    if (!needsReencode) {
      _progress(
        onProgress,
        progressStart + progressSpan,
        MediaJoinStage.merging,
        current: normalized.length,
        total: normalized.length,
      );
      return;
    }

    await _runFfmpeg(
      [
        '-y',
        '-fflags',
        '+genpts',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        '-map',
        '0:v:0',
        '-map',
        '0:a:0',
        '-c:v',
        'mpeg4',
        '-q:v',
        '4',
        '-pix_fmt',
        'yuv420p',
        '-video_track_timescale',
        '90000',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-ar',
        '44100',
        '-ac',
        '2',
        '-max_muxing_queue_size',
        '2048',
        '-avoid_negative_ts',
        'make_zero',
        '-metadata:s:v:0',
        'rotate=0',
        '-movflags',
        '+faststart',
        pendingPath,
      ],
      'video concat re-encode fallback',
      cancellationToken,
      onStatistics: (statistics) {
        final elapsed = statistics.getTime().clamp(
              0,
              expectedDuration.inMilliseconds,
            );
        final local = expectedDuration.inMilliseconds <= 0
            ? 0.0
            : elapsed / expectedDuration.inMilliseconds;
        _progress(
          onProgress,
          progressStart + progressSpan * local.clamp(0.0, 1.0),
          MediaJoinStage.merging,
          current: normalized.length,
          total: normalized.length,
        );
      },
    );
  }

  Future<void> _validate({
    required String path,
    required bool expectedVideo,
    required bool expectedAudio,
    required Duration expectedDuration,
    required String label,
    required MediaJoinCancellationToken cancellationToken,
    required bool deepDecode,
    List<Duration> validationPoints = const <Duration>[],
  }) async {
    cancellationToken.throwIfCancelled();
    final file = File(path);
    if (!await file.exists() || await file.length() <= 0) {
      throw StateError('The $label file is missing or empty.');
    }
    final info = await probe(path);
    if (expectedVideo && !info.hasVideo) {
      throw StateError('The $label file is missing its video stream.');
    }
    if (expectedAudio && !info.hasAudio) {
      throw StateError('The $label file is missing its audio stream.');
    }
    if (!expectedVideo && info.hasVideo) {
      throw StateError('The $label audio output unexpectedly contains video.');
    }

    final expectedMs = expectedDuration.inMilliseconds;
    final actualMs = info.duration.inMilliseconds;
    final tolerance = _durationToleranceMs(expectedMs);
    if (expectedMs > 0 &&
        (actualMs < math.max(1, expectedMs - tolerance) ||
            actualMs > expectedMs + tolerance)) {
      throw StateError(
        'Invalid duration for $label: expected ${_ffmpegTime(expectedDuration)}, '
        'got ${_ffmpegTime(info.duration)}.',
      );
    }

    if (!deepDecode) return;
    if (expectedVideo) {
      await _runFfmpeg(
        [
          '-v',
          'error',
          '-xerror',
          '-i',
          path,
          '-map',
          '0:v:0',
          '-frames:v',
          '1',
          '-f',
          'null',
          '-',
        ],
        'validate $label video start',
        cancellationToken,
      );
    }
    if (expectedAudio) {
      await _runFfmpeg(
        [
          '-v',
          'error',
          '-xerror',
          '-i',
          path,
          '-map',
          '0:a:0',
          '-t',
          '0.350',
          '-f',
          'null',
          '-',
        ],
        'validate $label audio start',
        cancellationToken,
      );
    }

    if (info.duration > const Duration(seconds: 1)) {
      final tail = info.duration - const Duration(milliseconds: 700);
      if (expectedVideo) {
        await _runFfmpeg(
          [
            '-v',
            'error',
            '-xerror',
            '-ss',
            _ffmpegTime(tail),
            '-i',
            path,
            '-map',
            '0:v:0',
            '-frames:v',
            '1',
            '-f',
            'null',
            '-',
          ],
          'validate $label video end',
          cancellationToken,
        );
      }
      if (expectedAudio) {
        await _runFfmpeg(
          [
            '-v',
            'error',
            '-xerror',
            '-ss',
            _ffmpegTime(tail),
            '-i',
            path,
            '-map',
            '0:a:0',
            '-t',
            '0.350',
            '-f',
            'null',
            '-',
          ],
          'validate $label audio end',
          cancellationToken,
        );
      }
    }

    for (final point in _sampleValidationPoints(validationPoints, info.duration)) {
      cancellationToken.throwIfCancelled();
      final start = point > const Duration(milliseconds: 250)
          ? point - const Duration(milliseconds: 250)
          : Duration.zero;
      final args = <String>[
        '-v',
        'error',
        '-xerror',
        '-ss',
        _ffmpegTime(start),
        '-i',
        path,
      ];
      if (expectedVideo) args.addAll(['-map', '0:v:0']);
      if (expectedAudio) args.addAll(['-map', '0:a:0']);
      args.addAll(['-t', '0.500', '-f', 'null', '-']);
      await _runFfmpeg(
        args,
        'validate $label junction',
        cancellationToken,
      );
    }
    await AppLogger.log(
      'Media join: validation passed label="$label" ${info.logSummary}',
    );
  }

  Future<void> _runFfmpeg(
    List<String> arguments,
    String step,
    MediaJoinCancellationToken cancellationToken, {
    void Function(Statistics statistics)? onStatistics,
  }) async {
    cancellationToken.throwIfCancelled();
    await AppLogger.log(
      'Media join ffmpeg $step start args=${arguments.map(_quoteLogArg).join(' ')}',
    );
    final completer = Completer<FFmpegSession>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (completed) {
        if (!completer.isCompleted) completer.complete(completed);
      },
      null,
      onStatistics,
    );
    cancellationToken._currentSession = session;
    if (cancellationToken.isCancelled) {
      try {
        await session.cancel().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    final completed = await Future.any<FFmpegSession?>([
      completer.future.then<FFmpegSession?>((value) => value),
      cancellationToken.cancellationDispatched.then<FFmpegSession?>((_) => null),
    ]);
    if (completed == null) {
      if (identical(cancellationToken._currentSession, session)) {
        cancellationToken._currentSession = null;
      }
      try {
        await completer.future.timeout(const Duration(seconds: 1));
      } on TimeoutException {
        await AppLogger.log(
          'Media join ffmpeg $step cancel callback timeout; treating as cancelled',
        );
      } catch (_) {}
      throw const MediaJoinCancelled();
    }
    if (identical(cancellationToken._currentSession, session)) {
      cancellationToken._currentSession = null;
    }
    final returnCode = await completed.getReturnCode();
    final logs = await completed.getAllLogsAsString() ?? '';
    if (cancellationToken.isCancelled || ReturnCode.isCancel(returnCode)) {
      await AppLogger.log('Media join ffmpeg $step cancelled');
      throw const MediaJoinCancelled();
    }
    if (!ReturnCode.isSuccess(returnCode)) {
      await AppLogger.log(
        'Media join ffmpeg $step failed returnCode=${returnCode?.getValue()} '
        'logs="${_compactLog(logs)}"',
      );
      throw StateError(
        logs.trim().isEmpty
            ? 'FFmpeg failed with code ${returnCode?.getValue()}.'
            : logs,
      );
    }
    await AppLogger.log(
      'Media join ffmpeg $step completed returnCode=${returnCode?.getValue()}',
    );
  }

  void _progress(
    void Function(MediaJoinProgress progress)? callback,
    double fraction,
    MediaJoinStage stage, {
    required int current,
    required int total,
  }) {
    callback?.call(
      MediaJoinProgress(
        fraction: fraction.clamp(0.0, 1.0).toDouble(),
        stage: stage,
        current: current,
        total: total,
      ),
    );
  }

  static const _audioNormalizationFilter =
      'aresample=44100:async=1:first_pts=0,'
      'aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,'
      'asetpts=PTS-STARTPTS';

  static const _videoAudioNormalizationFilter =
      'aresample=44100:async=1:first_pts=0,'
      'aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,'
      'asetpts=PTS-STARTPTS,apad';

  String _streamMap(
    MediaJoinItemInfo item, {
    required bool audio,
    int inputIndex = 0,
  }) {
    final index = audio ? item.audioStreamIndex : item.videoStreamIndex;
    if (index != null) return '$inputIndex:$index';
    return audio ? '$inputIndex:a:0' : '$inputIndex:v:0';
  }

  bool _isAttachedPictureStream(StreamInformation stream) {
    try {
      final properties = stream.getAllProperties();
      if (properties is! Map) return false;
      final disposition = properties['disposition'];
      if (disposition is! Map) return false;
      final value = disposition['attached_pic'];
      return value == 1 || value == true || value == '1';
    } catch (_) {
      return false;
    }
  }

  StreamInformation? _preferredStream(Iterable<StreamInformation> streams) {
    StreamInformation? first;
    for (final stream in streams) {
      first ??= stream;
      if (_streamDispositionEnabled(stream, 'default')) return stream;
    }
    return first;
  }

  bool _streamDispositionEnabled(StreamInformation stream, String key) {
    try {
      final properties = stream.getAllProperties();
      if (properties is! Map) return false;
      final disposition = properties['disposition'];
      if (disposition is! Map) return false;
      final value = disposition[key];
      return value == 1 || value == true || value == '1';
    } catch (_) {
      return false;
    }
  }

  int _rotationDegrees(StreamInformation? stream) {
    if (stream == null) return 0;
    try {
      final properties = stream.getAllProperties();
      if (properties is! Map) return 0;
      final tags = properties['tags'];
      if (tags is Map) {
        final raw = tags['rotate'];
        final value = int.tryParse(raw?.toString() ?? '');
        if (value != null) return _normalizeRotation(value);
      }
      final sideData = properties['side_data_list'];
      if (sideData is List) {
        for (final entry in sideData) {
          if (entry is! Map) continue;
          final raw = entry['rotation'];
          final value = double.tryParse(raw?.toString() ?? '');
          if (value != null) return _normalizeRotation(value.round());
        }
      }
    } catch (_) {}
    return 0;
  }

  int _normalizeRotation(int value) {
    final normalized = ((value % 360) + 360) % 360;
    if (normalized >= 45 && normalized < 135) return 90;
    if (normalized >= 135 && normalized < 225) return 180;
    if (normalized >= 225 && normalized < 315) return 270;
    return 0;
  }

  Duration? _parseDuration(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final seconds = double.tryParse(raw.trim());
    if (seconds == null || !seconds.isFinite || seconds <= 0) return null;
    return Duration(microseconds: (seconds * 1000000).round());
  }

  double? _parseRate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    if (!value.contains('/')) {
      final parsed = double.tryParse(value);
      return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
    }
    final parts = value.split('/');
    if (parts.length != 2) return null;
    final numerator = double.tryParse(parts[0]);
    final denominator = double.tryParse(parts[1]);
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    final rate = numerator / denominator;
    return rate.isFinite && rate > 0 ? rate : null;
  }

  int _evenDimension(int value) {
    final safe = value.clamp(2, 7680).toInt();
    return safe.isEven ? safe : safe - 1;
  }

  double _targetFrameRate(double? value) {
    if (value == null || !value.isFinite || value < 1) return 30;
    return value.clamp(12.0, 60.0).toDouble();
  }

  int _durationToleranceMs(int expectedMs) {
    if (expectedMs < 2000) return 700;
    if (expectedMs < 10000) return 1200;
    final fivePercent = (expectedMs * 0.05).round();
    return fivePercent > 2000 ? fivePercent : 2000;
  }

  List<Duration> _sampleValidationPoints(
    List<Duration> points,
    Duration actualDuration,
  ) {
    final usable = points
        .where(
          (point) =>
              point > const Duration(milliseconds: 500) &&
              point < actualDuration - const Duration(milliseconds: 500),
        )
        .toList(growable: false);
    if (usable.length <= 24) return usable;
    final sampled = <Duration>[];
    for (var i = 0; i < 24; i++) {
      final index = ((usable.length - 1) * i / 23).round();
      final point = usable[index];
      if (sampled.isEmpty || sampled.last != point) sampled.add(point);
    }
    return sampled;
  }

  String _ffmpegTime(Duration value) =>
      (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(6);

  String _compactLog(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 1200
        ? normalized
        : '${normalized.substring(0, 1200)}…';
  }

  String _quoteLogArg(String value) {
    if (!value.contains(RegExp(r'[\s"\\]'))) return value;
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }
}
