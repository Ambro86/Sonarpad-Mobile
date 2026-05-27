import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';

class PodcastEpisodePlayerScreen extends StatefulWidget {
  const PodcastEpisodePlayerScreen({super.key, required this.episode});

  final PodcastEpisode episode;

  @override
  State<PodcastEpisodePlayerScreen> createState() =>
      _PodcastEpisodePlayerScreenState();
}

class _PodcastEpisodePlayerScreenState
    extends State<PodcastEpisodePlayerScreen> {
  final _audio = AudioPlayerService();
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
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.episodeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pause() async {
    await _audio.pause();
  }



  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Auto-play all'apertura del player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _play();
    });
  }

  Future<void> _loadSettings() async {
    final step = await AppSettingsService().loadSeekSliderStep();
    if (mounted) setState(() => _seekStep = step);
  }

  @override
  void dispose() {
    unawaited(_audio.stop().whenComplete(_audio.dispose));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed:
                      _loading || !_loaded ? null : () => _audio.seekBackward(),
                  icon: const Icon(Icons.fast_rewind),
                  label: Text(l10n.rewind15s),
                ),
                StreamBuilder<bool>(
                  stream: _audio.playingStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return Semantics(
                      focused: true,
                      child: FilledButton.icon(
                        onPressed:
                            _loading ? null : (isPlaying ? _pause : _play),
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(isPlaying ? l10n.pause : l10n.play),
                      ),
                    );
                  },
                ),
                FilledButton.icon(
                  onPressed:
                      _loading || !_loaded ? null : () => _audio.seekForward(),
                  icon: const Icon(Icons.fast_forward),
                  label: Text(l10n.forward15s),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                          onIncrease: () => seekBy(currentStep),
                          onDecrease: () => seekBy(-currentStep),
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
