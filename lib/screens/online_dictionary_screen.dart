import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../services/online_dictionary_service.dart';
import '../services/recent_searches_service.dart';
import '../utils/app_logger.dart';
import '../widgets/universal_accessible_view.dart';
import 'recent_searches_screen.dart';

typedef DictionaryServiceFactory = OnlineDictionaryService Function();

class OnlineDictionaryScreen extends StatefulWidget {
  const OnlineDictionaryScreen({super.key, this.serviceFactory});
  final DictionaryServiceFactory? serviceFactory;
  @override
  State<OnlineDictionaryScreen> createState() => _OnlineDictionaryScreenState();
}

class _OnlineDictionaryScreenState extends State<OnlineDictionaryScreen> {
  static const languages = [
    'it',
    'en',
    'de',
    'es',
    'fr',
    'pt',
    'cs',
    'pl',
    'ro',
    'tr',
    'uk',
    'zh',
    'lt',
    'sv',
    'vi',
    'sr',
    'ru',
    'hi',
  ];
  String _query = '';
  String? _language;
  String _translation = 'en';
  bool _changed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_language != null) return;
    final code = AppLocalizations.of(
      context,
    ).localeName.split(RegExp('[_-]')).first;
    _language = languages.contains(code) ? code : 'en';
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _changed) return;
    setState(() {
      final saved = prefs.getString('online_dictionary_language');
      if (languages.contains(saved)) _language = saved;
      final translation = prefs.getString('online_dictionary_translation');
      if (translation == '' || languages.contains(translation)) {
        _translation = translation!;
      }
    });
  }

  Future<void> _save() async {
    final language = _language!;
    final translation = _translation;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('online_dictionary_language', language);
    await prefs.setString('online_dictionary_translation', translation);
  }

  void _search() {
    final query = _query.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    unawaited(_save());
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/online-dictionary/results'),
        builder: (_) => OnlineDictionaryResultsScreen(
          word: query,
          language: _language!,
          translation: _translation,
          serviceFactory: widget.serviceFactory,
        ),
      ),
    );
  }

  AccessibleListRow _slider(
    String id,
    String title,
    String value,
    List<String> choices,
    void Function(String) change,
  ) {
    final l10n = AppLocalizations.of(context);
    String label(String code) =>
        code.isEmpty ? l10n.onlineDictionaryNone : l10n.languageLabel(code);
    final index = choices.indexOf(value).clamp(0, choices.length - 1);
    return AccessibleListRow(
      id: id,
      title: title,
      kind: 'slider',
      value: value,
      valueLabel: label(choices[index]),
      sliderValue: index.toDouble(),
      sliderMin: 0,
      sliderMax: (choices.length - 1).toDouble(),
      sliderStep: 1,
      options: [
        for (var i = 0; i < choices.length; i++)
          AccessibleOption(value: i, label: label(choices[i])),
      ],
      sliderIncreasedValueLabel: label(
        choices[(index + 1).clamp(0, choices.length - 1)],
      ),
      sliderDecreasedValueLabel: label(
        choices[(index - 1).clamp(0, choices.length - 1)],
      ),
      onValueChanged: (value) {
        final number = num.tryParse('$value');
        if (number == null || !number.isFinite) return;
        setState(() {
          _changed = true;
          change(choices[number.round().clamp(0, choices.length - 1)]);
        });
        unawaited(_save());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.onlineDictionaryTitle)),
      body: UniversalAccessibleList(
        initialFocusId: 'word',
        sections: [
          AccessibleListSection(
            rows: [
              AccessibleListRow(
                id: 'word',
                title: l10n.onlineDictionaryWord,
                kind: 'textField',
                value: _query,
                textInputAction: 'search',
                onValueChanged: (value) => _query = value?.toString() ?? '',
                onSubmitted: (_) => _search(),
              ),
              _slider(
                'language',
                l10n.onlineDictionaryLanguage,
                _language!,
                languages,
                (v) => _language = v,
              ),
              _slider(
                'translation',
                l10n.onlineDictionaryTranslation,
                _translation,
                ['', ...languages],
                (v) => _translation = v,
              ),
              AccessibleListRow(
                id: 'search',
                title: l10n.search,
                kind: 'button',
                finishEditingOnActivate: true,
                onActivate: _search,
              ),
              AccessibleListRow(
                id: 'recent',
                title: l10n.audiodescriptionRecent,
                kind: 'button',
                onActivate: () async {
                  final value = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => RecentSearchesScreen(
                        title: l10n.audiodescriptionRecent,
                        domain: 'online_dictionary',
                      ),
                    ),
                  );
                  if (!mounted || value == null) return;
                  setState(() => _query = value);
                  _search();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnlineDictionaryResultsScreen extends StatefulWidget {
  const OnlineDictionaryResultsScreen({
    super.key,
    required this.word,
    required this.language,
    this.translation = '',
    this.serviceFactory,
  });
  final String word, language, translation;
  final DictionaryServiceFactory? serviceFactory;
  @override
  State<OnlineDictionaryResultsScreen> createState() =>
      _OnlineDictionaryResultsScreenState();
}

class _OnlineDictionaryResultsScreenState
    extends State<OnlineDictionaryResultsScreen> {
  OnlineDictionaryService? _service;
  DictionaryEntry? _entry, _translated;
  String? _error, _translationError;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _service?.close();
    final service = widget.serviceFactory?.call() ?? OnlineDictionaryService();
    _service = service;
    setState(() {
      _loading = true;
      _error = null;
      _translationError = null;
    });
    final clock = Stopwatch()..start();
    try {
      final entry = await service.lookup(
        widget.word,
        language: widget.language,
      );
      DictionaryEntry? translated;
      String? translationError;
      if (!mounted || generation != _generation) return;
      if (widget.translation.isNotEmpty &&
          widget.translation != widget.language) {
        try {
          translated = await service.lookup(
            widget.word,
            language: widget.translation,
          );
        } catch (e) {
          translationError = e is DictionaryRequestException
              ? e.code
              : 'network';
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _entry = entry;
        _translated = translated;
        _translationError = translationError;
        _loading = false;
      });
      unawaited(
        RecentSearchesService().addSearch('online_dictionary', widget.word),
      );
      unawaited(
        AppLogger.log(
          'Dictionary lookup language=${widget.language} '
          'definitions=${entry.definitions.length} synonyms=${entry.synonyms.length} '
          'translation=${widget.translation} translationError=$translationError '
          'elapsedMs=${clock.elapsedMilliseconds}',
        ),
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      final code = e is DictionaryRequestException ? e.code : 'network';
      setState(() {
        _error = code;
        _loading = false;
      });
      unawaited(
        AppLogger.log(
          'Dictionary lookup language=${widget.language} '
          'error=$code elapsedMs=${clock.elapsedMilliseconds}',
        ),
      );
    }
  }

  @override
  void dispose() {
    _generation++;
    _service?.close();
    super.dispose();
  }

  List<AccessibleListRow> _entryRows(DictionaryEntry entry, String prefix) {
    final l10n = AppLocalizations.of(context);
    return [
      AccessibleListRow(
        id: '$prefix-heading',
        title: l10n.onlineDictionaryEntryTitle(
          entry.word,
          l10n.languageLabel(entry.language),
        ),
        kind: 'header',
      ),
      AccessibleListRow(
        id: '$prefix-definitions',
        title: l10n.onlineDictionaryDefinitions,
        kind: 'header',
      ),
      for (var i = 0; i < entry.definitions.length; i++)
        AccessibleListRow(
          id: '$prefix-definition-$i',
          title: l10n.onlineDictionaryDefinition(i + 1, entry.definitions[i]),
          kind: 'text',
        ),
      if (entry.synonyms.isNotEmpty) ...[
        AccessibleListRow(
          id: '$prefix-synonyms',
          title: l10n.onlineDictionarySynonyms,
          kind: 'header',
        ),
        for (var i = 0; i < entry.synonyms.length; i++)
          AccessibleListRow(
            id: '$prefix-synonym-$i',
            title: entry.synonyms[i],
            kind: 'text',
          ),
      ],
      if (entry.limited)
        AccessibleListRow(
          id: '$prefix-limited',
          title: l10n.onlineDictionaryLimited,
          kind: 'text',
        ),
      AccessibleListRow(
        id: '$prefix-source',
        title: l10n.onlineDictionarySource(entry.source.toString()),
        kind: 'text',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <AccessibleListRow>[
      if (_loading) ...[
        AccessibleListRow(id: 'loading', title: l10n.loading, kind: 'text'),
        AccessibleListRow(
          id: 'cancel',
          title: l10n.cancel,
          kind: 'button',
          onActivate: () => Navigator.of(context).pop(),
        ),
      ] else if (_error != null) ...[
        AccessibleListRow(
          id: 'error',
          title: _error == 'not_found'
              ? l10n.onlineDictionaryNotFound
              : l10n.error(l10n.technicalErrorGeneric),
          kind: 'text',
        ),
        AccessibleListRow(
          id: 'retry',
          title: l10n.retry,
          kind: 'button',
          onActivate: _load,
        ),
      ] else ...[
        ..._entryRows(_entry!, 'entry'),
        if (_translated != null) ..._entryRows(_translated!, 'translation'),
        if (_translationError != null && _translationError != 'not_found')
          AccessibleListRow(
            id: 'translation-error',
            title:
                '${l10n.onlineDictionaryTranslation} ${l10n.error(l10n.technicalErrorGeneric)}',
            kind: 'text',
          ),
      ],
    ];
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.searchResults)),
      body: UniversalAccessibleList(
        key: ValueKey(
          'dictionary-${_loading ? 'loading' : _error ?? 'result'}',
        ),
        initialFocusId: rows.first.id,
        sections: [AccessibleListSection(rows: rows)],
      ),
    );
  }
}
