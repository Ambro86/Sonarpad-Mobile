import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import 'edge_tts_log_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService();
  String _languageCode = 'it';
  String _voice = AppSettingsService.defaultVoiceForLanguage('it');
  final _tvSecretCodeController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tvSecretCodeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final language = await _settings.loadTtsLanguage();
    final voice = await _settings.loadTtsVoice();
    final tvSecretCode = await _settings.getTvSecretCode();
    if (!mounted) return;
    setState(() {
      _languageCode = language;
      _voice = _validVoiceForLanguage(language, voice);
      _tvSecretCodeController.text = tvSecretCode;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    await _saveTtsSelection();
    await _settings.setTvSecretCode(_tvSecretCodeController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsSaved)),
    );
  }

  Future<void> _saveTtsSelection() async {
    await _settings.saveTtsSettings(
      languageCode: _languageCode,
      voice: _voice,
    );
  }

  void _persistTtsSelection() {
    unawaited(
      _saveTtsSelection().catchError((Object error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio voce TTS: $error')),
        );
      }),
    );
  }

  String _validVoiceForLanguage(String languageCode, String voice) {
    final voices = AppSettingsService.voicesForLanguage(languageCode);
    if (voices.any((option) => option.voice == voice)) return voice;
    return AppSettingsService.defaultVoiceForLanguage(languageCode);
  }

  Future<void> _requestSecretCode() async {
    final nameCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Richiedi codice all\'autore'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: surnameCtrl,
                decoration: const InputDecoration(labelText: 'Cognome'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Invia'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final name = nameCtrl.text.trim();
      final surname = surnameCtrl.text.trim();
      final email = emailCtrl.text.trim();

      if (name.isEmpty || surname.isEmpty || email.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Compila tutti i campi per richiedere il codice.')),
        );
        return;
      }

      final subject = Uri.encodeComponent('Richiesta Codice Sonarpad');
      final os = Platform.isIOS
          ? 'iOS'
          : Platform.isAndroid
              ? 'Android'
              : Platform.isWindows
                  ? 'Windows'
                  : Platform.isMacOS
                      ? 'macOS'
                      : Platform.isLinux
                          ? 'Linux'
                          : 'Sconosciuto';
      final body = Uri.encodeComponent(
          'Nome: $name\nCognome: $surname\nEmail: $email\nSistema Operativo: $os');
      final url =
          Uri.parse('mailto:ambro86@gmail.com?subject=$subject&body=$body');

      try {
        await launchUrl(url);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore apertura mail: $e')),
        );
      }
    }
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
                    _persistTtsSelection();
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
                  onChanged: (value) {
                    setState(
                      () => _voice = value ??
                          AppSettingsService.defaultVoiceForLanguage(
                              _languageCode),
                    );
                    _persistTtsSelection();
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tvSecretCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Codice Sonarpad per funzioni aggiuntive',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _requestSecretCode,
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Richiedi codice all\'autore'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(l10n.saveSettings),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings:
                          const RouteSettings(name: '/settings/edge-tts-log'),
                      builder: (_) => const EdgeTtsLogScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Visualizza log Edge TTS'),
                ),
              ],
            ),
    );
  }
}
