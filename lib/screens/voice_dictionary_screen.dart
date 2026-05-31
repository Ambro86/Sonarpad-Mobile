import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/voice_dictionary_service.dart';

class VoiceDictionaryScreen extends StatefulWidget {
  const VoiceDictionaryScreen({super.key});

  @override
  State<VoiceDictionaryScreen> createState() => _VoiceDictionaryScreenState();
}

class _VoiceDictionaryScreenState extends State<VoiceDictionaryScreen> {
  final _service = VoiceDictionaryService();
  final _originalController = TextEditingController();
  final _replacementController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _entries = <VoiceDictionaryEntry>[];
  var _matchCase = true;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _originalController.dispose();
    _replacementController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await _service.loadEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _addEntry() async {
    if (!_formKey.currentState!.validate()) return;

    await _service.addEntry(
      VoiceDictionaryEntry(
        original: _originalController.text,
        replacement: _replacementController.text,
        matchCase: _matchCase,
      ),
    );
    _originalController.clear();
    _replacementController.clear();
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
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.voiceDictionaryAdd,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _originalController,
                    decoration: InputDecoration(
                      labelText: l10n.voiceDictionaryOriginalWord,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        value == null || value.trim().isEmpty
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
                    onFieldSubmitted: (_) => _addEntry(),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.voiceDictionaryMatchCase),
                    value: _matchCase,
                    onChanged: (value) => setState(() => _matchCase = value),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.ok),
                  ),
                ],
              ),
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
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${entry.original} -> ${entry.replacement}'),
                  subtitle: Text(
                    entry.matchCase
                        ? l10n.voiceDictionaryMatchCase
                        : l10n.voiceDictionaryIgnoreCase,
                  ),
                  trailing: IconButton(
                    tooltip: l10n.voiceDictionaryRemove,
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeEntry(index),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
