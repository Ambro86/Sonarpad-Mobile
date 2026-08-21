import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';
import 'app_settings_service.dart';
import 'radio_recording_service.dart';
import 'tv_service.dart';

/// Describes a radio/TV stream that can be recorded independently from the
/// player screen that created the request.
class GlobalRecordingTarget {
  const GlobalRecordingTarget({
    required this.id,
    required this.stationName,
    required this.streamUrl,
    required this.includeVideo,
    this.tvChannel,
  });

  final String id;
  final String stationName;
  final String streamUrl;
  final bool includeVideo;
  final TvChannel? tvChannel;
}

/// App-session recording coordinator.
///
/// Timers and FFmpeg sessions live here instead of inside RadioPlayerScreen,
/// so navigating to another Sonarpad screen does not cancel a scheduled or
/// already-running recording. This intentionally does not promise execution
/// after the operating system suspends or terminates the app.
class GlobalRecordingService extends ChangeNotifier {
  GlobalRecordingService._();

  static final GlobalRecordingService instance = GlobalRecordingService._();

  RadioRecordingService? _recordingService;
  GlobalRecordingTarget? _activeTarget;
  GlobalRecordingTarget? _scheduledTarget;
  DateTime? _scheduledStart;
  DateTime? _scheduledEnd;
  String? _scheduledTitle;
  Timer? _scheduledStartTimer;
  Timer? _scheduledStopTimer;
  bool _starting = false;
  File? _activeOutput;
  final Map<String, File> _lastOutputByTarget = <String, File>{};

  bool get isRecording => _recordingService?.isRecording ?? false;
  bool get isStarting => _starting;
  bool get hasAnyActiveRecording => isRecording || _starting;
  bool get hasAnySchedule => _scheduledTarget != null;

  bool isRecordingFor(String targetId) =>
      _activeTarget?.id == targetId && hasAnyActiveRecording;

  bool hasScheduleFor(String targetId) => _scheduledTarget?.id == targetId;

  bool hasPendingScheduleFor(String targetId) =>
      _scheduledTarget?.id == targetId &&
      (_scheduledStartTimer?.isActive ?? false);

  DateTime? scheduledStartFor(String targetId) =>
      _scheduledTarget?.id == targetId ? _scheduledStart : null;

  DateTime? scheduledEndFor(String targetId) =>
      _scheduledTarget?.id == targetId ? _scheduledEnd : null;

  String? scheduledTitleFor(String targetId) =>
      _scheduledTarget?.id == targetId ? _scheduledTitle : null;

  File? outputFor(String targetId) {
    if (_activeTarget?.id == targetId && _activeOutput != null) {
      return _activeOutput;
    }
    return _lastOutputByTarget[targetId];
  }

  void schedule({
    required GlobalRecordingTarget target,
    required DateTime start,
    required DateTime end,
    String? title,
  }) {
    if (hasAnyActiveRecording) {
      throw StateError('A recording is already active.');
    }
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'Must be after start.');
    }

    _cancelScheduleInternal();
    _scheduledTarget = target;
    _scheduledStart = start;
    _scheduledEnd = end;
    final trimmedTitle = title?.trim();
    _scheduledTitle = trimmedTitle == null || trimmedTitle.isEmpty
        ? null
        : trimmedTitle;

    final delay = start.difference(DateTime.now());
    _scheduledStartTimer = Timer(
      delay <= Duration.zero ? Duration.zero : delay,
      () => unawaited(_startScheduledRecording()),
    );
    notifyListeners();
    unawaited(AppLogger.log(
      'Global recording: schedule set target="${target.stationName}" '
      'start=$start end=$end title=${_scheduledTitle ?? ''} '
      'tv=${target.includeVideo}',
    ));
  }

  bool cancelSchedule({String? targetId}) {
    if (_scheduledTarget == null) return false;
    if (targetId != null && _scheduledTarget?.id != targetId) return false;
    final targetName = _scheduledTarget?.stationName;
    _cancelScheduleInternal();
    notifyListeners();
    unawaited(AppLogger.log(
      'Global recording: schedule cancelled target="${targetName ?? ''}"',
    ));
    return true;
  }

  Future<File> startNow(
    GlobalRecordingTarget target, {
    String? titleOverride,
  }) async {
    if (hasAnyActiveRecording) {
      throw StateError('A recording is already active.');
    }

    _starting = true;
    _activeTarget = target;
    notifyListeners();
    try {
      final recordingService = RadioRecordingService(
        directoryName:
            target.includeVideo ? 'TV Registrazioni' : 'Radio Registrazioni',
        includeVideo: target.includeVideo,
      );

      String? recordingVideoUrl;
      String? recordingAudioUrl;
      final originalTvChannel = target.tvChannel;
      var effectiveTvChannel = originalTvChannel;
      var effectiveStreamUrl = target.streamUrl;
      if (originalTvChannel != null) {
        final refreshedTvChannel = await _refreshScheduledTvChannel(
          originalTvChannel,
          target.stationName,
        );
        effectiveTvChannel = refreshedTvChannel;
        try {
          effectiveStreamUrl =
              await TvService().resolveStreamUrl(refreshedTvChannel);
          await AppLogger.log(
            'Global recording: refreshed TV stream target="${target.stationName}" '
            'channel="${refreshedTvChannel.name}"',
          );
        } catch (error) {
          await AppLogger.log(
            'Global recording: TV stream refresh failed; using scheduled/player URL '
            'target="${target.stationName}" error=$error',
          );
        }
      }
      if (effectiveTvChannel != null &&
          TvService().isRaiAudioDescriptionChannel(effectiveTvChannel) &&
          !TvService.isDashStreamUrl(effectiveStreamUrl)) {
        final streams =
            await TvService().resolveAudioDescriptionStreams(effectiveTvChannel);
        if (streams.hasAudioDescription && streams.videoUrl != streams.audioUrl) {
          recordingVideoUrl = streams.videoUrl;
          recordingAudioUrl = streams.audioUrl;
          await AppLogger.log(
            'Global recording: RAI AD recording requested '
            'videoUrl=$recordingVideoUrl audioUrl=$recordingAudioUrl',
          );
        } else {
          await AppLogger.log(
            'Global recording: RAI AD fallback to normal stream '
            'hasAD=${streams.hasAudioDescription}',
          );
        }
      }

      final trimmedTitle = titleOverride?.trim();
      final file = await recordingService.start(
        stationName: trimmedTitle == null || trimmedTitle.isEmpty
            ? target.stationName
            : trimmedTitle,
        streamUrl: effectiveStreamUrl,
        videoStreamUrl: recordingVideoUrl,
        audioStreamUrl: recordingAudioUrl,
        httpUserAgent: effectiveTvChannel?.httpUserAgent,
      );
      _recordingService = recordingService;
      _activeOutput = file;
      _lastOutputByTarget[target.id] = file;
      await AppLogger.log(
        'Global recording: started target="${target.stationName}" '
        'output="${file.path}"',
      );
      return file;
    } catch (error) {
      _recordingService = null;
      _activeTarget = null;
      _activeOutput = null;
      await AppLogger.log(
        'Global recording: start failed target="${target.stationName}" '
        'error=$error',
      );
      rethrow;
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<TvChannel> _refreshScheduledTvChannel(
    TvChannel scheduledChannel,
    String stationName,
  ) async {
    final tvService = TvService();
    try {
      final secretCode = await AppSettingsService().getTvSecretCode();
      final result = await tvService.loadChannelsWithCache(secretCode);
      if (result.channels.isEmpty) {
        await AppLogger.log(
          'Global recording: TV channel list unavailable; using scheduled channel '
          'target="$stationName"',
        );
        return scheduledChannel;
      }

      for (final channel in result.channels) {
        if (tvService.isSameFavoriteChannel(channel, scheduledChannel)) {
          await AppLogger.log(
            'Global recording: TV channel refreshed from '
            '${result.fromCache ? "cached" : "current"} list '
            'target="$stationName" channel="${channel.name}" '
            'tvgId="${channel.tvgId}" resolverId="${channel.resolverChannelId ?? ''}"',
          );
          return channel;
        }
      }

      await AppLogger.log(
        'Global recording: scheduled TV channel not found in '
        '${result.fromCache ? "cached" : "current"} list; using scheduled channel '
        'target="$stationName" channel="${scheduledChannel.name}"',
      );
    } catch (error) {
      await AppLogger.log(
        'Global recording: TV channel-list refresh failed; using scheduled channel '
        'target="$stationName" error=$error',
      );
    }
    return scheduledChannel;
  }

  Future<File?> stopActive({bool cancelLinkedSchedule = true}) async {
    final service = _recordingService;
    final target = _activeTarget;
    if (service == null) return _activeOutput;

    try {
      final file = await service.stop();
      if (target != null && file != null) {
        _lastOutputByTarget[target.id] = file;
      }
      await AppLogger.log(
        'Global recording: stopped target="${target?.stationName ?? ''}" '
        'output="${file?.path ?? ''}"',
      );
      return file;
    } finally {
      _recordingService = null;
      _activeTarget = null;
      _activeOutput = null;
      if (cancelLinkedSchedule &&
          target != null &&
          _scheduledTarget?.id == target.id &&
          _scheduledStopTimer != null) {
        _cancelScheduleInternal();
      }
      notifyListeners();
    }
  }

  Future<void> _startScheduledRecording() async {
    final target = _scheduledTarget;
    final end = _scheduledEnd;
    final title = _scheduledTitle;
    _scheduledStartTimer?.cancel();
    _scheduledStartTimer = null;
    notifyListeners();
    if (target == null) return;

    try {
      if (hasAnyActiveRecording) {
        await AppLogger.log(
          'Global recording: scheduled start skipped because another '
          'recording is active target="${target.stationName}"',
        );
        _cancelScheduleInternal();
        notifyListeners();
        return;
      }

      await AppLogger.log(
        'Global recording: scheduled start target="${target.stationName}" '
        'title=${title ?? ''} end=$end',
      );
      await startNow(target, titleOverride: title);

      if (end == null) {
        _cancelScheduleInternal();
        notifyListeners();
        return;
      }
      final delay = end.difference(DateTime.now());
      if (delay <= Duration.zero) {
        await _stopScheduledRecording();
      } else {
        _scheduledStopTimer = Timer(
          delay,
          () => unawaited(_stopScheduledRecording()),
        );
        notifyListeners();
      }
    } catch (error) {
      await AppLogger.log(
        'Global recording: scheduled start failed '
        'target="${target.stationName}" error=$error',
      );
      _cancelScheduleInternal();
      notifyListeners();
    }
  }

  Future<void> _stopScheduledRecording() async {
    final target = _scheduledTarget;
    try {
      await AppLogger.log(
        'Global recording: scheduled stop target="${target?.stationName ?? ''}"',
      );
      if (target != null && _activeTarget?.id == target.id && isRecording) {
        await stopActive(cancelLinkedSchedule: false);
      }
    } catch (error) {
      await AppLogger.log(
        'Global recording: scheduled stop failed '
        'target="${target?.stationName ?? ''}" error=$error',
      );
    } finally {
      _cancelScheduleInternal();
      notifyListeners();
    }
  }

  void _cancelScheduleInternal() {
    _scheduledStartTimer?.cancel();
    _scheduledStopTimer?.cancel();
    _scheduledStartTimer = null;
    _scheduledStopTimer = null;
    _scheduledTarget = null;
    _scheduledStart = null;
    _scheduledEnd = null;
    _scheduledTitle = null;
  }
}
