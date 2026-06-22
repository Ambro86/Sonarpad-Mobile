import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../services/voice_dictionary_service.dart';

class VoiceDictionaryScreen extends StatefulWidget {
  const VoiceDictionaryScreen({super.key});

  @override
  State<VoiceDictionaryScreen> createState() => _VoiceDictionaryScreenState();
}

class _VoiceDictionaryScreenState extends State<VoiceDictionaryScreen> {
  final _service = VoiceDictionaryService();
  var _entries = <VoiceDictionaryEntry>[];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _service.loadEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _showAddEntryDialog() async {
    final entry = await showDialog<VoiceDictionaryEntry>(
      context: context,
      builder: (_) => const _VoiceDictionaryEntryDialog(),
    );
    if (entry == null) return;
    await _service.addEntry(entry);
    await _load();
  }

  Future<void> _removeEntry(int index) async {
    await _service.removeAt(index);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.voiceDictionaryTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _showAddEntryDialog,
              icon: const Icon(Icons.add),
              label: Text(l10n.voiceDictionaryAdd),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.voiceDictionaryEntries,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_loading)
              Text(l10n.loading)
            else if (_entries.isEmpty)
              Text(l10n.voiceDictionaryEmpty)
            else
              ...List.generate(_entries.length, (index) {
                final entry = _entries[index];
                return Semantics(
                  container: true,
                  customSemanticsActions: {
                    CustomSemanticsAction(
                      label: l10n.voiceDictionaryRemove,
                    ): () => _removeEntry(index),
                  },
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${entry.original} -> ${entry.replacement}'),
                    subtitle: Text(
                      entry.matchCase
                          ? l10n.voiceDictionaryMatchCase
                          : l10n.voiceDictionaryIgnoreCase,
                    ),
                    trailing: ExcludeSemantics(
                      child: IconButton(
                        tooltip: l10n.voiceDictionaryRemove,
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeEntry(index),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _VoiceDictionaryEntryDialog extends StatefulWidget {
  const _VoiceDictionaryEntryDialog();

  @override
  State<_VoiceDictionaryEntryDialog> createState() =>
      _VoiceDictionaryEntryDialogState();
}

class _VoiceDictionaryEntryDialogState
    extends State<_VoiceDictionaryEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _originalController = TextEditingController();
  final _replacementController = TextEditingController();
  var _matchCase = true;

  @override
  void dispose() {
    _originalController.dispose();
    _replacementController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      VoiceDictionaryEntry(
        original: _originalController.text,
        replacement: _replacementController.text,
        matchCase: _matchCase,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.voiceDictionaryAdd),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _originalController,
                decoration: InputDecoration(
                  labelText: l10n.voiceDictionaryOriginalWord,
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.voiceDictionaryOriginalRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _replacementController,
                decoration: InputDecoration(
                  labelText: l10n.voiceDictionaryReplacementWord,
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.voiceDictionaryMatchCase),
                value: _matchCase,
                onChanged: (value) => setState(() => _matchCase = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.annulla),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
