import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../services/tv_service.dart';
import 'tv_channel_screen.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  final _settings = AppSettingsService();
  final _service = TvService();

  List<TvChannel> _channels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final code = await _settings.getTvSecretCode();
    try {
      final channels = _service.loadChannels(code);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore durante la decodifica dei canali: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openChannel(TvChannel channel) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TvChannelScreen(channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TV in diretta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildList(),
    );
  }

  Widget _buildList() {
    if (_channels.isEmpty) {
      return const Center(
          child: Text(
              'Nessun canale TV trovato. Controlla il codice inserito nelle impostazioni.'));
    }

    final map = <String, List<TvChannel>>{};
    for (var ch in _channels) {
      map.putIfAbsent(ch.category, () => []).add(ch);
    }

    final categories = ['Rai', 'Mediaset', 'Regionali', 'Altri'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: categories.where((c) => map.containsKey(c)).map((c) {
        return ExpansionTile(
          initiallyExpanded: c == 'Rai',
          title: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
          children: map[c]!.map((ch) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.tv),
                title: Text(ch.name),
                onTap: () => _openChannel(ch),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
