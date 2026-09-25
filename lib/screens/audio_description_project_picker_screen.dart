import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../services/audio_description_project_library.dart';
import '../services/document_library_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class AudioDescriptionProjectPickerScreen extends StatefulWidget {
  const AudioDescriptionProjectPickerScreen({super.key, this.library});
  final DocumentLibraryService? library;

  @override
  State<AudioDescriptionProjectPickerScreen> createState() =>
      _AudioDescriptionProjectPickerScreenState();
}

class _AudioDescriptionProjectPickerScreenState
    extends State<AudioDescriptionProjectPickerScreen> {
  late final _library = widget.library ?? DocumentLibraryService();
  List<DocumentItem> _projects = [];
  bool _loading = true;
  bool _opening = false;
  bool _failed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final projects = await loadAudioDescriptionProjects(_library);
      if (mounted) setState(() => _projects = projects);
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description project picker: $error\n$stackTrace',
      );
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _unlock(DocumentItem document) async {
    if (!document.isPasswordProtected) return true;
    final unlocked = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ProjectPasswordDialog(library: _library, document: document),
    );
    return unlocked == true;
  }

  Future<void> _open(DocumentItem document) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!await _unlock(document) || !mounted) return;
      final path = await _library.resolveFilePath(document);
      if (mounted) Navigator.pop(context, path);
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Audio description project picker: open failed $error\n$stackTrace',
      );
      if (mounted) {
        showStatusMessage(
          context,
          AppLocalizations.of(context).technicalErrorGeneric,
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matches = _projects.where(
      (doc) => doc.name.toLowerCase().contains(_query.toLowerCase()),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.audioDescriptionFindProject)),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading),
            )
          : UniversalAccessibleList(
              initialFocusId: 'project_search',
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'project_search',
                      title: l10n.search,
                      kind: 'textField',
                      value: _query,
                      onValueChanged: (value) =>
                          setState(() => _query = value?.toString() ?? ''),
                    ),
                    if (_failed || matches.isEmpty)
                      AccessibleListRow(
                        id: 'project_empty',
                        kind: 'text',
                        accessibilityButtonTrait: false,
                        title: _failed
                            ? l10n.technicalErrorGeneric
                            : l10n.audioDescriptionNoSavedProjects,
                      ),
                    for (final document in matches)
                      AccessibleListRow(
                        id: document.id,
                        title: document.displayName,
                        value: document.isPasswordProtected
                            ? l10n.documentPasswordProtectedStatus
                            : null,
                        onActivate: () => _open(document),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ProjectPasswordDialog extends StatefulWidget {
  const _ProjectPasswordDialog({required this.library, required this.document});
  final DocumentLibraryService library;
  final DocumentItem document;
  @override
  State<_ProjectPasswordDialog> createState() => _ProjectPasswordDialogState();
}

class _ProjectPasswordDialogState extends State<_ProjectPasswordDialog> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.library.verifyDocumentPassword(
      widget.document,
      _controller.text,
    )) {
      Navigator.pop(context, true);
    } else {
      setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.documentPasswordRequiredTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.enterDocumentPasswordToOpen),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.documentPassword,
              errorText: _invalid ? l10n.incorrectDocumentPassword : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}
