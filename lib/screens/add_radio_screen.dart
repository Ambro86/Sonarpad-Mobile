import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class AddRadioScreen extends StatefulWidget {
  const AddRadioScreen({super.key});

  @override
  State<AddRadioScreen> createState() => _AddRadioScreenState();
}

class _AddRadioScreenState extends State<AddRadioScreen> {
  final _service = RadioService();
  final _addNameController = TextEditingController();
  final _addUrlController = TextEditingController();

  String _addLanguage = 'italian';
  RadioGenreOption _addGenre = RadioService.genres[1];
  bool _addingCommunity = false;

  Future<void> _addCommunityRadio() async {
    final l10n = AppLocalizations.of(context);
    final name = _addNameController.text.trim();
    final url = _addUrlController.text.trim();
    if (name.isEmpty || url.isEmpty) {
            showStatusMessage(context, l10n.radioAddMissingFields);
      return;
    }
    setState(() => _addingCommunity = true);
    try {
      final message = await _service.addCommunityRadio(
        name: name,
        streamUrl: url,
        language: _addLanguage,
        genre: _addGenre.tag ?? _addGenre.value,
      );
      if (!mounted) return;
      _addNameController.clear();
      _addUrlController.clear();
            showStatusMessage(context, message.trim().isEmpty
              ? l10n.radioCommunityAdded
              : message.trim());
      Navigator.pop(context); // Chiude la finestra dopo il successo
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, l10n.radioCommunityAddError(e));
    } finally {
      if (mounted) setState(() => _addingCommunity = false);
    }
  }

  @override
  void dispose() {
    _addNameController.dispose();
    _addUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.radioAddCommunity)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [AccessibleListSection(rows: [
                AccessibleListRow(id: 'name', title: l10n.radioAddName, kind: 'textField', value: _addNameController.text),
                AccessibleListRow(id: 'url', title: l10n.radioAddUrl, kind: 'textField', value: _addUrlController.text),
                AccessibleListRow(
                  id: 'language',
                  title: l10n.radioLanguage,
                  kind: 'picker',
                  value: _addLanguage,
                  options: [
                    for (final language in RadioService.communityLanguages)
                      AccessibleOption(value: language, label: l10n.radioCommunityLanguageLabel(language)),
                  ],
                ),
                AccessibleListRow(
                  id: 'genre',
                  title: l10n.radioGenre,
                  kind: 'picker',
                  value: _addGenre.value,
                  options: [
                    for (final genre in RadioService.genres.where((genre) => genre.tag != null))
                      AccessibleOption(value: genre.value, label: l10n.radioGenreLabel(genre.value)),
                  ],
                ),
                AccessibleListRow(id: 'submit', title: _addingCommunity ? l10n.radioSearching : l10n.radioAddSubmit, kind: 'button', enabled: !_addingCommunity),
              ])],
              onEvent: (event) {
                if (event.id == 'name' && event.type == 'textChanged') {
                  _addNameController.text = event.value?.toString() ?? '';
                } else if (event.id == 'url' && event.type == 'textChanged') {
                  _addUrlController.text = event.value?.toString() ?? '';
                } else if (event.id == 'language' && event.type == 'picker' && event.value != null) {
                  setState(() => _addLanguage = event.value.toString());
                } else if (event.id == 'genre' && event.type == 'picker') {
                  final value = event.value?.toString();
                  final found = RadioService.genres.where((genre) => genre.value == value);
                  if (found.isNotEmpty) setState(() => _addGenre = found.first);
                } else if (event.id == 'submit' && event.type == 'activate' && !_addingCommunity) {
                  _addCommunityRadio();
                }
              },
            )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _addNameController,
            decoration: InputDecoration(labelText: l10n.radioAddName),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addUrlController,
            decoration: InputDecoration(labelText: l10n.radioAddUrl),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _addLanguage,
            decoration: InputDecoration(labelText: l10n.radioLanguage),
            items: RadioService.communityLanguages
                .map((language) => DropdownMenuItem(
                      value: language,
                      child: Text(l10n.radioCommunityLanguageLabel(language)),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _addLanguage = value ?? 'italian'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RadioGenreOption>(
            initialValue: _addGenre,
            decoration: InputDecoration(labelText: l10n.radioGenre),
            items: RadioService.genres
                .where((genre) => genre.tag != null)
                .map((genre) => DropdownMenuItem(
                      value: genre,
                      child: Text(l10n.radioGenreLabel(genre.value)),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _addGenre = value ?? RadioService.genres[1]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _addingCommunity ? null : _addCommunityRadio,
            icon: const Icon(Icons.cloud_upload),
            label: Text(
                _addingCommunity ? l10n.radioSearching : l10n.radioAddSubmit),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
