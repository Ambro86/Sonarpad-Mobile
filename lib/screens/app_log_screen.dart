import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../utils/app_logger.dart';

class AppLogScreen extends StatefulWidget {
  const AppLogScreen({super.key});

  @override
  State<AppLogScreen> createState() => _AppLogScreenState();
}

class _AppLogScreenState extends State<AppLogScreen> {
  String _logContent = '';
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

  Future<void> _copyLog() async {
    final logs = await AppLogger.readLogs();
    if (!mounted) return;
    setState(() => _logContent = logs);
    await Clipboard.setData(ClipboardData(text: logs));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).logCopiedToClipboard)),
    );
  }

  Future<void> _clearLog() async {
    await AppLogger.clearLogs();
    await _loadLogs();
  }

  List<String> get _logLines => _logContent
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.systemLog),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            tooltip: l10n.clearSystemLog,
            onPressed: _loading ? null : _clearLog,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.copySystemLog,
            onPressed: _loading ? null : _copyLog,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(semanticsLabel: l10n.loading))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _logLines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final line = _logLines[index];
                return SelectableText(
                  line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                );
              },
            ),
    );
  }
}
