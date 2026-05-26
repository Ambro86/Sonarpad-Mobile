import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
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

  Future<void> _play() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_loaded) {
        await _audio.setUrl(widget.episode.audioUrl,
            title: 'In riproduzione: ${widget.episode.title}');
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

  Future<void> _togglePlayback() async {
    if (_loading) return;
    if (_audio.isPlaying) {
      await _pause();
    } else {
      await _play();
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-play all'apertura del player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _play();
    });
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
