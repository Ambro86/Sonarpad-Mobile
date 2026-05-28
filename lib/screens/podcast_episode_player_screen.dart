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
    extends State<PodcastEpisodePlayerScreen> {
  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();

  VideoPlayerController? _videoController;
  bool _isVideoEnabled = false;

  bool _loaded = false;
  bool _loading = false;
  String? _error;
  int _seekStep = 60;

  Future<void> _play() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.isVideoSupported && _isVideoEnabled) {
        if (_loaded) await _audio.stop();
        _videoController?.dispose();
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.episode.audioUrl));
        await _videoController!.initialize();
        await _videoController!.play();
      } else {
        _videoController?.pause();
        _videoController?.dispose();
        _videoController = null;

        if (!_loaded) {
          final String stableId;
          if (widget.episode.id != null) {
            stableId = widget.episode.id!;
          } else {
            final uri = Uri.parse(widget.episode.audioUrl);
            stableId = 'media:${uri.scheme}://${uri.host}${uri.path}';
          }

          await _audio.setUrl(
            widget.episode.audioUrl,
            title: 'In riproduzione: ${widget.episode.title}',
            mediaId: stableId,
          );
          _loaded = true;
        }
        unawaited(_audio.play());
      }
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      AppLogger.log('PodcastPlayer: Error during _play: $e');
      setState(() => _error = l10n.episodeError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        AppLogger.log('PodcastPlayer: _play complete. loading=false, loaded=$_loaded, isVideo=${_videoController != null}');
      }
    }
  }

  Future<void> _pause() async {
    if (_videoController != null) {
      await _videoController!.pause();
      setState(() {});
    } else {
      await _audio.pause();
    }
  }

  Future<void> _toggleVideo(bool enable) async {
    setState(() => _isVideoEnabled = enable);
    await _settings.setVideoEnabled(enable);
    _loaded = false; // force reload to switch player
    _play();
  }



  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isVideoEnabled = await _settings.isVideoEnabled();
      if (!mounted) return;
      setState(() {});
      _play();
    });
  }

  Future<void> _loadSettings() async {
    final step = await AppSettingsService().loadSeekSliderStep();
    if (mounted) setState(() => _seekStep = step);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    unawaited(_audio.stop().whenComplete(_audio.dispose));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.log('PodcastPlayer: build() called. loading=$_loading, loaded=$_loaded, error=$_error, videoEnabled=$_isVideoEnabled, videoControllerInit=${_videoController?.value.isInitialized}');
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('In riproduzione: ${widget.episode.title}'),
          leading: BackButton(onPressed: () => Navigator.pop(context)),
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

                    int currentStep = _seekStep;
                    if (duration.inSeconds < currentStep) {
                      currentStep = (duration.inSeconds * 0.2).round();
                      if (currentStep < 1) currentStep = 1;
                    }

                    void seekBy(int seconds) {
                      final newPos = position + Duration(seconds: seconds);
                      if (newPos < Duration.zero) {
                        _audio.seek(Duration.zero);
                      } else if (newPos > duration) {
                        _audio.seek(duration);
                      } else {
                        _audio.seek(newPos);
                      }
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
                        Semantics(
                          container: true,
                          label: 'Posizione riproduzione',
                          value: format(position),
                          increasedValue: format(position + Duration(seconds: currentStep)),
                          decreasedValue: format(position - Duration(seconds: currentStep)),
                          onIncrease: () {
                            AppLogger.log('PodcastPlayer: VoiceOver onIncrease slider');
                            seekBy(currentStep);
                          },
                          onDecrease: () {
                            AppLogger.log('PodcastPlayer: VoiceOver onDecrease slider');
                            seekBy(-currentStep);
                          },
                          child: ExcludeSemantics(
                            child: Slider(
                              value: posSecs.clamp(0.0, durSecs),
                              min: 0,
                              max: durSecs,
                              onChanged: (val) {
                                _audio.seek(Duration(seconds: val.toInt()));
                              },
                            ),
                          ),
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
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.back),
            ),
          ],
        ),
    );
  }
}
