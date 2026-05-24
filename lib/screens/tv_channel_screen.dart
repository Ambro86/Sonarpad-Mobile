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

  @override
  void initState() {
    super.initState();
    _loadGuide();
  }

  Future<void> _loadGuide() async {
    try {
      final code = await _settings.getTvSecretCode();
      final guide = await _service.loadChannelGuide(widget.channel.name, code);
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

  Future<void> _play() async {
    final station = RadioStation(
      name: widget.channel.name,
      streamUrl: widget.channel.url,
      languageCode: 'it',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RadioPlayerScreen(station: station),
      ),
    );
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
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                onPressed: _play,
                icon: const Icon(Icons.play_circle_fill, size: 32),
                label: const Text('Riproduci Diretta', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(semanticsLabel: 'Caricamento guida in corso'))
                : _error != null
                    ? Center(child: Text(_error!))
                    : _guide.isEmpty
                        ? const Center(child: Text('Nessun programma trovato per oggi.'))
                        : ListView.builder(
                            itemCount: _guide.length,
                            itemBuilder: (context, index) {
                              final program = _guide[index];
                              final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                              final isCurrent = program.startTime <= now && program.endTime > now;
                              
                              return ListTile(
                                tileColor: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
                                leading: Text(
                                  program.hour,
                                  style: TextStyle(
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                                title: Text(
                                  program.title,
                                  style: TextStyle(
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                trailing: isCurrent ? const Icon(Icons.live_tv, color: Colors.red) : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
