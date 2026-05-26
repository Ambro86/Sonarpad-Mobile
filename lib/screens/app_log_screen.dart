import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_logger.dart';

class AppLogScreen extends StatefulWidget {
  const AppLogScreen({super.key});

  @override
  State<AppLogScreen> createState() => _AppLogScreenState();
}

class _AppLogScreenState extends State<AppLogScreen> {
  String _logContent = 'Caricamento log...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final logs = await AppLogger.readLogs();
    setState(() {
      _logContent = logs;
      _loading = false;
    });
  }

  void _copyLog() {
    Clipboard.setData(ClipboardData(text: _logContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log copiato negli appunti')),
    );
  }

  Future<void> _clearLog() async {
    await AppLogger.clearLogs();
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log di Sistema'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            tooltip: 'Svuota log',
            onPressed: _loading ? null : _clearLog,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copia log',
            onPressed: _loading ? null : _copyLog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _logContent,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
    );
  }
}
