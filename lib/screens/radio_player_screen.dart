import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/audio_player_service.dart';
import '../widgets/volume_slider.dart';
import 'package:video_player/video_player.dart';
import '../services/app_settings_service.dart';

class RadioPlayerScreen extends StatefulWidget {
  final RadioStation station;
  final bool isVideoSupported;
  const RadioPlayerScreen({super.key, required this.station, this.isVideoSupported = false});

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> {
  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  
  VideoPlayerController? _videoController;
  bool _isVideoEnabled = false;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isVideoEnabled = await _settings.isVideoEnabled();
      if (!mounted) return;
      setState(() {});
      _play();
    });
  }

  Future<void> _play() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.isVideoSupported && _isVideoEnabled) {
        await _audio.stop();
        _videoController?.dispose();
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.station.streamUrl));
        await _videoController!.initialize();
        await _videoController!.play();
      } else {
        _videoController?.pause();
        _videoController?.dispose();
        _videoController = null;
        await _audio.setUrl(widget.station.streamUrl,
            title: 'In riproduzione: ${widget.station.name}');
        if (!mounted) return;
        unawaited(_audio.play().catchError((e) {
          if (!mounted) return;
          setState(() => _error = e.toString());
        }));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stop() async {
    if (_videoController != null) {
      await _videoController!.pause();
      setState(() {});
    } else {
      await _audio.stop();
    }
  }

  Future<void> _toggleVideo(bool enable) async {
    setState(() => _isVideoEnabled = enable);
    await _settings.setVideoEnabled(enable);
    _play();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    unawaited(_audio.stop().whenComplete(_audio.dispose));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.nowPlaying}: ${widget.station.name}'),
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
              if (_videoController != null)
                Semantics(
                  focused: true,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : (_videoController!.value.isPlaying ? _stop : _play),
                    icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(_videoController!.value.isPlaying ? l10n.pause : l10n.play),
                  ),
                )
              else
                StreamBuilder<bool>(
                  stream: _audio.playingStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return Semantics(
                      focused: true,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : (isPlaying ? _stop : _play),
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(isPlaying ? l10n.pause : l10n.play),
                      ),
                    );
                  },
                ),
            ],
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
