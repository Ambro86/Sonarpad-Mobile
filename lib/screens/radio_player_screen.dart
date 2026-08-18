import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:path/path.dart' as p;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/audio_player_service.dart';
import '../services/radio_recording_service.dart';
import '../services/radio_service.dart';
import '../services/raiplay_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/tv_service.dart';
import '../widgets/volume_slider.dart';
import 'package:video_player/video_player.dart';
import '../services/app_settings_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/native_ios_accessible_view.dart';

class RadioPlayerScreen extends StatefulWidget {
  final RadioStation station;
  final bool isVideoSupported;
  final TvChannel? tvChannel;
  const RadioPlayerScreen({
    super.key,
    required this.station,
    this.isVideoSupported = false,
    this.tvChannel,
  });

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> {
  static const _mediaCommands = MethodChannel('sonarpad/tts_commands');
  static const _mediaEvents = EventChannel('sonarpad/tts_events');

  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  late final RadioRecordingService _recordingService;
  StreamSubscription<dynamic>? _mediaEventsSubscription;
  StreamSubscription<bool>? _mediaKitPlayingSubscription;
  StreamSubscription<String>? _mediaKitErrorSubscription;
  StreamSubscription<dynamic>? _mediaKitPositionSubscription;
  StreamSubscription<dynamic>? _mediaKitDurationSubscription;
  StreamSubscription<dynamic>? _mediaKitTracksSubscription;
  StreamSubscription<dynamic>? _mediaKitBufferingSubscription;
  StreamSubscription<dynamic>? _mediaKitCompletedSubscription;
  Timer? _mediaKitDiagnosticsTimer;

  VideoPlayerController? _videoController;
  mk.Player? _mediaKitPlayer;
  mkv.VideoController? _mediaKitController;
  bool _isVideoEnabled = false;
  bool _displayVideoInPortrait = false;
  bool _isFavorite = false;
  bool _mediaKitPlaying = false;
  bool _mediaKitVideoSettingApplied = false;
  bool _landscapeFullscreenApplied = false;
  bool _mediaKitRaiAudioTrackApplied = false;
  bool _mediaKitBuffering = false;
  bool _mediaKitCompleted = false;
  bool _mediaKitIsMpd = false;
  bool _mpdWakelockRequested = false;
  Duration? _mediaKitLastPosition;
  Duration? _mediaKitLastDuration;
  DateTime? _mediaKitLastProgressAt;
  DateTime? _mediaKitLastPositionLogAt;
  DateTime? _mediaKitLastAutoRecoveryAt;
  bool _mediaKitAutoRecoveryInProgress = false;
  double _mediaKitVolume = 1.0;
  double _videoPlayerVolume = 1.0;
  bool _recording = false;
  bool _isRecordingFeatureUnlocked = false;
  File? _recordingOutput;
  DateTime? _scheduledRecordingStart;
  DateTime? _scheduledRecordingEnd;
  String? _scheduledRecordingTitle;
  Timer? _scheduledRecordingStartTimer;
  Timer? _scheduledRecordingStopTimer;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recordingService = RadioRecordingService(
      directoryName:
          widget.tvChannel == null ? 'Radio Registrazioni' : 'TV Registrazioni',
      includeVideo: widget.tvChannel != null,
    );
    if (Platform.isIOS) {
      _mediaEventsSubscription =
          _mediaEvents.receiveBroadcastStream().listen((event) {
        if (event == 'toggle' &&
            mounted &&
            (_videoController != null || _mediaKitPlayer != null)) {
          unawaited(_toggleVideoPlayback());
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isVideoEnabled = await _settings.isVideoEnabled();
      _displayVideoInPortrait = await _settings.displayVideoInPortrait();
      _isFavorite = await _loadIsFavorite();
      _isRecordingFeatureUnlocked = await _loadRecordingFeatureAccess();
      if (widget.tvChannel == null) {
        unawaited(RadioService().addRecentRadio(widget.station));
        unawaited(RadioService().recordRadioBrowserClick(widget.station));
      }
      if (!mounted) return;
      setState(() {});
      _play();
    });
  }

  Future<bool> _loadRecordingFeatureAccess() async {
    final code = await _settings.getTvSecretCode();
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    return TvService().isSecretCodeValid(trimmed) ||
        RaiPlayService().isSecretCodeValid(trimmed) ||
        RaiPlaySoundService().isSecretCodeValid(trimmed);
  }

  Future<bool> _loadIsFavorite() async {
    if (widget.tvChannel != null) {
      final favorites = await TvService().loadFavorites();
      return favorites.any((item) =>
          TvService().isSameFavoriteChannel(item, widget.tvChannel!));
    }
    final favorites = await RadioService().loadFavorites();
    return favorites.any((item) => item.streamUrl == widget.station.streamUrl);
  }

  Future<void> _play() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_requiresRaiAudioDescriptionMediaKitPlayback) {
        final tvChannel = widget.tvChannel!;
        final streams =
            await TvService().resolveAudioDescriptionStreams(tvChannel);
        await AppLogger.log(
          'RadioPlayer: RAI MediaKit playback selected '
          'videoEnabled=$_isVideoEnabled hasAD=${streams.hasAudioDescription}',
        );
        await _playMediaKitVideo(
          streamUrl: streams.videoUrl,
          preferRaiAudioDescription: streams.hasAudioDescription,
        );
        return;
      }

      // Tutti i canali TV usano sempre MediaKit, anche quando il video è
      // disattivato. just_audio/AVPlayer può perdere immediatamente la
      // connessione con alcuni master HLS televisivi (in particolare i live
      // Mediaset). MediaKit apre invece lo stesso master nei due modi; quando
      // il video è spento viene disabilitata soltanto la traccia video.
      if (_requiresTvMediaKitPlayback) {
        await AppLogger.log(
          'RadioPlayer: TV MediaKit playback selected '
          'station="${widget.station.name}" videoEnabled=$_isVideoEnabled',
        );
        await _playMediaKitVideo();
        return;
      }

      if (_requiresVideoPlayback) {
        await _playMediaKitVideo();
        return;
      }

      if (widget.isVideoSupported && _isVideoEnabled) {
        await _audio.stop();
        await _disposeMediaKitPlayer();
        _videoController?.dispose();
        _videoPlayerVolume = await _settings.loadMediaVolume();
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.station.streamUrl),
          httpHeaders: widget.tvChannel?.playbackHeaders ?? const {},
          videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
        );
        await _videoController!.initialize();
        await _videoController!.setVolume(_videoPlayerVolume);
        AppLogger.log(
          'RadioPlayer: video_player volume applied after initialize volume=$_videoPlayerVolume',
        );
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod(
            'setupMagicTap',
            widget.station.name,
          );
        }
        await _videoController!.play();
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod('setMagicTapPlaying', true);
        }
      } else {
        if (Platform.isIOS && _videoController != null) {
          await _mediaCommands.invokeMethod('clearMagicTap');
        }
        await _disposeMediaKitPlayer();
        _videoController?.pause();
        _videoController?.dispose();
        _videoController = null;
        await _audio.setUrl(
          widget.station.streamUrl,
          title: l10n.nowPlayingTitle(widget.station.name),
          headers: widget.tvChannel?.playbackHeaders,
        );
        if (!mounted) return;
        unawaited(_audio.play().catchError((e) {
          if (!mounted) return;
          setState(() => _error = e.toString());
        }));
      }
    } catch (e) {
      if (_mediaKitIsMpd) {
        await _disableMpdWakelock();
      }
      if (!mounted) return;
      AppLogger.log('RadioPlayer: Error during _play: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        AppLogger.log(
            'RadioPlayer: _play complete. loading=false, isVideo=${_videoController != null || _mediaKitPlayer != null}');
      }
    }
  }

  Future<void> _playMediaKitVideo({
    String? streamUrl,
    bool preferRaiAudioDescription = false,
  }) async {
    final playbackUrl = streamUrl ?? widget.station.streamUrl;
    final isMpd = TvService.isDashStreamUrl(playbackUrl);
    final mediaKitHeaders = _mediaKitHttpHeaders();
    await _audio.stop();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    await _disposeMediaKitPlayer();
    _mediaKitIsMpd = isMpd;
    if (isMpd) {
      // AudioPlayerService.stop() disattiva il wakelock globale. Gli MPD live
      // vengono riaperti a ogni finestra DASH, quindi lo riattiviamo anche
      // durante i refresh per lasciare attivi timer e callback su iOS.
      await _enableMpdWakelock();
    } else {
      await _disableMpdWakelock();
    }

    final player = mk.Player();
    final controller = mkv.VideoController(player);
    _mediaKitPlayer = player;
    _mediaKitController = controller;
    _mediaKitPlaying = false;
    _mediaKitVideoSettingApplied = false;
    _mediaKitRaiAudioTrackApplied = false;
    _mediaKitBuffering = false;
    _mediaKitCompleted = false;
    _mediaKitLastPosition = null;
    _mediaKitLastDuration = null;
    _mediaKitLastProgressAt = DateTime.now();
    _mediaKitLastPositionLogAt = null;
    _mediaKitAutoRecoveryInProgress = false;
    _mediaKitVolume = await _settings.loadMediaVolume();
    var initialVolumeApplied = false;
    var postStartStabilizationScheduled = false;

    AppLogger.log(
      'RadioPlayer: MediaKit open start station="${widget.station.name}" url=$playbackUrl videoEnabled=$_isVideoEnabled volume=$_mediaKitVolume preferRaiAD=$preferRaiAudioDescription',
    );

    _mediaKitPlayingSubscription = player.stream.playing.listen((playing) {
      AppLogger.log(
        'RadioPlayer: MediaKit playing emitted playing=$playing buffering=$_mediaKitBuffering completed=$_mediaKitCompleted position=$_mediaKitLastPosition duration=$_mediaKitLastDuration videoEnabled=$_isVideoEnabled videoApplied=$_mediaKitVideoSettingApplied',
      );
      if (playing) {
        if (!initialVolumeApplied) {
          initialVolumeApplied = true;
          unawaited(player.setVolume(_mediaKitVolume * 100).then((_) {
            AppLogger.log(
              'RadioPlayer: MediaKit volume applied after start volume=$_mediaKitVolume',
            );
          }).catchError((error) {
            AppLogger.log(
              'RadioPlayer: failed to apply MediaKit volume after start: $error',
            );
          }));
        }
        if (!_mediaKitVideoSettingApplied) {
          _mediaKitVideoSettingApplied = true;
          unawaited(_applyMediaKitVideoEnabled(player, _isVideoEnabled));
        }
        if (!postStartStabilizationScheduled) {
          postStartStabilizationScheduled = true;
          unawaited(_stabilizeMediaKitAfterStart(player));
        }
      }
      if (!mounted) return;
      setState(() => _mediaKitPlaying = playing);
      if (Platform.isIOS) {
        unawaited(_mediaCommands.invokeMethod('setMagicTapPlaying', playing));
      }
    });
    _mediaKitErrorSubscription = player.stream.error.listen((error) {
      AppLogger.log(
        'RadioPlayer: MediaKit error station="${widget.station.name}" error=$error position=$_mediaKitLastPosition duration=$_mediaKitLastDuration buffering=$_mediaKitBuffering playing=$_mediaKitPlaying',
      );
      if (!mounted) return;
      setState(() => _error = error);
    });
    _mediaKitPositionSubscription = player.stream.position.listen((position) {
      final previous = _mediaKitLastPosition;
      _mediaKitLastPosition = position;
      if (previous == null || position > previous) {
        _mediaKitLastProgressAt = DateTime.now();
      }
      final now = DateTime.now();
      final lastLog = _mediaKitLastPositionLogAt;
      if (lastLog == null ||
          now.difference(lastLog) >= const Duration(seconds: 5)) {
        _mediaKitLastPositionLogAt = now;
        AppLogger.log(
          'RadioPlayer: MediaKit position position=$position duration=$_mediaKitLastDuration playing=$_mediaKitPlaying buffering=$_mediaKitBuffering completed=$_mediaKitCompleted',
        );
      }
      if (_shouldPreemptivelyRefreshMediaKitDashLiveWindow(player)) {
        unawaited(_refreshMediaKitDashLiveWindow(player, reason: 'preemptive'));
      }
    });
    _mediaKitDurationSubscription = player.stream.duration.listen((duration) {
      _mediaKitLastDuration = duration;
      AppLogger.log(
        'RadioPlayer: MediaKit duration emitted duration=$duration station="${widget.station.name}"',
      );
    });
    _mediaKitBufferingSubscription =
        player.stream.buffering.listen((buffering) {
      _mediaKitBuffering = buffering;
      AppLogger.log(
        'RadioPlayer: MediaKit buffering emitted buffering=$buffering playing=$_mediaKitPlaying position=$_mediaKitLastPosition duration=$_mediaKitLastDuration',
      );
    });
    _mediaKitCompletedSubscription =
        player.stream.completed.listen((completed) {
      _mediaKitCompleted = completed;
      AppLogger.log(
        'RadioPlayer: MediaKit completed emitted completed=$completed playing=$_mediaKitPlaying position=$_mediaKitLastPosition duration=$_mediaKitLastDuration buffering=$_mediaKitBuffering',
      );
    });
    _startMediaKitDiagnostics(player);

    if (preferRaiAudioDescription) {
      _mediaKitTracksSubscription = player.stream.tracks.listen((tracks) {
        unawaited(_selectMediaKitRaiAudioDescriptionTrack(player, tracks));
      });
      unawaited(_retrySelectMediaKitRaiAudioDescriptionTrack(player));
    }

    if (Platform.isIOS) {
      await _mediaCommands.invokeMethod(
        'setupMagicTap',
        widget.station.name,
      );
    }
    await player.open(
      mk.Media(
        playbackUrl,
        httpHeaders: mediaKitHeaders,
      ),
    );
    if (mounted && _mediaKitPlayer == player && !_mediaKitVideoSettingApplied) {
      _mediaKitVideoSettingApplied = true;
      await _applyMediaKitVideoEnabled(player, _isVideoEnabled);
    }
    AppLogger.log(
      'RadioPlayer: MediaKit open completed station="${widget.station.name}" playing=$_mediaKitPlaying buffering=$_mediaKitBuffering position=$_mediaKitLastPosition duration=$_mediaKitLastDuration preferRaiAD=$preferRaiAudioDescription',
    );
  }

  Map<String, String> _mediaKitHttpHeaders() {
    final tvHeaders = widget.tvChannel?.playbackHeaders ?? const {};
    if (tvHeaders.isNotEmpty) {
      return tvHeaders;
    }

    return const {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    };
  }

  Future<void> _retrySelectMediaKitRaiAudioDescriptionTrack(
    mk.Player player,
  ) async {
    for (final delay in const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ]) {
      await Future.delayed(delay);
      if (!mounted ||
          _mediaKitPlayer != player ||
          _mediaKitRaiAudioTrackApplied) {
        return;
      }
      try {
        final tracks = (player.state as dynamic).tracks;
        await _selectMediaKitRaiAudioDescriptionTrack(player, tracks);
      } catch (error) {
        AppLogger.log(
          'RadioPlayer: RAI AD track retry not ready yet: $error',
        );
      }
    }
  }

  Future<void> _selectMediaKitRaiAudioDescriptionTrack(
    mk.Player player,
    dynamic tracks,
  ) async {
    if (!mounted ||
        _mediaKitPlayer != player ||
        _mediaKitRaiAudioTrackApplied) {
      return;
    }

    try {
      final audioTracks =
          List<dynamic>.from((tracks as dynamic).audio as Iterable);
      if (audioTracks.isEmpty) return;

      dynamic describedTrack;
      dynamic italianTrack;
      for (final track in audioTracks) {
        final language = _mediaKitTrackField(track, 'language').toLowerCase();
        final title = _mediaKitTrackField(track, 'title').toLowerCase();
        final id = _mediaKitTrackField(track, 'id');
        AppLogger.log(
          'RadioPlayer: MediaKit audio track candidate id=$id language=$language title=$title',
        );

        if (language == 'des' ||
            title.contains('audiodescri') ||
            title.contains('audio descri')) {
          describedTrack = track;
          break;
        }
        if (italianTrack == null && language == 'ita') {
          italianTrack = track;
        }
      }

      final selectedTrack = describedTrack ?? italianTrack;
      if (selectedTrack == null) return;

      await player.setAudioTrack(selectedTrack);
      _mediaKitRaiAudioTrackApplied = true;
      await AppLogger.log(
        'RadioPlayer: MediaKit selected RAI preferred audio track id=${_mediaKitTrackField(selectedTrack, 'id')} language=${_mediaKitTrackField(selectedTrack, 'language')} title=${_mediaKitTrackField(selectedTrack, 'title')}',
      );
    } catch (error) {
      AppLogger.log(
        'RadioPlayer: failed to select RAI audiodescription audio track: $error',
      );
    }
  }

  String _mediaKitTrackField(dynamic track, String fieldName) {
    try {
      final value = switch (fieldName) {
        'id' => (track as dynamic).id,
        'language' => (track as dynamic).language,
        'title' => (track as dynamic).title,
        _ => null,
      };
      return value?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _startMediaKitDiagnostics(mk.Player player) {
    _mediaKitDiagnosticsTimer?.cancel();
    _mediaKitDiagnosticsTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _mediaKitPlayer != player) {
        timer.cancel();
        return;
      }
      final lastProgress = _mediaKitLastProgressAt;
      final stallText = lastProgress == null
          ? 'unknown'
          : '${DateTime.now().difference(lastProgress).inSeconds}s';
      AppLogger.log(
        'RadioPlayer: MediaKit heartbeat station="${widget.station.name}" playing=$_mediaKitPlaying buffering=$_mediaKitBuffering completed=$_mediaKitCompleted position=$_mediaKitLastPosition duration=$_mediaKitLastDuration stalledFor=$stallText videoEnabled=$_isVideoEnabled videoApplied=$_mediaKitVideoSettingApplied volume=$_mediaKitVolume',
      );
      if (_shouldRecoverMediaKitDashStall(player)) {
        unawaited(_recoverMediaKitDashStall(player));
      }
    });
  }

  bool _shouldPreemptivelyRefreshMediaKitDashLiveWindow(mk.Player player) {
    if (!_requiresVideoPlayback || _mediaKitPlayer != player) return false;
    if (_mediaKitAutoRecoveryInProgress) return false;
    if (!_mediaKitPlaying || _mediaKitCompleted) return false;
    if (_mediaKitBuffering) return false;

    final position = _mediaKitLastPosition;
    final duration = _mediaKitLastDuration;
    if (position == null || duration == null) return false;

    // DASH/HBBTV live streams such as La7 Cinema can expose a short finite
    // window of about 36 seconds. Refresh just before the end of that window,
    // while playback is still alive, so the user should hear much less of the
    // stall than with a recovery after buffering has already started.
    if (duration < const Duration(seconds: 20)) return false;
    if (position < const Duration(seconds: 10)) return false;

    final remaining = duration - position;
    if (remaining > const Duration(seconds: 3)) return false;

    final lastRecovery = _mediaKitLastAutoRecoveryAt;
    if (lastRecovery != null &&
        DateTime.now().difference(lastRecovery) < const Duration(seconds: 20)) {
      return false;
    }

    return true;
  }

  bool _shouldRecoverMediaKitDashStall(mk.Player player) {
    if (!_requiresVideoPlayback || _mediaKitPlayer != player) return false;
    if (_mediaKitAutoRecoveryInProgress) return false;
    if (!_mediaKitPlaying || !_mediaKitBuffering || _mediaKitCompleted) {
      return false;
    }

    final position = _mediaKitLastPosition;
    final duration = _mediaKitLastDuration;
    final lastProgress = _mediaKitLastProgressAt;
    if (position == null || duration == null || lastProgress == null) {
      return false;
    }

    final stalledFor = DateTime.now().difference(lastProgress);
    if (stalledFor < const Duration(seconds: 7)) return false;

    // La7 Cinema and similar HBBTV DASH live streams can expose a short
    // moving window as a finite duration. On iOS/MediaKit the stream may
    // reach the end of that window, keep reporting playing=true, then stay
    // buffering forever until the MPD is reopened. Recover only when we are
    // clearly stalled near the end of the current window.
    final nearLiveWindowEnd = duration > Duration.zero &&
        duration - position <= const Duration(seconds: 2);
    if (!nearLiveWindowEnd) return false;

    final lastRecovery = _mediaKitLastAutoRecoveryAt;
    if (lastRecovery != null &&
        DateTime.now().difference(lastRecovery) < const Duration(seconds: 20)) {
      return false;
    }

    return true;
  }

  Future<void> _recoverMediaKitDashStall(mk.Player player) async {
    await _refreshMediaKitDashLiveWindow(player, reason: 'stalled');
  }

  Future<void> _refreshMediaKitDashLiveWindow(
    mk.Player player, {
    required String reason,
  }) async {
    if (_mediaKitAutoRecoveryInProgress || _mediaKitPlayer != player) return;
    _mediaKitAutoRecoveryInProgress = true;
    _mediaKitLastAutoRecoveryAt = DateTime.now();
    final remaining =
        (_mediaKitLastDuration != null && _mediaKitLastPosition != null)
            ? _mediaKitLastDuration! - _mediaKitLastPosition!
            : null;
    AppLogger.log(
      'RadioPlayer: MediaKit DASH live window refresh reason=$reason station="${widget.station.name}" position=$_mediaKitLastPosition duration=$_mediaKitLastDuration remaining=$remaining buffering=$_mediaKitBuffering playing=$_mediaKitPlaying videoEnabled=$_isVideoEnabled',
    );
    try {
      await _play();
    } catch (error) {
      AppLogger.log(
        'RadioPlayer: MediaKit DASH live window refresh failed reason=$reason error=$error',
      );
    } finally {
      _mediaKitAutoRecoveryInProgress = false;
    }
  }

  Future<void> _stabilizeMediaKitAfterStart(mk.Player player) async {
    // Some DASH/MPD HBBTV streams on iOS need the stream to start before
    // applying playback parameters. Do not select tracks before play here:
    // that can break some channels. This only reapplies the volume shortly
    // after startup, which is safe and helps streams that become silent while
    // still reporting a playing state.
    for (final delay in const [Duration(seconds: 2), Duration(seconds: 6)]) {
      await Future.delayed(delay);
      if (!mounted || _mediaKitPlayer != player || !_mediaKitPlaying) return;
      try {
        await player.setVolume(_mediaKitVolume * 100);
        AppLogger.log(
          'RadioPlayer: MediaKit volume re-applied after start volume=$_mediaKitVolume delay=${delay.inSeconds}s',
        );
      } catch (error) {
        AppLogger.log(
          'RadioPlayer: failed to re-apply MediaKit volume after start: $error',
        );
      }
    }
  }

  Future<void> _stop() async {
    if (_mediaKitPlayer != null) {
      await _mediaKitPlayer!.pause();
      if (_mediaKitIsMpd) {
        await _disableMpdWakelock();
      }
      if (mounted) setState(() {});
    } else if (_videoController != null) {
      await _videoController!.pause();
      setState(() {});
    } else {
      await _audio.stop();
    }
  }

  Future<void> _enableMpdWakelock() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    _mpdWakelockRequested = true;
    try {
      // La chiamata è intenzionalmente ripetuta: _audio.stop() può avere
      // disattivato il wakelock durante la riapertura della finestra MPD.
      await WakelockPlus.enable();
      await AppLogger.log('RadioPlayer: MPD wakelock enabled');
    } catch (error) {
      await AppLogger.log(
        'RadioPlayer: MPD wakelock enable failed: $error',
      );
    }
  }

  Future<void> _disableMpdWakelock() async {
    if (!_mpdWakelockRequested || !(Platform.isIOS || Platform.isAndroid)) {
      return;
    }
    _mpdWakelockRequested = false;
    try {
      await WakelockPlus.disable();
      await AppLogger.log('RadioPlayer: MPD wakelock disabled');
    } catch (error) {
      await AppLogger.log(
        'RadioPlayer: MPD wakelock disable failed: $error',
      );
    }
  }

  Future<bool> _applyMediaKitVideoEnabled(
    mk.Player player,
    bool enable,
  ) async {
    try {
      await player.setVideoTrack(
        enable ? mk.VideoTrack.auto() : mk.VideoTrack.no(),
      );
      AppLogger.log(
        'RadioPlayer: MediaKit video ${enable ? 'enabled' : 'disabled'} after start',
      );
      return true;
    } catch (error) {
      AppLogger.log(
        'RadioPlayer: failed to apply MediaKit video setting after start: $error',
      );
      return false;
    }
  }

  Future<void> _applyTvMediaKitVideoSetting(bool enable) async {
    await _settings.setVideoEnabled(enable);
    if (!mounted) return;

    final player = _mediaKitPlayer;
    if (player == null) {
      await _play();
      return;
    }

    _mediaKitVideoSettingApplied = true;
    final applied = await _applyMediaKitVideoEnabled(player, enable);
    if (!mounted || _mediaKitPlayer != player) return;
    if (!applied) {
      AppLogger.log(
        'RadioPlayer: restarting TV MediaKit because the video track setting could not be applied',
      );
      await _play();
      return;
    }
    setState(() {});
  }

  Future<void> _applyMpdVideoSetting(bool enable) async {
    await _settings.setVideoEnabled(enable);
    if (!mounted) return;
    AppLogger.log(
      'RadioPlayer: MPD video setting changed to $enable; restarting DASH stream to apply cleanly position=$_mediaKitLastPosition duration=$_mediaKitLastDuration buffering=$_mediaKitBuffering playing=$_mediaKitPlaying',
    );
    await _play();
  }

  void _setMediaKitVolume(double value) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    setState(() => _mediaKitVolume = clamped);
    unawaited(_settings.saveMediaVolume(clamped));
    final player = _mediaKitPlayer;
    if (player != null) {
      unawaited(player.setVolume(clamped * 100).catchError((error) {
        AppLogger.log('RadioPlayer: failed to set MediaKit volume: $error');
      }));
    }
  }

  void _setVideoPlayerVolume(double value) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    setState(() => _videoPlayerVolume = clamped);
    unawaited(_settings.saveMediaVolume(clamped));
    final controller = _videoController;
    if (controller != null) {
      unawaited(controller.setVolume(clamped).catchError((error) {
        AppLogger.log('RadioPlayer: failed to set video_player volume: $error');
      }));
    }
  }

  Future<void> _toggleVideoPlayback() async {
    final mediaKitPlayer = _mediaKitPlayer;
    if (mediaKitPlayer != null) {
      if (_mediaKitPlaying) {
        await mediaKitPlayer.pause();
        if (_mediaKitIsMpd) {
          await _disableMpdWakelock();
        }
      } else {
        if (_mediaKitIsMpd) {
          await _enableMpdWakelock();
        }
        try {
          await mediaKitPlayer.play();
        } catch (_) {
          if (_mediaKitIsMpd) {
            await _disableMpdWakelock();
          }
          rethrow;
        }
      }
      return;
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      if (Platform.isIOS) {
        await _mediaCommands.invokeMethod('setMagicTapPlaying', false);
      }
    } else {
      await controller.play();
      if (Platform.isIOS) {
        await _mediaCommands.invokeMethod('setMagicTapPlaying', true);
      }
    }
    if (mounted) setState(() {});
  }

  void _toggleVideo(bool enable) {
    AppLogger.log(
      'RadioPlayer: enable video switch changed enable=$enable requiresVideoPlayback=$_requiresVideoPlayback requiresRaiADMediaKit=$_requiresRaiAudioDescriptionMediaKitPlayback position=$_mediaKitLastPosition duration=$_mediaKitLastDuration buffering=$_mediaKitBuffering playing=$_mediaKitPlaying',
    );
    setState(() => _isVideoEnabled = enable);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isVideoEnabled != enable) return;
      if (_requiresVideoPlayback) {
        // I live DASH mantengono il riavvio già previsto, perché alcuni MPD
        // applicano in modo affidabile il cambio traccia solo alla riapertura.
        unawaited(_applyMpdVideoSetting(enable));
      } else if (_requiresTvMediaKitPlayback) {
        unawaited(_applyTvMediaKitVideoSetting(enable));
      } else {
        unawaited(_applyVideoSetting(enable));
      }
    });
  }

  Future<void> _applyVideoSetting(bool enable) async {
    await _settings.setVideoEnabled(enable);
    await _play();
  }

  Future<void> _toggleFavorite() async {
    final l10n = AppLocalizations.of(context);
    if (widget.tvChannel != null) {
      final service = TvService();
      final channel = widget.tvChannel!;
      final favorites = await service.loadFavorites();
      final alreadyFavorite = favorites.any(
        (item) => service.isSameFavoriteChannel(item, channel),
      );
      final next = alreadyFavorite
          ? favorites
              .where((item) => !service.isSameFavoriteChannel(item, channel))
              .toList()
          : [...favorites, channel];
      await service.saveFavorites(next);
      if (!mounted) return;
      setState(() => _isFavorite = !alreadyFavorite);
      showStatusMessage(
          context,
          alreadyFavorite
              ? l10n.radioFavoriteRemoved(channel.name)
              : l10n.radioFavoriteAdded(channel.name));
      return;
    }

    final service = RadioService();
    final favorites = await service.loadFavorites();
    final alreadyFavorite = favorites.any(
      (item) => item.streamUrl == widget.station.streamUrl,
    );
    final next = alreadyFavorite
        ? favorites
            .where((item) => item.streamUrl != widget.station.streamUrl)
            .toList()
        : [...favorites, widget.station];
    await service.saveFavorites(next);
    if (!mounted) return;
    setState(() => _isFavorite = !alreadyFavorite);
    showStatusMessage(
        context,
        alreadyFavorite
            ? l10n.radioFavoriteRemoved(widget.station.name)
            : l10n.radioFavoriteAdded(widget.station.name));
  }

  Future<void> _toggleRecording() async {
    try {
      if (_recording) {
        await _stopRecordingNow();
        if (_scheduledRecordingStopTimer != null) {
          _cancelScheduledRecording(showMessage: false);
        }
        return;
      }
      await _startRecordingNow();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordingOutput = null;
      });
      showStatusMessage(
          context, AppLocalizations.of(context).recordingError(error));
    }
  }

  Future<File?> _stopRecordingNow({bool showMessage = true}) async {
    final l10n = AppLocalizations.of(context);
    final file = await _recordingService.stop();
    if (!mounted) return file;
    setState(() {
      _recording = false;
      _recordingOutput = file;
    });
    if (showMessage) {
      showStatusMessage(
          context,
          l10n.recordingSaved(
            file == null ? '' : p.basenameWithoutExtension(file.path),
          ));
    }
    return file;
  }

  Future<File> _startRecordingNow({
    String? titleOverride,
    bool showMessage = true,
  }) async {
    final l10n = AppLocalizations.of(context);
    String? recordingVideoUrl;
    String? recordingAudioUrl;
    final tvChannel = widget.tvChannel;
    if (tvChannel != null &&
        TvService().isRaiAudioDescriptionChannel(tvChannel) &&
        !TvService.isDashStreamUrl(widget.station.streamUrl)) {
      final streams =
          await TvService().resolveAudioDescriptionStreams(tvChannel);
      if (streams.hasAudioDescription && streams.videoUrl != streams.audioUrl) {
        recordingVideoUrl = streams.videoUrl;
        recordingAudioUrl = streams.audioUrl;
        await AppLogger.log(
          'RadioPlayer: RAI AD recording requested videoUrl=$recordingVideoUrl audioUrl=$recordingAudioUrl',
        );
      } else {
        await AppLogger.log(
          'RadioPlayer: RAI AD recording fallback to normal stream hasAD=${streams.hasAudioDescription}',
        );
      }
    }

    final file = await _recordingService.start(
      stationName: _scheduledRecordingFileName(titleOverride),
      streamUrl: widget.station.streamUrl,
      videoStreamUrl: recordingVideoUrl,
      audioStreamUrl: recordingAudioUrl,
      httpUserAgent: widget.tvChannel?.httpUserAgent,
    );
    if (!mounted) return file;
    setState(() {
      _recording = true;
      _recordingOutput = file;
    });
    if (showMessage) {
      showStatusMessage(context, l10n.recordingStarted);
    }
    return file;
  }

  String _scheduledRecordingFileName(String? titleOverride) {
    final title = titleOverride?.trim();
    if (title != null && title.isNotEmpty) return title;
    return widget.station.name;
  }

  Future<TimeOfDay?> _showScheduledRecordingTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    required String title,
  }) async {
    int selectedHour = initialTime.hour;
    int selectedMinute = initialTime.minute;

    String twoDigits(int value) => value.toString().padLeft(2, '0');
    int clampInt(int value, int min, int max) => value.clamp(min, max).toInt();

    return showDialog<TimeOfDay>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final nextHour = twoDigits(clampInt(selectedHour + 1, 0, 23));
            final previousHour = twoDigits(clampInt(selectedHour - 1, 0, 23));
            final nextMinute = twoDigits(clampInt(selectedMinute + 1, 0, 59));
            final previousMinute =
                twoDigits(clampInt(selectedMinute - 1, 0, 59));

            void setHour(int value) {
              setDialogState(() {
                selectedHour = clampInt(value, 0, 23);
              });
            }

            void setMinute(int value) {
              setDialogState(() {
                selectedMinute = clampInt(value, 0, 59);
              });
            }

            Widget buildValueSlider({
              required String visibleLabel,
              required String semanticsLabel,
              required int value,
              required int min,
              required int max,
              required String increasedValue,
              required String decreasedValue,
              required ValueChanged<int> onChanged,
            }) {
              final valueText = twoDigits(value);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Text('$visibleLabel: $valueText'),
                  ),
                  Semantics(
                    slider: true,
                    label: semanticsLabel,
                    value: valueText,
                    increasedValue: increasedValue,
                    decreasedValue: decreasedValue,
                    onIncrease: () => onChanged(value + 1),
                    onDecrease: () => onChanged(value - 1),
                    child: ExcludeSemantics(
                      child: Slider(
                        value: value.toDouble(),
                        min: min.toDouble(),
                        max: max.toDouble(),
                        divisions: max - min,
                        label: valueText,
                        onChanged: (newValue) => onChanged(newValue.round()),
                      ),
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildValueSlider(
                    visibleLabel: 'Ore',
                    semanticsLabel: 'Seleziona le ore',
                    value: selectedHour,
                    min: 0,
                    max: 23,
                    increasedValue: nextHour,
                    decreasedValue: previousHour,
                    onChanged: setHour,
                  ),
                  const SizedBox(height: 16),
                  buildValueSlider(
                    visibleLabel: 'Minuti',
                    semanticsLabel: 'Seleziona i minuti',
                    value: selectedMinute,
                    min: 0,
                    max: 59,
                    increasedValue: nextMinute,
                    decreasedValue: previousMinute,
                    onChanged: setMinute,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    TimeOfDay(hour: selectedHour, minute: selectedMinute),
                  ),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showScheduleRecordingDialog() async {
    if (_recording) {
      showStatusMessage(
        context,
        'Termina la registrazione in corso prima di programmarne una nuova.',
      );
      return;
    }
    final now = DateTime.now();
    TimeOfDay startTime = TimeOfDay.fromDateTime(
      now.add(const Duration(minutes: 5)),
    );
    TimeOfDay endTime = TimeOfDay.fromDateTime(
      now.add(const Duration(minutes: 35)),
    );
    final titleController = TextEditingController();
    try {
      final request = await showDialog<_ScheduledRecordingRequest>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> pickStart() async {
                final picked = await _showScheduledRecordingTimePicker(
                  context: context,
                  initialTime: startTime,
                  title: 'Ora di inizio',
                );
                if (picked != null) {
                  setDialogState(() => startTime = picked);
                }
              }

              Future<void> pickEnd() async {
                final picked = await _showScheduledRecordingTimePicker(
                  context: context,
                  initialTime: endTime,
                  title: 'Ora di fine',
                );
                if (picked != null) {
                  setDialogState(() => endTime = picked);
                }
              }

              return AlertDialog(
                title: const Text('Programma registrazione'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 360,
                  child: useNativeIosAccessibleViews
                      ? NativeIosAccessibleList(
                          sections: [NativeIosListSection(rows: [
                            const NativeIosListRow(
                              id: 'info',
                              kind: 'text',
                              title: 'In questa versione la registrazione programmata parte solo se Sonarpad resta aperto su questo player. Se chiudi l’app o questa schermata, la registrazione non può partire da sola.',
                            ),
                            NativeIosListRow(
                              id: 'start',
                              title: 'Ora di inizio: ${_formatTimeOfDay(startTime)}',
                            ),
                            NativeIosListRow(
                              id: 'end',
                              title: 'Ora di fine: ${_formatTimeOfDay(endTime)}',
                            ),
                            NativeIosListRow(
                              id: 'title',
                              kind: 'textField',
                              title: 'Titolo facoltativo',
                              placeholder: 'Lascia vuoto per usare il nome della radio o TV',
                              value: titleController.text,
                            ),
                          ])],
                          onEvent: (event) {
                            if (event.id == 'start' && event.type == 'activate') {
                              pickStart();
                            } else if (event.id == 'end' && event.type == 'activate') {
                              pickEnd();
                            } else if (event.id == 'title' && event.type == 'textChanged') {
                              titleController.text = event.value?.toString() ?? '';
                            }
                          },
                        )
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'In questa versione la registrazione programmata parte solo se Sonarpad resta aperto su questo player. Se chiudi l’app o questa schermata, la registrazione non può partire da sola.',
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: pickStart,
                                icon: const Icon(Icons.schedule),
                                label: Text('Ora di inizio: ${_formatTimeOfDay(startTime)}'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: pickEnd,
                                icon: const Icon(Icons.schedule),
                                label: Text('Ora di fine: ${_formatTimeOfDay(endTime)}'),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Titolo facoltativo',
                                  hintText: 'Lascia vuoto per usare il nome della radio o TV',
                                ),
                                textInputAction: TextInputAction.done,
                              ),
                            ],
                          ),
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annulla'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                        _ScheduledRecordingRequest(
                          startTime: startTime,
                          endTime: endTime,
                          title: titleController.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Programma'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (request == null || !mounted) return;
      _scheduleRecording(request);
    } finally {
      titleController.dispose();
    }
  }

  void _scheduleRecording(_ScheduledRecordingRequest request) {
    final now = DateTime.now();
    var start = DateTime(
      now.year,
      now.month,
      now.day,
      request.startTime.hour,
      request.startTime.minute,
    );
    if (!start.isAfter(now)) {
      start = start.add(const Duration(days: 1));
    }
    var end = DateTime(
      start.year,
      start.month,
      start.day,
      request.endTime.hour,
      request.endTime.minute,
    );
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    _cancelScheduledRecording(showMessage: false);
    final title = request.title.trim().isEmpty ? null : request.title.trim();
    setState(() {
      _scheduledRecordingStart = start;
      _scheduledRecordingEnd = end;
      _scheduledRecordingTitle = title;
      _scheduledRecordingStartTimer = Timer(
        start.difference(now),
        () => unawaited(_startScheduledRecording()),
      );
    });
    unawaited(AppLogger.log(
      'RadioPlayer: scheduled recording set start=$start end=$end title=${title ?? ''} station="${widget.station.name}" tv=${widget.tvChannel != null}',
    ));
    showStatusMessage(
      context,
      'Registrazione programmata: ${_formatScheduledDateTime(start)} - ${_formatScheduledDateTime(end)}.',
    );
  }

  Future<void> _startScheduledRecording() async {
    if (!mounted) return;
    final end = _scheduledRecordingEnd;
    final title = _scheduledRecordingTitle;
    try {
      if (_recording) {
        AppLogger.log(
          'RadioPlayer: scheduled recording skipped because another recording is already active',
        );
        showStatusMessage(
          context,
          'Registrazione programmata non avviata: una registrazione è già in corso.',
        );
        _clearScheduledRecordingState();
        return;
      }
      await AppLogger.log(
        'RadioPlayer: scheduled recording start title=${title ?? ''} end=$end',
      );
      await _startRecordingNow(titleOverride: title, showMessage: false);
      if (!mounted) return;
      showStatusMessage(context, 'Registrazione programmata avviata.');
      if (end == null) {
        _clearScheduledRecordingState();
        return;
      }
      final delay = end.difference(DateTime.now());
      if (delay <= Duration.zero) {
        await _stopScheduledRecording();
      } else {
        setState(() {
          _scheduledRecordingStartTimer?.cancel();
          _scheduledRecordingStartTimer = null;
          _scheduledRecordingStopTimer = Timer(
            delay,
            () => unawaited(_stopScheduledRecording()),
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      await AppLogger.log(
          'RadioPlayer: scheduled recording start failed: $error');
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordingOutput = null;
      });
      _clearScheduledRecordingState();
      showStatusMessage(context, 'Errore registrazione programmata: $error');
    }
  }

  Future<void> _stopScheduledRecording() async {
    if (!mounted) return;
    try {
      await AppLogger.log('RadioPlayer: scheduled recording stop');
      if (_recording) {
        await _stopRecordingNow(showMessage: false);
        if (!mounted) return;
        showStatusMessage(context, 'Registrazione programmata salvata.');
      }
    } catch (error) {
      if (!mounted) return;
      showStatusMessage(
          context, 'Errore salvataggio registrazione programmata: $error');
    } finally {
      if (mounted) {
        _clearScheduledRecordingState();
      }
    }
  }

  void _cancelScheduledRecording({bool showMessage = true}) {
    _scheduledRecordingStartTimer?.cancel();
    _scheduledRecordingStopTimer?.cancel();
    final hadSchedule = _scheduledRecordingStart != null ||
        _scheduledRecordingStartTimer != null ||
        _scheduledRecordingStopTimer != null;
    _clearScheduledRecordingState(setStateIfMounted: false);
    if (mounted) {
      setState(() {});
      if (showMessage && hadSchedule) {
        showStatusMessage(context, 'Registrazione programmata annullata.');
      }
    }
    if (hadSchedule) {
      unawaited(AppLogger.log('RadioPlayer: scheduled recording cancelled'));
    }
  }

  void _clearScheduledRecordingState({bool setStateIfMounted = true}) {
    void clear() {
      _scheduledRecordingStartTimer?.cancel();
      _scheduledRecordingStopTimer?.cancel();
      _scheduledRecordingStartTimer = null;
      _scheduledRecordingStopTimer = null;
      _scheduledRecordingStart = null;
      _scheduledRecordingEnd = null;
      _scheduledRecordingTitle = null;
    }

    if (setStateIfMounted && mounted) {
      setState(clear);
    } else {
      clear();
    }
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatScheduledDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  String? get _scheduledRecordingSummary {
    final start = _scheduledRecordingStart;
    final end = _scheduledRecordingEnd;
    if (start == null || end == null) return null;
    final title = _scheduledRecordingTitle;
    final titlePart = title == null || title.isEmpty ? '' : ' Titolo: $title.';
    return 'Registrazione programmata: ${_formatScheduledDateTime(start)} - ${_formatScheduledDateTime(end)}.$titlePart';
  }

  bool get _hasPendingScheduledRecording =>
      _scheduledRecordingStartTimer?.isActive ?? false;

  bool get _requiresRaiAudioDescriptionMediaKitPlayback =>
      widget.isVideoSupported &&
      widget.tvChannel != null &&
      TvService().isRaiAudioDescriptionChannel(widget.tvChannel!);

  bool get _requiresTvMediaKitPlayback =>
      widget.isVideoSupported && widget.tvChannel != null;

  bool get _requiresVideoPlayback =>
      widget.isVideoSupported &&
      TvService.isDashStreamUrl(widget.station.streamUrl);

  bool get _isVideoPlaying => _mediaKitPlayer != null
      ? _mediaKitPlaying
      : (_videoController?.value.isPlaying ?? false);

  bool get _canRecordStream => _isRecordingFeatureUnlocked;

  bool get _useLandscapeFullscreenVideo =>
      _displayVideoInPortrait &&
      _isVideoEnabled &&
      ((_videoController != null && _videoController!.value.isInitialized) ||
          _mediaKitController != null);

  void _syncLandscapeFullscreenOrientation() {
    final enable = _useLandscapeFullscreenVideo;
    if (_landscapeFullscreenApplied == enable) return;
    _landscapeFullscreenApplied = enable;
    if (Platform.isIOS || Platform.isAndroid) {
      if (enable) {
        unawaited(SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]));
        unawaited(
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
      } else {
        unawaited(
            SystemChrome.setPreferredOrientations(DeviceOrientation.values));
        unawaited(SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        ));
      }
    }
  }

  void _restoreSystemOrientation() {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    _landscapeFullscreenApplied = false;
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    unawaited(SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    ));
  }

  @override
  void dispose() {
    _scheduledRecordingStartTimer?.cancel();
    _scheduledRecordingStopTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    if (Platform.isIOS &&
        (_videoController != null || _mediaKitPlayer != null)) {
      unawaited(_mediaCommands.invokeMethod('clearMagicTap'));
    }
    _restoreSystemOrientation();
    unawaited(_mediaEventsSubscription?.cancel() ?? Future<void>.value());
    unawaited(_disableMpdWakelock());
    unawaited(_disposeMediaKitPlayer());
    if (_recordingService.isRecording) {
      unawaited(_recordingService.stop().catchError((error) {
        AppLogger.log(
            'RadioPlayer: recording stop during dispose failed: $error');
        return null;
      }));
    }
    _videoController?.dispose();
    unawaited(_audio.stopAndDispose());
    super.dispose();
  }

  Future<void> _disposeMediaKitPlayer() async {
    _mediaKitDiagnosticsTimer?.cancel();
    _mediaKitDiagnosticsTimer = null;
    await _mediaKitPlayingSubscription?.cancel();
    await _mediaKitErrorSubscription?.cancel();
    await _mediaKitPositionSubscription?.cancel();
    await _mediaKitDurationSubscription?.cancel();
    await _mediaKitTracksSubscription?.cancel();
    await _mediaKitBufferingSubscription?.cancel();
    await _mediaKitCompletedSubscription?.cancel();
    _mediaKitPlayingSubscription = null;
    _mediaKitErrorSubscription = null;
    _mediaKitPositionSubscription = null;
    _mediaKitDurationSubscription = null;
    _mediaKitTracksSubscription = null;
    _mediaKitBufferingSubscription = null;
    _mediaKitCompletedSubscription = null;
    final player = _mediaKitPlayer;
    AppLogger.log(
      'RadioPlayer: MediaKit dispose start playerPresent=${player != null} position=$_mediaKitLastPosition duration=$_mediaKitLastDuration buffering=$_mediaKitBuffering playing=$_mediaKitPlaying completed=$_mediaKitCompleted',
    );
    _mediaKitPlayer = null;
    _mediaKitController = null;
    _mediaKitPlaying = false;
    _mediaKitVideoSettingApplied = false;
    _mediaKitRaiAudioTrackApplied = false;
    _mediaKitBuffering = false;
    _mediaKitCompleted = false;
    _mediaKitLastPosition = null;
    _mediaKitLastDuration = null;
    _mediaKitLastProgressAt = null;
    _mediaKitLastPositionLogAt = null;
    _mediaKitAutoRecoveryInProgress = false;
    if (player != null) {
      await player.dispose();
      AppLogger.log('RadioPlayer: MediaKit dispose completed');
    }
  }

  Widget _buildVideoPlayerSurface(VideoPlayerController controller) {
    final aspect = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    return AspectRatio(
      aspectRatio: aspect,
      child: VideoPlayer(controller),
    );
  }

  Widget _buildMediaKitVideoSurface() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: mkv.Video(
        controller: _mediaKitController!,
        controls: mkv.AdaptiveVideoControls,
      ),
    );
  }

  Widget _buildVideoPlayerFullscreenSurface(VideoPlayerController controller) {
    final aspect = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: aspect >= 1 ? aspect : 1,
              height: aspect >= 1 ? 1 : 1 / aspect,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaKitVideoFullscreenSurface() {
    final video = mkv.Video(
      controller: _mediaKitController!,
      controls: mkv.AdaptiveVideoControls,
    );
    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 16,
              height: 9,
              child: video,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeFullscreenControls(AppLocalizations l10n) {
    return Material(
      color: Colors.black54,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                title: Text(
                  l10n.enableVideo,
                  style: const TextStyle(color: Colors.white),
                ),
                value: _isVideoEnabled,
                onChanged: _loading ? null : _toggleVideo,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _loading ? null : _toggleVideoPlayback,
                    icon:
                        Icon(_isVideoPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(_isVideoPlaying ? l10n.pause : l10n.play),
                  ),
                  if (_canRecordStream)
                    FilledButton.icon(
                      onPressed: _loading ? null : _toggleRecording,
                      icon: Icon(
                        _recording ? Icons.stop : Icons.fiber_manual_record,
                      ),
                      label: Text(
                        _recording ? l10n.stopRecording : l10n.startRecording,
                      ),
                    ),
                  if (_canRecordStream)
                    OutlinedButton.icon(
                      onPressed: _loading || _recording
                          ? null
                          : _showScheduleRecordingDialog,
                      icon: const Icon(Icons.schedule),
                      label: const Text('Programma registrazione'),
                    ),
                ],
              ),
              if (_recordingOutput != null) ...[
                const SizedBox(height: 12),
                Text(
                  p.basenameWithoutExtension(_recordingOutput!.path),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
              if (_scheduledRecordingSummary != null) ...[
                const SizedBox(height: 12),
                Text(
                  _scheduledRecordingSummary!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                if (_hasPendingScheduledRecording)
                  TextButton.icon(
                    onPressed: () => _cancelScheduledRecording(),
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: const Text(
                      'Annulla registrazione programmata',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
              if (_videoController != null &&
                  _videoController!.value.isInitialized) ...[
                const SizedBox(height: 12),
                _PlayerVolumeSlider(
                  volume: _videoPlayerVolume,
                  onChanged: _setVideoPlayerVolume,
                ),
              ],
              if (_mediaKitPlayer != null) ...[
                const SizedBox(height: 12),
                _PlayerVolumeSlider(
                  volume: _mediaKitVolume,
                  onChanged: _setMediaKitVolume,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeFullscreenScaffold(AppLocalizations l10n) {
    final videoSurface =
        _videoController != null && _videoController!.value.isInitialized
            ? _buildVideoPlayerFullscreenSurface(_videoController!)
            : _buildMediaKitVideoFullscreenSurface();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: videoSurface),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    color: Colors.white,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildLandscapeFullscreenControls(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeIosPlayerBody(AppLocalizations l10n, bool showStationDetails) {
    Widget buildControls(bool audioPlaying) {
      final videoMode = _mediaKitPlayer != null || _videoController != null;
      final rows = <NativeIosListRow>[
        NativeIosListRow(id: 'title', kind: 'header', title: widget.station.name),
        if (showStationDetails) NativeIosListRow(id: 'details', kind: 'text', title: widget.station.detailsText),
        if (_loading) NativeIosListRow(id: 'loading', kind: 'text', title: l10n.loading),
        if (_error != null) NativeIosListRow(id: 'error', kind: 'text', title: _error!),
        if (widget.isVideoSupported) NativeIosListRow(id: 'video', title: l10n.enableVideo, kind: 'toggle', toggleValue: _isVideoEnabled),
        NativeIosListRow(
          id: 'play_pause',
          title: videoMode ? (_isVideoPlaying ? l10n.pause : l10n.play) : (audioPlaying ? l10n.pause : l10n.play),
          kind: 'button',
          enabled: !_loading,
        ),
        if (_canRecordStream)
          NativeIosListRow(id: 'record', title: _recording ? l10n.stopRecording : l10n.startRecording, kind: 'button', enabled: !_loading),
        if (_canRecordStream)
          NativeIosListRow(id: 'schedule', title: 'Programma registrazione', enabled: !_loading && !_recording),
        if (_recordingOutput != null)
          NativeIosListRow(id: 'recording_name', kind: 'text', title: p.basenameWithoutExtension(_recordingOutput!.path)),
        if (_scheduledRecordingSummary != null)
          NativeIosListRow(id: 'schedule_summary', kind: 'text', title: _scheduledRecordingSummary!),
        if (_hasPendingScheduledRecording)
          const NativeIosListRow(id: 'cancel_schedule', title: 'Annulla registrazione programmata'),
        NativeIosListRow(
          id: 'favorite',
          title: _isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
          kind: 'button',
        ),
      ];
      return NativeIosAccessibleList(
        sections: [NativeIosListSection(rows: rows)],
        onEvent: (event) async {
          if (event.id == 'video' && event.type == 'toggle') {
            _toggleVideo(event.value == true);
          } else if (event.id == 'play_pause' && event.type == 'activate') {
            if (videoMode) {
              await _toggleVideoPlayback();
            } else if (audioPlaying) {
              await _stop();
            } else {
              await _play();
            }
          } else if (event.id == 'record' && event.type == 'activate') {
            await _toggleRecording();
          } else if (event.id == 'schedule' && event.type == 'activate' && !_recording) {
            await _showScheduleRecordingDialog();
          } else if (event.id == 'cancel_schedule' && event.type == 'activate') {
            _cancelScheduledRecording();
          } else if (event.id == 'favorite' && event.type == 'activate') {
            await _toggleFavorite();
          }
        },
      );
    }

    final nativeList = (_mediaKitPlayer == null && _videoController == null)
        ? StreamBuilder<bool>(
            stream: _audio.playingStream,
            builder: (context, snapshot) => buildControls(snapshot.data ?? false),
          )
        : buildControls(false);

    return Column(
      children: [
        if (_videoController != null && _videoController!.value.isInitialized)
          Padding(padding: const EdgeInsets.all(12), child: _buildVideoPlayerSurface(_videoController!)),
        if (_mediaKitController != null && _isVideoEnabled)
          Padding(padding: const EdgeInsets.all(12), child: _buildMediaKitVideoSurface()),
        Expanded(child: nativeList),
        if (_videoController == null && _mediaKitPlayer == null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: VolumeSlider(audioPlayer: _audio)),
        if (_videoController != null && _videoController!.value.isInitialized)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _PlayerVolumeSlider(volume: _videoPlayerVolume, onChanged: _setVideoPlayerVolume),
          ),
        if (_mediaKitPlayer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _PlayerVolumeSlider(volume: _mediaKitVolume, onChanged: _setMediaKitVolume),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.log(
        'RadioPlayer: build() called. loading=$_loading, error=$_error, videoEnabled=$_isVideoEnabled, videoControllerInit=${_videoController?.value.isInitialized}');
    _syncLandscapeFullscreenOrientation();
    final l10n = AppLocalizations.of(context);
    final showStationDetails = widget.tvChannel == null &&
        widget.station.detailsText.trim().isNotEmpty;
    if (_useLandscapeFullscreenVideo) {
      return _buildLandscapeFullscreenScaffold(l10n);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.nowPlaying}: ${widget.station.name}'),
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: useNativeIosAccessibleViews
          ? _buildNativeIosPlayerBody(l10n, showStationDetails)
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.station.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (showStationDetails) ...[
            const SizedBox(height: 8),
            Text(
              widget.station.detailsText,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          if (_loading) LinearProgressIndicator(semanticsLabel: l10n.loading),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          if (widget.isVideoSupported) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.enableVideo),
              value: _isVideoEnabled,
              onChanged: _toggleVideo,
              contentPadding: EdgeInsets.zero,
            ),
          ],
          if (_videoController != null &&
              _videoController!.value.isInitialized) ...[
            const SizedBox(height: 24),
            _buildVideoPlayerSurface(_videoController!),
          ],
          if (_mediaKitController != null && _isVideoEnabled) ...[
            const SizedBox(height: 24),
            _buildMediaKitVideoSurface(),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (_mediaKitPlayer != null || _videoController != null)
                FilledButton.icon(
                  onPressed: _loading ? null : _toggleVideoPlayback,
                  icon: Icon(_isVideoPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isVideoPlaying ? l10n.pause : l10n.play),
                )
              else
                StreamBuilder<bool>(
                  stream: _audio.playingStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return FilledButton.icon(
                      onPressed: _loading ? null : (isPlaying ? _stop : _play),
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(isPlaying ? l10n.pause : l10n.play),
                    );
                  },
                ),
              if (_canRecordStream)
                FilledButton.icon(
                  onPressed: _loading ? null : _toggleRecording,
                  icon:
                      Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(
                      _recording ? l10n.stopRecording : l10n.startRecording),
                ),
              if (_canRecordStream)
                OutlinedButton.icon(
                  onPressed: _loading || _recording
                      ? null
                      : _showScheduleRecordingDialog,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Programma registrazione'),
                ),
            ],
          ),
          if (_recordingOutput != null) ...[
            const SizedBox(height: 12),
            Text(
              p.basenameWithoutExtension(_recordingOutput!.path),
              textAlign: TextAlign.center,
            ),
          ],
          if (_scheduledRecordingSummary != null) ...[
            const SizedBox(height: 12),
            Text(
              _scheduledRecordingSummary!,
              textAlign: TextAlign.center,
            ),
            if (_hasPendingScheduledRecording)
              TextButton.icon(
                onPressed: () => _cancelScheduledRecording(),
                icon: const Icon(Icons.cancel),
                label: const Text('Annulla registrazione programmata'),
              ),
          ],
          if (_videoController == null && _mediaKitPlayer == null) ...[
            const SizedBox(height: 24),
            VolumeSlider(audioPlayer: _audio),
          ],
          if (_videoController != null &&
              _videoController!.value.isInitialized) ...[
            const SizedBox(height: 24),
            _PlayerVolumeSlider(
              volume: _videoPlayerVolume,
              onChanged: _setVideoPlayerVolume,
            ),
          ],
          if (_mediaKitPlayer != null) ...[
            const SizedBox(height: 24),
            _PlayerVolumeSlider(
              volume: _mediaKitVolume,
              onChanged: _setMediaKitVolume,
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _toggleFavorite,
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            label: Text(
              _isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduledRecordingRequest {
  const _ScheduledRecordingRequest({
    required this.startTime,
    required this.endTime,
    required this.title,
  });

  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String title;
}

class _PlayerVolumeSlider extends StatelessWidget {
  const _PlayerVolumeSlider({
    required this.volume,
    required this.onChanged,
  });

  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percentage = (volume * 100).round();
    final label = l10n.volumeValue(percentage);
    final increased = ((volume + 0.1).clamp(0.0, 1.0) * 100).round();
    final decreased = ((volume - 0.1).clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('mediakit_volume_slider_semantics'),
          slider: true,
          label: l10n.adjustVolume,
          value: '$percentage%',
          increasedValue: '$increased%',
          decreasedValue: '$decreased%',
          onIncrease: () =>
              onChanged((volume + 0.1).clamp(0.0, 1.0).toDouble()),
          onDecrease: () =>
              onChanged((volume - 0.1).clamp(0.0, 1.0).toDouble()),
          child: ExcludeSemantics(
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
