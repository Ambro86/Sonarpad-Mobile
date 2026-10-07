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
import '../services/global_recording_service.dart';
import '../services/radio_service.dart';
import '../services/raiplay_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/rai_native_player_service.dart';
import '../services/tv_service.dart';
import '../services/stream_diagnostics_service.dart';
import '../widgets/volume_slider.dart';
import 'package:video_player/video_player.dart';
import '../services/app_settings_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/tv_recording_schedule_action.dart';
import '../widgets/universal_accessible_view.dart';

class RadioPlayerScreen extends StatefulWidget {
  final RadioStation station;
  final bool isVideoSupported;
  final TvChannel? tvChannel;
  final bool autoStartRecording;
  const RadioPlayerScreen({
    super.key,
    required this.station,
    this.isVideoSupported = false,
    this.tvChannel,
    this.autoStartRecording = false,
  });

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> {
  static const _mediaCommands = MethodChannel('sonarpad/tts_commands');
  static const _mediaEvents = EventChannel('sonarpad/tts_events');

  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  final _recordingService = GlobalRecordingService.instance;
  final _raiNativePlayer = RaiNativePlayerService();
  late final GlobalRecordingTarget _recordingTarget;
  StreamSubscription<dynamic>? _mediaEventsSubscription;
  StreamSubscription<dynamic>? _raiNativeEventsSubscription;
  StreamSubscription<Duration>? _androidLa7AudioPositionSubscription;
  StreamSubscription<bool>? _mediaKitPlayingSubscription;
  StreamSubscription<String>? _mediaKitErrorSubscription;
  StreamSubscription<dynamic>? _mediaKitPositionSubscription;
  StreamSubscription<dynamic>? _mediaKitDurationSubscription;
  StreamSubscription<dynamic>? _mediaKitTracksSubscription;
  StreamSubscription<dynamic>? _mediaKitBufferingSubscription;
  StreamSubscription<dynamic>? _mediaKitCompletedSubscription;
  Timer? _mediaKitDiagnosticsTimer;
  Timer? _raiDirectAudioFallbackTimer;
  Timer? _streamConnectionTimer;
  StreamSubscription<mk.PlayerLog>? _mediaKitLogSubscription;
  StreamDiagnosticsSession? _streamDiagnostics;
  StreamDiagnosticsSession? _mediaKitDiagnosticsSession;
  final _streamRecovery = StreamPlaybackRecoveryState();
  Future<void>? _mediaKitDisposeInFlight;
  int _playRequestId = 0;
  int _mediaKitOpenId = 0;
  String? _mediaKitPlaybackUrl;
  String _mediaKitStage = 'none';
  bool _streamRetryInProgress = false;
  bool _streamUserPaused = false;
  int _androidLa7AutoRecoveryCount = 0;
  bool _androidLa7AutoRecoveryInProgress = false;

  bool get _streamReconnecting =>
      widget.tvChannel != null && _streamRecovery.isReconnecting;
  bool get _showStreamRetry =>
      widget.tvChannel != null && _streamRecovery.canRetry;

  VideoPlayerController? _videoController;
  mk.Player? _mediaKitPlayer;
  mkv.VideoController? _mediaKitController;
  bool _raiNativeActive = false;
  bool _raiNativePlaying = false;
  bool _raiNativeBuffering = false;
  bool _raiNativeFallbackInProgress = false;
  int _raiNativeGeneration = 0;
  int _raiNativeRestartCount = 0;
  Timer? _raiNativeStallTimer;
  bool _isVideoEnabled = false;
  bool _displayVideoInPortrait = false;
  bool _isFavorite = false;
  bool _mediaKitPlaying = false;
  bool _mediaKitVideoSettingApplied = false;
  bool _landscapeFullscreenApplied = false;
  Size? _lastFullscreenVideoSurfaceSize;
  String? _lastFullscreenVideoSurfaceEngine;
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
  bool _raiDirectAudioFallbackInProgress = false;
  bool _raiNormalAudioFallbackInProgress = false;
  mk.Player? _raiRecoverySourcePlayer;
  double _mediaKitVolume = 1.0;
  double _videoPlayerVolume = 1.0;
  bool _isRecordingFeatureUnlocked = false;
  bool _preferRaiAudioDescription = true;
  bool _allowExitWithActiveRecording = false;
  bool _recordingExitPromptOpen = false;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recordingTarget = widget.tvChannel == null
        ? GlobalRecordingTarget(
            id: 'radio:${widget.station.streamUrl}',
            stationName: widget.station.name,
            streamUrl: widget.station.streamUrl,
            includeVideo: false,
          )
        : tvRecordingTargetForChannel(
            widget.tvChannel!,
            resolvedStreamUrl: widget.station.streamUrl,
          );
    _recordingService.addListener(_onGlobalRecordingChanged);
    if (Platform.isIOS) {
      _mediaEventsSubscription =
          _mediaEvents.receiveBroadcastStream().listen((event) {
        if (event == 'toggle' &&
            mounted &&
            (_videoController != null || _mediaKitPlayer != null || _raiNativeActive)) {
          unawaited(_toggleVideoPlayback());
        }
      });
      _raiNativeEventsSubscription =
          _raiNativePlayer.events.listen(_handleRaiNativePlayerEvent);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isVideoEnabled = await _settings.isVideoEnabled();
      _displayVideoInPortrait = await _settings.displayVideoInPortrait();
      _isFavorite = await _loadIsFavorite();
      _isRecordingFeatureUnlocked = await _loadRecordingFeatureAccess();
      _preferRaiAudioDescription =
          await _settings.preferRaiAudioDescription();
      if (widget.tvChannel == null) {
        unawaited(RadioService().addRecentRadio(widget.station));
        unawaited(RadioService().recordRadioBrowserClick(widget.station));
      }
      if (!mounted) return;
      setState(() {});
      if (widget.autoStartRecording) {
        unawaited(_playThenStartRecording());
      } else {
        _play();
      }
    });
  }

  Future<void> _playThenStartRecording() async {
    await _play();
    if (!mounted ||
        !widget.autoStartRecording ||
        !_isRecordingFeatureUnlocked ||
        _error != null ||
        _recording ||
        _anotherRecordingActive) {
      return;
    }
    await _toggleRecording();
  }

  void _onGlobalRecordingChanged() {
    if (mounted) setState(() {});
  }

  bool get _recording =>
      _recordingService.isRecordingFor(_recordingTarget.id);

  bool get _anotherRecordingActive =>
      _recordingService.hasAnyActiveRecording && !_recording;

  File? get _recordingOutput =>
      _recordingService.outputFor(_recordingTarget.id);

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

  Future<void> _play({bool reconnecting = false}) async {
    if (!mounted) return;
    final requestId = ++_playRequestId;
    await _androidLa7AudioPositionSubscription?.cancel();
    if (!mounted) return;
    _androidLa7AudioPositionSubscription = null;
    if (!reconnecting) {
      _androidLa7AutoRecoveryCount = 0;
      _androidLa7AutoRecoveryInProgress = false;
    }
    final l10n = AppLocalizations.of(context);
    _raiDirectAudioFallbackTimer?.cancel();
    _raiDirectAudioFallbackTimer = null;
    _raiNativeStallTimer?.cancel();
    _raiNativeStallTimer = null;
    _raiDirectAudioFallbackInProgress = false;
    _raiNormalAudioFallbackInProgress = false;
    _raiRecoverySourcePlayer = null;
    _streamDiagnostics?.close('new_playback_request');
    _streamDiagnostics = widget.tvChannel == null
        ? null
        : StreamDiagnosticsSession(
            channel: widget.station.name,
            videoEnabled: _isVideoEnabled,
            writeLog: (line) => unawaited(AppLogger.log(line)),
          );
    final diagnostics = _streamDiagnostics;
    _streamRecovery.begin(reconnecting: reconnecting);
    _streamUserPaused = false;
    _scheduleStreamConnectionNotice(requestId);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_useNativeRaiPlayback) {
        await _playRaiNative(
          requestId: requestId,
          diagnostics: diagnostics,
        );
        return;
      }

      if (_requiresRaiAudioDescriptionMediaKitPlayback) {
        await _playRaiMediaKitFallback(
          requestId: requestId,
          diagnostics: diagnostics,
        );
        return;
      }

      if (_useAndroidLa7BackgroundAudio) {
        await AppLogger.log(
          'RadioPlayer: Android La7 audio-only uses just_audio background/ExoPlayer',
        );
        diagnostics?.record('android_la7_background_audio', {
          'engine': 'just_audio_exoplayer',
          'screenOffResilient': true,
        });
        await _disposeMediaKitPlayer();
        if (!mounted || requestId != _playRequestId) return;
        _videoController?.pause();
        _videoController?.dispose();
        _videoController = null;
        final refreshedUrl = reconnecting && widget.tvChannel != null
            ? await TvService().resolveStreamUrl(
                widget.tvChannel!,
                diagnostics: diagnostics,
              )
            : widget.station.streamUrl;
        if (!mounted || requestId != _playRequestId) return;
        await _audio.setUrl(
          refreshedUrl,
          title: l10n.nowPlayingTitle(widget.station.name),
          headers: widget.tvChannel?.playbackHeaders,
        );
        if (!mounted || requestId != _playRequestId) return;
        var firstProgressLogged = false;
        _androidLa7AudioPositionSubscription =
            _audio.positionStream.listen((position) {
          if (!mounted || requestId != _playRequestId) return;
          if (position <= Duration.zero || !_audio.isPlaying) return;
          if (!firstProgressLogged) {
            firstProgressLogged = true;
            diagnostics?.record('first_playback_progress', {
              'stage': 'android_la7_background_audio',
              'positionMs': position.inMilliseconds,
            });
          }
          if (_streamRecovery.observe(
            position: position,
            playing: true,
            buffering: false,
          )) {
            _streamConnectionTimer?.cancel();
            if (_error != null) setState(() => _error = null);
          }
          if (_androidLa7AutoRecoveryCount > 0 &&
              position >= const Duration(seconds: 5)) {
            _androidLa7AutoRecoveryCount = 0;
          }
        });
        unawaited(_audio.play().then((_) {
          if (!mounted || requestId != _playRequestId || _streamUserPaused) {
            return;
          }
          diagnostics?.record('android_la7_background_audio_ended');
          unawaited(_recoverAndroidLa7BackgroundAudio(
            requestId,
            reason: 'playback_ended',
          ));
        }).catchError((error) {
          if (!mounted || requestId != _playRequestId || _streamUserPaused) {
            return;
          }
          AppLogger.log(
            'RadioPlayer: Android La7 background audio error: ${StreamDiagnosticsSession.redact(error.toString())}',
          );
          diagnostics?.record('android_la7_background_audio_error', {
            'category': StreamDiagnosticsSession.classifyError(error),
            'error': error.toString(),
          });
          unawaited(_recoverAndroidLa7BackgroundAudio(
            requestId,
            reason: 'playback_error',
          ));
        }));
        return;
      }

      // Tutti gli altri canali TV continuano a usare MediaKit su Android e
      // iOS. Solo i canali Rai con relinker Mediapolis prendono il percorso
      // AVPlayer nativo sopra, esclusivamente su iOS.
      if (_requiresTvMediaKitPlayback) {
        await AppLogger.log(
          'RadioPlayer: TV MediaKit playback selected '
          'station="${widget.station.name}" videoEnabled=$_isVideoEnabled',
        );
        final refreshedUrl = reconnecting && widget.tvChannel != null
            ? await TvService().resolveStreamUrl(widget.tvChannel!, diagnostics: diagnostics)
            : null;
        if (!mounted || requestId != _playRequestId) {
        return;
      }
        await _playMediaKitVideo(streamUrl: refreshedUrl, playRequestId: requestId);
        return;
      }

      if (_requiresVideoPlayback) {
        await _playMediaKitVideo(playRequestId: requestId);
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
          setState(() => _error = l10n.technicalErrorGeneric);
        }));
      }
    } catch (e) {
      if (!mounted || requestId != _playRequestId) {
        return;
      }
      if (_mediaKitIsMpd) {
        await _disableMpdWakelock();
      }
      if (!mounted || requestId != _playRequestId) {
        return;
      }
      AppLogger.log('RadioPlayer: Error during _play: ${StreamDiagnosticsSession.redact(e.toString())}');
      diagnostics?.record('play_request_error', {
        'category': StreamDiagnosticsSession.classifyError(e),
        'error': e.toString(),
      });
      if (widget.tvChannel != null) {
        if (_requiresRaiAudioDescriptionMediaKitPlayback && !_isVideoEnabled &&
            (_raiDirectAudioFallbackTimer?.isActive ?? false)) {
          _beginStreamReconnection(requestId);
        } else {
          _setStreamFailure(requestId);
        }
      } else {
        setState(() => _error = l10n.technicalErrorGeneric);
      }
    } finally {
      if (mounted && requestId == _playRequestId) {
        setState(() => _loading = false);
        AppLogger.log(
            'RadioPlayer: _play complete. loading=false, isVideo=${_videoController != null || _mediaKitPlayer != null || _raiNativeActive}');
      }
    }
  }

  Future<void> _playRaiNative({
    required int requestId,
    required StreamDiagnosticsSession? diagnostics,
  }) async {
    final channel = widget.tvChannel!;
    final generation = ++_raiNativeGeneration;
    final stageClock = Stopwatch()..start();

    if (_raiNativeActive) {
      _raiNativeActive = false;
      _raiNativePlaying = false;
      _raiNativeBuffering = false;
      await _raiNativePlayer.dispose();
    }

    final masterUrl = await TvService().resolveStreamUrl(
      channel,
      diagnostics: diagnostics,
    );
    if (!mounted || requestId != _playRequestId ||
        generation != _raiNativeGeneration) {
      return;
    }

    await _audio.stop();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    await _disposeMediaKitPlayer();
    if (!mounted || requestId != _playRequestId ||
        generation != _raiNativeGeneration) {
      return;
    }

    _mediaKitVolume = await _settings.loadMediaVolume();
    if (!mounted || requestId != _playRequestId ||
        generation != _raiNativeGeneration) {
      return;
    }

    final headers = <String, String>{
      'User-Agent': channel.playbackUserAgent,
      ...channel.playbackHeaders,
    };

    _raiNativeActive = true;
    _raiNativePlaying = false;
    _raiNativeBuffering = true;
    _raiNativeFallbackInProgress = false;
    _mediaKitPlaying = false;
    _mediaKitBuffering = true;
    _mediaKitCompleted = false;
    _mediaKitLastPosition = Duration.zero;
    _mediaKitLastDuration = Duration.zero;
    _mediaKitLastProgressAt = DateTime.now();
    _mediaKitPlaybackUrl = masterUrl;
    _mediaKitStage = 'native_avplayer';
    _mediaKitDiagnosticsSession = diagnostics;

    diagnostics?.record('native_avplayer_open_start', {
      'stage': _mediaKitStage,
      'url': StreamDiagnosticsSession.safeUrl(masterUrl),
      'videoEnabled': _isVideoEnabled,
      'preferAD': _preferRaiAudioDescription,
      'userAgent': headers['User-Agent'],
      'architecture': 'avfoundation_master_hls',
    });
    await AppLogger.log(
      'RadioPlayer: RAI iOS native AVPlayer selected '
      'master=${StreamDiagnosticsSession.safeUrl(masterUrl)} '
      'videoEnabled=$_isVideoEnabled preferAD=$_preferRaiAudioDescription',
    );

    if (Platform.isIOS) {
      await _mediaCommands.invokeMethod('setupMagicTap', widget.station.name);
    }
    if (!mounted || requestId != _playRequestId ||
        generation != _raiNativeGeneration) {
      return;
    }

    try {
      await _raiNativePlayer.open(
        url: masterUrl,
        headers: headers,
        preferAudioDescription: _preferRaiAudioDescription,
        videoEnabled: _isVideoEnabled,
        volume: _mediaKitVolume,
      );
    } catch (error) {
      if (!mounted || requestId != _playRequestId ||
          generation != _raiNativeGeneration) {
        return;
      }
      diagnostics?.record('native_avplayer_open_error', {
        'stage': _mediaKitStage,
        'error': error.toString(),
      });
      await AppLogger.log(
        'RadioPlayer: RAI AVPlayer open failed; using existing MediaKit fallback '
        'error=${StreamDiagnosticsSession.redact(error.toString())}',
      );
      await _activateRaiNativeFallback(reason: 'native_open_failed');
      return;
    }
    if (!mounted || requestId != _playRequestId ||
        generation != _raiNativeGeneration) {
      return;
    }

    diagnostics?.record('native_avplayer_open_returned', {
      'stage': _mediaKitStage,
      'stageMs': stageClock.elapsedMilliseconds,
      'note': 'open_returned_is_not_playback_confirmation',
    });
    setState(() {});
  }

  void _handleRaiNativePlayerEvent(dynamic rawEvent) {
    if (!mounted || rawEvent is! Map) {
      return;
    }
    final event = Map<String, dynamic>.from(rawEvent);
    final type = event['type']?.toString() ?? '';

    if (type == 'state') {
      if (!_raiNativeActive) {
        return;
      }
      final playing = event['playing'] == true;
      final buffering = event['buffering'] == true;
      final wasPlaying = _raiNativePlaying;
      _raiNativePlaying = playing;
      _raiNativeBuffering = buffering;
      // Reuse the existing generic stream telemetry fields so connection
      // notices, retry UI and diagnostics behave exactly like other TV paths.
      _mediaKitPlaying = playing;
      _mediaKitBuffering = buffering;
      final positionMs = (event['positionMs'] as num?)?.toInt() ?? 0;
      final durationMs = (event['durationMs'] as num?)?.toInt() ?? 0;
      _mediaKitLastPosition = Duration(milliseconds: positionMs);
      _mediaKitLastDuration = Duration(milliseconds: durationMs);
      if (Platform.isIOS && wasPlaying != playing) {
        unawaited(_mediaCommands.invokeMethod('setMagicTapPlaying', playing));
      }
      _streamDiagnostics?.record('native_avplayer_state', {
        'stage': _mediaKitStage,
        'playing': playing,
        'buffering': buffering,
        'reason': event['reason'],
        'positionMs': positionMs,
        'durationMs': durationMs,
      });
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (type == 'position') {
      if (!_raiNativeActive) {
        return;
      }
      final positionMs = (event['positionMs'] as num?)?.toInt() ?? 0;
      final durationMs = (event['durationMs'] as num?)?.toInt() ?? 0;
      final position = Duration(milliseconds: positionMs);
      final previous = _mediaKitLastPosition ?? Duration.zero;
      _mediaKitLastPosition = position;
      _mediaKitLastDuration = Duration(milliseconds: durationMs);
      if (position > previous) {
        _mediaKitLastProgressAt = DateTime.now();
        _raiNativeStallTimer?.cancel();
        _raiNativeStallTimer = null;
      }
      if (position > Duration.zero && _raiNativePlaying && !_raiNativeBuffering) {
        if (_streamRecovery.observe(
          position: position,
          playing: _raiNativePlaying,
          buffering: _raiNativeBuffering,
        )) {
          _streamConnectionTimer?.cancel();
          setState(() => _error = null);
          _streamDiagnostics?.record('first_playback_progress', {
            'stage': _mediaKitStage,
            'positionMs': positionMs,
            'engine': 'AVPlayer',
          });
        }
      }
      return;
    }

    if (type == 'audio_tracks') {
      if (!_raiNativeActive) {
        return;
      }
      unawaited(AppLogger.log(
        'RadioPlayer: RAI AVPlayer audio tracks '
        'preferAD=${event['preferAudioDescription']} '
        'selected=${event['selected']} locale=${event['selectedLocale']} '
        'selectedAD=${event['selectedIsAudioDescription']} '
        'tracks=${event['tracks']}',
      ));
      _streamDiagnostics?.record('native_avplayer_audio_selection', {
        'stage': _mediaKitStage,
        'preferAD': event['preferAudioDescription'],
        'selected': event['selected'],
        'selectedLocale': event['selectedLocale'],
        'selectedAD': event['selectedIsAudioDescription'],
      });
      return;
    }

    if (type == 'stalled') {
      if (!_raiNativeActive) {
        return;
      }
      final generation = _raiNativeGeneration;
      final stalledAt = _mediaKitLastPosition ?? Duration.zero;
      _streamDiagnostics?.record('native_avplayer_stalled', {
        'stage': _mediaKitStage,
        'positionMs': stalledAt.inMilliseconds,
      });
      unawaited(AppLogger.log(
        'RadioPlayer: RAI AVPlayer reported playback stalled '
        'position=$stalledAt buffering=$_raiNativeBuffering',
      ));
      _raiNativeStallTimer?.cancel();
      _raiNativeStallTimer = Timer(const Duration(seconds: 8), () {
        if (!mounted || !_raiNativeActive ||
            generation != _raiNativeGeneration ||
            (_mediaKitLastPosition ?? Duration.zero) > stalledAt) {
          return;
        }
        unawaited(_recoverRaiNative(reason: 'playback_stalled'));
      });
      return;
    }

    if (type == 'error') {
      if (!_raiNativeActive || _raiNativeFallbackInProgress) {
        return;
      }
      final message = event['message']?.toString() ?? 'AVPlayer error';
      _streamDiagnostics?.record('native_avplayer_error', {
        'stage': _mediaKitStage,
        'domain': event['domain'],
        'code': event['code'],
        'error': message,
      });
      unawaited(AppLogger.log(
        'RadioPlayer: RAI AVPlayer native error; trying MediaKit fallback '
        'error=${StreamDiagnosticsSession.redact(message)}',
      ));
      unawaited(_recoverRaiNative(reason: 'native_error'));
      return;
    }

    if (type == 'log') {
      unawaited(AppLogger.log(
        'RadioPlayer: RAI AVPlayer ${event['category']}: '
        '${StreamDiagnosticsSession.redact(event['message']?.toString() ?? '')}',
      ));
    }
  }

  Future<void> _recoverRaiNative({required String reason}) async {
    if (!mounted || !_raiNativeActive || _raiNativeFallbackInProgress) {
      return;
    }
    _raiNativeStallTimer?.cancel();
    _raiNativeStallTimer = null;
    if (_raiNativeRestartCount == 0) {
      _raiNativeRestartCount = 1;
      final requestId = _playRequestId;
      _beginStreamReconnection(requestId);
      _streamDiagnostics?.record('native_avplayer_restart', {
        'stage': _mediaKitStage,
        'reason': reason,
        'positionMs': _mediaKitLastPosition?.inMilliseconds,
      });
      await AppLogger.log(
        'RadioPlayer: RAI AVPlayer restarting once with a fresh Mediapolis URL '
        'reason=$reason station="${widget.station.name}"',
      );
      await _play(reconnecting: true);
      return;
    }
    await _activateRaiNativeFallback(reason: reason);
  }

  Future<void> _activateRaiNativeFallback({required String reason}) async {
    if (!mounted || !_raiNativeActive || _raiNativeFallbackInProgress ||
        !_requiresRaiAudioDescriptionMediaKitPlayback) {
      return;
    }
    final requestId = _playRequestId;
    _raiNativeStallTimer?.cancel();
    _raiNativeStallTimer = null;
    _raiNativeFallbackInProgress = true;
    ++_raiNativeGeneration;
    _beginStreamReconnection(requestId);
    _streamDiagnostics?.record('native_avplayer_fallback', {
      'stage': _mediaKitStage,
      'reason': reason,
      'positionMs': _mediaKitLastPosition?.inMilliseconds,
    });

    try {
      await AppLogger.log(
        'RadioPlayer: RAI AVPlayer fallback to existing MediaKit path '
        'reason=$reason station="${widget.station.name}"',
      );
      await _raiNativePlayer.dispose();
      _raiNativeActive = false;
      _raiNativePlaying = false;
      _raiNativeBuffering = false;
      if (!mounted || requestId != _playRequestId) {
        return;
      }
      await _playRaiMediaKitFallback(
        requestId: requestId,
        diagnostics: _streamDiagnostics,
      );
    } catch (error) {
      await AppLogger.log(
        'RadioPlayer: RAI MediaKit fallback after AVPlayer failed: '
        '${StreamDiagnosticsSession.redact(error.toString())}',
      );
      _setStreamFailure(requestId);
    } finally {
      if (requestId == _playRequestId) {
        _raiNativeFallbackInProgress = false;
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _playRaiMediaKitFallback({
    required int requestId,
    required StreamDiagnosticsSession? diagnostics,
  }) async {
    final tvChannel = widget.tvChannel!;
    final streams =
        await TvService().resolveAudioDescriptionStreams(
          tvChannel, diagnostics: diagnostics,
        );
    if (!mounted || requestId != _playRequestId) {
      return;
    }

    if (!_isVideoEnabled) {
      final selectedAudioUrl = !_preferRaiAudioDescription &&
              streams.hasAudioDescription
          ? streams.normalAudioUrl
          : streams.audioUrl;
      final selectedAudioIsDescription = _preferRaiAudioDescription &&
          streams.hasAudioDescription &&
          selectedAudioUrl == streams.audioUrl;
      final hasDedicatedAudio = selectedAudioUrl != streams.videoUrl;
      final normalAudioFallbackUrl = selectedAudioIsDescription &&
              streams.normalAudioUrl != streams.videoUrl &&
              streams.normalAudioUrl != selectedAudioUrl
          ? streams.normalAudioUrl
          : null;

      if (hasDedicatedAudio) {
        await AppLogger.log(
          'RadioPlayer: RAI direct audio selected because video is disabled '
          'preferAD=$_preferRaiAudioDescription selectedAD=$selectedAudioIsDescription '
          'url=${StreamDiagnosticsSession.safeUrl(selectedAudioUrl)} '
          'normalFallback=${normalAudioFallbackUrl == null ? 'none' : StreamDiagnosticsSession.safeUrl(normalAudioFallbackUrl)}',
        );
        await _playMediaKitVideo(
          streamUrl: selectedAudioUrl,
          preferRaiAudioDescription: false,
          enableRaiDirectAudioFallback: false,
          raiNormalAudioFallbackUrl: normalAudioFallbackUrl,
          playRequestId: requestId,
          diagnosticStage: selectedAudioIsDescription ? 'direct_ad' : 'direct_ita',
        );
        return;
      }

      // Se il resolver non riesce a estrarre una child audio dedicata,
      // conserviamo il master come compatibilità. In questo raro caso
      // resta attivo anche il recupero master -> audio diretto, così un
      // successivo relinker può ancora restituire AD/ITA utilizzabili.
      await AppLogger.log(
        'RadioPlayer: RAI direct audio unavailable; using master compatibility '
        'videoEnabled=false hasAD=${streams.hasAudioDescription}',
      );
      await _playMediaKitVideo(
        streamUrl: streams.videoUrl,
        selectRaiPreferredAudioTrack: true,
        preferRaiAudioDescription:
            _preferRaiAudioDescription && streams.hasAudioDescription,
        enableRaiDirectAudioFallback: true,
        playRequestId: requestId,
        diagnosticStage: 'master_compatibility',
      );
      return;
    }

    await AppLogger.log(
      'RadioPlayer: RAI MediaKit master playback selected '
      'videoEnabled=true hasAD=${streams.hasAudioDescription}',
    );
    await _playMediaKitVideo(
      streamUrl: streams.videoUrl,
      selectRaiPreferredAudioTrack: true,
      preferRaiAudioDescription:
          _preferRaiAudioDescription && streams.hasAudioDescription,
      enableRaiDirectAudioFallback: false,
      playRequestId: requestId,
      diagnosticStage: 'master_video',
    );
    return;
  }

  Future<void> _playMediaKitVideo({
    String? streamUrl,
    bool selectRaiPreferredAudioTrack = false,
    bool preferRaiAudioDescription = false,
    bool enableRaiDirectAudioFallback = false,
    String? raiNormalAudioFallbackUrl,
    int? playRequestId,
    String diagnosticStage = 'tv_stream',
  }) async {
    final requestId = playRequestId ?? _playRequestId;
    if (!mounted || requestId != _playRequestId) {
      return;
    }
    final openId = ++_mediaKitOpenId;
    final diagnostics = _streamDiagnostics;
    final stage = '$diagnosticStage#$openId';
    bool requestIsCurrent() => mounted && requestId == _playRequestId &&
        openId == _mediaKitOpenId;
    final playbackUrl = streamUrl ?? widget.station.streamUrl;
    final isMpd = TvService.isDashStreamUrl(playbackUrl);
    final mediaKitHeaders = _mediaKitHttpHeaders();
    await _audio.stop();
    if (!requestIsCurrent()) return;
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    await _disposeMediaKitPlayer();
    if (!requestIsCurrent()) return;
    _mediaKitIsMpd = isMpd;
    if (isMpd) {
      // AudioPlayerService.stop() disattiva il wakelock globale. Gli MPD live
      // vengono riaperti a ogni finestra DASH, quindi lo riattiviamo anche
      // durante i refresh per lasciare attivi timer e callback su iOS.
      await _enableMpdWakelock();
    } else {
      await _disableMpdWakelock();
    }

    if (!requestIsCurrent()) return;
    final player = mk.Player();
    _mediaKitPlayer = player;
    bool playerIsCurrent() => requestIsCurrent() && _mediaKitPlayer == player;
    if (Platform.isAndroid) {
      final platformPlayer = player.platform;
      if (platformPlayer is mk.NativePlayer) {
        try {
          await platformPlayer.setProperty(
            'ao',
            'audiotrack,opensles',
          );
          AppLogger.log(
            'RadioPlayer: Android MediaKit audio output prefers audiotrack with opensles fallback',
          );
        } catch (error) {
          AppLogger.log(
            'RadioPlayer: unable to set Android MediaKit audio output preference: $error',
          );
        }
      }
    }
    if (!playerIsCurrent()) return;
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
    if (!playerIsCurrent()) return;
    _mediaKitPlaybackUrl = playbackUrl;
    _mediaKitStage = stage;
    _mediaKitDiagnosticsSession = diagnostics;
    final stageClock = Stopwatch()..start();
    var firstProgressLogged = false;
    diagnostics?.record('player_open_start', {
      'stage': stage,
      'url': StreamDiagnosticsSession.safeUrl(playbackUrl),
      'videoEnabled': _isVideoEnabled,
      'userAgent': mediaKitHeaders['User-Agent'],
      'preferAD': preferRaiAudioDescription,
      'masterFallback': enableRaiDirectAudioFallback,
      'itaFallback': raiNormalAudioFallbackUrl != null,
    });
    _scheduleStreamConnectionNotice(requestId);
    var initialVolumeApplied = false;
    var postStartStabilizationScheduled = false;

    AppLogger.log(
      'RadioPlayer: MediaKit open start station="${widget.station.name}" url=${StreamDiagnosticsSession.safeUrl(playbackUrl)} videoEnabled=$_isVideoEnabled volume=$_mediaKitVolume preferRaiAD=$preferRaiAudioDescription',
    );

    _mediaKitPlayingSubscription = player.stream.playing.listen((playing) {
      if (!playerIsCurrent()) return;
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
      if (!playerIsCurrent()) return;
      AppLogger.log(
        'RadioPlayer: MediaKit error station="${widget.station.name}" error=${StreamDiagnosticsSession.redact(error)} position=$_mediaKitLastPosition duration=$_mediaKitLastDuration buffering=$_mediaKitBuffering playing=$_mediaKitPlaying',
      );
      diagnostics?.record('player_error', {
        'stage': stage,
        'stageMs': stageClock.elapsedMilliseconds,
        'category': StreamDiagnosticsSession.classifyError(error),
        'error': error,
        'positionMs': _mediaKitLastPosition?.inMilliseconds,
        'buffering': _mediaKitBuffering,
      });
      _probeCurrentStream('native_error');
      if (widget.tvChannel != null) {
        final recoveryPending = _requiresRaiAudioDescriptionMediaKitPlayback &&
            !_isVideoEnabled &&
            ((_raiDirectAudioFallbackTimer?.isActive ?? false) ||
                identical(_raiRecoverySourcePlayer, player));
        if (recoveryPending) {
          _beginStreamReconnection(requestId);
        } else {
          _setStreamFailure(requestId);
        }
      } else {
        setState(() => _error = AppLocalizations.of(context).technicalErrorGeneric);
      }
    });
    if (diagnostics != null) {
      _mediaKitLogSubscription = player.stream.log.listen((entry) {
        if (!playerIsCurrent()) return;
        diagnostics.nativeMessage(
          stage: stage, level: entry.level, prefix: entry.prefix, text: entry.text,
        );
      });
    }
    _mediaKitPositionSubscription = player.stream.position.listen((position) {
      if (!playerIsCurrent()) return;
      final previous = _mediaKitLastPosition;
      _mediaKitLastPosition = position;
      if (previous == null || position > previous) {
        _mediaKitLastProgressAt = DateTime.now();
      }
      if (position > Duration.zero && _mediaKitPlaying && !_mediaKitBuffering) {
        if (!firstProgressLogged) {
          firstProgressLogged = true;
          diagnostics?.record('first_playback_progress', {
            'stage': stage,
            'stageMs': stageClock.elapsedMilliseconds,
            'positionMs': position.inMilliseconds,
          });
        }
        if (_streamRecovery.observe(
          position: position, playing: _mediaKitPlaying, buffering: _mediaKitBuffering,
        )) {
          _streamConnectionTimer?.cancel();
          if (widget.tvChannel != null) setState(() => _error = null);
        }
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
      if (!playerIsCurrent()) return;
      _mediaKitLastDuration = duration;
      AppLogger.log(
        'RadioPlayer: MediaKit duration emitted duration=$duration station="${widget.station.name}"',
      );
    });
    _mediaKitBufferingSubscription =
        player.stream.buffering.listen((buffering) {
      if (!playerIsCurrent()) return;
      diagnostics?.record('buffering', {
        'stage': stage, 'value': buffering,
        'stageMs': stageClock.elapsedMilliseconds,
        'positionMs': _mediaKitLastPosition?.inMilliseconds,
      });
      _mediaKitBuffering = buffering;
      AppLogger.log(
        'RadioPlayer: MediaKit buffering emitted buffering=$buffering playing=$_mediaKitPlaying position=$_mediaKitLastPosition duration=$_mediaKitLastDuration',
      );
    });
    _mediaKitCompletedSubscription =
        player.stream.completed.listen((completed) {
      if (!playerIsCurrent()) return;
      _mediaKitCompleted = completed;
      AppLogger.log(
        'RadioPlayer: MediaKit completed emitted completed=$completed playing=$_mediaKitPlaying position=$_mediaKitLastPosition duration=$_mediaKitLastDuration buffering=$_mediaKitBuffering',
      );
    });
    _startMediaKitDiagnostics(player);

    if (selectRaiPreferredAudioTrack) {
      _mediaKitTracksSubscription = player.stream.tracks.listen((tracks) {
        unawaited(_selectMediaKitRaiPreferredAudioTrack(
          player,
          tracks,
          preferAudioDescription: preferRaiAudioDescription,
        ));
      });
      unawaited(_retrySelectMediaKitRaiPreferredAudioTrack(
        player,
        preferAudioDescription: preferRaiAudioDescription,
      ));
    }

    if (Platform.isIOS) {
      await _mediaCommands.invokeMethod(
        'setupMagicTap',
        widget.station.name,
      );
    }
    if (!playerIsCurrent()) return;
    if (enableRaiDirectAudioFallback) {
      _scheduleRaiDirectAudioFallback(player);
    } else if (raiNormalAudioFallbackUrl != null &&
        raiNormalAudioFallbackUrl.isNotEmpty &&
        raiNormalAudioFallbackUrl != playbackUrl) {
      _scheduleRaiNormalAudioFallback(
        player,
        raiNormalAudioFallbackUrl,
      );
    }
    try {
      await player.open(
        mk.Media(
          playbackUrl,
          httpHeaders: mediaKitHeaders,
        ),
      );
    } catch (error) {
      if (!playerIsCurrent()) {
        await AppLogger.log(
          'RadioPlayer: MediaKit open superseded by a newer playback request; ignoring stale error: ${StreamDiagnosticsSession.redact(error.toString())}',
        );
        return;
      }
      diagnostics?.record('player_open_exception', {
        'stage': stage, 'stageMs': stageClock.elapsedMilliseconds,
        'category': StreamDiagnosticsSession.classifyError(error),
        'error': error.toString(),
      });
      _probeCurrentStream('open_exception');
      rethrow;
    }
    if (!playerIsCurrent()) {
      await AppLogger.log(
        'RadioPlayer: MediaKit open completed after playback was superseded; ignoring stale completion',
      );
      return;
    }
    diagnostics?.record('player_open_returned', {
      'stage': stage, 'stageMs': stageClock.elapsedMilliseconds,
      'positionMs': _mediaKitLastPosition?.inMilliseconds,
      'buffering': _mediaKitBuffering,
      'note': 'open_returned_is_not_playback_confirmation',
    });
    if (mounted && !_mediaKitVideoSettingApplied) {
      _mediaKitVideoSettingApplied = true;
      await _applyMediaKitVideoEnabled(player, _isVideoEnabled);
    }
    AppLogger.log(
      'RadioPlayer: MediaKit open completed station="${widget.station.name}" playing=$_mediaKitPlaying buffering=$_mediaKitBuffering position=$_mediaKitLastPosition duration=$_mediaKitLastDuration preferRaiAD=$preferRaiAudioDescription',
    );
  }

  Future<void> _recoverAndroidLa7BackgroundAudio(
    int requestId, {
    required String reason,
  }) async {
    if (!mounted ||
        requestId != _playRequestId ||
        !_useAndroidLa7BackgroundAudio ||
        _streamUserPaused ||
        _androidLa7AutoRecoveryInProgress) {
      return;
    }
    if (_androidLa7AutoRecoveryCount >= 3) {
      _streamDiagnostics?.record('android_la7_auto_recovery_exhausted', {
        'reason': reason,
        'attempts': _androidLa7AutoRecoveryCount,
      });
      _setStreamFailure(requestId);
      return;
    }

    _androidLa7AutoRecoveryInProgress = true;
    final attempt = ++_androidLa7AutoRecoveryCount;
    final delay = switch (attempt) {
      1 => const Duration(seconds: 1),
      2 => const Duration(seconds: 3),
      _ => const Duration(seconds: 8),
    };
    _streamDiagnostics?.record('android_la7_auto_recovery', {
      'reason': reason,
      'attempt': attempt,
      'delayMs': delay.inMilliseconds,
    });
    _beginStreamReconnection(requestId);
    try {
      await Future.delayed(delay);
      if (!mounted || requestId != _playRequestId || _streamUserPaused) return;
      await _play(reconnecting: true);
    } finally {
      _androidLa7AutoRecoveryInProgress = false;
    }
  }

  Future<void> _retryStreamPlayback() async {
    if (!mounted || _streamRetryInProgress || widget.tvChannel == null) return;
    _streamDiagnostics?.record('manual_retry');
    _raiNativeRestartCount = 0;
    setState(() => _streamRetryInProgress = true);
    announceStatusMessage(context, AppLocalizations.of(context).streamReconnecting);
    try {
      // _play resolves the RAI relinker again; no expired stream is reused.
      // Request tokens invalidate all callbacks belonging to the old attempt.
      await _play(reconnecting: true);
    } finally {
      if (mounted) setState(() => _streamRetryInProgress = false);
    }
  }

  void _beginStreamReconnection(int requestId) {
    if (!mounted || requestId != _playRequestId) {
      return;
    }
    final announce = !_streamRecovery.isReconnecting;
    setState(() {
      _streamRecovery.reconnect();
      _error = null;
    });
    _streamDiagnostics?.record('reconnecting', {'stage': _mediaKitStage});
    _scheduleStreamConnectionNotice(requestId);
    if (announce) {
      announceStatusMessage(context, AppLocalizations.of(context).streamReconnecting);
    }
  }

  void _setStreamFailure(int requestId) {
    if (!mounted || requestId != _playRequestId) {
      return;
    }
    final message = AppLocalizations.of(context).streamPlaybackRetryMessage;
    final announce = _error != message;
    _streamConnectionTimer?.cancel();
    setState(() {
      _streamRecovery.fail();
      _error = message;
      _loading = false;
    });
    if (announce) announceStatusMessage(context, message);
  }

  void _scheduleStreamConnectionNotice(int requestId) {
    _streamConnectionTimer?.cancel();
    if (widget.tvChannel == null) return;
    // UI deadline only: no new retries, timeouts or stops in native playback.
    _streamConnectionTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted ||
          requestId != _playRequestId ||
          _streamRecovery.hasProgress ||
          _streamUserPaused) {
        return;
      }
      // Some live streams expose buffered media before their position clock.
      // Do not turn that into a spurious startup error on a working channel.
      if ((_mediaKitLastDuration ?? Duration.zero) > Duration.zero &&
          _mediaKitPlaying &&
          !_mediaKitBuffering) {
        return;
      }
      _streamDiagnostics?.record('startup_wait_exceeded', {
        'stage': _mediaKitStage,
        'playerPresent': _mediaKitPlayer != null || _raiNativeActive,
        'nativeEngine': _raiNativeActive ? 'AVPlayer' : 'MediaKit',
        'nativeDisposePending': _mediaKitDisposeInFlight != null,
        'positionMs': _mediaKitLastPosition?.inMilliseconds,
        'buffering': _mediaKitBuffering,
      });
      _probeCurrentStream('startup_wait_exceeded');
      if (_raiNativeActive && !_raiNativeFallbackInProgress) {
        unawaited(_recoverRaiNative(reason: 'startup_wait_exceeded'));
        return;
      }
      _setStreamFailure(requestId);
    });
  }

  void _probeCurrentStream(String reason) {
    final url = _mediaKitPlaybackUrl;
    final diagnostics = _mediaKitDiagnosticsSession;
    if (url == null ||
        diagnostics == null ||
        diagnostics != _streamDiagnostics) {
      return;
    }
    unawaited(diagnostics.probeFailure(
      url: url,
      stage: _mediaKitStage,
      reason: reason,
      headers: _mediaKitHttpHeaders(),
    ));
  }

  void _scheduleRaiDirectAudioFallback(mk.Player player) {
    final requestId = _playRequestId;
    _raiDirectAudioFallbackTimer?.cancel();
    _raiDirectAudioFallbackTimer = Timer(const Duration(seconds: 6), () {
      _raiDirectAudioFallbackTimer = null;
      if (!mounted || requestId != _playRequestId ||
          _mediaKitPlayer != player ||
          _raiDirectAudioFallbackInProgress ||
          _isVideoEnabled) {
        return;
      }

      final position = _mediaKitLastPosition ?? Duration.zero;
      final duration = _mediaKitLastDuration ?? Duration.zero;
      if (position > Duration.zero || duration > Duration.zero) {
        unawaited(AppLogger.log(
          'RadioPlayer: RAI direct-audio fallback not needed after 6s; primary playback has progress position=$position duration=$duration',
        ));
        return;
      }

      unawaited(_activateRaiDirectAudioFallback(player));
    });
  }

  Future<void> _activateRaiDirectAudioFallback(mk.Player stalledPlayer) async {
    if (!mounted ||
        _mediaKitPlayer != stalledPlayer ||
        _raiDirectAudioFallbackInProgress ||
        _isVideoEnabled) {
      return;
    }

    final requestId = _playRequestId;
    final diagnostics = _streamDiagnostics;
    _raiDirectAudioFallbackInProgress = true;
    _raiRecoverySourcePlayer = stalledPlayer;
    _beginStreamReconnection(requestId);
    _probeCurrentStream('master_startup_stalled');
    try {
      await AppLogger.log(
        'RadioPlayer: RAI primary MediaKit playback stalled for 6s; resolving a fresh direct-audio fallback station="${widget.station.name}" position=$_mediaKitLastPosition duration=$_mediaKitLastDuration buffering=$_mediaKitBuffering playing=$_mediaKitPlaying',
      );

      final channel = widget.tvChannel;
      if (channel == null || !mounted || requestId != _playRequestId) return;
      final streams = await TvService().resolveAudioDescriptionStreams(
        channel, diagnostics: diagnostics,
      );

      if (!mounted || requestId != _playRequestId ||
          _mediaKitPlayer != stalledPlayer ||
          _isVideoEnabled) {
        return;
      }

      // Il relinker può impiegare qualche istante. Se nel frattempo il master
      // originale ha iniziato davvero a riprodurre, non lo interrompiamo.
      final position = _mediaKitLastPosition ?? Duration.zero;
      final duration = _mediaKitLastDuration ?? Duration.zero;
      if (position > Duration.zero || duration > Duration.zero) {
        await AppLogger.log(
          'RadioPlayer: RAI primary playback recovered while resolving fallback; keeping current stream position=$position duration=$duration',
        );
        return;
      }

      final selectedAudioUrl = !_preferRaiAudioDescription &&
              streams.hasAudioDescription
          ? streams.normalAudioUrl
          : streams.audioUrl;
      final selectedAudioIsDescription = _preferRaiAudioDescription &&
          streams.hasAudioDescription &&
          selectedAudioUrl == streams.audioUrl;
      final normalAudioFallbackUrl = selectedAudioIsDescription &&
              streams.normalAudioUrl != streams.videoUrl &&
              streams.normalAudioUrl != selectedAudioUrl
          ? streams.normalAudioUrl
          : null;

      await _stopStalledRaiMediaKitPlayer(
        stalledPlayer,
        stage: 'master',
      );
      if (!mounted || requestId != _playRequestId ||
          _mediaKitPlayer != stalledPlayer || _isVideoEnabled) {
        return;
      }

      await AppLogger.log(
        'RadioPlayer: RAI direct-audio fallback starting with fresh relinker URL '
        'preferAD=$_preferRaiAudioDescription selectedAD=$selectedAudioIsDescription '
        'url=${StreamDiagnosticsSession.safeUrl(selectedAudioUrl)} '
        'normalFallback=${normalAudioFallbackUrl == null ? 'none' : StreamDiagnosticsSession.safeUrl(normalAudioFallbackUrl)}',
      );
      await _playMediaKitVideo(
        streamUrl: selectedAudioUrl,
        preferRaiAudioDescription: false,
        enableRaiDirectAudioFallback: false,
        raiNormalAudioFallbackUrl: normalAudioFallbackUrl,
        playRequestId: requestId,
        diagnosticStage: 'compatibility_recovery',
      );
    } catch (error) {
      await AppLogger.log(
        'RadioPlayer: RAI direct-audio fallback failed: ${StreamDiagnosticsSession.redact(error.toString())}',
      );
      _setStreamFailure(requestId);
    } finally {
      if (requestId == _playRequestId) _raiDirectAudioFallbackInProgress = false;
      if (identical(_raiRecoverySourcePlayer, stalledPlayer)) {
        _raiRecoverySourcePlayer = null;
      }
    }
  }

  void _scheduleRaiNormalAudioFallback(
    mk.Player player,
    String normalAudioUrl,
  ) {
    final requestId = _playRequestId;
    _raiDirectAudioFallbackTimer?.cancel();
    _raiDirectAudioFallbackTimer = Timer(const Duration(seconds: 6), () {
      _raiDirectAudioFallbackTimer = null;
      if (!mounted || requestId != _playRequestId ||
          _mediaKitPlayer != player ||
          _raiNormalAudioFallbackInProgress ||
          _isVideoEnabled) {
        return;
      }

      final position = _mediaKitLastPosition ?? Duration.zero;
      final duration = _mediaKitLastDuration ?? Duration.zero;
      if (position > Duration.zero || duration > Duration.zero) {
        unawaited(AppLogger.log(
          'RadioPlayer: RAI direct AD fallback not needed after 6s; direct AD has progress position=$position duration=$duration',
        ));
        return;
      }

      unawaited(_activateRaiNormalAudioFallback(player, normalAudioUrl));
    });
  }

  Future<void> _activateRaiNormalAudioFallback(
    mk.Player stalledPlayer,
    String normalAudioUrl,
  ) async {
    if (!mounted ||
        _mediaKitPlayer != stalledPlayer ||
        _raiNormalAudioFallbackInProgress ||
        _isVideoEnabled) {
      return;
    }

    final position = _mediaKitLastPosition ?? Duration.zero;
    final duration = _mediaKitLastDuration ?? Duration.zero;
    if (position > Duration.zero || duration > Duration.zero) {
      await AppLogger.log(
        'RadioPlayer: RAI direct AD recovered before ITA fallback; keeping current stream position=$position duration=$duration',
      );
      return;
    }

    final requestId = _playRequestId;
    _raiNormalAudioFallbackInProgress = true;
    _raiRecoverySourcePlayer = stalledPlayer;
    _beginStreamReconnection(requestId);
    _probeCurrentStream('direct_ad_startup_stalled');
    try {
      await AppLogger.log(
        'RadioPlayer: RAI direct AD stalled for 6s; falling back to direct ITA station="${widget.station.name}" url=${StreamDiagnosticsSession.safeUrl(normalAudioUrl)}',
      );
      await _stopStalledRaiMediaKitPlayer(
        stalledPlayer,
        stage: 'direct AD',
      );
      if (!mounted || requestId != _playRequestId ||
          _mediaKitPlayer != stalledPlayer || _isVideoEnabled) {
        return;
      }
      await _playMediaKitVideo(
        streamUrl: normalAudioUrl,
        preferRaiAudioDescription: false,
        enableRaiDirectAudioFallback: false,
        playRequestId: requestId,
        diagnosticStage: 'direct_ita_fallback',
      );
    } catch (error) {
      await AppLogger.log(
        'RadioPlayer: RAI direct ITA fallback failed: ${StreamDiagnosticsSession.redact(error.toString())}',
      );
      _setStreamFailure(requestId);
    } finally {
      if (requestId == _playRequestId) _raiNormalAudioFallbackInProgress = false;
      if (identical(_raiRecoverySourcePlayer, stalledPlayer)) {
        _raiRecoverySourcePlayer = null;
      }
    }
  }

  Future<void> _stopStalledRaiMediaKitPlayer(
    mk.Player player, {
    required String stage,
  }) async {
    if (_mediaKitPlayer != player) return;
    final diagnostics = _mediaKitDiagnosticsSession;
    final clock = Stopwatch()..start();
    diagnostics?.record('native_stop_start', {'stage': stage});
    try {
      await AppLogger.log(
        'RadioPlayer: RAI stalled playback stop before dispose stage=$stage',
      );
      await player.stop().timeout(const Duration(seconds: 2));
      diagnostics?.record('native_stop_end', {
        'stage': stage, 'elapsedMs': clock.elapsedMilliseconds,
      });
      await AppLogger.log(
        'RadioPlayer: RAI stalled playback stop completed stage=$stage',
      );
    } on TimeoutException {
      diagnostics?.record('native_stop_wait_timeout', {
        'stage': stage, 'elapsedMs': clock.elapsedMilliseconds,
        'note': 'native_operation_may_still_be_pending',
      });
      await AppLogger.log(
        'RadioPlayer: RAI stalled playback stop timed out after 2s stage=$stage; continuing with normal dispose',
      );
    } catch (error) {
      await AppLogger.log(
        'RadioPlayer: RAI stalled playback stop failed stage=$stage error=${StreamDiagnosticsSession.redact(error.toString())}; continuing with normal dispose',
      );
    }
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

  Future<void> _retrySelectMediaKitRaiPreferredAudioTrack(
    mk.Player player, {
    required bool preferAudioDescription,
  }) async {
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
        await _selectMediaKitRaiPreferredAudioTrack(
          player,
          tracks,
          preferAudioDescription: preferAudioDescription,
        );
      } catch (error) {
        AppLogger.log(
          'RadioPlayer: RAI preferred audio track retry not ready yet: $error',
        );
      }
    }
  }

  Future<void> _selectMediaKitRaiPreferredAudioTrack(
    mk.Player player,
    dynamic tracks, {
    required bool preferAudioDescription,
  }) async {
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

        if (describedTrack == null &&
            (language == 'des' ||
                title.contains('audiodescri') ||
                title.contains('audio descri'))) {
          describedTrack = track;
        }
        if (italianTrack == null &&
            (language == 'ita' ||
                language == 'it' ||
                title.contains('italiano'))) {
          italianTrack = track;
        }
      }

      final selectedTrack = preferAudioDescription
          ? (describedTrack ?? italianTrack)
          : italianTrack;
      if (selectedTrack == null) return;

      await player.setAudioTrack(selectedTrack);
      _mediaKitRaiAudioTrackApplied = true;
      await AppLogger.log(
        'RadioPlayer: MediaKit selected RAI preferred audio track preferAD=$preferAudioDescription '
        'id=${_mediaKitTrackField(selectedTrack, 'id')} '
        'language=${_mediaKitTrackField(selectedTrack, 'language')} '
        'title=${_mediaKitTrackField(selectedTrack, 'title')}',
      );
    } catch (error) {
      AppLogger.log(
        'RadioPlayer: failed to select RAI preferred audio track: $error',
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
      if (!_streamUserPaused && lastProgress != null &&
          (_mediaKitBuffering ||
              (_mediaKitLastDuration ?? Duration.zero) == Duration.zero) &&
          DateTime.now().difference(lastProgress) >= const Duration(seconds: 10)) {
        _probeCurrentStream('playback_stalled');
      }
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
    if (_raiNativeActive) {
      _streamUserPaused = true;
      _streamDiagnostics?.record('user_pause', {'stage': _mediaKitStage});
      await _raiNativePlayer.pause();
      return;
    }
    if (_mediaKitPlayer != null) {
      await _mediaKitPlayer!.pause();
      if (_mediaKitIsMpd) {
        await _disableMpdWakelock();
      }
      if (mounted) {
        setState(() {});
      }
    } else if (_videoController != null) {
      await _videoController!.pause();
      setState(() {});
    } else {
      if (_useAndroidLa7BackgroundAudio) {
        _streamUserPaused = true;
        _streamDiagnostics?.record('user_pause', {
          'stage': 'android_la7_background_audio',
        });
      }
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

    if (Platform.isAndroid &&
        widget.tvChannel != null &&
        widget.tvChannel!.name.trim().toLowerCase() == 'la7' &&
        !enable) {
      // Audio-only La7 on Android is intentionally handed back to
      // just_audio/ExoPlayer so the foreground media service keeps the live
      // stream alive when the screen is locked.
      await _play();
      return;
    }

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
    if (_raiNativeActive) {
      unawaited(_raiNativePlayer.setVolume(clamped).catchError((error) {
        AppLogger.log('RadioPlayer: failed to set RAI AVPlayer volume: $error');
      }));
    }
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
    if (_raiNativeActive) {
      if (_raiNativePlaying) {
        _streamUserPaused = true;
        _streamDiagnostics?.record('user_pause', {'stage': _mediaKitStage});
        await _raiNativePlayer.pause();
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod('setMagicTapPlaying', false);
        }
      } else {
        _streamUserPaused = false;
        _streamDiagnostics?.record('user_play', {'stage': _mediaKitStage});
        if (!_streamRecovery.hasProgress) {
          _scheduleStreamConnectionNotice(_playRequestId);
        }
        await _raiNativePlayer.play();
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod('setMagicTapPlaying', true);
        }
      }
      return;
    }

    final mediaKitPlayer = _mediaKitPlayer;
    if (mediaKitPlayer != null) {
      if (_mediaKitPlaying) {
        _streamUserPaused = true;
        _streamDiagnostics?.record('user_pause', {'stage': _mediaKitStage});
        await mediaKitPlayer.pause();
        if (_mediaKitIsMpd) {
          await _disableMpdWakelock();
        }
      } else {
        if (_mediaKitIsMpd) {
          await _enableMpdWakelock();
        }
        try {
          _streamUserPaused = false;
          _streamDiagnostics?.record('user_play', {'stage': _mediaKitStage});
          if (!_streamRecovery.hasProgress) {
            _scheduleStreamConnectionNotice(_playRequestId);
          }
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
    _streamDiagnostics?.record('video_mode_change', {
      'stage': _mediaKitStage, 'enabled': enable,
      'positionMs': _mediaKitLastPosition?.inMilliseconds,
    });
    AppLogger.log(
      'RadioPlayer: enable video switch changed enable=$enable requiresVideoPlayback=$_requiresVideoPlayback requiresRaiADMediaKit=$_requiresRaiAudioDescriptionMediaKitPlayback position=$_mediaKitLastPosition duration=$_mediaKitLastDuration buffering=$_mediaKitBuffering playing=$_mediaKitPlaying',
    );
    setState(() => _isVideoEnabled = enable);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isVideoEnabled != enable) return;
      if (_raiNativeActive) {
        unawaited(_settings.setVideoEnabled(enable));
        unawaited(_raiNativePlayer.setVideoEnabled(enable));
        setState(() {});
      } else if (_requiresVideoPlayback) {
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
        return;
      }
      if (_anotherRecordingActive) {
        return;
      }
      await _startRecordingNow();
    } catch (error) {
      if (!mounted) return;
      showStatusMessage(
        context,
        AppLocalizations.of(context).recordingError(AppLocalizations.of(context).technicalErrorGeneric),
      );
    }
  }

  Future<File?> _stopRecordingNow({bool showMessage = true}) async {
    final l10n = AppLocalizations.of(context);
    final file = await _recordingService.stopActive();
    if (!mounted) return file;
    if (showMessage) {
      showStatusMessage(
        context,
        l10n.recordingSaved(
          file == null ? '' : p.basenameWithoutExtension(file.path),
        ),
      );
    }
    return file;
  }

  Future<File> _startRecordingNow({
    String? titleOverride,
    bool showMessage = true,
  }) async {
    final l10n = AppLocalizations.of(context);
    final file = await _recordingService.startNow(
      _recordingTarget,
      titleOverride: titleOverride,
    );
    if (!mounted) return file;
    if (showMessage) {
      showStatusMessage(context, l10n.recordingStarted);
    }
    return file;
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
            final l10n = AppLocalizations.of(context);
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
                    visibleLabel: l10n.radioScheduleHours,
                    semanticsLabel: l10n.radioScheduleSelectHours,
                    value: selectedHour,
                    min: 0,
                    max: 23,
                    increasedValue: nextHour,
                    decreasedValue: previousHour,
                    onChanged: setHour,
                  ),
                  const SizedBox(height: 16),
                  buildValueSlider(
                    visibleLabel: l10n.radioScheduleMinutes,
                    semanticsLabel: l10n.radioScheduleSelectMinutes,
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
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    TimeOfDay(hour: selectedHour, minute: selectedMinute),
                  ),
                  child: Text(l10n.ok),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showScheduleRecordingDialog() async {
    final l10n = AppLocalizations.of(context);
    if (_recordingService.hasAnyActiveRecording) {
      showStatusMessage(
        context,
        l10n.radioScheduleStopCurrentFirst,
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
                  title: l10n.radioScheduleStartTime,
                );
                if (picked != null) {
                  setDialogState(() => startTime = picked);
                }
              }

              Future<void> pickEnd() async {
                final picked = await _showScheduledRecordingTimePicker(
                  context: context,
                  initialTime: endTime,
                  title: l10n.radioScheduleEndTime,
                );
                if (picked != null) {
                  setDialogState(() => endTime = picked);
                }
              }

              return AlertDialog(
                title: Text(l10n.radioScheduleDialogTitle),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 360,
                  child: useSharedAccessibleViewModel
                      ? UniversalAccessibleList(
                          sections: [AccessibleListSection(rows: [
                            AccessibleListRow(
                              id: 'info',
                              kind: 'text',
                              title: l10n.radioScheduleOpenRequirement,
                            ),
                            AccessibleListRow(
                              id: 'start',
                              title: l10n.radioScheduleStartTimeValue(_formatTimeOfDay(startTime)),
                            ),
                            AccessibleListRow(
                              id: 'end',
                              title: l10n.radioScheduleEndTimeValue(_formatTimeOfDay(endTime)),
                            ),
                            AccessibleListRow(
                              id: 'title',
                              kind: 'textField',
                              title: l10n.radioScheduleOptionalTitle,
                              placeholder: l10n.radioScheduleTitleHint,
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
                              Text(l10n.radioScheduleOpenRequirement),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: pickStart,
                                icon: const Icon(Icons.schedule),
                                label: Text(l10n.radioScheduleStartTimeValue(_formatTimeOfDay(startTime))),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: pickEnd,
                                icon: const Icon(Icons.schedule),
                                label: Text(l10n.radioScheduleEndTimeValue(_formatTimeOfDay(endTime))),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: titleController,
                                decoration: InputDecoration(
                                  labelText: l10n.radioScheduleOptionalTitle,
                                  hintText: l10n.radioScheduleTitleHint,
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
                    child: Text(l10n.cancel),
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
                    child: Text(l10n.radioScheduleAction),
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
    final l10n = AppLocalizations.of(context);
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

    final title = request.title.trim().isEmpty ? null : request.title.trim();
    try {
      _recordingService.schedule(
        target: _recordingTarget,
        start: start,
        end: end,
        title: title,
      );
    } catch (error) {
      showStatusMessage(context, l10n.radioScheduledRecordingError(l10n.technicalErrorGeneric));
      return;
    }
    showStatusMessage(
      context,
      l10n.radioScheduledRecordingRange(
        _formatScheduledDateTime(start),
        _formatScheduledDateTime(end),
      ),
    );
  }

  void _cancelScheduledRecording({bool showMessage = true}) {
    final cancelled =
        _recordingService.cancelSchedule(targetId: _recordingTarget.id);
    if (showMessage && cancelled && mounted) {
      showStatusMessage(
        context,
        AppLocalizations.of(context).radioScheduledRecordingCancelled,
      );
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
    final start =
        _recordingService.scheduledStartFor(_recordingTarget.id);
    final end = _recordingService.scheduledEndFor(_recordingTarget.id);
    if (start == null || end == null) return null;
    final l10n = AppLocalizations.of(context);
    final startText = _formatScheduledDateTime(start);
    final endText = _formatScheduledDateTime(end);
    final title =
        _recordingService.scheduledTitleFor(_recordingTarget.id);
    if (title == null || title.isEmpty) {
      return l10n.radioScheduledRecordingRange(startText, endText);
    }
    return l10n.radioScheduledRecordingRangeWithTitle(
      startText,
      endText,
      title,
    );
  }

  bool get _hasPendingScheduledRecording =>
      _recordingService.hasPendingScheduleFor(_recordingTarget.id);

  bool get _useNativeRaiPlayback =>
      Platform.isIOS && _requiresRaiAudioDescriptionMediaKitPlayback;

  bool get _requiresRaiAudioDescriptionMediaKitPlayback =>
      widget.isVideoSupported &&
      widget.tvChannel != null &&
      TvService().isRaiAudioDescriptionChannel(widget.tvChannel!);

  bool get _requiresTvMediaKitPlayback =>
      widget.isVideoSupported && widget.tvChannel != null;

  bool get _useAndroidLa7BackgroundAudio =>
      Platform.isAndroid &&
      widget.tvChannel != null &&
      widget.tvChannel!.name.trim().toLowerCase() == 'la7' &&
      !_isVideoEnabled;

  bool get _requiresVideoPlayback =>
      widget.isVideoSupported &&
      TvService.isDashStreamUrl(widget.station.streamUrl);

  bool get _isVideoPlaying => _raiNativeActive
      ? _raiNativePlaying
      : (_mediaKitPlayer != null
          ? _mediaKitPlaying
          : (_videoController?.value.isPlaying ?? false));

  bool get _canRecordStream => _isRecordingFeatureUnlocked;

  bool get _useLandscapeFullscreenVideo =>
      _displayVideoInPortrait &&
      _isVideoEnabled &&
      ((_videoController != null && _videoController!.value.isInitialized) ||
          _mediaKitController != null ||
          _raiNativeActive);

  void _syncLandscapeFullscreenOrientation() {
    final enable = _useLandscapeFullscreenVideo;
    if (_landscapeFullscreenApplied == enable) return;
    _landscapeFullscreenApplied = enable;
    unawaited(AppLogger.log(
      'RadioPlayer: fullscreen orientation change enable=$enable '
      'setting=$_displayVideoInPortrait videoEnabled=$_isVideoEnabled '
      'mediaKitController=${_mediaKitController != null} '
      'videoPlayerInitialized=${_videoController?.value.isInitialized ?? false}',
    ));
    if (!enable) {
      _lastFullscreenVideoSurfaceSize = null;
      _lastFullscreenVideoSurfaceEngine = null;
    }
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

  Future<void> _requestPlayerExit() async {
    if (!mounted || _recordingExitPromptOpen) return;
    if (!_recording) {
      Navigator.of(context).pop();
      return;
    }

    _recordingExitPromptOpen = true;
    final l10n = AppLocalizations.of(context);
    try {
      final stopRecording = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.recordingInProgressStatus),
            content: Text(l10n.recordingExitPrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.stopRecording),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.continueRecording),
              ),
            ],
          ),
        ),
      );

      if (!mounted || stopRecording == null) return;
      if (stopRecording) {
        try {
          await _stopRecordingNow(showMessage: false);
        } catch (error) {
          if (!mounted) return;
          showStatusMessage(
            context,
            l10n.recordingError(l10n.technicalErrorGeneric),
          );
          return;
        }
      }

      if (!mounted) return;
      setState(() => _allowExitWithActiveRecording = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop();
    } finally {
      _recordingExitPromptOpen = false;
    }
  }

  Widget _withRecordingExitGuard(Widget child) {
    return PopScope<void>(
      canPop: !_recording || _allowExitWithActiveRecording,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _allowExitWithActiveRecording) return;
        unawaited(_requestPlayerExit());
      },
      child: child,
    );
  }

  @override
  void dispose() {
    ++_playRequestId;
    ++_mediaKitOpenId;
    _streamConnectionTimer?.cancel();
    _streamDiagnostics?.close();
    _raiDirectAudioFallbackTimer?.cancel();
    _raiDirectAudioFallbackTimer = null;
    _raiNativeStallTimer?.cancel();
    _raiNativeStallTimer = null;
    _recordingService.removeListener(_onGlobalRecordingChanged);
    FocusManager.instance.primaryFocus?.unfocus();
    if (Platform.isIOS &&
        (_videoController != null || _mediaKitPlayer != null || _raiNativeActive)) {
      unawaited(_mediaCommands.invokeMethod('clearMagicTap'));
    }
    _restoreSystemOrientation();
    unawaited(_mediaEventsSubscription?.cancel() ?? Future<void>.value());
    unawaited(_raiNativeEventsSubscription?.cancel() ?? Future<void>.value());
    unawaited(
        _androidLa7AudioPositionSubscription?.cancel() ?? Future<void>.value());
    _androidLa7AudioPositionSubscription = null;
    unawaited(_raiNativePlayer.dispose());
    unawaited(_disableMpdWakelock());
    unawaited(_disposeMediaKitPlayer());
    _videoController?.dispose();
    unawaited(_audio.stopAndDispose());
    super.dispose();
  }

  Future<void> _disposeMediaKitPlayer() {
    final pending = _mediaKitDisposeInFlight;
    if (pending != null) return pending;
    final future = _disposeMediaKitPlayerInternal();
    _mediaKitDisposeInFlight = future;
    return future.whenComplete(() {
      if (identical(_mediaKitDisposeInFlight, future)) {
        _mediaKitDisposeInFlight = null;
      }
    });
  }

  Future<void> _disposeMediaKitPlayerInternal() async {
    final diagnostics = _streamDiagnostics ?? _mediaKitDiagnosticsSession;
    final previousAttempt = _mediaKitDiagnosticsSession?.id;
    final stage = _mediaKitStage;
    final clock = Stopwatch()..start();
    _raiDirectAudioFallbackTimer?.cancel();
    _raiDirectAudioFallbackTimer = null;
    _mediaKitDiagnosticsTimer?.cancel();
    _mediaKitDiagnosticsTimer = null;
    await _mediaKitPlayingSubscription?.cancel();
    await _mediaKitErrorSubscription?.cancel();
    await _mediaKitPositionSubscription?.cancel();
    await _mediaKitDurationSubscription?.cancel();
    await _mediaKitTracksSubscription?.cancel();
    await _mediaKitBufferingSubscription?.cancel();
    await _mediaKitCompletedSubscription?.cancel();
    await _mediaKitLogSubscription?.cancel();
    _mediaKitLogSubscription = null;
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
    diagnostics?.record('native_dispose_start', {
      'stage': stage,
      'playerPresent': player != null,
      'previousAttempt': previousAttempt,
      'positionMs': _mediaKitLastPosition?.inMilliseconds,
      'buffering': _mediaKitBuffering,
    });
    _mediaKitPlayer = null;
    if (identical(_raiRecoverySourcePlayer, player)) _raiRecoverySourcePlayer = null;
    _mediaKitPlaybackUrl = null;
    _mediaKitDiagnosticsSession = null;
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
      diagnostics?.record('native_dispose_end', {
        'stage': stage, 'elapsedMs': clock.elapsedMilliseconds,
      });
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

  Widget _buildRaiNativeVideoSurface() {
    return const AspectRatio(
      aspectRatio: 16 / 9,
      child: RaiNativeVideoView(),
    );
  }

  Widget _buildFullscreenVideoSurface({
    required Widget child,
    required double aspectRatio,
    required String engine,
  }) {
    final safeAspect = aspectRatio > 0 && aspectRatio.isFinite
        ? aspectRatio
        : 16 / 9;
    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mediaSize = MediaQuery.sizeOf(context);
            final maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : mediaSize.width;
            final maxHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : mediaSize.height;

            var width = maxWidth;
            var height = width / safeAspect;
            if (height < maxHeight) {
              height = maxHeight;
              width = height * safeAspect;
            }

            final surfaceSize = Size(width, height);
            if (_lastFullscreenVideoSurfaceEngine != engine ||
                _lastFullscreenVideoSurfaceSize != surfaceSize) {
              _lastFullscreenVideoSurfaceEngine = engine;
              _lastFullscreenVideoSurfaceSize = surfaceSize;
              unawaited(AppLogger.log(
                'RadioPlayer: fullscreen video layout engine=$engine '
                'available=${maxWidth.toStringAsFixed(1)}x${maxHeight.toStringAsFixed(1)} '
                'surface=${width.toStringAsFixed(1)}x${height.toStringAsFixed(1)} '
                'aspect=${safeAspect.toStringAsFixed(4)} '
                'playing=$_mediaKitPlaying videoEnabled=$_isVideoEnabled',
              ));
            }

            return Center(
              child: OverflowBox(
                alignment: Alignment.center,
                minWidth: width,
                maxWidth: width,
                minHeight: height,
                maxHeight: height,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoPlayerFullscreenSurface(VideoPlayerController controller) {
    final aspect = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    return _buildFullscreenVideoSurface(
      child: VideoPlayer(controller),
      aspectRatio: aspect,
      engine: 'video_player',
    );
  }

  Widget _buildMediaKitVideoFullscreenSurface() {
    return _buildFullscreenVideoSurface(
      child: mkv.Video(
        controller: _mediaKitController!,
        controls: mkv.AdaptiveVideoControls,
      ),
      aspectRatio: 16 / 9,
      engine: 'media_kit',
    );
  }

  Widget _buildRaiNativeVideoFullscreenSurface() {
    return _buildFullscreenVideoSurface(
      child: const RaiNativeVideoView(),
      aspectRatio: 16 / 9,
      engine: 'avplayer_rai',
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
              if (_streamReconnecting)
                Text(l10n.streamReconnecting, textAlign: TextAlign.center),
              if (_error != null)
                Text(_error!, textAlign: TextAlign.center),
              if (_showStreamRetry)
                OutlinedButton.icon(
                  onPressed: _streamRetryInProgress ? null : _retryStreamPlayback,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
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
                      onPressed: _loading || _anotherRecordingActive ? null : _toggleRecording,
                      icon: Icon(
                        _recording ? Icons.stop : Icons.fiber_manual_record,
                      ),
                      label: Text(
                        _recording ? l10n.stopRecording : l10n.startRecording,
                      ),
                    ),
                  if (_canRecordStream)
                    OutlinedButton.icon(
                      onPressed: _loading || _recordingService.hasAnyActiveRecording
                          ? null
                          : _showScheduleRecordingDialog,
                      icon: const Icon(Icons.schedule),
                      label: Text(l10n.radioScheduleDialogTitle),
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
                    label: Text(
                      l10n.radioScheduleCancelAction,
                      style: const TextStyle(color: Colors.white),
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
              if (_mediaKitPlayer != null || _raiNativeActive) ...[
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
    final videoSurface = _raiNativeActive
        ? _buildRaiNativeVideoFullscreenSurface()
        : (_videoController != null && _videoController!.value.isInitialized
            ? _buildVideoPlayerFullscreenSurface(_videoController!)
            : _buildMediaKitVideoFullscreenSurface());

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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: SonarpadBackSemantics(
                        onBack: _requestPlayerExit,
                        child: IconButton(
                          color: Colors.white,
                          tooltip:
                              MaterialLocalizations.of(context).backButtonTooltip,
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _requestPlayerExit,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Material(
                      color: Colors.black54,
                      shape: CircleBorder(),
                      child: SonarpadVisualHomeButton(
                        color: Colors.white,
                        compact: true,
                      ),
                    ),
                  ],
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

  Widget _buildSharedAccessiblePlayerBody(AppLocalizations l10n, bool showStationDetails) {
    Widget buildControls(bool audioPlaying) {
      final videoMode =
          _raiNativeActive || _mediaKitPlayer != null || _videoController != null;
      final rows = <AccessibleListRow>[
        AccessibleListRow(id: 'title', kind: 'header', title: widget.station.name),
        if (showStationDetails) AccessibleListRow(id: 'details', kind: 'text', title: widget.station.detailsText),
        if (_loading) AccessibleListRow(id: 'loading', kind: 'text', title: l10n.loading),
        if (_streamReconnecting)
          AccessibleListRow(id: 'reconnecting', kind: 'text', title: l10n.streamReconnecting),
        if (_error != null) AccessibleListRow(id: 'error', kind: 'text', title: _error!),
        if (_showStreamRetry)
          AccessibleListRow(id: 'retry_stream', kind: 'button', title: l10n.retry,
              enabled: !_streamRetryInProgress),
        if (widget.isVideoSupported) AccessibleListRow(id: 'video', title: l10n.enableVideo, kind: 'toggle', toggleValue: _isVideoEnabled),
        AccessibleListRow(
          id: 'play_pause',
          title: videoMode ? (_isVideoPlaying ? l10n.pause : l10n.play) : (audioPlaying ? l10n.pause : l10n.play),
          kind: 'button',
          enabled: !_loading,
        ),
        if (_canRecordStream)
          AccessibleListRow(id: 'record', title: _recording ? l10n.stopRecording : l10n.startRecording, kind: 'button', enabled: !_loading && !_anotherRecordingActive),
        if (_canRecordStream)
          AccessibleListRow(
            id: 'schedule',
            title: l10n.radioScheduleDialogTitle,
            enabled: !_loading && !_recordingService.hasAnyActiveRecording,
          ),
        if (_recordingOutput != null)
          AccessibleListRow(id: 'recording_name', kind: 'text', title: p.basenameWithoutExtension(_recordingOutput!.path)),
        if (_scheduledRecordingSummary != null)
          AccessibleListRow(id: 'schedule_summary', kind: 'text', title: _scheduledRecordingSummary!),
        if (_hasPendingScheduledRecording)
          AccessibleListRow(
            id: 'cancel_schedule',
            title: l10n.radioScheduleCancelAction,
          ),
        AccessibleListRow(
          id: 'favorite',
          title: _isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
          kind: 'button',
        ),
      ];
      return UniversalAccessibleList(
        sections: [AccessibleListSection(rows: rows)],
        onEvent: (event) async {
          if (event.id == 'retry_stream' && event.type == 'activate') {
            await _retryStreamPlayback();
          } else if (event.id == 'video' && event.type == 'toggle') {
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
          } else if (event.id == 'schedule' && event.type == 'activate' && !_recordingService.hasAnyActiveRecording) {
            await _showScheduleRecordingDialog();
          } else if (event.id == 'cancel_schedule' && event.type == 'activate') {
            _cancelScheduledRecording();
          } else if (event.id == 'favorite' && event.type == 'activate') {
            await _toggleFavorite();
          }
        },
      );
    }

    final nativeList = (!_raiNativeActive &&
            _mediaKitPlayer == null &&
            _videoController == null)
        ? StreamBuilder<bool>(
            stream: _audio.playingStream,
            builder: (context, snapshot) => buildControls(snapshot.data ?? false),
          )
        : buildControls(false);

    return Column(
      children: [
        if (_isVideoEnabled &&
            _videoController != null &&
            _videoController!.value.isInitialized)
          Padding(padding: const EdgeInsets.all(12), child: _buildVideoPlayerSurface(_videoController!)),
        if (_raiNativeActive && _isVideoEnabled)
          Padding(padding: const EdgeInsets.all(12), child: _buildRaiNativeVideoSurface()),
        if (_mediaKitController != null && _isVideoEnabled)
          Padding(padding: const EdgeInsets.all(12), child: _buildMediaKitVideoSurface()),
        Expanded(child: nativeList),
        if (!_raiNativeActive && _videoController == null && _mediaKitPlayer == null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: VolumeSlider(audioPlayer: _audio)),
        if (_videoController != null && _videoController!.value.isInitialized)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _PlayerVolumeSlider(volume: _videoPlayerVolume, onChanged: _setVideoPlayerVolume),
          ),
        if (_mediaKitPlayer != null || _raiNativeActive)
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
      return _withRecordingExitGuard(
        _buildLandscapeFullscreenScaffold(l10n),
      );
    }
    return _withRecordingExitGuard(Scaffold(
      appBar: SonarpadAppBar(
        title: Text('${l10n.nowPlaying}: ${widget.station.name}'),
        leading: SonarpadBackButton(
          onPressed: _requestPlayerExit,
        ),
      ),
      body: useSharedAccessibleViewModel
          ? _buildSharedAccessiblePlayerBody(l10n, showStationDetails)
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
          if (_loading || _streamReconnecting)
            LinearProgressIndicator(semanticsLabel: _streamReconnecting
                ? l10n.streamReconnecting : l10n.loading),
          if (_streamReconnecting)
            Text(l10n.streamReconnecting, textAlign: TextAlign.center),
          if (_showStreamRetry)
            OutlinedButton.icon(
              onPressed: _streamRetryInProgress ? null : _retryStreamPlayback,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
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
          if (_isVideoEnabled &&
              _videoController != null &&
              _videoController!.value.isInitialized) ...[
            const SizedBox(height: 24),
            _buildVideoPlayerSurface(_videoController!),
          ],
          if (_raiNativeActive && _isVideoEnabled) ...[
            const SizedBox(height: 24),
            _buildRaiNativeVideoSurface(),
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
              if (_raiNativeActive ||
                  _mediaKitPlayer != null ||
                  _videoController != null)
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
                  onPressed: _loading || _anotherRecordingActive ? null : _toggleRecording,
                  icon:
                      Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(
                      _recording ? l10n.stopRecording : l10n.startRecording),
                ),
              if (_canRecordStream)
                OutlinedButton.icon(
                  onPressed: _loading || _recordingService.hasAnyActiveRecording
                      ? null
                      : _showScheduleRecordingDialog,
                  icon: const Icon(Icons.schedule),
                  label: Text(l10n.radioScheduleDialogTitle),
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
                label: Text(l10n.radioScheduleCancelAction),
              ),
          ],
          if (!_raiNativeActive &&
              _videoController == null &&
              _mediaKitPlayer == null) ...[
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
          if (_mediaKitPlayer != null || _raiNativeActive) ...[
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
    ));
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
