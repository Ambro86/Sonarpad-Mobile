import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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

    final l10n = AppLocalizations.of(context);
    final int percentage = (_volume * 100).round();
    final String labelStr = l10n.volumeValue(percentage);

    final int increasedPercentage =
        ((_volume + 0.1).clamp(0.0, 1.0) * 100).round();
    final int decreasedPercentage =
        ((_volume - 0.1).clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            labelStr,
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          key: const ValueKey('volume_slider_semantics'),
          slider: true,
          label: l10n.adjustVolume,
          value: '$percentage%',
          increasedValue: '$increasedPercentage%',
          decreasedValue: '$decreasedPercentage%',
          onIncrease: () => _setVolume((_volume + 0.1).clamp(0.0, 1.0)),
          onDecrease: () => _setVolume((_volume - 0.1).clamp(0.0, 1.0)),
          child: ExcludeSemantics(
            child: Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: _setVolume,
            ),
          ),
        ),
      ],
    );
  }
}
