import 'dart:io';

import 'package:flutter/material.dart';

import '../models/radio_station.dart';
import '../services/app_settings_service.dart';
import '../services/tv_service.dart';
import 'radio_player_screen.dart';

class TvChannelScreen extends StatefulWidget {
  final TvChannel channel;

  const TvChannelScreen({super.key, required this.channel});

  @override
  State<TvChannelScreen> createState() => _TvChannelScreenState();
}

class _TvChannelScreenState extends State<TvChannelScreen> {
  final _settings = AppSettingsService();
  final _service = TvService();

  List<TvProgram> _guide = [];
  bool _loading = true;
  String? _error;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadGuide();
  }

  Future<void> _loadGuide() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await _settings.getTvSecretCode();
      final guide = await _service.loadChannelGuide(
        _service.guideChannelName(widget.channel),
        code,
        targetDate: _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _guide = guide;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile caricare la guida TV per ${widget.channel.name}.';
        _loading = false;
      });
    }
  }

  String _getLabelForDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;
    if (diff == -1) return 'Ieri';
    if (diff == 0) return 'Oggi';
    if (diff == 1) return 'Domani';
    if (diff == 2) return 'Dopodomani';
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _selectDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        DateTime tempDate = _selectedDate;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Scegli giorno'),
              content: RadioGroup<DateTime>(
                groupValue: tempDate,
                onChanged: (value) {
                  if (value != null) setStateDialog(() => tempDate = value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [-1, 0, 1, 2].map((offset) {
                    final d = today.add(Duration(days: offset));
                    return RadioListTile<DateTime>(
                      title: Text(_getLabelForDate(d)),
                      value: d,
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, tempDate),
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null && selected != _selectedDate) {
      setState(() => _selectedDate = selected);
      _loadGuide();
    }
  }

  Future<void> _play() async {
    try {
      final isRaiAd = _service.isRaiAudioDescriptionChannel(widget.channel);

      // Su iOS: per i canali RAI tentiamo la traccia di audiodescrizione.
      // resolveAudioDescriptionStreamUrl scarica il master HLS, cerca
      // EXT-X-MEDIA con LANGUAGE="des" / NAME="Audiodescrizione" /
      // CHARACTERISTICS contains "describes-video" e restituisce quell'URI.
      // Se la traccia non c'è, cade back sull'URL principale.
      final String resolvedUrl;
      if (!Platform.isWindows && isRaiAd) {
        resolvedUrl =
            await _service.resolveAudioDescriptionStreamUrl(widget.channel);
      } else {
        resolvedUrl = await _service.resolveStreamUrl(widget.channel);
      }

      if (!mounted) return;

      if (Platform.isWindows) {
        await _playWithExternalWindowsPlayer(
          resolvedUrl,
          preferAudioDescription: isRaiAd,
        );
        return;
      }

      final station = RadioStation(
        name: widget.channel.name,
        streamUrl: resolvedUrl,
        languageCode: 'it',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/tv/channel/player'),
          builder: (_) => RadioPlayerScreen(
            station: station,
            isVideoSupported: true,
            tvChannel: widget.channel,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile avviare la diretta: $e')),
      );
    }
  }

  Future<void> _playWithExternalWindowsPlayer(
    String url, {
    required bool preferAudioDescription,
  }) async {
    final ffplayArgs = [
      '-user_agent',
      'Sonarpad TV/1.0',
      if (preferAudioDescription) ...['-ast', 'a:2'],
      '-nodisp',
      '-loglevel',
      'warning',
      url,
    ];
    try {
      await Process.start(
        'ffplay.exe',
        ffplayArgs,
        mode: ProcessStartMode.detached,
      );
      return;
    } on ProcessException {
      // Continue with VLC fallback below.
    }

    const vlcPaths = [
      r'C:\Program Files\VideoLAN\VLC\vlc.exe',
      r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe',
    ];
    for (final path in vlcPaths) {
      if (await File(path).exists()) {
        await Process.start(
          path,
          [
            '--http-user-agent=Sonarpad TV/1.0',
            if (preferAudioDescription) '--audio-track=2',
            url,
          ],
          mode: ProcessStartMode.detached,
        );
        return;
      }
    }

    throw Exception('ffplay o VLC non trovato per riprodurre la diretta.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              hint: 'Guarda ${widget.channel.name} in diretta',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64)),
                onPressed: _play,
                icon: const Icon(Icons.play_circle_fill, size: 32),
                label: const Text('Riproduci Diretta',
                    style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: _selectDay,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                'Giorno: ${_getLabelForDate(_selectedDate)}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        semanticsLabel: 'Caricamento guida in corso'))
                : _error != null
                    ? Center(child: Text(_error!))
                    : _guide.isEmpty
                        ? const Center(
                            child: Text('Nessun programma trovato per oggi.'))
                        : ListView.builder(
                            itemCount: _guide.length,
                            itemBuilder: (context, index) {
                              final program = _guide[index];
                              final now =
                                  DateTime.now().millisecondsSinceEpoch ~/ 1000;
                              final isCurrent = program.startTime <= now &&
                                  program.endTime > now;

                              return ListTile(
                                tileColor: isCurrent
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : null,
                                leading: Text(
                                  program.hour,
                                  style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                                title: Text(
                                  program.title,
                                  style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                trailing: isCurrent
                                    ? const Icon(Icons.live_tv,
                                        color: Colors.red)
                                    : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
