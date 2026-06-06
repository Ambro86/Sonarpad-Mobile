import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/volume_slider.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_logger.dart';

class PodcastEpisodePlayerScreen extends StatefulWidget {
  const PodcastEpisodePlayerScreen({
    super.key,
    required this.episode,
    this.isVideoSupported = false,
    this.startWithVideo = false,
  });

  final PodcastEpisode episode;
  final bool isVideoSupported;
  final bool startWithVideo;

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
  StreamSubscription<dynamic>? _mediaEventsSubscription;

  VideoPlayerController? _videoController;
  bool _isVideoEnabled = false;

  bool _loaded = false;
  bool _loading = false;
  String? _error;
  int _seekStep = 60;
  int _lastVideoBookmarkSecond = -1;
  Timer? _diagnosticHeartbeat;
  AppLifecycleState? _lastLifecycleState;

  String get _logSubject =>
      'episodeTitle="${widget.episode.title}", url=${widget.episode.audioUrl}, '
      'stableId=${_getStableId()}';

  String _getStableId() {
    if (widget.episode.id != null) {
      return widget.episode.id!;
    }
    final uri = Uri.parse(widget.episode.audioUrl);
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

  Future<void> _play() async {
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
        if (_loaded) await _audio.stop();
        _videoController?.dispose();
        final uri = Uri.parse(widget.episode.audioUrl);
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
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod(
            'setupMagicTap',
            widget.episode.title,
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
        if (await _settings.isAutoBookmarkEnabled()) {
          final savedPos = await _settings.getMediaBookmark(stableId);
          if (savedPos != null && savedPos >= 3) {
            final dur = _videoController!.value.duration;
            if (savedPos < (dur.inSeconds - 30)) {
              await _videoController!.seekTo(Duration(seconds: savedPos));
            }
          }
        }

        AppLogger.log('PodcastPlayer: video play start, $_logSubject');
        await _videoController!.play();
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod('setMagicTapPlaying', true);
        }
        AppLogger.log('PodcastPlayer: video play completed, $_logSubject');
      } else {
        AppLogger.log(
          'PodcastPlayer: audio branch start loaded=$_loaded, $_logSubject',
        );
        await _saveVideoBookmark();
        if (Platform.isIOS && _videoController != null) {
          await _mediaCommands.invokeMethod('clearMagicTap');
        }
        _videoController?.pause();
        _videoController?.dispose();
        _videoController = null;

        if (!_loaded) {
          AppLogger.log('PodcastPlayer: audio setUrl start, $_logSubject');
          await _audio.setUrl(
            widget.episode.audioUrl,
            title: l10n.nowPlayingTitle(widget.episode.title),
            mediaId: _getStableId(),
          );
          _loaded = true;
          AppLogger.log(
            'PodcastPlayer: audio setUrl completed loaded=$_loaded, '
            'title="In riproduzione: ${widget.episode.title}", $_logSubject',
          );
        }
        AppLogger.log(
          'PodcastPlayer: audio play scheduled, '
          'title="In riproduzione: ${widget.episode.title}", $_logSubject',
        );
        unawaited(_audio.play().catchError((Object e, StackTrace stackTrace) {
          AppLogger.log(
            'PodcastPlayer: audio play async error: $e, $_logSubject',
          );
        }));
      }
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      AppLogger.log('PodcastPlayer: Error during _play: $e, $_logSubject');
      setState(() => _error = l10n.episodeError(e));
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

  Future<void> _pause() async {
    AppLogger.log(
      'PodcastPlayer: _pause start video=${_videoController != null} '
      'loaded=$_loaded loading=$_loading, $_logSubject',
    );
    if (_videoController != null) {
      await _videoController!.pause();
      await _saveVideoBookmark();
      setState(() {});
    } else {
      await _audio.pause();
    }
  }

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      await _saveVideoBookmark();
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
    AppLogger.log('PodcastPlayer: _toggleVideo enable=$enable, $_logSubject');
    setState(() => _isVideoEnabled = enable);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isVideoEnabled != enable) return;
      unawaited(_applyVideoSetting(enable));
    });
  }

  Future<void> _applyVideoSetting(bool enable) async {
    if (_videoController != null && _videoController!.value.isPlaying) {
      await _pause();
    }
    await _settings.setVideoEnabled(enable);
    _loaded = false; // force reload to switch player
    await _play().catchError((Object e, StackTrace stackTrace) {
      AppLogger.log('PodcastPlayer: _toggleVideo _play error: $e, $_logSubject');
    });
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
      'PodcastPlayer: initState title=${widget.episode.title} '
      'url=${widget.episode.audioUrl} isVideoSupported=${widget.isVideoSupported}, '
      '$_logSubject',
    );
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AppLogger.log(
        'PodcastPlayer: postFrame callback start mounted=$mounted, $_logSubject',
      );
      _isVideoEnabled =
          widget.startWithVideo || await _settings.isVideoEnabled();
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
    _lastLifecycleState = state;
    AppLogger.log(
      'PodcastPlayer: lifecycle state=$state mounted=$mounted '
      'loaded=$_loaded loading=$_loading video=${_videoController != null}, '
      '$_logSubject',
    );
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
    unawaited(_mediaEventsSubscription?.cancel() ?? Future<void>.value());
    unawaited(_saveVideoBookmark());
    _videoController?.dispose();
    unawaited(_audio.stopAndDispose());
    super.dispose();
    AppLogger.log('PodcastPlayer: dispose end, $_logSubject');
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.log(
      'PodcastPlayer: build() called. loading=$_loading, loaded=$_loaded, '
      'error=$_error, videoEnabled=$_isVideoEnabled, '
      'videoControllerInit=${_videoController?.value.isInitialized}, '
      '$_logSubject',
    );
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nowPlayingTitle(widget.episode.title)),
          leading: BackButton(
            onPressed: () {
              AppLogger.log('PodcastPlayer: appbar back pressed, $_logSubject');
              Navigator.pop(context);
            },
          ),
        ),
        body: Semantics(
          container: Platform.isIOS,
          explicitChildNodes: Platform.isIOS,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.episode.title,
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
              if (widget.isVideoSupported) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(l10n.enableVideo),
                  value: _isVideoEnabled,
                  onChanged: _toggleVideo,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (_videoController != null && _videoController!.value.isInitialized) ...[
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (_videoController == null)
                    FilledButton.icon(
                      onPressed:
                          _loading || !_loaded ? null : () => _audio.seekBackward(),
                      icon: const Icon(Icons.fast_rewind),
                      label: Text(l10n.rewind15s),
                    ),
                  if (_videoController != null)
                    FilledButton.icon(
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
                  if (_videoController == null)
                    FilledButton.icon(
                      onPressed:
                          _loading || !_loaded ? null : () => _audio.seekForward(),
                      icon: const Icon(Icons.fast_forward),
                      label: Text(l10n.forward15s),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (_videoController == null)
                _PodcastPositionControl(
                  audio: _audio,
                  seekStep: _seekStep,
                  logSubject: _logSubject,
                ),
              if (_videoController == null) ...[
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
