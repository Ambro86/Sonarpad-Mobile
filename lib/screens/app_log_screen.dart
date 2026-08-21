import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

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
    if (mounted) {
      setState(() => _loading = true);
    }
    final logs = await AppLogger.readLogs();
    if (!mounted) return;
    setState(() {
      _logContent = AppLocalizations.of(context).localizeTechnicalError(logs);
      _loading = false;
    });
  }

  Future<void> _copyLog() async {
    final logs = await AppLogger.readLogs();
    await Clipboard.setData(ClipboardData(text: logs));
    if (!mounted) return;

    showStatusMessage(
        context, AppLocalizations.of(context).logCopiedToClipboard);
  }

  Future<void> _clearLog() async {
    final l10n = AppLocalizations.of(context);
    await AppLogger.clearLogs();
    await _loadLogs();
    if (!mounted) return;

    announceStatusMessage(context, l10n.logCleared);
  }

  List<String> get _logLines =>
      _logContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

  @override
  void dispose() {
    // Non togliamo forzatamente il focus quando si lascia questa schermata:
    // su iOS/VoiceOver può contribuire alla perdita temporanea dei semantics
    // nella schermata precedente.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.systemLog),
        actions: [
          IconButton(
            icon:
                Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
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
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading))
          : useSharedAccessibleViewModel
              ? UniversalAccessibleList(
                  sections: [
                    AccessibleListSection(
                      header: l10n.systemLog,
                      rows: _logLines
                          .asMap()
                          .entries
                          .map((entry) => AccessibleListRow(
                                id: 'log_${entry.key}',
                                title: entry.value,
                                kind: 'text',
                              ))
                          .toList(growable: false),
                    ),
                  ],
                  onEvent: (_) {},
                )
              : Semantics(
              container: true,
              label: l10n.systemLog,
              hint: '${l10n.copySystemLog}. ${l10n.clearSystemLog}.',
              child: ExcludeSemantics(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logLines.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final line = _logLines[index];
                    return Text(
                      line,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
