import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/universal_accessible_view.dart';

class DocumentRenameScreen extends StatefulWidget {
  const DocumentRenameScreen({
    super.key,
    required this.initialName,
  });

  final String initialName;

  @override
  State<DocumentRenameScreen> createState() => _DocumentRenameScreenState();
}

class _DocumentRenameScreenState extends State<DocumentRenameScreen> {
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
      appBar: AppBar(title: Text(l10n.renameDocument)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'new_name',
                      title: l10n.newDocumentName,
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
                } else if (event.id == 'cancel' && event.type == 'activate') {
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
                    key: const ValueKey('document_rename_name'),
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(labelText: l10n.newDocumentName),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('document_rename_ok'),
                    onPressed: _canSubmit ? _submit : null,
                    child: Text(l10n.ok),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey('document_rename_cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
    );
  }
}
