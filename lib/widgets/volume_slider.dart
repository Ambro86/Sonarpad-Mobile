import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';

class VolumeSlider extends StatefulWidget {
  final AudioPlayerService audioPlayer;

  const VolumeSlider({super.key, required this.audioPlayer});

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  final AppSettingsService _settings = AppSettingsService();
  double _volume = 1.0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadVolume();
  }

  Future<void> _loadVolume() async {
    final vol = await _settings.loadMediaVolume();
    if (mounted) {
      setState(() {
        _volume = vol;
        _initialized = true;
      });
    }
  }

  void _setVolume(double newVolume) {
    final clamped = newVolume.clamp(0.0, 1.0);
    setState(() {
      _volume = clamped;
    });
    widget.audioPlayer.setVolume(clamped);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox();

    final int percentage = (_volume * 100).round();
    final String labelStr = 'Volume: $percentage%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            labelStr,
            textAlign: TextAlign.center,
          ),
        ),
        Slider(
          value: _volume,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          semanticFormatterCallback: (double value) {
            final int p = (value * 100).round();
            return 'Volume: $p%';
          },
          onChanged: _setVolume,
        ),
      ],
    );
  }
}
