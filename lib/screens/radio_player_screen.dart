import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:path/path.dart' as p;
import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/audio_player_service.dart';
import '../services/radio_recording_service.dart';
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
  late final RadioRecordingService _recordingService;
  StreamSubscription<dynamic>? _mediaEventsSubscription;
  StreamSubscription<bool>? _mediaKitPlayingSubscription;
  StreamSubscription<String>? _mediaKitErrorSubscription;

  VideoPlayerController? _videoController;
  mk.Player? _mediaKitPlayer;
  mkv.VideoController? _mediaKitController;
  bool _isVideoEnabled = false;
  bool _isFavorite = false;
  bool _mediaKitPlaying = false;
  bool _mediaKitVideoSettingApplied = false;
  double _mediaKitVolume = 1.0;
  bool _recording = false;
  File? _recordingOutput;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recordingService = RadioRecordingService(
      directoryName:
          widget.tvChannel == null ? 'Radio Registrazioni' : 'TV Registrazioni',
      includeVideo: widget.tvChannel != null,
    );
    if (Platform.isIOS) {
      _mediaEventsSubscription =
          _mediaEvents.receiveBroadcastStream().listen((event) {
        if (event == 'toggle' &&
            mounted &&
            (_videoController != null || _mediaKitPlayer != null)) {
          unawaited(_toggleVideoPlayback());
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isVideoEnabled = await _settings.isVideoEnabled();
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
      if (_requiresVideoPlayback) {
        await _playMediaKitVideo();
        return;
      }

      if (widget.isVideoSupported && _isVideoEnabled) {
        await _audio.stop();
        await _disposeMediaKitPlayer();
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
        await _disposeMediaKitPlayer();
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

  Future<void> _playMediaKitVideo() async {
    await _audio.stop();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    await _disposeMediaKitPlayer();

    final player = mk.Player();
    final controller = mkv.VideoController(player);
    _mediaKitPlayer = player;
    _mediaKitController = controller;
    _mediaKitPlaying = false;
    _mediaKitVideoSettingApplied = false;
    _mediaKitVolume = await _settings.loadMediaVolume();
    var initialVolumeApplied = false;
    _mediaKitPlayingSubscription = player.stream.playing.listen((playing) {
      if (playing) {
        if (!initialVolumeApplied) {
          initialVolumeApplied = true;
          unawaited(player.setVolume(_mediaKitVolume * 100).catchError((error) {
            AppLogger.log(
              'RadioPlayer: failed to apply MediaKit volume after start: $error',
            );
          }));
        }
        if (!_mediaKitVideoSettingApplied) {
          _mediaKitVideoSettingApplied = true;
          unawaited(_applyMediaKitVideoEnabled(player, _isVideoEnabled));
        }
      }
      if (!mounted) return;
      setState(() => _mediaKitPlaying = playing);
      if (Platform.isIOS) {
        unawaited(_mediaCommands.invokeMethod('setMagicTapPlaying', playing));
      }
    });
    _mediaKitErrorSubscription = player.stream.error.listen((error) {
      AppLogger.log('RadioPlayer media_kit error: $error');
      if (!mounted) return;
      setState(() => _error = error);
    });

    if (Platform.isIOS) {
      await _mediaCommands.invokeMethod(
        'setupMagicTap',
        widget.station.name,
      );
    }
    await player.open(
      mk.Media(
        widget.station.streamUrl,
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        },
      ),
    );
  }

  Future<void> _stop() async {
    if (_mediaKitPlayer != null) {
      await _mediaKitPlayer!.pause();
      if (mounted) setState(() {});
    } else if (_videoController != null) {
      await _videoController!.pause();
      setState(() {});
    } else {
      await _audio.stop();
    }
  }

  Future<void> _applyMediaKitVideoEnabled(
    mk.Player player,
    bool enable,
  ) async {
    try {
      await player.setVideoTrack(
        enable ? mk.VideoTrack.auto() : mk.VideoTrack.no(),
      );
      AppLogger.log(
        'RadioPlayer: MediaKit video ${enable ? 'enabled' : 'disabled'} after start',
      );
    } catch (error) {
      AppLogger.log(
        'RadioPlayer: failed to apply MediaKit video setting after start: $error',
      );
    }
  }

  Future<void> _applyMpdVideoSetting(bool enable) async {
    await _settings.setVideoEnabled(enable);
    final player = _mediaKitPlayer;
    if (player == null || !_mediaKitVideoSettingApplied) return;
    await _applyMediaKitVideoEnabled(player, enable);
  }

  void _setMediaKitVolume(double value) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    setState(() => _mediaKitVolume = clamped);
    unawaited(_settings.saveMediaVolume(clamped));
    final player = _mediaKitPlayer;
    if (player != null) {
      unawaited(player.setVolume(clamped * 100).catchError((error) {
        AppLogger.log('RadioPlayer: failed to set MediaKit volume: $error');
      }));
    }
  }

  Future<void> _toggleVideoPlayback() async {
    final mediaKitPlayer = _mediaKitPlayer;
    if (mediaKitPlayer != null) {
      if (_mediaKitPlaying) {
        await mediaKitPlayer.pause();
      } else {
        await mediaKitPlayer.play();
      }
      return;
    }

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
    setState(() => _isVideoEnabled = enable);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isVideoEnabled != enable) return;
      if (_requiresVideoPlayback) {
        unawaited(_applyMpdVideoSetting(enable));
      } else {
        unawaited(_applyVideoSetting(enable));
      }
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

  Future<void> _toggleRecording() async {
    final l10n = AppLocalizations.of(context);
    try {
      if (_recording) {
        final file = await _recordingService.stop();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _recordingOutput = file;
        });
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.recordingSaved(
                file == null ? '' : p.basenameWithoutExtension(file.path),
              ),
            ),
          ),
        );
        return;
      }

      final file = await _recordingService.start(
        stationName: widget.station.name,
        streamUrl: widget.station.streamUrl,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordingOutput = file;
      });
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.recordingStarted)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordingOutput = null;
      });
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.recordingError(error))),
      );
    }
  }

  bool get _requiresVideoPlayback =>
      widget.isVideoSupported && TvService.isDashStreamUrl(widget.station.streamUrl);

  bool get _isVideoPlaying =>
      _mediaKitPlayer != null ? _mediaKitPlaying : (_videoController?.value.isPlaying ?? false);

  bool get _canRecordStream => true;

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Platform.isIOS &&
        (_videoController != null || _mediaKitPlayer != null)) {
      unawaited(_mediaCommands.invokeMethod('clearMagicTap'));
    }
    unawaited(_mediaEventsSubscription?.cancel() ?? Future<void>.value());
    unawaited(_disposeMediaKitPlayer());
    if (_recordingService.isRecording) {
      unawaited(_recordingService.stop().catchError((error) {
        AppLogger.log('RadioPlayer: recording stop during dispose failed: $error');
        return null;
      }));
    }
    _videoController?.dispose();
    unawaited(_audio.stopAndDispose());
    super.dispose();
  }

  Future<void> _disposeMediaKitPlayer() async {
    await _mediaKitPlayingSubscription?.cancel();
    await _mediaKitErrorSubscription?.cancel();
    _mediaKitPlayingSubscription = null;
    _mediaKitErrorSubscription = null;
    final player = _mediaKitPlayer;
    _mediaKitPlayer = null;
    _mediaKitController = null;
    _mediaKitPlaying = false;
    _mediaKitVideoSettingApplied = false;
    if (player != null) {
      await player.dispose();
    }
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
        leading: BackButton(
          onPressed: () {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            Navigator.pop(context);
          },
        ),
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
          if (_mediaKitController != null && _isVideoEnabled) ...[
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: mkv.Video(
                controller: _mediaKitController!,
                controls: mkv.AdaptiveVideoControls,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (_mediaKitPlayer != null || _videoController != null)
                FilledButton.icon(
                  onPressed: _loading ? null : _toggleVideoPlayback,
                  icon: Icon(_isVideoPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isVideoPlaying ? l10n.pause : l10n.play),
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
              if (_canRecordStream)
                FilledButton.icon(
                  onPressed: _loading ? null : _toggleRecording,
                  icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(_recording
                      ? l10n.stopRecording
                      : l10n.startRecording),
                ),
            ],
          ),
          if (_recordingOutput != null) ...[
            const SizedBox(height: 12),
            Text(
              p.basenameWithoutExtension(_recordingOutput!.path),
              textAlign: TextAlign.center,
            ),
          ],
          if (_videoController == null && _mediaKitPlayer == null) ...[
            const SizedBox(height: 24),
            VolumeSlider(audioPlayer: _audio),
          ],
          if (_mediaKitPlayer != null) ...[
            const SizedBox(height: 24),
            _MediaKitVolumeSlider(
              volume: _mediaKitVolume,
              onChanged: _setMediaKitVolume,
            ),
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

class _MediaKitVolumeSlider extends StatelessWidget {
  const _MediaKitVolumeSlider({
    required this.volume,
    required this.onChanged,
  });

  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percentage = (volume * 100).round();
    final label = l10n.volumeValue(percentage);
    final increased = ((volume + 0.1).clamp(0.0, 1.0) * 100).round();
    final decreased = ((volume - 0.1).clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('mediakit_volume_slider_semantics'),
          slider: true,
          label: l10n.adjustVolume,
          value: '$percentage%',
          increasedValue: '$increased%',
          decreasedValue: '$decreased%',
          onIncrease: () =>
              onChanged((volume + 0.1).clamp(0.0, 1.0).toDouble()),
          onDecrease: () =>
              onChanged((volume - 0.1).clamp(0.0, 1.0).toDouble()),
          child: ExcludeSemantics(
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
