import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/status_message.dart';

class RequestCodeDialog extends StatefulWidget {
  const RequestCodeDialog({super.key, required this.openMail});
  final Future<bool> Function(String name, String surname, String email)
  openMail;

  @override
  State<RequestCodeDialog> createState() => _RequestCodeDialogState();
}

class _RequestCodeDialogState extends State<RequestCodeDialog> {
  final _controllers = List.generate(3, (_) => TextEditingController());
  final _focus = List.generate(3, (_) => FocusNode());
  String? _error;
  bool _opening = false;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focus) {
      node.dispose();
    }
    super.dispose();
  }

  void _showError(String message, {int? missing}) {
    setState(() => _error = message);
    if (missing != null) _focus[missing].requestFocus();
    announceStatusMessage(
      context,
      message,
      announcementDelay: const Duration(milliseconds: 300),
    );
  }

  Future<void> _submit() async {
    if (_opening) return;
    final values = _controllers.map((c) => c.text.trim()).toList();
    final l10n = AppLocalizations.of(context);
    final missing = values.indexWhere((value) => value.isEmpty);
    if (missing >= 0) {
      _showError(l10n.settingsFillFieldsCode, missing: missing);
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    bool opened;
    try {
      opened = await widget.openMail(values[0], values[1], values[2]);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (opened) {
      Navigator.pop(context);
    } else {
      _showError(l10n.settingsMailOpenError(l10n.technicalErrorGeneric));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.settingsName,
      l10n.settingsSurname,
      l10n.settingsEmail,
    ];
    return PopScope(
      canPop: !_opening,
      child: AlertDialog(
        title: Text(l10n.settingsRequestCode),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              TextField(
                controller: _controllers[i],
                focusNode: _focus[i],
                enabled: !_opening,
                decoration: InputDecoration(labelText: labels[i]),
                keyboardType: i == 2
                    ? TextInputType.emailAddress
                    : TextInputType.name,
                textInputAction: i == 2
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: (_) {
                  if (i == 2) {
                    _submit();
                  } else {
                    _focus[i + 1].requestFocus();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
            if (_error != null) Text(_error!),
            if (_opening)
              CircularProgressIndicator(semanticsLabel: l10n.loading),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _opening ? null : () => Navigator.pop(context),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            onPressed: _opening ? null : _submit,
            child: Text(l10n.settingsSend),
          ),
        ],
      ),
    );
  }
}
