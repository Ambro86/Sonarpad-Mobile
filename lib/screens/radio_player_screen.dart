import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/audio_player_service.dart';

class RadioPlayerScreen extends StatefulWidget {
  final RadioStation station;
  const RadioPlayerScreen({super.key, required this.station});

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> {
  final _audio = AudioPlayerService();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _play();
    });
  }

  Future<void> _play() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _audio.setUrl(widget.station.streamUrl);
      if (!mounted) return;
      setState(() => _loading = false);
      unawaited(_audio.play().catchError((e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      }));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stop() async {
    await _audio.stop();
  }

  Future<void> _togglePlayback() async {
    if (_loading) return;
    if (_audio.isPlaying) {
      await _stop();
    } else {
      await _play();
    }
  }

  @override
  void dispose() {
    unawaited(_audio.stop().whenComplete(_audio.dispose));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      onTap: _togglePlayback,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Player Radio'),
          leading: BackButton(onPressed: () => Navigator.pop(context)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.station.name,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                StreamBuilder<bool>(
                  stream: _audio.playingStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return Semantics(
                      focused: true,
                      child: FilledButton.icon(
                        onPressed:
                            _loading ? null : (isPlaying ? _stop : _play),
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(isPlaying ? l10n.pause : l10n.play),
                      ),
                    );
                  },
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
      ),
    );
  }
}
