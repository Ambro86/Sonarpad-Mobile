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
  bool _playing = false;
  String? _error;

  Future<void> _play() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_loaded) {
        await _audio.setUrl(widget.episode.audioUrl);
        _loaded = true;
      }
      unawaited(_audio.play());
      if (!mounted) return;
      setState(() => _playing = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.episodeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pause() async {
    await _audio.pause();
    if (!mounted) return;
    setState(() => _playing = false);
  }

  Future<void> _stop() async {
    await _audio.stop();
    if (!mounted) return;
    setState(() {
      _loaded = false;
      _playing = false;
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
        title: Text(l10n.episodePlayer),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.episode.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (widget.episode.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(widget.episode.description),
          ],
          const SizedBox(height: 24),
          if (_loading)
            LinearProgressIndicator(semanticsLabel: l10n.loadingEpisodeAudio),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _loading || _playing ? null : _play,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.play),
              ),
              FilledButton.icon(
                onPressed: _playing ? _pause : null,
                icon: const Icon(Icons.pause),
                label: Text(l10n.pause),
              ),
              OutlinedButton.icon(
                onPressed: _loaded || _playing ? _stop : null,
                icon: const Icon(Icons.stop),
                label: Text(l10n.stop),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.back),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
