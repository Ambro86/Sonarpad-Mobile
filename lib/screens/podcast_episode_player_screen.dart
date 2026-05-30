import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/volume_slider.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_logger.dart';

class PodcastEpisodePlayerScreen extends StatefulWidget {
  const PodcastEpisodePlayerScreen({super.key, required this.episode, this.isVideoSupported = false});

  final PodcastEpisode episode;
  final bool isVideoSupported;

  @override
  State<PodcastEpisodePlayerScreen> createState() =>
      _PodcastEpisodePlayerScreenState();
}

class _PodcastEpisodePlayerScreenState
    extends State<PodcastEpisodePlayerScreen> with WidgetsBindingObserver {
  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();

  VideoPlayerController? _videoController;
  bool _isVideoEnabled = false;

  bool _loaded = false;
  bool _loading = false;
  String? _error;
  int _seekStep = 60;
  int _lastLoggedSecond = -1;

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
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.episode.audioUrl));
        AppLogger.log('PodcastPlayer: video initialize start, $_logSubject');
        await _videoController!.initialize();
        AppLogger.log('PodcastPlayer: video initialize completed, $_logSubject');

        _videoController!.addListener(() {
          if (!mounted || _videoController == null) return;
          final currentSecond = _videoController!.value.position.inSeconds;
          if (currentSecond > 0 && currentSecond % 15 == 0) {
            if (_lastLoggedSecond != currentSecond) {
               _lastLoggedSecond = currentSecond;
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
        AppLogger.log('PodcastPlayer: video play completed, $_logSubject');
      } else {
        AppLogger.log(
          'PodcastPlayer: audio branch start loaded=$_loaded, $_logSubject',
        );
        await _saveVideoBookmark();
        _videoController?.pause();
        _videoController?.dispose();
        _videoController = null;

        if (!_loaded) {
          AppLogger.log('PodcastPlayer: audio setUrl start, $_logSubject');
          await _audio.setUrl(
            widget.episode.audioUrl,
            title: 'In riproduzione: ${widget.episode.title}',
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

  Future<void> _toggleVideo(bool enable) async {
    AppLogger.log('PodcastPlayer: _toggleVideo enable=$enable, $_logSubject');
    if (_videoController != null && _videoController!.value.isPlaying) {
      await _pause();
    }
    setState(() => _isVideoEnabled = enable);
    await _settings.setVideoEnabled(enable);
    _loaded = false; // force reload to switch player
    unawaited(_play().catchError((Object e, StackTrace stackTrace) {
      AppLogger.log('PodcastPlayer: _toggleVideo _play error: $e, $_logSubject');
    }));
  }



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _isVideoEnabled = await _settings.isVideoEnabled();
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
        title: Text('In riproduzione: ${widget.episode.title}'),
          leading: BackButton(
            onPressed: () {
              AppLogger.log('PodcastPlayer: appbar back pressed, $_logSubject');
              Navigator.pop(context);
            },
          ),
        ),
        body: ListView(
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
                    onPressed:
                        _loading ? null : (_videoController!.value.isPlaying ? _pause : _play),
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
              StreamBuilder<Duration?>(
              stream: _audio.durationStream,
              builder: (context, durSnapshot) {
                final duration = durSnapshot.data ?? Duration.zero;
                if (duration == Duration.zero) return const SizedBox();

                return StreamBuilder<Duration>(
                  stream: _audio.positionStream,
                  builder: (context, posSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;

                    // Logga solo al cambio di secondo per non esplodere la console
                    if (_lastLoggedSecond != position.inSeconds) {
                        _lastLoggedSecond = position.inSeconds;
                        AppLogger.log('PodcastPlayer: positionStream builder called, pos: ${position.inSeconds}s, dur: ${duration.inSeconds}s');
                    }

                    int currentStep = _seekStep;
                    if (duration.inSeconds < currentStep) {
                      currentStep = (duration.inSeconds * 0.2).round();
                      if (currentStep < 1) currentStep = 1;
                    }

                    String format(Duration d) {
                      final mins = d.inMinutes;
                      final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
                      return '$mins:$secs';
                    }

                    final posSecs = position.inSeconds.toDouble();
                    final durSecs = duration.inSeconds.toDouble();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            '${format(position)} / ${format(duration)}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Slider(
                          value: posSecs.clamp(0.0, durSecs),
                          min: 0,
                          max: durSecs,
                          semanticFormatterCallback: (double value) {
                            return format(Duration(seconds: value.toInt()));
                          },
                          onChanged: (val) {
                            _audio.seek(Duration(seconds: val.toInt()));
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            if (_videoController == null) ...[
              const SizedBox(height: 24),
              VolumeSlider(audioPlayer: _audio),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                AppLogger.log('PodcastPlayer: bottom back pressed, $_logSubject');
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.back),
            ),
          ],
        ),
    );
  }
}
