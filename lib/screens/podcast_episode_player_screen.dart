import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../models/podcast.dart';
import '../models/media_playback_speed.dart';
import '../services/media_playback_rate_transaction.dart';
import '../widgets/letter_jump_option_picker_screen.dart';
import '../utils/status_message.dart';
import 'package:intl/intl.dart';
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
    this.speedCategory = MediaPlaybackSpeedCategory.media,
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
    this.autoNavigateNext = false,
    this.extraActions = const <PodcastPlayerExtraAction>[],
  });

  final PodcastEpisode episode;
  final MediaPlaybackSpeedCategory speedCategory;
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
  final bool autoNavigateNext;
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
  StreamSubscription<void>? _audioCompletionSubscription;

  VideoPlayerController? _videoController;
  bool _videoUsesExternalAudio = false;
  bool _isVideoEnabled = false;
  bool _displayVideoInPortrait = false;
  bool _landscapeFullscreenApplied = false;

  final _sharedPlayerController = AccessibleListController();
  final _playbackSpeedFocusNode = FocusNode();
  bool _mediaSpeedControlEnabled = false;
  bool _changingPlaybackSpeed = false;
  bool _speedPickerOpen = false;
  double _preferredPlaybackSpeed = 1.0;
  double _playbackSpeed = 1.0;
  double _lastConfirmedVideoSpeed = 1.0;

  bool get _showPlaybackSpeed => _mediaSpeedControlEnabled && !_episode.isLive;
  bool get _canChangePlaybackSpeed => _showPlaybackSpeed && _loaded &&
      !_loading && !_switchingVideoMode && !_changingPlaybackSpeed;

  bool _loaded = false;
  bool _loading = false;
  List<PodcastChapter>? _detectedChapters;
  String? _error;
  int _seekStep = 60;
  double _accessibleVolume = 1.0;
  bool _accessibleVolumeLoaded = false;
  Duration _accessibleAudioPosition = Duration.zero;
  Duration _accessibleAudioDuration = Duration.zero;
  StreamSubscription<Duration>? _accessiblePositionSubscription;
  StreamSubscription<Duration?>? _accessibleDurationSubscription;
  Timer? _accessiblePositionRefreshTimer;
  int _lastVideoBookmarkSecond = -1;
  Timer? _diagnosticHeartbeat;
  AppLifecycleState? _lastLifecycleState;
  PodcastEpisode? _refreshedEpisode;
  bool _restoreVideoOffAfterBootstrap = false;
  bool _refreshingEpisode = false;
  bool _switchingVideoMode = false;
  String? _autoAdvanceHandledMediaId;

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
    if (_changingPlaybackSpeed || !mounted) {
      return;
    }
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
      await _loadPlaybackSpeedPreference();
      if (!mounted) return;
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
        _lastConfirmedVideoSpeed = 1.0;
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
          final savedVolume =
              (await _settings.loadMediaVolume()).clamp(0.0, 1.0).toDouble();
          _accessibleVolume = savedVolume;
          _accessibleVolumeLoaded = true;
          await _videoController!.setVolume(savedVolume);
        }
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod(
            'setupMagicTap',
            _episode.title,
          );
        }

        _videoController!.addListener(() {
          if (!mounted || _videoController == null) return;
          final value = _videoController!.value;
          final currentSecond = value.position.inSeconds;
          if (currentSecond > 0 && currentSecond % 15 == 0) {
            if (_lastVideoBookmarkSecond != currentSecond) {
              _lastVideoBookmarkSecond = currentSecond;
              _saveVideoBookmark();
            }
          }
          if (value.isCompleted) {
            unawaited(_handlePlaybackCompleted());
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
        await _applyPreferredPlaybackSpeed(
          video: _videoController,
          startVideo: shouldPlay,
        );
        if (!mounted) return;
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
        await _applyPreferredPlaybackSpeed();
        if (!mounted) return;
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

  bool get _hasNavigablePrevious =>
      widget.navigateEpisode != null &&
      (widget.hasPreviousEpisode?.call() ?? false);

  bool get _hasNavigableNext =>
      widget.navigateEpisode != null &&
      (widget.hasNextEpisode?.call() ?? false);

  bool get _canNavigatePrevious =>
      widget.showPreviousEpisodeAction &&
      widget.previousEpisodeLabel != null &&
      _hasNavigablePrevious;

  bool get _canNavigateNext =>
      widget.showNextEpisodeAction &&
      widget.nextEpisodeLabel != null &&
      _hasNavigableNext;

  Future<void> _handlePlaybackCompleted() async {
    if (!widget.autoNavigateNext || !mounted || _changingPlaybackSpeed) {
      return;
    }
    final mediaId = _getStableId();
    if (_autoAdvanceHandledMediaId == mediaId) return;
    _autoAdvanceHandledMediaId = mediaId;

    if (!_hasNavigableNext) {
      AppLogger.log(
        'PodcastPlayer: autoplay reached end of queue; no next item, $_logSubject',
      );
      return;
    }

    AppLogger.log('PodcastPlayer: autoplay advancing to next item, $_logSubject');
    await _navigateAdjacentEpisodeSilently(1);
  }

  Future<void> _runExtraAction(PodcastPlayerExtraAction action) async {
    if (_loading || _changingPlaybackSpeed) {
      return;
    }
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
    await _navigateAdjacentEpisodeInternal(direction, silentFailure: false);
  }

  Future<void> _navigateAdjacentEpisodeSilently(int direction) async {
    await _navigateAdjacentEpisodeInternal(direction, silentFailure: true);
  }

  Future<void> _navigateAdjacentEpisodeInternal(
    int direction, {
    required bool silentFailure,
  }) async {
    final navigate = widget.navigateEpisode;
    if (navigate == null || _loading || _refreshingEpisode ||
        _changingPlaybackSpeed) {
      return;
    }
    if (direction < 0 && !_hasNavigablePrevious) return;
    if (direction > 0 && !_hasNavigableNext) return;

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
      _autoAdvanceHandledMediaId = null;
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
      if (mounted && !silentFailure) {
        final l10n = AppLocalizations.of(context);
        setState(() => _error = l10n.episodeError(l10n.technicalErrorGeneric));
      }
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _pause() async {
    if (_changingPlaybackSpeed) {
      return;
    }
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
    if (_changingPlaybackSpeed) {
      return;
    }
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
      final resumed = await _resumeVideoAtSelectedSpeed(controller);
      if (!resumed || !mounted) {
        return;
      }
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
    if (_changingPlaybackSpeed) {
      return;
    }
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
    if (_changingPlaybackSpeed) {
      return;
    }
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
    if (_changingPlaybackSpeed) {
      return;
    }
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
    if (_loading || _switchingVideoMode || _changingPlaybackSpeed) {
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
    _audioCompletionSubscription = _audio.completionStream.listen((_) {
      unawaited(_handlePlaybackCompleted());
    });
    _accessiblePositionSubscription = _audio.positionStream.listen((position) {
      _accessibleAudioPosition = position;
    });
    _accessibleDurationSubscription = _audio.durationStream.listen((duration) {
      _accessibleAudioDuration = duration ?? Duration.zero;
    });
    _accessiblePositionRefreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || !useSharedAccessibleViewModel) return;
        setState(() {});
      },
    );
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

  Future<void> _loadPlaybackSpeedPreference() async {
    // Resolve before starting either engine; unknown duration is not a live flag.
    final enabled = await _settings.isMediaSpeedControlEnabled();
    final speed = enabled && !_episode.isLive
        ? await _settings.loadMediaPlaybackSpeed(widget.speedCategory)
        : 1.0;
    if (!mounted) {
      return;
    }
    _mediaSpeedControlEnabled = enabled;
    _preferredPlaybackSpeed = speed;
  }

  List<MediaPlaybackRateTarget> _playbackRateTargets(
    VideoPlayerController? video,
  ) => [
        if (video != null)
          MediaPlaybackRateTarget(
            previousRate: video.value.playbackSpeed,
            setRate: video.setPlaybackSpeed,
          ),
        if (video == null || _videoUsesExternalAudio)
          MediaPlaybackRateTarget(
            previousRate: _audio.playbackSpeed,
            setRate: _audio.setPlaybackSpeed,
          ),
      ];

  Future<void> _applyPreferredPlaybackSpeed({
    VideoPlayerController? video,
    bool startVideo = false,
  }) async {
    var targets = _playbackRateTargets(video);
    // A recreated video engine starts at 1x while just_audio can retain the
    // previous source's rate. Establish a common rollback point first.
    if (targets.any((target) => target.previousRate != targets.first.previousRate)) {
      await applyMediaPlaybackRate(rate: 1.0, targets: targets);
      targets = _playbackRateTargets(video);
    }
    final rate = _preferredPlaybackSpeed;
    try {
      if (targets.any((target) => target.previousRate != rate)) {
        await applyMediaPlaybackRate(
          rate: rate,
          targets: targets,
          afterApply: () async {
            if (mounted && startVideo && video == _videoController) {
              await video?.play();
            }
          },
          beforeRollback: () async {
            await video?.pause();
          },
        );
      } else if (mounted && startVideo && video == _videoController) {
        // Default/disabled setting keeps the existing playback path unchanged.
        await video?.play();
      }
      if (mounted) {
        _playbackSpeed = rate;
        if (startVideo) {
          _lastConfirmedVideoSpeed = rate;
        }
      }
    } on MediaPlaybackRateException catch (error) {
      AppLogger.log('media_speed_restore_failed rollback=${error.rollbackFailed} '
          'error=${error.cause}');
      if (!mounted) {
        return;
      }
      final previous = targets.first.previousRate;
      if (error.rollbackFailed || (_episode.isLive && previous != 1.0)) {
        await video?.pause();
        await _audio.pause();
        rethrow;
      }
      _playbackSpeed = previous;
      if (startVideo && video == _videoController) {
        await video?.play();
        _lastConfirmedVideoSpeed = previous;
      }
      if (mounted) {
        showStatusMessage(context,
            AppLocalizations.of(context).mediaPlaybackSpeedUnavailable);
      }
    }
  }

  Future<bool> _resumeVideoAtSelectedSpeed(VideoPlayerController controller) async {
    try {
      await controller.play();
      _lastConfirmedVideoSpeed = _playbackSpeed;
      return true;
    } catch (error) {
      // video_player can defer platform rate validation until play(). This also
      // covers a rate chosen while paused; never leave external audio running
      // at a rate which the video engine rejected.
      AppLogger.log('media_speed_video_resume_failed error=$error');
      if (!mounted) {
        return false;
      }
      final l10n = AppLocalizations.of(context);
      try {
        await controller.pause();
        if (_videoUsesExternalAudio) {
          await _audio.pause();
        }
        if (_playbackSpeed == _lastConfirmedVideoSpeed) {
          if (!mounted) {
            return false;
          }
          showStatusMessage(context, l10n.technicalErrorGeneric);
          return false;
        }
        await applyMediaPlaybackRate(
          rate: _lastConfirmedVideoSpeed,
          targets: _playbackRateTargets(controller),
          afterApply: () async {
            if (!mounted) {
              return;
            }
            if (_videoUsesExternalAudio) {
              await _audio.seek(controller.value.position);
            }
            if (mounted) {
              await controller.play();
            }
          },
          beforeRollback: controller.pause,
        );
        if (!mounted) {
          return false;
        }
        setState(() {
          _playbackSpeed = _lastConfirmedVideoSpeed;
          _preferredPlaybackSpeed = _lastConfirmedVideoSpeed;
        });
        try {
          await _settings.saveMediaPlaybackSpeed(widget.speedCategory, _playbackSpeed);
        } catch (saveError) {
          AppLogger.log('media_speed_preference_save_failed error=$saveError');
        }
        if (mounted) {
          showStatusMessage(context, l10n.mediaPlaybackSpeedUnavailable);
        }
        return mounted;
      } catch (recoveryError) {
        AppLogger.log('media_speed_video_recovery_failed error=$recoveryError');
        try {
          try {
            await controller.pause();
          } finally {
            if (_videoUsesExternalAudio) {
              await _audio.pause();
            }
          }
        } catch (pauseError) {
          AppLogger.log('media_speed_pause_failed error=$pauseError');
        }
        if (mounted) {
          showStatusMessage(context, l10n.mediaPlaybackSpeedRecoveryFailed);
        }
        return false;
      }
    }
  }

  String _playbackSpeedLabel(AppLocalizations l10n, double speed) {
    final number = NumberFormat('0.##', l10n.localeName).format(speed);
    return speed == 1.0 ? '$number× (${l10n.mediaPlaybackSpeedNormal})' : '$number×';
  }

  Future<void> _choosePlaybackSpeed() async {
    if (!_canChangePlaybackSpeed || _speedPickerOpen) {
      return;
    }
    _speedPickerOpen = true;
    final episodeId = _getStableId();
    final l10n = AppLocalizations.of(context);
    try {
      final chosen = await Navigator.of(context).push<double>(
        MaterialPageRoute<double>(
          settings: const RouteSettings(name: '/media/playback-speed'),
          builder: (_) => LetterJumpOptionPickerScreen<double>(
            title: l10n.mediaPlaybackSpeed,
            options: mediaPlaybackSpeeds,
            labelBuilder: (rate) => _playbackSpeedLabel(l10n, rate),
            selectedBuilder: (rate) => rate == _playbackSpeed,
            selectedLabel: l10n.letterJumpSelected,
            selectLetterLabel: l10n.mediaPlaybackSpeed,
            selectLetterTitle: l10n.mediaPlaybackSpeed,
            enableLetterPicker: false,
          ),
        ),
      );
      if (!mounted || episodeId != _getStableId()) {
        return;
      }
      if (chosen != null && _canChangePlaybackSpeed && chosen != _playbackSpeed) {
        await _changePlaybackSpeed(chosen);
      }
    } finally {
      _speedPickerOpen = false;
      if (mounted && _showPlaybackSpeed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
            return;
          }
          if (useSharedAccessibleViewModel && !_useLandscapeFullscreenVideo) {
            unawaited(_sharedPlayerController.focusToReturn('playback_speed'));
          } else {
            _playbackSpeedFocusNode.requestFocus();
          }
        });
      }
    }
  }

  Future<void> _changePlaybackSpeed(double rate) async {
    if (!_canChangePlaybackSpeed || !mediaPlaybackSpeeds.contains(rate)) {
      return;
    }
    final video = _videoController;
    final externalAudio = video != null && _videoUsesExternalAudio;
    final wasPlaying = video?.value.isPlaying ?? _audio.isPlaying;
    final previousRate = _playbackSpeed;
    final l10n = AppLocalizations.of(context);
    setState(() => _changingPlaybackSpeed = true);

    Future<void> pauseEngines() async {
      // Attempt both pauses even if one backend rejects its operation.
      try {
        await video?.pause();
      } finally {
        if (video == null || externalAudio) {
          await _audio.pause();
        }
      }
    }

    Future<void> resumeEngines() async {
      if (!mounted || video != _videoController) {
        return;
      }
      if (wasPlaying) {
        await video?.play();
        if (video == null || externalAudio) {
          // just_audio.play completes at pause/end, not when playback starts.
          unawaited(_audio.play().catchError((Object error) {
            AppLogger.log('media_speed_resume_failed error=$error');
            if (mounted) {
              showStatusMessage(context, l10n.technicalErrorGeneric);
            }
          }));
        }
      }
    }

    try {
      await pauseEngines();
      if (!mounted) {
        return;
      }
      final position = video?.value.position ?? _audio.position;
      await applyMediaPlaybackRate(
        rate: rate,
        targets: _playbackRateTargets(video),
        afterApply: () async {
          if (!mounted) {
            return;
          }
          if (video != null && externalAudio) {
            await video.seekTo(position);
            await _audio.seek(position);
          }
          await resumeEngines();
        },
        beforeRollback: pauseEngines,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _playbackSpeed = rate;
        _preferredPlaybackSpeed = rate;
        if (video != null && wasPlaying) {
          _lastConfirmedVideoSpeed = rate;
        }
      });
      AppLogger.log('media_speed_applied category=${widget.speedCategory.name} '
          'rate=$rate externalAudio=$externalAudio');
      try {
        await _settings.saveMediaPlaybackSpeed(widget.speedCategory, rate);
      } catch (error) {
        AppLogger.log('media_speed_preference_save_failed error=$error');
      }
      if (mounted) {
        announceStatusMessage(context,
            l10n.mediaPlaybackSpeedChanged(_playbackSpeedLabel(l10n, rate)));
      }
    } catch (error) {
      AppLogger.log('media_speed_change_failed error=$error');
      if (!mounted) {
        return;
      }
      var recovered = error is MediaPlaybackRateException && !error.rollbackFailed;
      if (recovered) {
        try {
          await resumeEngines();
        } catch (_) {
          recovered = false;
        }
      }
      if (!recovered) {
        try {
          await pauseEngines();
        } catch (_) {
          // Never start another engine as an error recovery side effect.
        }
      }
      if (mounted) {
        setState(() => _playbackSpeed = previousRate);
        showStatusMessage(context, recovered
            ? l10n.mediaPlaybackSpeedUnavailable
            : l10n.mediaPlaybackSpeedRecoveryFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _changingPlaybackSpeed = false);
      }
    }
  }

  Widget _buildPlaybackSpeedButton(AppLocalizations l10n) => OutlinedButton.icon(
        key: const ValueKey('media_playback_speed'),
        focusNode: _playbackSpeedFocusNode,
        onPressed: _canChangePlaybackSpeed ? _choosePlaybackSpeed : null,
        icon: const Icon(Icons.speed),
        label: Text(
          l10n.mediaPlaybackSpeedChanged(
            _playbackSpeedLabel(l10n, _playbackSpeed),
          ),
        ),
      );

  Future<void> _loadSettings() async {
    AppLogger.log('PodcastPlayer: load seek step start, $_logSubject');
    final results = await Future.wait<Object>([
      _settings.loadSeekSliderStep(),
      _settings.loadMediaVolume(),
    ]);
    final step = results[0] as int;
    final volume = (results[1] as double).clamp(0.0, 1.0).toDouble();
    if (mounted) {
      setState(() {
        _seekStep = step;
        _accessibleVolume = volume;
        _accessibleVolumeLoaded = true;
      });
    }
    AppLogger.log(
      'PodcastPlayer: load seek step completed step=$step mounted=$mounted, '
      '$_logSubject',
    );
  }

  void _setAccessibleVolume(double value) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (mounted) {
      setState(() {
        _accessibleVolume = clamped;
        _accessibleVolumeLoaded = true;
      });
    } else {
      _accessibleVolume = clamped;
      _accessibleVolumeLoaded = true;
    }
    final controller = _videoController;
    if (controller != null && !_videoUsesExternalAudio) {
      unawaited(controller.setVolume(clamped));
    } else {
      unawaited(_audio.setVolume(clamped));
    }
    unawaited(_settings.saveMediaVolume(clamped));
  }

  Future<void> _setAccessiblePosition(Duration target) async {
    if (_changingPlaybackSpeed) {
      return;
    }
    final controller = _videoController;
    try {
      if (controller != null && controller.value.isInitialized) {
        final duration = controller.value.duration;
        final clamped = target < Duration.zero
            ? Duration.zero
            : (duration > Duration.zero && target > duration ? duration : target);
        await controller.seekTo(clamped);
        if (_videoUsesExternalAudio) {
          await _audio.seek(clamped);
        }
      } else {
        final duration = _accessibleAudioDuration;
        final clamped = target < Duration.zero
            ? Duration.zero
            : (duration > Duration.zero && target > duration ? duration : target);
        _accessibleAudioPosition = clamped;
        await _audio.seek(clamped);
      }
      if (mounted) setState(() {});
    } catch (error) {
      AppLogger.log(
        'PodcastPlayer: accessible position seek failed '
        'target=${target.inMilliseconds}ms error=$error, $_logSubject',
      );
    }
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
    _playbackSpeedFocusNode.dispose();
    _diagnosticHeartbeat?.cancel();
    _accessiblePositionRefreshTimer?.cancel();
    unawaited(_accessiblePositionSubscription?.cancel() ?? Future<void>.value());
    unawaited(_accessibleDurationSubscription?.cancel() ?? Future<void>.value());
    if (Platform.isIOS && _videoController != null) {
      unawaited(_mediaCommands.invokeMethod('clearMagicTap'));
    }
    _restoreSystemOrientation();
    unawaited(_mediaEventsSubscription?.cancel() ?? Future<void>.value());
    unawaited(_audioCompletionSubscription?.cancel() ?? Future<void>.value());
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
              onChanged: _changingPlaybackSpeed || _loading || _switchingVideoMode ? null : _toggleVideo,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (_showPlaybackSpeed) _buildPlaybackSpeedButton(l10n),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (_canNavigatePrevious)
                  FilledButton.icon(
                    key: const ValueKey('podcast_fullscreen_previous_episode'),
                    onPressed: _changingPlaybackSpeed || _loading
                        ? null
                        : () => _navigateAdjacentEpisode(-1),
                    icon: const Icon(Icons.skip_previous),
                    label: Text(widget.previousEpisodeLabel!),
                  ),
                if (canSeek)
                  FilledButton.icon(
                    onPressed: _changingPlaybackSpeed || _loading || !_loaded ? null : _seekBackward,
                    icon: const Icon(Icons.fast_rewind),
                    label: Text(l10n.rewind15s),
                  ),
                FilledButton.icon(
                  key: const ValueKey('podcast_video_fullscreen_play_pause'),
                  onPressed: _changingPlaybackSpeed || _loading ? null : _toggleVideoPlayback,
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
                    onPressed: _changingPlaybackSpeed || _loading || !_loaded ? null : _seekForward,
                    icon: const Icon(Icons.fast_forward),
                    label: Text(l10n.forward15s),
                  ),
                if (_canNavigateNext)
                  FilledButton.icon(
                    key: const ValueKey('podcast_fullscreen_next_episode'),
                    onPressed: _changingPlaybackSpeed || _loading
                        ? null
                        : () => _navigateAdjacentEpisode(1),
                    icon: const Icon(Icons.skip_next),
                    label: Text(widget.nextEpisodeLabel!),
                  ),
                for (final action in widget.extraActions)
                  FilledButton.tonalIcon(
                    key: ValueKey('podcast_fullscreen_extra_${action.id}'),
                    onPressed: _changingPlaybackSpeed || _loading ? null : () => _runExtraAction(action),
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
            const SizedBox(height: 12),
            if (_videoUsesExternalAudio)
              VolumeSlider(audioPlayer: _audio)
            else
              _VideoVolumeSlider(controller: _videoController!),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: SonarpadBackSemantics(
                        onBack: () {
                          AppLogger.log(
                            'PodcastPlayer: fullscreen back pressed, $_logSubject',
                          );
                          Navigator.pop(context);
                        },
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
              child: _buildLandscapeFullscreenControls(l10n, canSeek),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedAccessiblePlayerBody(AppLocalizations l10n, bool canSeek) {
    Widget buildControls(
      bool isPlaying,
      Duration position,
      Duration duration,
    ) {
      final videoReady =
          _videoController != null && _videoController!.value.isInitialized;
      final videoPlaying = videoReady && _videoController!.value.isPlaying;
      final hasPositionSlider = canSeek && duration > Duration.zero;

      var positionStep = _seekStep;
      if (hasPositionSlider && duration.inSeconds < positionStep) {
        positionStep = (duration.inSeconds * 0.2).round();
        if (positionStep < 1) positionStep = 1;
      }

      final clampedPosition = position < Duration.zero
          ? Duration.zero
          : (duration > Duration.zero && position > duration
              ? duration
              : position);
      final increasedPosition = hasPositionSlider
          ? clampedPosition + Duration(seconds: positionStep) > duration
              ? duration
              : clampedPosition + Duration(seconds: positionStep)
          : clampedPosition;
      final decreasedPosition = hasPositionSlider
          ? clampedPosition - Duration(seconds: positionStep) < Duration.zero
              ? Duration.zero
              : clampedPosition - Duration(seconds: positionStep)
          : clampedPosition;
      final spokenPosition = hasPositionSlider
          ? l10n.playbackPositionValue(
              l10n.formatPlaybackSpokenDuration(clampedPosition),
              l10n.formatPlaybackSpokenDuration(duration),
            )
          : null;

      final rows = <AccessibleListRow>[
        AccessibleListRow(
          id: 'now_playing_title',
          kind: 'text',
          title: l10n.nowPlayingTitle(_episode.title),
          accessibilityButtonTrait: false,
        ),
        if (_loading)
          AccessibleListRow(
            id: 'loading',
            kind: 'text',
            title: l10n.loadingEpisodeAudio,
          ),
        if (_error != null)
          AccessibleListRow(
            id: 'error',
            kind: 'text',
            title: _error!,
          ),
        if (_podcastService.hasChapterSource(_episode) ||
            (_detectedChapters?.isNotEmpty ?? false))
          AccessibleListRow(id: 'chapters', title: l10n.podcastChapters),
        if (widget.isVideoSupported)
          AccessibleListRow(
            id: 'video',
            title: l10n.enableVideo,
            kind: 'toggle',
            toggleValue: _isVideoEnabled,
            enabled: !_changingPlaybackSpeed && !_loading && !_switchingVideoMode,
          ),
        if (canSeek)
          AccessibleListRow(
            id: 'rewind',
            title: l10n.rewind15s,
            kind: 'button',
            enabled: !_changingPlaybackSpeed && !_loading && _loaded,
          ),
        AccessibleListRow(
          id: 'play_pause',
          title: _videoController != null
              ? (videoPlaying ? l10n.pause : l10n.play)
              : (isPlaying ? l10n.pause : l10n.play),
          kind: 'button',
          enabled: !_changingPlaybackSpeed && !_loading,
        ),
        if (canSeek)
          AccessibleListRow(
            id: 'forward',
            title: l10n.forward15s,
            kind: 'button',
            enabled: !_changingPlaybackSpeed && !_loading && _loaded,
          ),
        if (_showPlaybackSpeed)
          AccessibleListRow(
            id: 'playback_speed',
            title: l10n.mediaPlaybackSpeed,
            value: _playbackSpeedLabel(l10n, _playbackSpeed),
            valueLabel: _playbackSpeedLabel(l10n, _playbackSpeed),
            kind: 'button',
            enabled: _canChangePlaybackSpeed,
          ),
        if (_accessibleVolumeLoaded)
          AccessibleListRow(
            id: 'accessible_volume',
            title: l10n.adjustVolume,
            kind: 'slider',
            value: '${(_accessibleVolume * 100).round()}%',
            valueLabel: '${(_accessibleVolume * 100).round()}%',
            sliderValue: _accessibleVolume,
            sliderMin: 0.0,
            sliderMax: 1.0,
            sliderStep: 0.1,
            sliderIncreasedValueLabel:
                '${((_accessibleVolume + 0.1).clamp(0.0, 1.0) * 100).round()}%',
            sliderDecreasedValueLabel:
                '${((_accessibleVolume - 0.1).clamp(0.0, 1.0) * 100).round()}%',
            nativeSliderAccessibilityElement: true,
            enabled: !_changingPlaybackSpeed && !_loading,
          ),
        if (hasPositionSlider)
          AccessibleListRow(
            id: 'accessible_position',
            title: l10n.playbackPosition,
            kind: 'slider',
            value: spokenPosition,
            valueLabel: spokenPosition,
            sliderValue: clampedPosition.inMilliseconds / 1000.0,
            sliderMin: 0.0,
            sliderMax: duration.inMilliseconds / 1000.0,
            sliderStep: positionStep.toDouble(),
            sliderIncreasedValueLabel:
                l10n.formatPlaybackSpokenDuration(increasedPosition),
            sliderDecreasedValueLabel:
                l10n.formatPlaybackSpokenDuration(decreasedPosition),
            nativeSliderAccessibilityElement: true,
            enabled: !_changingPlaybackSpeed && !_loading && _loaded,
          ),
        if (_canNavigatePrevious)
          AccessibleListRow(
            id: 'previous_episode',
            title: widget.previousEpisodeLabel!,
            kind: 'button',
            enabled: !_changingPlaybackSpeed && !_loading,
          ),
        if (_canNavigateNext)
          AccessibleListRow(
            id: 'next_episode',
            title: widget.nextEpisodeLabel!,
            kind: 'button',
            enabled: !_changingPlaybackSpeed && !_loading,
          ),
        for (final action in widget.extraActions)
          AccessibleListRow(
            id: 'extra_${action.id}',
            title: action.label(),
            kind: 'button',
            enabled: !_changingPlaybackSpeed && !_loading,
          ),
      ];
      return UniversalAccessibleList(
        controller: _sharedPlayerController,
        sections: [AccessibleListSection(rows: rows)],
        onEvent: (event) async {
          if (_changingPlaybackSpeed) {
      return;
    }
          if (event.id == 'playback_speed' && event.type == 'activate') {
            await _choosePlaybackSpeed();
          } else if (event.id == 'accessible_volume' && event.type == 'slider') {
            final value = (event.value as num?)?.toDouble();
            if (value != null) _setAccessibleVolume(value);
          } else if (event.id == 'accessible_position' &&
              event.type == 'slider') {
            final value = (event.value as num?)?.toDouble();
            if (value != null) {
              await _setAccessiblePosition(
                Duration(milliseconds: (value * 1000).round()),
              );
            }
          } else if (event.id == 'chapters' && event.type == 'activate') {
            await _openChapters();
          } else if (event.id == 'video' && event.type == 'toggle') {
            _toggleVideo(event.value == true);
          } else if (event.id == 'previous_episode' &&
              event.type == 'activate') {
            await _navigateAdjacentEpisode(-1);
          } else if (event.id == 'rewind' && event.type == 'activate') {
            await _seekBackward();
          } else if (event.id == 'forward' && event.type == 'activate') {
            await _seekForward();
          } else if (event.id == 'next_episode' &&
              event.type == 'activate') {
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

    final controller = _videoController;
    final position = controller != null && controller.value.isInitialized
        ? controller.value.position
        : _accessibleAudioPosition;
    final duration = controller != null && controller.value.isInitialized
        ? controller.value.duration
        : _accessibleAudioDuration;

    final nativeList = controller == null
        ? StreamBuilder<bool>(
            stream: _audio.playingStream,
            builder: (context, snapshot) => buildControls(
              snapshot.data ?? false,
              position,
              duration,
            ),
          )
        : buildControls(false, position, duration);

    return Column(
      children: [
        if (controller != null && controller.value.isInitialized)
          Padding(
            padding: const EdgeInsets.all(12),
            child: ExcludeSemantics(
              child: _buildVideoPlayerSurface(controller),
            ),
          ),
        Expanded(child: nativeList),
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
      appBar: SonarpadAppBar(
        automaticallyImplyLeading: false,
        excludeHeaderSemantics: true,
        leading: SonarpadBackButton(
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
                  onChanged: _changingPlaybackSpeed || _loading || _switchingVideoMode
                      ? null
                      : _toggleVideo,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (_showPlaybackSpeed) ...[
                const SizedBox(height: 16),
                _buildPlaybackSpeedButton(l10n),
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
                      onPressed: _changingPlaybackSpeed || _loading
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
                      onPressed: _changingPlaybackSpeed || _loading ? null : _toggleVideoPlayback,
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
                      onPressed: _changingPlaybackSpeed || _loading
                          ? null
                          : () => _navigateAdjacentEpisode(1),
                      icon: const Icon(Icons.skip_next),
                      label: Text(widget.nextEpisodeLabel!),
                    ),
                  for (final action in widget.extraActions)
                    FilledButton.tonalIcon(
                      key: ValueKey('podcast_player_extra_${action.id}'),
                      onPressed: _changingPlaybackSpeed || _loading ? null : () => _runExtraAction(action),
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
              const SizedBox(height: 24),
              if (_videoController != null && !_videoUsesExternalAudio)
                _VideoVolumeSlider(controller: _videoController!)
              else
                VolumeSlider(audioPlayer: _audio),
            ],
          ),
        ),
    );
  }
}

class _VideoVolumeSlider extends StatefulWidget {
  const _VideoVolumeSlider({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_VideoVolumeSlider> createState() => _VideoVolumeSliderState();
}

class _VideoVolumeSliderState extends State<_VideoVolumeSlider> {
  final AppSettingsService _settings = AppSettingsService();
  double _volume = 1.0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadVolume();
  }

  @override
  void didUpdateWidget(covariant _VideoVolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller && _initialized) {
      unawaited(widget.controller.setVolume(_volume));
    }
  }

  Future<void> _loadVolume() async {
    final volume = await _settings.loadMediaVolume();
    if (!mounted) return;
    final clamped = volume.clamp(0.0, 1.0).toDouble();
    await widget.controller.setVolume(clamped);
    if (!mounted) return;
    setState(() {
      _volume = clamped;
      _initialized = true;
    });
  }

  void _setVolume(double value) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    setState(() => _volume = clamped);
    unawaited(widget.controller.setVolume(clamped));
    unawaited(_settings.saveMediaVolume(clamped));
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox();

    final l10n = AppLocalizations.of(context);
    final percentage = (_volume * 100).round();
    final increasedPercentage =
        ((_volume + 0.1).clamp(0.0, 1.0) * 100).round();
    final decreasedPercentage =
        ((_volume - 0.1).clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            l10n.volumeValue(percentage),
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('video_volume_slider_semantics'),
          slider: true,
          label: l10n.adjustVolume,
          value: '$percentage%',
          increasedValue: '$increasedPercentage%',
          decreasedValue: '$decreasedPercentage%',
          onIncrease: () => _setVolume((_volume + 0.1).clamp(0.0, 1.0)),
          onDecrease: () => _setVolume((_volume - 0.1).clamp(0.0, 1.0)),
          child: ExcludeSemantics(
            child: Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: _setVolume,
            ),
          ),
        ),
      ],
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
  Duration? _pendingSeekTarget;
  bool _seekDrainRunning = false;
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
      if (_seekDrainRunning || _pendingSeekTarget != null) return;
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


  void _queueSeek(Duration target) {
    _pendingSeekTarget = target;
    if (_seekDrainRunning) return;
    _seekDrainRunning = true;
    unawaited(_drainSeekQueue());
  }

  Future<void> _drainSeekQueue() async {
    try {
      while (mounted) {
        final target = _pendingSeekTarget;
        if (target == null) break;
        _pendingSeekTarget = null;
        try {
          await widget.audio.seek(target);
        } catch (error) {
          AppLogger.log(
            'PodcastPlayer: position seek failed target=${target.inSeconds}s '
            'error=$error, ${widget.logSubject}',
          );
        }
      }
    } finally {
      _seekDrainRunning = false;
      if (mounted && _pendingSeekTarget != null) {
        _seekDrainRunning = true;
        unawaited(_drainSeekQueue());
      }
    }
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
    _queueSeek(newPos);
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
            '${l10n.formatPlaybackClock(position)} / ${l10n.formatPlaybackClock(_duration)}',
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('podcast_position_slider_semantics'),
          slider: true,
          label: l10n.playbackPosition,
          value: l10n.playbackPositionValue(
            l10n.formatPlaybackSpokenDuration(position),
            l10n.formatPlaybackSpokenDuration(_duration),
          ),
          increasedValue: l10n.formatPlaybackSpokenDuration(
            position + Duration(seconds: currentStep),
          ),
          decreasedValue: l10n.formatPlaybackSpokenDuration(
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
                _queueSeek(newPos);
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
  Duration? _pendingSeekTarget;
  bool _seekDrainRunning = false;
  int _lastPositionLogSecond = -1;

  @override
  void initState() {
    super.initState();
    _visiblePosition = widget.controller.value.position;
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seekDrainRunning || _pendingSeekTarget != null) return;
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

  void _queueSeek(Duration target) {
    _pendingSeekTarget = target;
    if (_seekDrainRunning) return;
    _seekDrainRunning = true;
    unawaited(_drainSeekQueue());
  }

  Future<void> _drainSeekQueue() async {
    try {
      while (mounted) {
        final target = _pendingSeekTarget;
        if (target == null) break;
        _pendingSeekTarget = null;
        try {
          await widget.controller.seekTo(target);
          await widget.audio?.seek(target);
        } catch (error) {
          AppLogger.log(
            'PodcastPlayer: video position seek failed '
            'target=${target.inSeconds}s error=$error, ${widget.logSubject}',
          );
        }
      }
    } finally {
      _seekDrainRunning = false;
      if (mounted && _pendingSeekTarget != null) {
        _seekDrainRunning = true;
        unawaited(_drainSeekQueue());
      }
    }
  }

  void _seekTo(Duration position) {
    setState(() => _visiblePosition = position);
    _queueSeek(position);
  }

  int _computeCurrentStep(Duration duration) {
    int step = widget.seekStep;
    if (duration.inSeconds < step) {
      step = (duration.inSeconds * 0.2).round();
      if (step < 1) step = 1;
    }
    return step;
  }

  void _seekBy(int seconds) {
    final duration = widget.controller.value.duration;
    var newPos = _visiblePosition + Duration(seconds: seconds);
    if (newPos < Duration.zero) {
      newPos = Duration.zero;
    } else if (duration > Duration.zero && newPos > duration) {
      newPos = duration;
    }
    _seekTo(newPos);
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
            '${l10n.formatPlaybackClock(position)} / ${l10n.formatPlaybackClock(duration)}',
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('podcast_video_position_slider_semantics'),
          slider: true,
          label: l10n.playbackPosition,
          value: l10n.playbackPositionValue(
            l10n.formatPlaybackSpokenDuration(position),
            l10n.formatPlaybackSpokenDuration(duration),
          ),
          increasedValue: l10n.formatPlaybackSpokenDuration(
            position + Duration(seconds: currentStep),
          ),
          decreasedValue: l10n.formatPlaybackSpokenDuration(
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
                _seekTo(Duration(seconds: val.toInt()));
              },
            ),
          ),
        ),
      ],
    );
  }
}
