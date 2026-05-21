import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService();
  String _languageCode = 'it';
  String _voice = AppSettingsService.defaultVoiceForLanguage('it');
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final language = await _settings.loadTtsLanguage();
    final voice = await _settings.loadTtsVoice();
    if (!mounted) return;
    setState(() {
      _languageCode = language;
      _voice = _validVoiceForLanguage(language, voice);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    await _settings.saveTtsSettings(
      languageCode: _languageCode,
      voice: _voice,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsSaved)),
    );
  }

  String _validVoiceForLanguage(String languageCode, String voice) {
    final voices = AppSettingsService.voicesForLanguage(languageCode);
    if (voices.any((option) => option.voice == voice)) return voice;
    return AppSettingsService.defaultVoiceForLanguage(languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final voices = AppSettingsService.voicesForLanguage(_languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _languageCode,
                  decoration: InputDecoration(labelText: l10n.ttsVoiceLanguage),
                  items: AppSettingsService.ttsLanguages
                      .map((language) => DropdownMenuItem(
                            value: language.code,
                            child: Text(language.label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    final next = value ?? 'it';
                    setState(() {
                      _languageCode = next;
                      _voice = AppSettingsService.defaultVoiceForLanguage(next);
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _voice,
                  decoration: InputDecoration(labelText: l10n.ttsVoice),
                  items: voices
                      .map((voice) => DropdownMenuItem(
                            value: voice.voice,
                            child: Text('${voice.label} (${voice.voice})'),
                          ))
                      .toList(),
                  onChanged: (value) => setState(
                    () => _voice = value ??
                        AppSettingsService.defaultVoiceForLanguage(
                            _languageCode),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(l10n.saveSettings),
                ),
              ],
            ),
    );
  }
}
