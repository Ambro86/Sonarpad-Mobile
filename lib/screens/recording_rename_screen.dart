import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';


Future<File?> showAndRenameRecording(
  BuildContext context,
  File file, {
  required String routeName,
}) async {
  final l10n = AppLocalizations.of(context);
  final originalName = p.basenameWithoutExtension(file.path);
  final requestedName = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      settings: RouteSettings(name: routeName),
      builder: (_) => RecordingRenameScreen(initialName: originalName),
    ),
  );
  if (!context.mounted || requestedName == null) return null;

  var newName = requestedName.trim();
  if (newName.isEmpty || newName == originalName) return null;

  final extension = p.extension(file.path);
  if (extension.isNotEmpty &&
      newName.toLowerCase().endsWith(extension.toLowerCase())) {
    newName = newName.substring(0, newName.length - extension.length).trim();
    if (newName.isEmpty || newName == originalName) return null;
  }

  final target = File(p.join(file.parent.path, '$newName$extension'));
  if (await target.exists()) {
    if (context.mounted) {
      showStatusMessage(context, l10n.recordingNameAlreadyExists);
    }
    return null;
  }

  try {
    return await file.rename(target.path);
  } catch (_) {
    if (context.mounted) {
      showStatusMessage(
        context,
        l10n.error(l10n.technicalErrorGeneric),
      );
    }
    return null;
  }
}

class RecordingRenameScreen extends StatefulWidget {
  const RecordingRenameScreen({
    super.key,
    required this.initialName,
  });

  final String initialName;

  @override
  State<RecordingRenameScreen> createState() => _RecordingRenameScreenState();
}

class _RecordingRenameScreenState extends State<RecordingRenameScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.renameRecording),
      ),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'new_name',
                      title: l10n.newRecordingName,
                      kind: 'textField',
                      value: _controller.text,
                      textInputAction: 'done',
                      onSubmitted: (_) => _submit(),
                    ),
                    AccessibleListRow(
                      id: 'ok',
                      title: l10n.ok,
                      kind: 'button',
                      enabled: _canSubmit,
                    ),
                    AccessibleListRow(
                      id: 'cancel',
                      title: l10n.cancel,
                      kind: 'button',
                    ),
                  ],
                ),
              ],
              onEvent: (event) {
                if (event.id == 'new_name' && event.type == 'textChanged') {
                  setState(() {
                    _controller.text = event.value?.toString() ?? '';
                  });
                } else if (event.id == 'ok' && event.type == 'activate') {
                  _submit();
                } else if (event.id == 'cancel' &&
                    event.type == 'activate') {
                  Navigator.of(context).pop();
                }
              },
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('recording_rename_name'),
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.newRecordingName,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('recording_rename_ok'),
                    onPressed: _canSubmit ? _submit : null,
                    child: Text(l10n.ok),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey('recording_rename_cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
    );
  }
}
