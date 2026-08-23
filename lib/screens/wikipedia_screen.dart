import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../services/wikipedia_service.dart';
import '../services/document_library_service.dart';
import '../services/recent_searches_service.dart';
import 'document_reader_screen.dart';
import 'recent_searches_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class WikipediaScreen extends StatefulWidget {
  const WikipediaScreen({super.key});

  @override
  State<WikipediaScreen> createState() => _WikipediaScreenState();
}

class _WikipediaScreenState extends State<WikipediaScreen> {
  final _controller = TextEditingController();
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_language == null) {
      final code = AppLocalizations.of(context).localeName;
      _language = switch (code) {
        'en' => 'en',
        'es' => 'es',
        'fr' => 'fr',
        'pt' => 'pt',
        'pt_BR' => 'pt',
        'pl' => 'pl',
        'cs' => 'cs',
        'de' => 'de',
        'zh_CN' => 'zh',
        _ => 'it',
      };
    }
  }

  static const _languages = [
    'it',
    'en',
    'es',
    'pt',
    'fr',
    'de',
    'uk',
    'lt',
    'sv',
    'vi',
    'cs',
    'pl',
    'sr',
    'ru',
    'zh',
    'hi',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/wikipedia/results'),
        builder: (_) => _WikipediaResultsScreen(
          query: q,
          language: _language!,
        ),
      ),
    );
  }

  Future<void> _openRecentArticle(String title) async {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.loading),
      ),
    );
    try {
      final results = await WikipediaService().search(title, lang: _language!);
      if (!mounted) return;
      Navigator.of(context).pop(); // Chiude il dialog di caricamento

      if (results.isNotEmpty) {
        // Cerca il match esatto per titolo, altrimenti prende il primo
        final match = results.firstWhere(
          (r) => r.title.toLowerCase() == title.toLowerCase(),
          orElse: () => results.first,
        );
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/wikipedia/article'),
            builder: (_) => _WikipediaArticleScreen(
              result: match,
              language: _language!,
            ),
          ),
        );
      } else {
                showStatusMessage(context, l10n.articleNotFound);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
                showStatusMessage(context, "${l10n.errorOpening}: ${l10n.technicalErrorGeneric}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importFromWikipedia)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              key: ValueKey('shared-wikipedia-main-${_language ?? 'it'}'),
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'query',
                      title: l10n.searchWikipedia,
                      kind: 'textField',
                      value: _controller.text,
                      placeholder: l10n.searchWikipedia,
                      textInputAction: 'search',
                      onSubmitted: (_) => _search(),
                    ),
                    AccessibleListRow(
                      id: 'language',
                      title: l10n.wikipediaLanguage,
                      kind: 'picker',
                      value: _language ?? 'it',
                      valueLabel: l10n.languageLabel(_language ?? 'it'),
                      options: _languages
                          .map((code) => AccessibleOption(
                                value: code,
                                label: '${l10n.languageLabel(code)} ($code)',
                              ))
                          .toList(),
                    ),
                    AccessibleListRow(id: 'recent', title: l10n.recentArticles, kind: 'action'),
                    AccessibleListRow(id: 'search', title: l10n.search, kind: 'button'),
                  ],
                ),
              ],
              onEvent: (event) async {
                if (event.type == 'textChanged' && event.id == 'query') {
                  final value = event.value?.toString() ?? '';
                  _controller.value = TextEditingValue(
                    text: value,
                    selection: TextSelection.collapsed(offset: value.length),
                  );
                  return;
                }
                if (event.type == 'picker' && event.id == 'language') {
                  final value = event.value?.toString();
                  if (value != null) setState(() => _language = value);
                  return;
                }
                if (event.type != 'activate') return;
                if (event.id == 'search') {
                  _search();
                } else if (event.id == 'recent') {
                  final q = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (ctx) => RecentSearchesScreen(
                        title: l10n.recentArticles,
                        domain: 'wikipedia',
                      ),
                    ),
                  );
                  if (q != null && mounted) await _openRecentArticle(q);
                }
              },
            )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: l10n.searchWikipedia),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: InputDecoration(labelText: l10n.wikipediaLanguage),
            items: _languages
                .map((code) => DropdownMenuItem(
                    value: code,
                    child: Text('${l10n.languageLabel(code)} ($code)')))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _language = value;
              });
            },
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              final q = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (ctx) => RecentSearchesScreen(
                    title: l10n.recentArticles,
                    domain: 'wikipedia',
                  ),
                ),
              );
              if (q != null && mounted) {
                _openRecentArticle(q);
              }
            },
            child: Text(l10n.recentArticles),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _search, child: Text(l10n.search)),
        ],
      ),
    );
  }
}

class _WikipediaResultsScreen extends StatefulWidget {
  final String query;
  final String language;

  const _WikipediaResultsScreen({
    required this.query,
    required this.language,
  });

  @override
  State<_WikipediaResultsScreen> createState() =>
      _WikipediaResultsScreenState();
}

class _WikipediaResultsScreenState extends State<_WikipediaResultsScreen> {
  final _service = WikipediaService();
  late final Future<List<WikipediaSearchResult>> _results;

  @override
  void initState() {
    super.initState();
    _results = _service.search(widget.query, lang: widget.language);
  }

  void _openArticle(WikipediaSearchResult result) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/wikipedia/article'),
        builder: (_) => _WikipediaArticleScreen(
          result: result,
          language: widget.language,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchResults)),
      body: FutureBuilder<List<WikipediaSearchResult>>(
        future: _results,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.wikipediaSearch,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.error(l10n.technicalErrorGeneric)));
          }
          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return Center(child: Text(l10n.noWikipediaResults));
          }
          if (useSharedAccessibleViewModel) {
            return UniversalAccessibleList(
              key: ValueKey('shared-wikipedia-results-${results.length}'),
              sections: [
                AccessibleListSection(
                  rows: results.asMap().entries.map((entry) =>
                    AccessibleListRow(
                      id: entry.key.toString(),
                      title: entry.value.title,
                      kind: 'action',
                    )).toList(),
                ),
              ],
              onEvent: (event) {
                if (event.type != 'activate' || event.id == null) return;
                final index = int.tryParse(event.id!);
                if (index != null && index >= 0 && index < results.length) {
                  _openArticle(results[index]);
                }
              },
            );
          }
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = results[index];
              return ListTile(
                title: Text(result.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openArticle(result),
              );
            },
          );
        },
      ),
    );
  }
}

class _WikipediaArticleScreen extends StatefulWidget {
  final WikipediaSearchResult result;
  final String language;

  const _WikipediaArticleScreen({
    required this.result,
    required this.language,
  });

  @override
  State<_WikipediaArticleScreen> createState() =>
      _WikipediaArticleScreenState();
}

class _WikipediaArticleScreenState extends State<_WikipediaArticleScreen> {
  final _service = WikipediaService();
  WikipediaArticle? _article;
  Object? _importError;
  bool _importing = true;

  @override
  void initState() {
    super.initState();
    _import();
  }

  Future<void> _import() async {
    try {
      final article = await _service.importArticle(
        widget.result.pageId,
        lang: widget.language,
      );
      await RecentSearchesService().addSearch('wikipedia', article.title);
      if (!mounted) return;
      setState(() => _article = article);
    } catch (error) {
      if (!mounted) return;
      setState(() => _importError = error);
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final article = _article;
    return Scaffold(
      appBar: AppBar(title: Text(widget.result.title)),
      body: useSharedAccessibleViewModel && !_importing && _importError == null && article != null
          ? UniversalAccessibleList(
              key: ValueKey('shared-wikipedia-article-${article.sections.length}'),
              sections: [
                AccessibleListSection(
                  header: article.title,
                  rows: [
                    AccessibleListRow(
                      id: '0',
                      title: l10n.wikipediaImportWholeArticle,
                      kind: 'action',
                    ),
                    ...article.sections.asMap().entries.map((entry) =>
                      AccessibleListRow(
                        id: '${entry.key + 1}',
                        title: _sectionLabel(entry.value),
                        kind: 'action',
                      )),
                  ],
                ),
              ],
              onEvent: (event) async {
                if (event.type != 'activate' || event.id == null) return;
                final index = int.tryParse(event.id!);
                if (index != null) await _importToLibrary(index);
              },
            )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_importing)
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.wikipediaImporting,
              ),
            ),
          if (_importError != null)
            Text(l10n.error(l10n.technicalErrorGeneric)),
          if (article != null) ...[
            Text(article.title,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.article),
              title: Text(l10n.wikipediaImportWholeArticle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _importToLibrary(0),
            ),
            for (var i = 0; i < article.sections.length; i += 1)
              ListTile(
                leading: const Icon(Icons.subject),
                title: Text(_sectionLabel(article.sections[i])),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importToLibrary(i + 1),
              ),
          ],
        ],
      ),
    );
  }

  String _selectedText(int selectedSection) {
    final article = _article;
    if (article == null || selectedSection == 0) {
      return _cleanWikipediaHeadingMarks(article?.text ?? '');
    }
    return _cleanWikipediaHeadingMarks(
        article.sections[selectedSection - 1].text);
  }

  String _cleanWikipediaHeadingMarks(String text) {
    final lines = text.split('\n');
    final cleaned = <String>[];
    for (final line in lines) {
      cleaned.add(_cleanWikipediaHeadingLine(line));
    }
    return cleaned.join('\n').trim();
  }

  String _cleanWikipediaHeadingLine(String line) {
    final trimmed = line.trim();
    for (var level = 6; level >= 2; level -= 1) {
      final marks = '=' * level;
      final prefix = '$marks ';
      final suffix = ' $marks';
      if (!trimmed.startsWith(prefix) || !trimmed.endsWith(suffix)) {
        continue;
      }
      final body = trimmed
          .substring(prefix.length, trimmed.length - suffix.length)
          .trim();
      if (body.isEmpty || body.contains('==')) {
        return line;
      }
      // Aggiunge righe vuote e un punto finale per forzare la separazione
      // dei paragrafi e far fare una pausa naturale al TTS.
      return '\n\n$body.\n\n';
    }
    return line;
  }

  String _sectionLabel(WikipediaArticleSection section) {
    final indent = section.level <= 2 ? '' : '  ' * (section.level - 2);
    return '$indent${section.title}';
  }

  Future<void> _importToLibrary(int selectedSection) async {
    final article = _article;
    if (article == null) return;
    final text = _selectedText(selectedSection);
    if (text.isEmpty) return;

    String docName = article.title;
    if (selectedSection > 0) {
      docName += ' - ${article.sections[selectedSection - 1].title}';
    }

    try {
      final doc = await DocumentLibraryService().createTextDocument(
        name: '$docName.txt',
        content: text,
        isTemporary: true,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/documents/reader'),
          builder: (_) => DocumentReaderScreen(document: doc),
        ),
      );
    } catch (e) {
      if (mounted) {
                final l10n = AppLocalizations.of(context);
        showStatusMessage(context, '${l10n.saveError}: ${l10n.technicalErrorGeneric}');
      }
    }
  }
}
