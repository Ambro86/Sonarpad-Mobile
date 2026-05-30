import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/audiodescription_service.dart';
import '../services/audio_player_service.dart';
import '../tts/edge_tts_bridge.dart';
import '../main.dart';
import 'app_log_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService();
  final _flutterTts = FlutterTts();
  String _appLanguage = 'it';
  String _languageCode = 'it';
  String _voice = AppSettingsService.defaultVoiceForLanguage('it');
  List<TtsVoiceLanguage> _edgeLanguages = AppSettingsService.ttsLanguages;
  List<TtsVoiceOption> _edgeVoices = AppSettingsService.ttsVoices;

  String _ttsEngine = 'edge';
  String _systemTtsLanguage = 'it-IT';
  String? _systemTtsVoice;
  List<Map<String, String>> _systemVoices = [];

  double _ttsSpeed = 1.0;
  double _ttsPitch = 1.0;
  bool _loading = true;
  bool _isSaving = false;
  late TextEditingController _tvSecretCodeController;
  bool _testingVoice = false;
  bool _autoBookmark = true;
  bool _homeGroupingEnabled = false;
  int _seekSliderStep = 60;
  final _audio = AudioPlayerService();
  String _savedTvSecretCode = '';

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 60) return '$totalSeconds secondi';
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    String minStr = m == 1 ? '1 minuto' : '$m minuti';
    String secStr = s == 1 ? '1 secondo' : '$s secondi';
    if (s == 0) return minStr;
    return '$minStr e $secStr';
  }

  @override
  void initState() {
    super.initState();
    _tvSecretCodeController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _tvSecretCodeController.dispose();
    unawaited(_audio.stop().whenComplete(_audio.dispose));
    super.dispose();
  }

  Future<void> _load() async {
    final appLang = await _settings.loadAppLanguage();
    final language = await _settings.loadTtsLanguage();
    final voice = await _settings.loadTtsVoice();
    final speed = await _settings.loadTtsSpeed();
    final pitch = await _settings.loadTtsPitch();
    final tvSecretCode = await _settings.getTvSecretCode();

    final ttsEngine = await _settings.loadTtsEngine();
    final sysLang = await _settings.loadSystemTtsLanguage();
    final sysVoice = await _settings.loadSystemTtsVoice();
    final autoBookmark = await _settings.isAutoBookmarkEnabled();
    final homeGrouping = await _settings.isHomeGroupingEnabled();
    final seekSliderStep = await _settings.loadSeekSliderStep();
    final edgeVoices = await AppSettingsService.loadEdgeVoices();
    final edgeLanguages = AppSettingsService.languagesForVoices(edgeVoices);
    final normalizedLanguage = AppSettingsService.normalizedTtsLanguageCodeFor(
      edgeLanguages,
      edgeVoices,
      language,
      voice,
    );

    await _loadSystemVoices();

    if (!mounted) return;
    setState(() {
      _appLanguage = appLang;
      _edgeLanguages = edgeLanguages;
      _edgeVoices = edgeVoices;
      _languageCode = normalizedLanguage;
      _voice = _validVoiceForLanguage(normalizedLanguage, voice);
      _ttsSpeed = speed;
      _ttsPitch = pitch;
      _tvSecretCodeController.text = tvSecretCode;
      _savedTvSecretCode = tvSecretCode;
      _ttsEngine = ttsEngine;
      _systemTtsLanguage = sysLang;
      _systemTtsVoice = sysVoice;
      _autoBookmark = autoBookmark;
      _homeGroupingEnabled = homeGrouping;
      _seekSliderStep = seekSliderStep;
      _loading = false;
    });
  }

  Future<void> _loadSystemVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices != null && voices is List) {
        final List<Map<String, String>> parsedVoices = [];
        for (var v in voices) {
          if (v is Map) {
            final name = v['name']?.toString() ?? '';
            final locale = v['locale']?.toString() ?? '';
            if (name.isNotEmpty && locale.isNotEmpty) {
              parsedVoices.add({'name': name, 'locale': locale});
            }
          }
        }
        _systemVoices = parsedVoices;
      }
    } catch (e) {
      debugPrint('Errore caricamento voci di sistema: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context);
    final rawCode = _tvSecretCodeController.text.trim();
    final codeChanged = rawCode != _savedTvSecretCode;

    if (codeChanged && rawCode.isNotEmpty) {
      try {
        await AudiodescriptionService().fetchRecentCatalog(rawCode);
      } catch (e) {
        setState(() => _isSaving = false);
        if (!mounted) return;
        await _showSaveResultDialog(
          title: l10n.sonarpadCodeInvalidTitle,
          message: l10n.sonarpadCodeInvalidMessage,
        );
        return;
      }
    }

    await _saveTtsSelection();
    await _settings.setTvSecretCode(rawCode);
    _savedTvSecretCode = rawCode;
    await _settings.setAutoBookmarkEnabled(_autoBookmark);
    await _settings.setHomeGroupingEnabled(_homeGroupingEnabled);
    await _settings.saveSeekSliderStep(_seekSliderStep);

    setState(() => _isSaving = false);
    if (!mounted) return;
    await _showSaveResultDialog(
      title: codeChanged && rawCode.isNotEmpty
          ? l10n.sonarpadCodeValidTitle
          : l10n.settingsSavedTitle,
      message: codeChanged && rawCode.isNotEmpty
          ? l10n.sonarpadCodeValidMessage
          : l10n.settingsSaved,
    );
  }

  Future<void> _showSaveResultDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  Future<void> _testVoice() async {
    setState(() => _testingVoice = true);
    try {
      await _saveTtsSelection();
      await _settings.saveTtsSpeed(_ttsSpeed);
      await _settings.saveTtsPitch(_ttsPitch);

      if (_ttsEngine == 'system') {
        await _flutterTts
            .setSpeechRate(_ttsSpeed * 0.5); // flutter_tts usa range 0-1
        await _flutterTts.setPitch(_ttsPitch);
        if (_systemTtsVoice != null) {
          await _flutterTts.setVoice(
              {"name": _systemTtsVoice!, "locale": _systemTtsLanguage});
        } else {
          await _flutterTts.setLanguage(_systemTtsLanguage);
        }
        await _flutterTts.speak('Questo è un test della voce di sistema.');
        // _flutterTts is asynchronous but we can just wait, or not wait.
        // For simplicity, we just trigger speak.
      } else {
        final tts = EdgeTtsBridge();
        final file = await tts.speakToFile(
          text: 'Questo è un test della voce selezionata.',
          voice: _voice,
        );
        if (!mounted) return;
        await _audio.playFile(file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore test voce: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _testingVoice = false);
      }
    }
  }

  Future<void> _saveTtsSelection() async {
    await _settings.saveTtsEngine(_ttsEngine);
    await _settings.saveTtsSettings(
      languageCode: _languageCode,
      voice: _voice,
    );
    await _settings.saveSystemTtsLanguage(_systemTtsLanguage);
    await _settings.saveSystemTtsVoice(_systemTtsVoice);
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
    final voices = AppSettingsService.voicesForLanguageFrom(
      _edgeVoices,
      languageCode,
    );
    if (voices.any((option) => option.voice == voice)) return voice;
    return AppSettingsService.defaultVoiceForLanguageFrom(
      _edgeVoices,
      languageCode,
    );
  }

  double _sliderStep(double value, double delta) {
    final next = (value + delta).clamp(0.5, 2.0);
    return (next * 10).round() / 10;
  }

  void _setTtsSpeed(double value, {bool persist = false}) {
    setState(() => _ttsSpeed = value);
    if (persist) {
      unawaited(_settings.saveTtsSpeed(value));
    }
  }

  void _setTtsPitch(double value, {bool persist = false}) {
    setState(() => _ttsPitch = value);
    if (persist) {
      unawaited(_settings.saveTtsPitch(value));
    }
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
              child: Text(AppLocalizations.of(context).annulla),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context).invia),
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
          SnackBar(
              content: Text(AppLocalizations.of(context).compilaTuttiICampiPerRichiedereIlCodice)),
        );
        return;
      }

      const subject = 'Richiesta Codice Sonarpad';
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

      final body =
          'Nome: $name; Cognome: $surname; Email: $email; Sistema Operativo: $os';

      // I client mail richiedono %20 per gli spazi nei link mailto, mentre Uri(queryParameters)
      // usa il '+' tipico dell'HTTP, che i client mail non decodificano.
      // Quindi, codifichiamo manualmente con Uri.encodeComponent.
      String encodeQueryParameters(Map<String, String> params) {
        return params.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
      }

      final url = Uri.parse(
        'mailto:ambro86@gmail.com?${encodeQueryParameters({
              'subject': subject,
              'body': body,
            })}',
      );

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
    final voices = AppSettingsService.voicesForLanguageFrom(
      _edgeVoices,
      _languageCode,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _appLanguage,
                  decoration: InputDecoration(labelText: l10n.appLanguage),
                  items: [
                    DropdownMenuItem(value: 'it', child: Text(l10n.italian)),
                    DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                    DropdownMenuItem(value: 'fr', child: Text(l10n.french)),
                    DropdownMenuItem(value: 'es', child: Text(l10n.spanish)),
                  ],
                  onChanged: (value) async {
                    if (value == null || value == _appLanguage) return;
                    setState(() => _appLanguage = value);
                    await _settings.saveAppLanguage(value);
                    if (!context.mounted) return;
                    SonarpadApp.setLocale(context, Locale(value));
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _ttsEngine,
                  decoration:
                      InputDecoration(labelText: l10n.settingsReadingEngine),
                  items: [
                    DropdownMenuItem(
                        value: 'edge',
                        child: Text(l10n.settingsEdgeTtsQuality)),
                    DropdownMenuItem(
                        value: 'system',
                        child: Text(l10n.settingsSystemVoices)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _ttsEngine = value);
                    _persistTtsSelection();
                  },
                ),
                const SizedBox(height: 12),
                if (_ttsEngine == 'edge') ...[
                  DropdownButtonFormField<String>(
                    initialValue: _languageCode,
                    decoration:
                        InputDecoration(labelText: l10n.ttsVoiceLanguage),
                    items: _edgeLanguages
                        .map((language) => DropdownMenuItem(
                              value: language.code,
                              child: Text(language.label),
                            ))
                        .toList(),
                    onChanged: (value) {
                      final next = value ?? 'it';
                      setState(() {
                        _languageCode = next;
                        _voice = AppSettingsService.defaultVoiceForLanguageFrom(
                          _edgeVoices,
                          next,
                        );
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
                            AppSettingsService.defaultVoiceForLanguageFrom(
                              _edgeVoices,
                              _languageCode,
                            ),
                      );
                      _persistTtsSelection();
                    },
                  ),
                ] else ...[
                  Builder(
                    builder: (context) {
                      final locales = _systemVoices
                          .map((v) => v['locale']!)
                          .toSet()
                          .toList()
                        ..sort();
                      if (locales.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(l10n.settingsNoSystemVoices),
                        );
                      }
                      final availableVoices = _systemVoices
                          .where((v) => v['locale'] == _systemTtsLanguage)
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: locales.contains(_systemTtsLanguage)
                                ? _systemTtsLanguage
                                : locales.first,
                            decoration: const InputDecoration(
                                labelText: 'Lingua di sistema'),
                            items: locales
                                .map((l) => DropdownMenuItem(
                                      value: l,
                                      child: Text(l),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _systemTtsLanguage = value;
                                _systemTtsVoice = null;
                              });
                              _persistTtsSelection();
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: availableVoices
                                    .any((v) => v['name'] == _systemTtsVoice)
                                ? _systemTtsVoice
                                : null,
                            decoration: const InputDecoration(
                                labelText: 'Voce di sistema'),
                            hint: Text(l10n.settingsDefaultVoiceHint),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(l10n.settingsDefaultVoice),
                              ),
                              ...availableVoices
                                  .map((v) => DropdownMenuItem<String?>(
                                        value: v['name'],
                                        child: Text(v['name'] ?? ''),
                                      )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _systemTtsVoice = value;
                              });
                              _persistTtsSelection();
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                          '${l10n.settingsVoiceSpeed}${_ttsSpeed.toStringAsFixed(1)}x'),
                    ),
                    Semantics(
                      container: true,
                      label: l10n.settingsVoiceSpeedLabel,
                      value: '${_ttsSpeed.toStringAsFixed(1)}x',
                      increasedValue:
                          '${_sliderStep(_ttsSpeed, 0.1).toStringAsFixed(1)}x',
                      decreasedValue:
                          '${_sliderStep(_ttsSpeed, -0.1).toStringAsFixed(1)}x',
                      onIncrease: () => _setTtsSpeed(
                        _sliderStep(_ttsSpeed, 0.1),
                        persist: true,
                      ),
                      onDecrease: () => _setTtsSpeed(
                        _sliderStep(_ttsSpeed, -0.1),
                        persist: true,
                      ),
                      child: ExcludeSemantics(
                        child: Slider(
                          value: _ttsSpeed,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          onChanged: _setTtsSpeed,
                          onChangeEnd: _settings.saveTtsSpeed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child:
                          Text('${l10n.settingsVoicePitch}${_ttsPitch.toStringAsFixed(1)}x'),
                    ),
                    Semantics(
                      container: true,
                      label: l10n.settingsVoicePitchLabel,
                      value: '${_ttsPitch.toStringAsFixed(1)}x',
                      increasedValue:
                          '${_sliderStep(_ttsPitch, 0.1).toStringAsFixed(1)}x',
                      decreasedValue:
                          '${_sliderStep(_ttsPitch, -0.1).toStringAsFixed(1)}x',
                      onIncrease: () => _setTtsPitch(
                        _sliderStep(_ttsPitch, 0.1),
                        persist: true,
                      ),
                      onDecrease: () => _setTtsPitch(
                        _sliderStep(_ttsPitch, -0.1),
                        persist: true,
                      ),
                      child: ExcludeSemantics(
                        child: Slider(
                          value: _ttsPitch,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          onChanged: _setTtsPitch,
                          onChangeEnd: _settings.saveTtsPitch,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _testingVoice ? null : _testVoice,
                  icon: _testingVoice
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.volume_up),
                  label: Text(_testingVoice
                      ? l10n.settingsTestingVoice
                      : l10n.settingsTestVoice),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                if (_appLanguage == 'it') ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(l10n.settingsAutoBookmark),
                    subtitle: Text(l10n.settingsAutoBookmarkHint),
                    value: _autoBookmark,
                    onChanged: (val) => setState(() => _autoBookmark = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(l10n.settingsHomeGrouping),
                    subtitle: Text(l10n.settingsHomeGroupingHint),
                    value: _homeGroupingEnabled,
                    onChanged: (val) => setState(() => _homeGroupingEnabled = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Text(
                            '${l10n.settingsSeekStep}: ${_formatTime(_seekSliderStep)}'),
                      ),
                      Semantics(
                        container: true,
                        label: l10n.settingsSeekStep,
                        value: _formatTime(_seekSliderStep),
                        increasedValue:
                            _formatTime((_seekSliderStep + 10).clamp(10, 300)),
                        decreasedValue:
                            _formatTime((_seekSliderStep - 10).clamp(10, 300)),
                        onIncrease: () {
                          setState(() {
                            _seekSliderStep =
                                (_seekSliderStep + 10).clamp(10, 300);
                          });
                        },
                        onDecrease: () {
                          setState(() {
                            _seekSliderStep =
                                (_seekSliderStep - 10).clamp(10, 300);
                          });
                        },
                        child: ExcludeSemantics(
                          child: Slider(
                            value: _seekSliderStep.toDouble(),
                            min: 10,
                            max: 300,
                            divisions: 29,
                            onChanged: (val) =>
                                setState(() => _seekSliderStep = val.toInt()),
                            onChangeEnd: (val) =>
                                _settings.saveSeekSliderStep(val.toInt()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tvSecretCodeController,
                    decoration: InputDecoration(
                      labelText: l10n.settingsSecretCode,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _requestSecretCode,
                    icon: const Icon(Icons.mail_outline),
                    label: Text(l10n.settingsRequestCode),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isSaving
                      ? l10n.settingsVerifyCodeAndSave
                      : l10n.saveSettings),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings:
                            const RouteSettings(name: '/settings/app-log'),
                        builder: (_) => const AppLogScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description),
                  label: Text(l10n.settingsViewSysLog),
                ),
              ],
            ),
    );
  }
}
