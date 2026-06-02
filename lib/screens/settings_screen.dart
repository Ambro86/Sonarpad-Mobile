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

enum _SettingsLeaveAction { save, discard, cancel }

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService();
  final _flutterTts = FlutterTts();
  final _screenFocusNode = FocusNode();
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
  String _savedAppLanguage = 'it';
  String _savedLanguageCode = 'it';
  String _savedVoice = AppSettingsService.defaultVoiceForLanguage('it');
  String _savedTtsEngine = 'edge';
  String _savedSystemTtsLanguage = 'it-IT';
  String? _savedSystemTtsVoice;
  double _savedTtsSpeed = 1.0;
  double _savedTtsPitch = 1.0;
  bool _savedAutoBookmark = true;
  bool _savedHomeGroupingEnabled = false;
  int _savedSeekSliderStep = 60;

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
    _screenFocusNode.dispose();
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
      _savedAppLanguage = appLang;
      _edgeLanguages = edgeLanguages;
      _edgeVoices = edgeVoices;
      _languageCode = normalizedLanguage;
      _savedLanguageCode = normalizedLanguage;
      _voice = _validVoiceForLanguage(normalizedLanguage, voice);
      _savedVoice = _voice;
      _ttsSpeed = speed;
      _savedTtsSpeed = speed;
      _ttsPitch = pitch;
      _savedTtsPitch = pitch;
      _tvSecretCodeController.text = tvSecretCode;
      _savedTvSecretCode = tvSecretCode;
      _ttsEngine = ttsEngine;
      _savedTtsEngine = ttsEngine;
      _systemTtsLanguage = sysLang;
      _savedSystemTtsLanguage = sysLang;
      _systemTtsVoice = sysVoice;
      _savedSystemTtsVoice = sysVoice;
      _autoBookmark = autoBookmark;
      _savedAutoBookmark = autoBookmark;
      _homeGroupingEnabled = homeGrouping;
      _savedHomeGroupingEnabled = homeGrouping;
      _seekSliderStep = seekSliderStep;
      _savedSeekSliderStep = seekSliderStep;
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
    await _settings.saveAppLanguage(_appLanguage);
    await _settings.saveTtsSpeed(_ttsSpeed);
    await _settings.saveTtsPitch(_ttsPitch);
    await _settings.setTvSecretCode(rawCode);
    await _settings.setAutoBookmarkEnabled(_autoBookmark);
    await _settings.setHomeGroupingEnabled(_homeGroupingEnabled);
    await _settings.saveSeekSliderStep(_seekSliderStep);
    _markSaved(rawCode);

    setState(() => _isSaving = false);
    if (!mounted) return;
    if (_appLanguage != Localizations.localeOf(context).languageCode) {
      SonarpadApp.setLocale(context, Locale(_appLanguage));
    }
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          codeChanged && rawCode.isNotEmpty
              ? l10n.sonarpadCodeValidMessage
              : l10n.settingsSaved,
        ),
      ),
    );
    _screenFocusNode.requestFocus();
  }

  Future<void> _showSaveResultDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
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
    if (!mounted) return;
    _screenFocusNode.requestFocus();
  }

  void _markSaved(String rawCode) {
    _savedAppLanguage = _appLanguage;
    _savedLanguageCode = _languageCode;
    _savedVoice = _voice;
    _savedTtsEngine = _ttsEngine;
    _savedSystemTtsLanguage = _systemTtsLanguage;
    _savedSystemTtsVoice = _systemTtsVoice;
    _savedTtsSpeed = _ttsSpeed;
    _savedTtsPitch = _ttsPitch;
    _savedTvSecretCode = rawCode;
    _savedAutoBookmark = _autoBookmark;
    _savedHomeGroupingEnabled = _homeGroupingEnabled;
    _savedSeekSliderStep = _seekSliderStep;
  }

  bool get _hasUnsavedChanges {
    if (_loading) return false;
    return _appLanguage != _savedAppLanguage ||
        _languageCode != _savedLanguageCode ||
        _voice != _savedVoice ||
        _ttsEngine != _savedTtsEngine ||
        _systemTtsLanguage != _savedSystemTtsLanguage ||
        _systemTtsVoice != _savedSystemTtsVoice ||
        _ttsSpeed != _savedTtsSpeed ||
        _ttsPitch != _savedTtsPitch ||
        _tvSecretCodeController.text.trim() != _savedTvSecretCode ||
        _autoBookmark != _savedAutoBookmark ||
        _homeGroupingEnabled != _savedHomeGroupingEnabled ||
        _seekSliderStep != _savedSeekSliderStep;
  }

  Future<bool> _confirmLeaveSettings() async {
    if (!_hasUnsavedChanges || _isSaving) return true;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_SettingsLeaveAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsUnsavedTitle),
        content: Text(l10n.settingsUnsavedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _SettingsLeaveAction.cancel),
            child: Text(l10n.annulla),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _SettingsLeaveAction.discard),
            child: Text(l10n.settingsExitWithoutSaving),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _SettingsLeaveAction.save),
            child: Text(l10n.saveSettings),
          ),
        ],
      ),
    );

    if (result == _SettingsLeaveAction.discard) return true;
    if (result == _SettingsLeaveAction.save) {
      await _save();
      return !_hasUnsavedChanges;
    }
    return false;
  }

  Future<void> _testVoice() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _testingVoice = true);
    try {
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
        await _flutterTts.speak(l10n.settingsVoiceTestText);
        // _flutterTts is asynchronous but we can just wait, or not wait.
        // For simplicity, we just trigger speak.
      } else {
        final tts = EdgeTtsBridge();
        final file = await tts.speakToFile(
          text: l10n.settingsVoiceTestText,
          voice: _voice,
        );
        if (!mounted) return;
        await _audio.playFile(file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsVoiceTestError(e))),
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

  void _setTtsSpeed(double value) {
    setState(() => _ttsSpeed = value);
  }

  void _setTtsPitch(double value) {
    setState(() => _ttsPitch = value);
  }

  Future<void> _requestSecretCode() async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.settingsRequestCode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.settingsName),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: surnameCtrl,
                decoration: InputDecoration(labelText: l10n.settingsSurname),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: l10n.settingsEmail),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.settingsCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.settingsSend),
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
          SnackBar(content: Text(l10n.settingsFillFieldsCode)),
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

      final body = l10n.settingsCodeRequestBody(name, surname, email, os);

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
          SnackBar(content: Text(l10n.settingsMailOpenError(e))),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmLeaveSettings();
        if (!context.mounted || !shouldLeave) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.settings)),
        body: _loading
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading))
          : Focus(
              focusNode: _screenFocusNode,
              child: ListView(
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
                    onChanged: (value) {
                      if (value == null || value == _appLanguage) return;
                      setState(() => _appLanguage = value);
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
                            decoration: InputDecoration(
                                labelText: l10n.settingsSystemLanguage),
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
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: availableVoices
                                    .any((v) => v['name'] == _systemTtsVoice)
                                ? _systemTtsVoice
                                : null,
                            decoration:
                                InputDecoration(labelText: l10n.settingsSystemVoice),
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
                      slider: true,
                      label: l10n.settingsVoiceSpeedLabel,
                      value: '${_ttsSpeed.toStringAsFixed(1)}x',
                      increasedValue:
                          '${_sliderStep(_ttsSpeed, 0.1).toStringAsFixed(1)}x',
                      decreasedValue:
                          '${_sliderStep(_ttsSpeed, -0.1).toStringAsFixed(1)}x',
                      onIncrease: () => _setTtsSpeed(
                        _sliderStep(_ttsSpeed, 0.1),
                      ),
                      onDecrease: () => _setTtsSpeed(
                        _sliderStep(_ttsSpeed, -0.1),
                      ),
                      child: ExcludeSemantics(
                        child: Slider(
                          value: _ttsSpeed,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          onChanged: _setTtsSpeed,
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
                      slider: true,
                      label: l10n.settingsVoicePitchLabel,
                      value: '${_ttsPitch.toStringAsFixed(1)}x',
                      increasedValue:
                          '${_sliderStep(_ttsPitch, 0.1).toStringAsFixed(1)}x',
                      decreasedValue:
                          '${_sliderStep(_ttsPitch, -0.1).toStringAsFixed(1)}x',
                      onIncrease: () => _setTtsPitch(
                        _sliderStep(_ttsPitch, 0.1),
                      ),
                      onDecrease: () => _setTtsPitch(
                        _sliderStep(_ttsPitch, -0.1),
                      ),
                      child: ExcludeSemantics(
                        child: Slider(
                          value: _ttsPitch,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          onChanged: _setTtsPitch,
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
                        slider: true,
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
                    obscureText: !Platform.isAndroid,
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
          ),
      ),
    );
  }
}
