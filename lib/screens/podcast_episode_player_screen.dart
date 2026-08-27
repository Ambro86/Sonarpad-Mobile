import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/podcast_service.dart';
import '../widgets/volume_slider.dart';
import '../widgets/universal_accessible_view.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_logger.dart';
import 'podcast_chapters_screen.dart';

class PodcastPlayerExtraAction {
  const PodcastPlayerExtraAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.pauseBeforeOpen = false,
  });

  final String id;
  final String Function() label;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool pauseBeforeOpen;
}

class PodcastEpisodePlayerScreen extends StatefulWidget {
  const PodcastEpisodePlayerScreen({
    super.key,
    required this.episode,
    this.isVideoSupported = false,
    this.startWithVideo = false,
    this.startWithVideoThenRestorePreference = false,
    this.refreshEpisode,
    this.navigateEpisode,
    this.hasPreviousEpisode,
    this.hasNextEpisode,
    this.previousEpisodeLabel,
    this.nextEpisodeLabel,
    this.showPreviousEpisodeAction = true,
    this.showNextEpisodeAction = true,
    this.extraActions = const <PodcastPlayerExtraAction>[],
  });

  final PodcastEpisode episode;
  final bool isVideoSupported;
  final bool startWithVideo;

  /// Used by SonarTube: when the saved preference is audio-only, initialize
  /// and start the video stream first, then immediately switch back to audio.
  /// This avoids asking the audio backend to bootstrap a progressive YouTube
  /// video URL directly on iOS.
  final bool startWithVideoThenRestorePreference;

  /// Optional one-shot media refresh used when a temporary signed stream URL
  /// fails. Other players leave this null and preserve their old behavior.
  final Future<PodcastEpisode?> Function()? refreshEpisode;

  /// Optional adjacent-item navigation. SonarTube supplies this only when a
  /// video was opened from a channel or playlist. The callback resolves the
  /// adjacent item on demand and returns fresh playable URLs.
  final Future<PodcastEpisode?> Function(int direction)? navigateEpisode;
  final bool Function()? hasPreviousEpisode;
  final bool Function()? hasNextEpisode;
  final String? previousEpisodeLabel;
  final String? nextEpisodeLabel;
  final bool showPreviousEpisodeAction;
  final bool showNextEpisodeAction;
  final List<PodcastPlayerExtraAction> extraActions;

  @override
  State<PodcastEpisodePlayerScreen> createState() =>
      _PodcastEpisodePlayerScreenState();
}

class _PodcastEpisodePlayerScreenState
    extends State<PodcastEpisodePlayerScreen> with WidgetsBindingObserver {
  static const _mediaCommands = MethodChannel('sonarpad/tts_commands');
  static const _mediaEvents = EventChannel('sonarpad/tts_events');

  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  final _podcastService = PodcastService();
  StreamSubscription<dynamic>? _mediaEventsSubscription;

  VideoPlayerController? _videoController;
  bool _videoUsesExternalAudio = false;
  bool _isVideoEnabled = false;
  bool _displayVideoInPortrait = false;
  bool _landscapeFullscreenApplied = false;

  bool _loaded = false;
  bool _loading = false;
  List<PodcastChapter>? _detectedChapters;
  String? _error;
  int _seekStep = 60;
  int _lastVideoBookmarkSecond = -1;
  Timer? _diagnosticHeartbeat;
  AppLifecycleState? _lastLifecycleState;
  PodcastEpisode? _refreshedEpisode;
  bool _restoreVideoOffAfterBootstrap = false;
  bool _refreshingEpisode = false;
  bool _switchingVideoMode = false;

  PodcastEpisode get _episode => _refreshedEpisode ?? widget.episode;

  String get _logSubject =>
      'episodeTitle="${_episode.title}", url=${_episode.audioUrl}, '
      'stableId=${_getStableId()}';

  String _getStableId() {
    if (_episode.id != null) {
      return _episode.id!;
    }
    final uri = Uri.parse(_episode.audioUrl);
    return 'media:${uri.scheme}://${uri.host}${uri.path}';
  }

  Future<void> _saveVideoBookmark() async {
    if (_videoController == null) return;
    final pos = _videoController!.value.position;
    final dur = _videoController!.value.duration;
    if (pos.inSeconds < 3) return;

    if (await _settings.isAutoBookmarkEnabled()) {
      bool isFinished = false;
      final durationSecs = dur.inSeconds;
      final remaining = durationSecs - pos.inSeconds;

      if (durationSecs > 600) {
        if (remaining < 30) isFinished = true;
      } else {
        if (durationSecs > 0 && (pos.inSeconds / durationSecs) > 0.95) isFinished = true;
      }

      final stableId = _getStableId();
      if (isFinished) {
        await _settings.saveMediaBookmark(stableId, 0);
      } else {
        await _settings.saveMediaBookmark(stableId, pos.inSeconds);
      }
    }
  }

  Future<void> _play({
    bool allowMediaRefresh = true,
    Duration? resumePosition,
    bool shouldPlay = true,
  }) async {
    AppLogger.log(
      'PodcastPlayer: _play start mounted=$mounted loaded=$_loaded '
      'loading=$_loading videoEnabled=$_isVideoEnabled '
      'videoSupported=${widget.isVideoSupported}, $_logSubject',
    );
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    AppLogger.log('PodcastPlayer: _play set loading=true');
    try {
      if (widget.isVideoSupported && _isVideoEnabled) {
        AppLogger.log(
          'PodcastPlayer: video branch start loaded=$_loaded, $_logSubject',
        );
        // The audio-only player may still be running even when `_loaded` was
        // reset for a mode change. Stop it unconditionally before creating the
        // video controller, otherwise both engines remain audible on iOS.
        await _audio.stop();
        final previousVideoController = _videoController;
        if (previousVideoController != null) {
          await previousVideoController.pause();
          await previousVideoController.dispose();
          _videoController = null;
        }
        final playbackUrl = _episode.videoUrl ?? _episode.audioUrl;
        final useExternalAudio = _episode.videoUrl != null &&
            _episode.videoUrl != _episode.audioUrl;
        _videoUsesExternalAudio = useExternalAudio;
        AppLogger.log(
          'PodcastPlayer: video playback url selected url=$playbackUrl, '
          'audioUrl=${_episode.audioUrl}, '
          'externalAudio=$useExternalAudio, $_logSubject',
        );
        final uri = Uri.parse(playbackUrl);
        if (uri.scheme == 'file') {
          _videoController = VideoPlayerController.file(
            File(uri.toFilePath()),
            videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
          );
        } else {
          _videoController = VideoPlayerController.networkUrl(
            uri,
            videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
          );
        }
        AppLogger.log('PodcastPlayer: video initialize start, $_logSubject');
        await _videoController!.initialize();
        AppLogger.log('PodcastPlayer: video initialize completed, $_logSubject');
        if (useExternalAudio) {
          await _videoController!.setVolume(0);
          await _audio.setUrl(
            _episode.audioUrl,
            title: l10n.nowPlayingTitle(_episode.title),
            mediaId: _getStableId(),
          );
          _loaded = true;
          AppLogger.log(
            'PodcastPlayer: external audio setUrl completed for video, '
            '$_logSubject',
          );
        } else {
          await _videoController!.setVolume(1);
        }
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod(
            'setupMagicTap',
            _episode.title,
          );
        }

        _videoController!.addListener(() {
          if (!mounted || _videoController == null) return;
          final currentSecond = _videoController!.value.position.inSeconds;
          if (currentSecond > 0 && currentSecond % 15 == 0) {
            if (_lastVideoBookmarkSecond != currentSecond) {
               _lastVideoBookmarkSecond = currentSecond;
               _saveVideoBookmark();
            }
          }
        });

        final stableId = _getStableId();
        if (resumePosition != null) {
          await _videoController!.seekTo(resumePosition);
          if (useExternalAudio) {
            await _audio.seek(resumePosition);
          }
          AppLogger.log(
            'PodcastPlayer: video transition restored position='
            '${resumePosition.inMilliseconds}ms, $_logSubject',
          );
        } else if (await _settings.isAutoBookmarkEnabled()) {
          final savedPos = await _settings.getMediaBookmark(stableId);
          if (savedPos != null && savedPos >= 3) {
            final dur = _videoController!.value.duration;
            if (savedPos < (dur.inSeconds - 30)) {
              await _videoController!.seekTo(Duration(seconds: savedPos));
              if (useExternalAudio) {
                await _audio.seek(Duration(seconds: savedPos));
              }
            }
          }
        }

        AppLogger.log(
          'PodcastPlayer: video ready shouldPlay=$shouldPlay, $_logSubject',
        );
        if (shouldPlay) {
          await _videoController!.play();
        }
        _loaded = true;
        if (useExternalAudio && shouldPlay) {
          unawaited(_audio.play().catchError((Object e, StackTrace stackTrace) {
            AppLogger.log(
              'PodcastPlayer: external audio play async error: $e, $_logSubject',
            );
            if (mounted) {
              setState(() => _error = l10n.episodeError(l10n.technicalErrorGeneric));
            }
          }));
        }
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod(
            'setMagicTapPlaying',
            shouldPlay,
          );
        }
        AppLogger.log('PodcastPlayer: video play completed, $_logSubject');
        if (_restoreVideoOffAfterBootstrap) {
          _restoreVideoOffAfterBootstrap = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_isVideoEnabled) return;
            AppLogger.log(
              'PodcastPlayer: SonarTube bootstrap completed; restoring audio-only preference, $_logSubject',
            );
            _toggleVideo(false);
          });
        }
      } else {
        AppLogger.log(
          'PodcastPlayer: audio branch start loaded=$_loaded, $_logSubject',
        );
        await _saveVideoBookmark();
        if (Platform.isIOS && _videoController != null) {
          await _mediaCommands.invokeMethod('clearMagicTap');
        }
        final previousVideoController = _videoController;
        if (previousVideoController != null) {
          await previousVideoController.pause();
          await previousVideoController.dispose();
        }
        _videoController = null;
        _videoUsesExternalAudio = false;

        if (!_loaded) {
          AppLogger.log('PodcastPlayer: audio setUrl start, $_logSubject');
          await _audio.setUrl(
            _episode.audioUrl,
            title: l10n.nowPlayingTitle(_episode.title),
            mediaId: _getStableId(),
          );
          _loaded = true;
          AppLogger.log(
            'PodcastPlayer: audio setUrl completed loaded=$_loaded, '
            'title="In riproduzione: ${_episode.title}", $_logSubject',
          );
          if (resumePosition != null) {
            await _audio.seek(resumePosition);
            AppLogger.log(
              'PodcastPlayer: audio transition restored position='
              '${resumePosition.inMilliseconds}ms, $_logSubject',
            );
          }
        }
        AppLogger.log(
          'PodcastPlayer: audio play scheduled, '
          'title="In riproduzione: ${_episode.title}", $_logSubject',
        );
        if (shouldPlay) {
          unawaited(_audio.play().catchError((Object e, StackTrace stackTrace) {
            AppLogger.log(
              'PodcastPlayer: audio play async error: $e, $_logSubject',
            );
          }));
        }
      }
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      if (allowMediaRefresh && await _refreshEpisodeAfterPlaybackFailure(e)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
        await _play(
          allowMediaRefresh: false,
          resumePosition: resumePosition,
          shouldPlay: shouldPlay,
        );
        return;
      }
      AppLogger.log('PodcastPlayer: Error during _play: $e, $_logSubject');
      setState(() => _error = l10n.episodeError(l10n.technicalErrorGeneric));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        AppLogger.log(
          'PodcastPlayer: _play complete. loading=false, loaded=$_loaded, '
          'isVideo=${_videoController != null}, $_logSubject',
        );
      }
    }
  }

  Future<bool> _refreshEpisodeAfterPlaybackFailure(Object error) async {
    final refresh = widget.refreshEpisode;
    if (refresh == null || _refreshingEpisode) return false;
    _refreshingEpisode = true;
    AppLogger.log(
      'PodcastPlayer: refreshing temporary media after playback failure: $error, $_logSubject',
    );
    try {
      final refreshed = await refresh();
      if (!mounted || refreshed == null) return false;
      await _saveVideoBookmark();
      _videoController?.pause();
      _videoController?.dispose();
      _videoController = null;
      _videoUsesExternalAudio = false;
      if (_loaded) {
        await _audio.stop();
      }
      _loaded = false;
      _refreshedEpisode = refreshed;
      AppLogger.log('PodcastPlayer: temporary media refreshed, $_logSubject');
      return true;
    } catch (refreshError) {
      AppLogger.log(
        'PodcastPlayer: temporary media refresh failed: $refreshError, $_logSubject',
      );
      return false;
    } finally {
      _refreshingEpisode = false;
    }
  }

  bool get _canNavigatePrevious =>
      widget.showPreviousEpisodeAction &&
      widget.navigateEpisode != null &&
      widget.previousEpisodeLabel != null &&
      (widget.hasPreviousEpisode?.call() ?? false);

  bool get _canNavigateNext =>
      widget.showNextEpisodeAction &&
      widget.navigateEpisode != null &&
      widget.nextEpisodeLabel != null &&
      (widget.hasNextEpisode?.call() ?? false);

  Future<void> _runExtraAction(PodcastPlayerExtraAction action) async {
    if (_loading) return;
    if (action.pauseBeforeOpen) {
      await _pause();
      if (Platform.isIOS && _videoController != null) {
        await _mediaCommands.invokeMethod('setMagicTapPlaying', false);
      }
    }
    await action.onPressed();
    if (mounted) setState(() {});
  }

  Future<void> _navigateAdjacentEpisode(int direction) async {
    final navigate = widget.navigateEpisode;
    if (navigate == null || _loading || _refreshingEpisode) return;
    if (direction < 0 && !_canNavigatePrevious) return;
    if (direction > 0 && !_canNavigateNext) return;

    AppLogger.log(
      'PodcastPlayer: adjacent navigation start direction=$direction, $_logSubject',
    );
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final replacement = await navigate(direction);
      if (!mounted || replacement == null) return;

      await _saveVideoBookmark();
      if (_videoController == null) {
        await _audio.saveCurrentBookmark();
      }
      final previousVideoController = _videoController;
      if (Platform.isIOS && previousVideoController != null) {
        await _mediaCommands.invokeMethod('clearMagicTap');
      }
      if (previousVideoController != null) {
        await previousVideoController.pause();
        previousVideoController.dispose();
      }
      _videoController = null;
      _videoUsesExternalAudio = false;
      if (_loaded) {
        await _audio.stop();
      }

      _loaded = false;
      _detectedChapters = null;
      _lastVideoBookmarkSecond = -1;
      _refreshedEpisode = replacement;
      _restoreVideoOffAfterBootstrap = false;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
      unawaited(_detectChapters());
      await _play();
      AppLogger.log(
        'PodcastPlayer: adjacent navigation complete direction=$direction, $_logSubject',
      );
    } catch (error) {
      AppLogger.log(
        'PodcastPlayer: adjacent navigation failed direction=$direction error=$error, $_logSubject',
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => _error = l10n.episodeError(l10n.technicalErrorGeneric));
      }
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _pause() async {
    AppLogger.log(
      'PodcastPlayer: _pause start video=${_videoController != null} '
      'loaded=$_loaded loading=$_loading, $_logSubject',
    );
    if (_videoController != null) {
      await _videoController!.pause();
      if (_videoUsesExternalAudio) {
        await _audio.pause();
      }
      await _saveVideoBookmark();
      setState(() {});
    } else {
      await _audio.pause();
      await _audio.saveCurrentBookmark();
    }
  }

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      if (_videoUsesExternalAudio) {
        await _audio.pause();
      }
      await _saveVideoBookmark();
      if (Platform.isIOS) {
        await _mediaCommands.invokeMethod('setMagicTapPlaying', false);
      }
    } else {
      await controller.play();
      if (_videoUsesExternalAudio) {
        await _audio.play();
      }
      if (Platform.isIOS) {
        await _mediaCommands.invokeMethod('setMagicTapPlaying', true);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _seekBackward() async {
    if (_videoController != null) {
      final position = _videoController!.value.position;
      final newPosition = position - Duration(seconds: _seekStep);
      final target = newPosition < Duration.zero ? Duration.zero : newPosition;
      await _videoController!.seekTo(target);
      if (_videoUsesExternalAudio) {
        await _audio.seek(target);
      }
      if (mounted) setState(() {});
      return;
    }
    await _audio.seekBackward();
  }

  Future<void> _seekForward() async {
    if (_videoController != null) {
      final position = _videoController!.value.position;
      final duration = _videoController!.value.duration;
      final newPosition = position + Duration(seconds: _seekStep);
      final target = duration > Duration.zero && newPosition > duration
          ? duration
          : newPosition;
      await _videoController!.seekTo(target);
      if (_videoUsesExternalAudio) {
        await _audio.seek(target);
      }
      if (mounted) setState(() {});
      return;
    }
    await _audio.seekForward();
  }


  Future<void> _openChapters() async {
    AppLogger.log('PodcastPlayer: open chapters, $_logSubject');
    final position = await Navigator.push<Duration>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/podcasts/chapters'),
        builder: (_) => PodcastChaptersScreen(
          episode: _episode,
          chapters: _detectedChapters,
        ),
      ),
    );
    if (position == null || !mounted) return;
    AppLogger.log(
      'PodcastPlayer: selected chapter position=${position.inMilliseconds}ms, '
      'video=${_videoController != null}, $_logSubject',
    );
    if (_videoController != null) {
      await _videoController!.seekTo(position);
      if (_videoUsesExternalAudio) {
        await _audio.seek(position);
      }
      if (mounted) setState(() {});
    } else {
      await _audio.seek(position);
    }
  }

  Future<void> _detectChapters() async {
    final chapters = await _podcastService.fetchEpisodeChapters(_episode);
    if (!mounted) return;
    setState(() => _detectedChapters = chapters);
  }

  void _toggleVideo(bool enable) {
    if (_loading || _switchingVideoMode) {
      AppLogger.log(
        'PodcastPlayer: _toggleVideo ignored during transition enable=$enable, '
        '$_logSubject',
      );
      return;
    }
    _restoreVideoOffAfterBootstrap = false;
    AppLogger.log('PodcastPlayer: _toggleVideo enable=$enable, $_logSubject');
    setState(() {
      _isVideoEnabled = enable;
      _switchingVideoMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isVideoEnabled != enable) {
        _switchingVideoMode = false;
        return;
      }
      unawaited(_applyVideoSetting(enable));
    });
  }

  Future<void> _applyVideoSetting(bool enable) async {
    final previousVideoController = _videoController;
    final wasPlaying = previousVideoController?.value.isPlaying ??
        _audio.isPlaying;
    final resumePosition = previousVideoController?.value.position ??
        _audio.position;

    AppLogger.log(
      'PodcastPlayer: mode transition start enableVideo=$enable '
      'wasPlaying=$wasPlaying position=${resumePosition.inMilliseconds}ms '
      'source=${previousVideoController == null ? 'audio' : 'video'}, '
      '$_logSubject',
    );

    try {
      if (previousVideoController != null) {
        await _saveVideoBookmark();
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod('clearMagicTap');
        }
        await previousVideoController.pause();
        if (_videoUsesExternalAudio || _audio.isPlaying) {
          await _audio.stop();
        }
        await previousVideoController.dispose();
        _videoController = null;
        _videoUsesExternalAudio = false;
      } else {
        // This is the critical audio-only -> video path from the reported log.
        // Stop just_audio before a VideoPlayerController is initialized.
        await _audio.stop();
      }

      await _settings.setVideoEnabled(enable);
      _loaded = false; // Force a reload only after the old engine is stopped.
      await _play(
        resumePosition: resumePosition,
        shouldPlay: wasPlaying,
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        'PodcastPlayer: mode transition failed error=$error '
        'stack=$stackTrace, $_logSubject',
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(
          () => _error = l10n.episodeError(l10n.technicalErrorGeneric),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _switchingVideoMode = false);
      }
    }
  }

  void _startDiagnosticHeartbeat() {
    _diagnosticHeartbeat?.cancel();
    _diagnosticHeartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final focus = FocusManager.instance.primaryFocus;
      AppLogger.log(
        'PodcastPlayer: heartbeat mounted=$mounted loaded=$_loaded '
        'loading=$_loading playing=${_audio.isPlaying} '
        'routeCurrent=${route?.isCurrent} routeActive=${route?.isActive} '
        'lifecycle=$_lastLifecycleState '
        'primaryFocus=${focus?.context?.widget.runtimeType}, $_logSubject',
      );
      
      final rootNode = RendererBinding.instance.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
      if (rootNode != null) {
        AppLogger.log('PodcastPlayer Semantics Tree:\n${rootNode.toStringDeep()}');
      } else {
        AppLogger.log('PodcastPlayer Semantics Tree: NULL (semantics not generated/enabled)');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      _mediaEventsSubscription =
          _mediaEvents.receiveBroadcastStream().listen((event) {
        if (event == 'toggle' && mounted && _videoController != null) {
          unawaited(_toggleVideoPlayback());
        }
      });
    }
    WidgetsBinding.instance.addObserver(this);
    _lastLifecycleState = WidgetsBinding.instance.lifecycleState;
    _startDiagnosticHeartbeat();
    AppLogger.log(
      'PodcastPlayer: initState title=${_episode.title} '
      'url=${_episode.audioUrl} isVideoSupported=${widget.isVideoSupported}, '
      '$_logSubject',
    );
    _loadSettings();
    unawaited(_detectChapters());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AppLogger.log(
        'PodcastPlayer: postFrame callback start mounted=$mounted, $_logSubject',
      );
      final savedVideoEnabled = await _settings.isVideoEnabled();
      _restoreVideoOffAfterBootstrap =
          widget.isVideoSupported &&
          widget.startWithVideoThenRestorePreference &&
          !savedVideoEnabled;
      _isVideoEnabled =
          widget.startWithVideo ||
          savedVideoEnabled ||
          _restoreVideoOffAfterBootstrap;
      _displayVideoInPortrait =
          await _settings.displayVideoInPortrait();
      if (!mounted) return;
      setState(() {});
      AppLogger.log(
        'PodcastPlayer: postFrame settings loaded '
        'videoEnabled=$_isVideoEnabled, $_logSubject',
      );
      unawaited(_play().catchError((Object e, StackTrace stackTrace) {
        AppLogger.log('PodcastPlayer: postFrame _play error: $e, $_logSubject');
      }));
    });
  }

  Future<void> _loadSettings() async {
    AppLogger.log('PodcastPlayer: load seek step start, $_logSubject');
    final step = await AppSettingsService().loadSeekSliderStep();
    if (mounted) setState(() => _seekStep = step);
    AppLogger.log(
      'PodcastPlayer: load seek step completed step=$step mounted=$mounted, '
      '$_logSubject',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _saveVideoBookmark();
      _audio.saveCurrentBookmark();
    }
    _lastLifecycleState = state;
    AppLogger.log(
      'PodcastPlayer: lifecycle state=$state mounted=$mounted '
      'loaded=$_loaded loading=$_loading video=${_videoController != null}, '
      '$_logSubject',
    );
  }

  bool get _useLandscapeFullscreenVideo =>
      _displayVideoInPortrait &&
      _isVideoEnabled &&
      _videoController != null &&
      _videoController!.value.isInitialized;

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
        unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
      } else {
        unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
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
    AppLogger.log(
      'PodcastPlayer: dispose start loaded=$_loaded loading=$_loading '
      'video=${_videoController != null}, $_logSubject',
    );
    WidgetsBinding.instance.removeObserver(this);
    _diagnosticHeartbeat?.cancel();
    if (Platform.isIOS && _videoController != null) {
      unawaited(_mediaCommands.invokeMethod('clearMagicTap'));
    }
    _restoreSystemOrientation();
    unawaited(_mediaEventsSubscription?.cancel() ?? Future<void>.value());
    unawaited(_saveVideoBookmark());
    _videoController?.dispose();
    unawaited(_audio.stopAndDispose());
    super.dispose();
    AppLogger.log('PodcastPlayer: dispose end, $_logSubject');
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

  Widget _buildVideoPlayerFullscreenSurface(VideoPlayerController controller) {
    final safeAspect = controller.value.aspectRatio > 0 &&
            controller.value.aspectRatio.isFinite
        ? controller.value.aspectRatio
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
            final isPortraitVideo = safeAspect < 1;
            if (isPortraitVideo && height > maxHeight) {
              // A vertical SonarTube video must remain completely visible.
              // It uses the same real-sized surface as TV, but with contain
              // sizing so faces and captions are not cropped above or below.
              height = maxHeight;
              width = height * safeAspect;
            } else if (!isPortraitVideo && height < maxHeight) {
              // Horizontal videos keep the proven TV fullscreen cover layout.
              height = maxHeight;
              width = height * safeAspect;
            }

            AppLogger.log(
              'PodcastPlayer: fullscreen video layout available='
              '${maxWidth}x$maxHeight surface=${width}x$height '
              'aspect=$safeAspect fit=${isPortraitVideo ? 'contain' : 'cover'}, '
              '$_logSubject',
            );
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
                  child: VideoPlayer(controller),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeFullscreenControls(
    AppLocalizations l10n,
    bool canSeek,
  ) {
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
              onChanged: _loading || _switchingVideoMode ? null : _toggleVideo,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (_canNavigatePrevious)
                  FilledButton.icon(
                    key: const ValueKey('podcast_fullscreen_previous_episode'),
                    onPressed: _loading
                        ? null
                        : () => _navigateAdjacentEpisode(-1),
                    icon: const Icon(Icons.skip_previous),
                    label: Text(widget.previousEpisodeLabel!),
                  ),
                if (canSeek)
                  FilledButton.icon(
                    onPressed: _loading || !_loaded ? null : _seekBackward,
                    icon: const Icon(Icons.fast_rewind),
                    label: Text(l10n.rewind15s),
                  ),
                FilledButton.icon(
                  key: const ValueKey('podcast_video_fullscreen_play_pause'),
                  onPressed: _loading ? null : _toggleVideoPlayback,
                  icon: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    _videoController!.value.isPlaying ? l10n.pause : l10n.play,
                  ),
                ),
                if (canSeek)
                  FilledButton.icon(
                    onPressed: _loading || !_loaded ? null : _seekForward,
                    icon: const Icon(Icons.fast_forward),
                    label: Text(l10n.forward15s),
                  ),
                if (_canNavigateNext)
                  FilledButton.icon(
                    key: const ValueKey('podcast_fullscreen_next_episode'),
                    onPressed: _loading
                        ? null
                        : () => _navigateAdjacentEpisode(1),
                    icon: const Icon(Icons.skip_next),
                    label: Text(widget.nextEpisodeLabel!),
                  ),
                for (final action in widget.extraActions)
                  FilledButton.tonalIcon(
                    key: ValueKey('podcast_fullscreen_extra_${action.id}'),
                    onPressed: _loading ? null : () => _runExtraAction(action),
                    icon: Icon(action.icon),
                    label: Text(action.label()),
                  ),
              ],
            ),
            if (canSeek) ...[
              const SizedBox(height: 12),
              _VideoPositionControl(
                controller: _videoController!,
                audio: _videoUsesExternalAudio ? _audio : null,
                seekStep: _seekStep,
                logSubject: _logSubject,
              ),
            ],
            if (_videoUsesExternalAudio) ...[
              const SizedBox(height: 12),
              VolumeSlider(audioPlayer: _audio),
            ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeFullscreenScaffold(
    AppLocalizations l10n,
    bool canSeek,
  ) {
    final surface = _videoUsesExternalAudio
        ? Semantics(
            key: const ValueKey('podcast_video_fullscreen_external_audio'),
            label: l10n.nowPlayingTitle(_episode.title),
            value: _videoController!.value.isPlaying ? l10n.pause : l10n.play,
            child: _buildVideoPlayerFullscreenSurface(_videoController!),
          )
        : KeyedSubtree(
            key: const ValueKey('podcast_video_fullscreen_inline_audio'),
            child: _buildVideoPlayerFullscreenSurface(_videoController!),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: surface),
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
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      AppLogger.log(
                        'PodcastPlayer: fullscreen back pressed, $_logSubject',
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildLandscapeFullscreenControls(l10n, canSeek),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedAccessiblePlayerBody(AppLocalizations l10n, bool canSeek) {
    Widget buildControls(bool isPlaying) {
      final videoReady = _videoController != null && _videoController!.value.isInitialized;
      final videoPlaying = videoReady && _videoController!.value.isPlaying;
      final rows = <AccessibleListRow>[
        AccessibleListRow(
          id: 'now_playing_title',
          kind: 'text',
          title: l10n.nowPlayingTitle(_episode.title),
          accessibilityButtonTrait: false,
        ),
        if (_loading) AccessibleListRow(id: 'loading', kind: 'text', title: l10n.loadingEpisodeAudio),
        if (_error != null) AccessibleListRow(id: 'error', kind: 'text', title: _error!),
        if (_podcastService.hasChapterSource(_episode) || (_detectedChapters?.isNotEmpty ?? false))
          AccessibleListRow(id: 'chapters', title: l10n.podcastChapters),
        if (widget.isVideoSupported)
          AccessibleListRow(
            id: 'video',
            title: l10n.enableVideo,
            kind: 'toggle',
            toggleValue: _isVideoEnabled,
            enabled: !_loading && !_switchingVideoMode,
          ),
        if (_canNavigatePrevious)
          AccessibleListRow(
            id: 'previous_episode',
            title: widget.previousEpisodeLabel!,
            kind: 'button',
            enabled: !_loading,
          ),
        if (canSeek) AccessibleListRow(id: 'rewind', title: l10n.rewind15s, kind: 'button', enabled: !_loading && _loaded),
        AccessibleListRow(
          id: 'play_pause',
          title: _videoController != null ? (videoPlaying ? l10n.pause : l10n.play) : (isPlaying ? l10n.pause : l10n.play),
          kind: 'button',
          enabled: !_loading,
        ),
        if (canSeek) AccessibleListRow(id: 'forward', title: l10n.forward15s, kind: 'button', enabled: !_loading && _loaded),
        if (_canNavigateNext)
          AccessibleListRow(
            id: 'next_episode',
            title: widget.nextEpisodeLabel!,
            kind: 'button',
            enabled: !_loading,
          ),
        for (final action in widget.extraActions)
          AccessibleListRow(
            id: 'extra_${action.id}',
            title: action.label(),
            kind: 'button',
            enabled: !_loading,
          ),
      ];
      return UniversalAccessibleList(
        sections: [AccessibleListSection(rows: rows)],
        onEvent: (event) async {
          if (event.id == 'chapters' && event.type == 'activate') {
            await _openChapters();
          } else if (event.id == 'video' && event.type == 'toggle') {
            _toggleVideo(event.value == true);
          } else if (event.id == 'previous_episode' && event.type == 'activate') {
            await _navigateAdjacentEpisode(-1);
          } else if (event.id == 'rewind' && event.type == 'activate') {
            await _seekBackward();
          } else if (event.id == 'forward' && event.type == 'activate') {
            await _seekForward();
          } else if (event.id == 'next_episode' && event.type == 'activate') {
            await _navigateAdjacentEpisode(1);
          } else if (event.type == 'activate' &&
              event.id?.startsWith('extra_') == true) {
            final actionId = event.id!.substring('extra_'.length);
            for (final action in widget.extraActions) {
              if (action.id == actionId) {
                await _runExtraAction(action);
                break;
              }
            }
          } else if (event.id == 'play_pause' && event.type == 'activate') {
            if (_videoController != null) {
              await _toggleVideoPlayback();
            } else if (isPlaying) {
              await _pause();
            } else {
              await _play();
            }
          }
        },
      );
    }

    final nativeList = _videoController == null
        ? StreamBuilder<bool>(
            stream: _audio.playingStream,
            builder: (context, snapshot) => buildControls(snapshot.data ?? false),
          )
        : buildControls(false);

    return Column(
      children: [
        if (_videoController != null && _videoController!.value.isInitialized)
          Padding(
            padding: const EdgeInsets.all(12),
            child: ExcludeSemantics(
              child: _buildVideoPlayerSurface(_videoController!),
            ),
          ),
        Expanded(child: nativeList),
        if (_videoController != null && canSeek)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _VideoPositionControl(
              controller: _videoController!,
              audio: _videoUsesExternalAudio ? _audio : null,
              seekStep: _seekStep,
              logSubject: _logSubject,
            ),
          )
        else if (_videoController == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PodcastPositionControl(audio: _audio, seekStep: _seekStep, logSubject: _logSubject),
          ),
        if (_videoController == null || _videoUsesExternalAudio)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: VolumeSlider(audioPlayer: _audio),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.log(
      'PodcastPlayer: build() called. loading=$_loading, loaded=$_loaded, '
      'error=$_error, videoEnabled=$_isVideoEnabled, '
      'videoControllerInit=${_videoController?.value.isInitialized}, '
      '$_logSubject',
    );
    _syncLandscapeFullscreenOrientation();
    final l10n = AppLocalizations.of(context);
    final canSeek = _videoController == null ||
        (_videoController!.value.isInitialized &&
            _videoController!.value.duration > Duration.zero);
    if (_useLandscapeFullscreenVideo) {
      return _buildLandscapeFullscreenScaffold(l10n, canSeek);
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        excludeHeaderSemantics: true,
        leading: BackButton(
          key: const ValueKey('podcast_player_back'),
          onPressed: () {
            AppLogger.log('PodcastPlayer: appbar back pressed, $_logSubject');
            Navigator.pop(context);
          },
        ),
        title: ExcludeSemantics(
          child: Text(l10n.nowPlayingTitle(_episode.title)),
        ),
      ),
      body: useSharedAccessibleViewModel
            ? _buildSharedAccessiblePlayerBody(l10n, canSeek)
            : Semantics(
          container: Platform.isIOS,
          explicitChildNodes: Platform.isIOS,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.nowPlayingTitle(_episode.title),
                key: const ValueKey('podcast_player_now_playing_title'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_loading)
                LinearProgressIndicator(semanticsLabel: l10n.loadingEpisodeAudio),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_podcastService.hasChapterSource(_episode) ||
                  (_detectedChapters?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 16),
                Center(
                  child: OutlinedButton.icon(
                    key: const ValueKey('podcast_chapters_button'),
                    onPressed: _openChapters,
                    icon: const Icon(Icons.list),
                    label: Text(l10n.podcastChapters),
                  ),
                ),
              ],
              if (widget.isVideoSupported) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  key: const ValueKey('podcast_video_toggle'),
                  title: Text(l10n.enableVideo),
                  value: _isVideoEnabled,
                  onChanged: _loading || _switchingVideoMode
                      ? null
                      : _toggleVideo,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (_videoController != null && _videoController!.value.isInitialized) ...[
                const SizedBox(height: 24),
                if (_videoUsesExternalAudio)
                  Semantics(
                    key: const ValueKey('podcast_video_external_audio'),
                    label: l10n.nowPlayingTitle(_episode.title),
                    value: _videoController!.value.isPlaying
                        ? l10n.pause
                        : l10n.play,
                    child: _buildVideoPlayerSurface(_videoController!),
                  )
                else
                  KeyedSubtree(
                    key: const ValueKey('podcast_video_inline_audio'),
                    child: _buildVideoPlayerSurface(_videoController!),
                  ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (_canNavigatePrevious)
                    FilledButton.icon(
                      key: const ValueKey('podcast_previous_episode'),
                      onPressed: _loading
                          ? null
                          : () => _navigateAdjacentEpisode(-1),
                      icon: const Icon(Icons.skip_previous),
                      label: Text(widget.previousEpisodeLabel!),
                    ),
                  if (canSeek)
                    FilledButton.icon(
                      onPressed:
                          _loading || !_loaded ? null : _seekBackward,
                      icon: const Icon(Icons.fast_rewind),
                      label: Text(l10n.rewind15s),
                    ),
                  if (_videoController != null)
                    FilledButton.icon(
                      key: const ValueKey('podcast_video_play_pause'),
                      onPressed: _loading ? null : _toggleVideoPlayback,
                      icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(_videoController!.value.isPlaying ? l10n.pause : l10n.play),
                    )
                  else
                    StreamBuilder<bool>(
                      stream: _audio.playingStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return FilledButton.icon(
                          onPressed:
                              _loading ? null : (isPlaying ? _pause : _play),
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                          label: Text(isPlaying ? l10n.pause : l10n.play),
                        );
                      },
                    ),
                  if (canSeek)
                    FilledButton.icon(
                      onPressed:
                          _loading || !_loaded ? null : _seekForward,
                      icon: const Icon(Icons.fast_forward),
                      label: Text(l10n.forward15s),
                    ),
                  if (_canNavigateNext)
                    FilledButton.icon(
                      key: const ValueKey('podcast_next_episode'),
                      onPressed: _loading
                          ? null
                          : () => _navigateAdjacentEpisode(1),
                      icon: const Icon(Icons.skip_next),
                      label: Text(widget.nextEpisodeLabel!),
                    ),
                  for (final action in widget.extraActions)
                    FilledButton.tonalIcon(
                      key: ValueKey('podcast_player_extra_${action.id}'),
                      onPressed: _loading ? null : () => _runExtraAction(action),
                      icon: Icon(action.icon),
                      label: Text(action.label()),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (_videoController != null && canSeek)
                _VideoPositionControl(
                  controller: _videoController!,
                  audio: _videoUsesExternalAudio ? _audio : null,
                  seekStep: _seekStep,
                  logSubject: _logSubject,
                )
              else
                _PodcastPositionControl(
                  audio: _audio,
                  seekStep: _seekStep,
                  logSubject: _logSubject,
                ),
              if (_videoController == null || _videoUsesExternalAudio) ...[
                const SizedBox(height: 24),
                VolumeSlider(audioPlayer: _audio),
              ],
            ],
          ),
        ),
    );
  }
}

class _PodcastPositionControl extends StatefulWidget {
  const _PodcastPositionControl({
    required this.audio,
    required this.seekStep,
    required this.logSubject,
  });

  final AudioPlayerService audio;
  final int seekStep;
  final String logSubject;

  @override
  State<_PodcastPositionControl> createState() => _PodcastPositionControlState();
}

class _PodcastPositionControlState extends State<_PodcastPositionControl> {
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  Timer? _refreshTimer;
  Duration _duration = Duration.zero;
  Duration _latestPosition = Duration.zero;
  Duration _visiblePosition = Duration.zero;
  int _lastPositionLogSecond = -1;

  @override
  void initState() {
    super.initState();
    _durationSubscription = widget.audio.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration ?? Duration.zero);
    });
    _positionSubscription = widget.audio.positionStream.listen((position) {
      _latestPosition = position;
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _latestPosition == _visiblePosition) return;
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      setState(() => _visiblePosition = _latestPosition);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final mins = d.inMinutes;
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }


  void _seekBy(int seconds) {
    var newPos = _visiblePosition + Duration(seconds: seconds);
    if (newPos < Duration.zero) {
      newPos = Duration.zero;
    } else if (newPos > _duration) {
      newPos = _duration;
    }
    setState(() {
      _visiblePosition = newPos;
      _latestPosition = newPos;
    });
    widget.audio.seek(newPos);
  }

  int _computeCurrentStep() {
    int step = widget.seekStep;
    if (_duration.inSeconds < step) {
      step = (_duration.inSeconds * 0.2).round();
      if (step < 1) step = 1;
    }
    return step;
  }

  void _handleIncrease() => _seekBy(_computeCurrentStep());
  void _handleDecrease() => _seekBy(-_computeCurrentStep());

  @override
  Widget build(BuildContext context) {
    if (_duration == Duration.zero) return const SizedBox();
    final l10n = AppLocalizations.of(context);
    final position = _visiblePosition;
    if (_lastPositionLogSecond != position.inSeconds &&
        position.inSeconds % 5 == 0) {
      _lastPositionLogSecond = position.inSeconds;
      AppLogger.log(
        'PodcastPlayer: position control updated, pos: ${position.inSeconds}s, '
        'dur: ${_duration.inSeconds}s, ${widget.logSubject}',
      );
    }

    int currentStep = widget.seekStep;
    if (_duration.inSeconds < currentStep) {
      currentStep = (_duration.inSeconds * 0.2).round();
      if (currentStep < 1) currentStep = 1;
    }

    final posSecs = position.inSeconds.toDouble();
    final durSecs = _duration.inSeconds.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            '${_format(position)} / ${_format(_duration)}',
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('podcast_position_slider_semantics'),
          slider: true,
          label: l10n.playbackPosition,
          value: l10n.playbackPositionValue(
            _format(position),
            _format(_duration),
          ),
          increasedValue: _format(
            position + Duration(seconds: currentStep),
          ),
          decreasedValue: _format(
            position - Duration(seconds: currentStep),
          ),
          onIncrease: _handleIncrease,
          onDecrease: _handleDecrease,
          child: ExcludeSemantics(
            child: Slider(
              value: posSecs.clamp(0.0, durSecs),
              min: 0,
              max: durSecs,
              onChanged: (val) {
                final newPos = Duration(seconds: val.toInt());
                setState(() {
                  _visiblePosition = newPos;
                  _latestPosition = newPos;
                });
                widget.audio.seek(newPos);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoPositionControl extends StatefulWidget {
  const _VideoPositionControl({
    required this.controller,
    required this.seekStep,
    required this.logSubject,
    this.audio,
  });

  final VideoPlayerController controller;
  final AudioPlayerService? audio;
  final int seekStep;
  final String logSubject;

  @override
  State<_VideoPositionControl> createState() => _VideoPositionControlState();
}

class _VideoPositionControlState extends State<_VideoPositionControl> {
  Timer? _refreshTimer;
  Duration _visiblePosition = Duration.zero;
  int _lastPositionLogSecond = -1;

  @override
  void initState() {
    super.initState();
    _visiblePosition = widget.controller.value.position;
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      final position = widget.controller.value.position;
      if (position == _visiblePosition) return;
      setState(() => _visiblePosition = position);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final mins = d.inMinutes;
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _seekTo(Duration position) async {
    setState(() => _visiblePosition = position);
    await widget.controller.seekTo(position);
    await widget.audio?.seek(position);
  }

  int _computeCurrentStep(Duration duration) {
    int step = widget.seekStep;
    if (duration.inSeconds < step) {
      step = (duration.inSeconds * 0.2).round();
      if (step < 1) step = 1;
    }
    return step;
  }

  Future<void> _seekBy(int seconds) async {
    final duration = widget.controller.value.duration;
    var newPos = _visiblePosition + Duration(seconds: seconds);
    if (newPos < Duration.zero) {
      newPos = Duration.zero;
    } else if (duration > Duration.zero && newPos > duration) {
      newPos = duration;
    }
    await _seekTo(newPos);
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    if (duration == Duration.zero) return const SizedBox();
    final l10n = AppLocalizations.of(context);
    final position = _visiblePosition;
    if (_lastPositionLogSecond != position.inSeconds &&
        position.inSeconds % 5 == 0) {
      _lastPositionLogSecond = position.inSeconds;
      AppLogger.log(
        'PodcastPlayer: video position control updated, '
        'pos: ${position.inSeconds}s, dur: ${duration.inSeconds}s, '
        '${widget.logSubject}',
      );
    }

    final currentStep = _computeCurrentStep(duration);
    final posSecs = position.inSeconds.toDouble();
    final durSecs = duration.inSeconds.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            '${_format(position)} / ${_format(duration)}',
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('podcast_video_position_slider_semantics'),
          slider: true,
          label: l10n.playbackPosition,
          value: l10n.playbackPositionValue(
            _format(position),
            _format(duration),
          ),
          increasedValue: _format(
            position + Duration(seconds: currentStep),
          ),
          decreasedValue: _format(
            position - Duration(seconds: currentStep),
          ),
          onIncrease: () => _seekBy(currentStep),
          onDecrease: () => _seekBy(-currentStep),
          child: ExcludeSemantics(
            child: Slider(
              value: posSecs.clamp(0.0, durSecs),
              min: 0,
              max: durSecs,
              onChanged: (val) {
                unawaited(_seekTo(Duration(seconds: val.toInt())));
              },
            ),
          ),
        ),
      ],
    );
  }
}
