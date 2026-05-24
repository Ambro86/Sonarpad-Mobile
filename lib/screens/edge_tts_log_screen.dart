import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class EdgeTtsLogScreen extends StatefulWidget {
  const EdgeTtsLogScreen({super.key});

  @override
  State<EdgeTtsLogScreen> createState() => _EdgeTtsLogScreenState();
}

class _EdgeTtsLogScreenState extends State<EdgeTtsLogScreen> {
  String _logContent = 'Caricamento log...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final dir = await getTemporaryDirectory();
      final List<File> logFiles = [];
      
      if (await dir.exists()) {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.log.txt')) {
            logFiles.add(entity);
          }
        }
      }

      if (logFiles.isEmpty) {
        if (!mounted) return;
        setState(() {
          _logContent = 'Nessun log trovato. Prova ad avviare una lettura Edge TTS prima.';
          _loading = false;
        });
        return;
      }

      // Ordina i file dal più recente al più vecchio
      logFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // Prendi gli ultimi 5 log per non appesantire troppo
      final buffer = StringBuffer();
      final filesToRead = logFiles.take(5).toList();
      
      for (final file in filesToRead) {
        buffer.writeln('=== LOG: ${file.path.split(Platform.pathSeparator).last} ===');
        try {
          final content = await file.readAsString();
          buffer.writeln(content.trim());
        } catch (e) {
          buffer.writeln('Errore lettura file: $e');
        }
        buffer.writeln('\n----------------------------------------\n');
      }

      if (!mounted) return;
      setState(() {
        _logContent = buffer.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logContent = 'Errore caricamento log: $e';
        _loading = false;
      });
    }
  }

  void _copyLog() {
    Clipboard.setData(ClipboardData(text: _logContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log copiato negli appunti')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Edge TTS'),
        actions: [
          Semantics(
            button: true,
            label: 'Copia log negli appunti',
            child: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copia log',
              onPressed: _loading ? null : _copyLog,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _logContent,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
      ),
    );
  }
}
