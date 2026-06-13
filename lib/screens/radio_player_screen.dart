import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/audio_player_service.dart';
import '../services/radio_service.dart';
import '../services/tv_service.dart';
import '../widgets/volume_slider.dart';
import 'package:video_player/video_player.dart';
import '../services/app_settings_service.dart';
import '../utils/app_logger.dart';

class RadioPlayerScreen extends StatefulWidget {
  final RadioStation station;
  final bool isVideoSupported;
  final TvChannel? tvChannel;
  const RadioPlayerScreen({
    super.key,
    required this.station,
    this.isVideoSupported = false,
    this.tvChannel,
  });

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> {
  static const _mediaCommands = MethodChannel('sonarpad/tts_commands');
  static const _mediaEvents = EventChannel('sonarpad/tts_events');

  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  StreamSubscription<dynamic>? _mediaEventsSubscription;

  VideoPlayerController? _videoController;
  bool _isVideoEnabled = false;
  bool _isFavorite = false;

  bool _loading = false;
  String? _error;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isVideoEnabled = await _settings.isVideoEnabled();
      if (_requiresVideoPlayback) {
        _isVideoEnabled = true;
      }
      _isFavorite = await _loadIsFavorite();
      if (widget.tvChannel == null) {
        unawaited(RadioService().addRecentRadio(widget.station));
        unawaited(RadioService().recordRadioBrowserClick(widget.station));
      }
      if (!mounted) return;
      setState(() {});
      _play();
    });
  }

  Future<bool> _loadIsFavorite() async {
    if (widget.tvChannel != null) {
      final favorites = await TvService().loadFavorites();
      return favorites.any((item) => item.name == widget.tvChannel!.name);
    }
    final favorites = await RadioService().loadFavorites();
    return favorites.any((item) => item.streamUrl == widget.station.streamUrl);
  }

  Future<void> _play() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.isVideoSupported && _isVideoEnabled) {
        if (Platform.isIOS && _requiresVideoPlayback) {
          throw Exception(
            'Questo canale usa MPEG-DASH (.mpd), non supportato dal player iOS integrato.',
          );
        }
        await _audio.stop();
        _videoController?.dispose();
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.station.streamUrl),
          videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
        );
        await _videoController!.initialize();
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod(
            'setupMagicTap',
            widget.station.name,
          );
        }
        await _videoController!.play();
        if (Platform.isIOS) {
          await _mediaCommands.invokeMethod('setMagicTapPlaying', true);
        }
      } else {
        if (Platform.isIOS && _videoController != null) {
          await _mediaCommands.invokeMethod('clearMagicTap');
        }
        _videoController?.pause();
        _videoController?.dispose();
        _videoController = null;
        await _audio.setUrl(widget.station.streamUrl,
            title: l10n.nowPlayingTitle(widget.station.name));
        if (!mounted) return;
        unawaited(_audio.play().catchError((e) {
          if (!mounted) return;
          setState(() => _error = e.toString());
        }));
      }
    } catch (e) {
      if (!mounted) return;
      AppLogger.log('RadioPlayer: Error during _play: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        AppLogger.log(
            'RadioPlayer: _play complete. loading=false, isVideo=${_videoController != null}');
      }
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

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
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
    if (_requiresVideoPlayback && !enable) return;
    setState(() => _isVideoEnabled = enable);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isVideoEnabled != enable) return;
      unawaited(_applyVideoSetting(enable));
    });
  }

  Future<void> _applyVideoSetting(bool enable) async {
    await _settings.setVideoEnabled(enable);
    await _play();
  }

  Future<void> _toggleFavorite() async {
    final l10n = AppLocalizations.of(context);
    if (widget.tvChannel != null) {
      final service = TvService();
      final channel = widget.tvChannel!;
      final favorites = await service.loadFavorites();
      final alreadyFavorite =
          favorites.any((item) => item.name == channel.name);
      final next = alreadyFavorite
          ? favorites.where((item) => item.name != channel.name).toList()
          : [...favorites, channel];
      await service.saveFavorites(next);
      if (!mounted) return;
      setState(() => _isFavorite = !alreadyFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alreadyFavorite
              ? l10n.radioFavoriteRemoved(channel.name)
              : l10n.radioFavoriteAdded(channel.name)),
        ),
      );
      return;
    }

    final service = RadioService();
    final favorites = await service.loadFavorites();
    final alreadyFavorite = favorites.any(
      (item) => item.streamUrl == widget.station.streamUrl,
    );
    final next = alreadyFavorite
        ? favorites
            .where((item) => item.streamUrl != widget.station.streamUrl)
            .toList()
        : [...favorites, widget.station];
    await service.saveFavorites(next);
    if (!mounted) return;
    setState(() => _isFavorite = !alreadyFavorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(alreadyFavorite
            ? l10n.radioFavoriteRemoved(widget.station.name)
            : l10n.radioFavoriteAdded(widget.station.name)),
      ),
    );
  }

  bool get _requiresVideoPlayback =>
      widget.isVideoSupported && TvService.isDashStreamUrl(widget.station.streamUrl);

  @override
  void dispose() {
    if (Platform.isIOS && _videoController != null) {
      unawaited(_mediaCommands.invokeMethod('clearMagicTap'));
    }
    unawaited(_mediaEventsSubscription?.cancel() ?? Future<void>.value());
    _videoController?.dispose();
    unawaited(_audio.stopAndDispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.log(
        'RadioPlayer: build() called. loading=$_loading, error=$_error, videoEnabled=$_isVideoEnabled, videoControllerInit=${_videoController?.value.isInitialized}');
    final l10n = AppLocalizations.of(context);
    final showStationDetails =
        widget.tvChannel == null && widget.station.detailsText.trim().isNotEmpty;
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
          if (showStationDetails) ...[
            const SizedBox(height: 8),
            Text(
              widget.station.detailsText,
              textAlign: TextAlign.center,
            ),
          ],
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
              contentPadding: EdgeInsets.zero,
            ),
          ],
          if (_videoController != null &&
              _videoController!.value.isInitialized) ...[
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
                FilledButton.icon(
                  onPressed: _loading ? null : _toggleVideoPlayback,
                  icon: Icon(_videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow),
                  label: Text(_videoController!.value.isPlaying
                      ? l10n.pause
                      : l10n.play),
                )
              else
                StreamBuilder<bool>(
                  stream: _audio.playingStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return FilledButton.icon(
                      onPressed: _loading ? null : (isPlaying ? _stop : _play),
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(isPlaying ? l10n.pause : l10n.play),
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
            onPressed: _toggleFavorite,
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            label: Text(
              _isFavorite ? l10n.radioRemoveFavorite : l10n.radioAddFavorite,
            ),
          ),
        ],
      ),
    );
  }
}
