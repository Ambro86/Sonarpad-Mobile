import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/document_library_service.dart';
import '../services/recent_searches_service.dart';
import '../services/treccani_service.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';
import 'document_reader_screen.dart';
import 'recent_searches_screen.dart';

class TreccaniScreen extends StatefulWidget {
  const TreccaniScreen({super.key});

  @override
  State<TreccaniScreen> createState() => _TreccaniScreenState();
}

class _TreccaniScreenState extends State<TreccaniScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/treccani/results'),
        builder: (_) => _TreccaniResultsScreen(query: query),
      ),
    );
  }

  Future<void> _openRecentArticle(String title) async {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.loading),
      ),
    );
    try {
      final results = await TreccaniService().search(title);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (results.isEmpty) {
        showStatusMessage(context, l10n.articleNotFound);
        return;
      }
      final match = results.firstWhere(
        (result) => result.title.toLowerCase() == title.toLowerCase(),
        orElse: () => results.first,
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/treccani/article'),
          builder: (_) => _TreccaniArticleScreen(result: match),
        ),
      );
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        showStatusMessage(
          context,
          '${l10n.errorOpening}: ${l10n.technicalErrorGeneric}',
        );
      }
    }
  }

  Future<void> _openRecent() async {
    final l10n = AppLocalizations.of(context);
    final query = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RecentSearchesScreen(
          title: l10n.recentArticles,
          domain: 'treccani',
        ),
      ),
    );
    if (query != null && mounted) await _openRecentArticle(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.treccaniTitle)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              key: const ValueKey('shared-treccani-main'),
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'query',
                      title: l10n.treccaniSearchLabel,
                      kind: 'textField',
                      value: _controller.text,
                      textInputAction: 'search',
                      onSubmitted: (_) => _search(),
                    ),
                    AccessibleListRow(
                      id: 'recent',
                      title: l10n.recentArticles,
                      kind: 'action',
                    ),
                    AccessibleListRow(
                      id: 'search',
                      title: l10n.search,
                      kind: 'button',
                    ),
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
                if (event.type != 'activate') return;
                if (event.id == 'search') {
                  _search();
                } else if (event.id == 'recent') {
                  await _openRecent();
                }
              },
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: l10n.treccaniSearchLabel,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: _openRecent,
                  child: Text(l10n.recentArticles),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _search,
                  child: Text(l10n.search),
                ),
              ],
            ),
    );
  }
}

class _TreccaniResultsScreen extends StatefulWidget {
  final String query;

  const _TreccaniResultsScreen({required this.query});

  @override
  State<_TreccaniResultsScreen> createState() =>
      _TreccaniResultsScreenState();
}

class _TreccaniResultsScreenState extends State<_TreccaniResultsScreen> {
  final _service = TreccaniService();
  late final Future<List<TreccaniSearchResult>> _results;

  @override
  void initState() {
    super.initState();
    _results = _service.search(widget.query);
  }

  void _openArticle(TreccaniSearchResult result) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/treccani/article'),
        builder: (_) => _TreccaniArticleScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.searchResults)),
      body: FutureBuilder<List<TreccaniSearchResult>>(
        future: _results,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.treccaniSearchLabel,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.error(l10n.technicalErrorGeneric)));
          }
          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return Center(child: Text(l10n.treccaniNoResults));
          }
          if (useSharedAccessibleViewModel) {
            return UniversalAccessibleList(
              key: ValueKey('shared-treccani-results-${results.length}'),
              sections: [
                AccessibleListSection(
                  rows: results.asMap().entries.map((entry) {
                    final result = entry.value;
                    return AccessibleListRow(
                      id: entry.key.toString(),
                      title: result.title,
                      subtitle: result.description.isEmpty
                          ? null
                          : result.description,
                      kind: 'action',
                    );
                  }).toList(),
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
                subtitle: result.description.isEmpty
                    ? null
                    : Text(result.description),
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

class _TreccaniArticleScreen extends StatefulWidget {
  final TreccaniSearchResult result;

  const _TreccaniArticleScreen({required this.result});

  @override
  State<_TreccaniArticleScreen> createState() => _TreccaniArticleScreenState();
}

class _TreccaniArticleScreenState extends State<_TreccaniArticleScreen> {
  final _service = TreccaniService();
  TreccaniArticle? _article;
  Object? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final article = await _service.loadArticle(widget.result);
      await RecentSearchesService().addSearch('treccani', article.title);
      if (!mounted) return;
      setState(() => _article = article);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final article = _article;
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(widget.result.title)),
      body: useSharedAccessibleViewModel &&
              !_loading &&
              _loadError == null &&
              article != null
          ? UniversalAccessibleList(
              key: ValueKey(
                'shared-treccani-article-${article.sections.length}',
              ),
              sections: [
                AccessibleListSection(
                  header: article.title,
                  rows: [
                    AccessibleListRow(
                      id: '0',
                      title: l10n.treccaniWholeEntry,
                      kind: 'action',
                    ),
                    ...article.sections.asMap().entries.map(
                          (entry) => AccessibleListRow(
                            id: '${entry.key + 1}',
                            title: _sectionLabel(entry.value),
                            kind: 'action',
                          ),
                        ),
                  ],
                ),
              ],
              onEvent: (event) async {
                if (event.type != 'activate' || event.id == null) return;
                final index = int.tryParse(event.id!);
                if (index != null) await _openAsDocument(index);
              },
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_loading)
                  Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: l10n.loading,
                    ),
                  ),
                if (_loadError != null)
                  Text(l10n.error(l10n.technicalErrorGeneric)),
                if (article != null) ...[
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.article),
                    title: Text(l10n.treccaniWholeEntry),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openAsDocument(0),
                  ),
                  for (var i = 0; i < article.sections.length; i += 1)
                    ListTile(
                      leading: const Icon(Icons.subject),
                      title: Text(_sectionLabel(article.sections[i])),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openAsDocument(i + 1),
                    ),
                ],
              ],
            ),
    );
  }

  String _sectionLabel(TreccaniArticleSection section) {
    final indent = section.level <= 2 ? '' : '  ' * (section.level - 2);
    return '$indent${section.title}';
  }

  String _selectedText(int selectedSection) {
    final article = _article;
    if (article == null) return '';
    final raw = selectedSection == 0
        ? article.text
        : article.sections[selectedSection - 1].text;
    return _cleanHeadingMarks(raw);
  }

  String _cleanHeadingMarks(String text) => text
      .split('\n')
      .map(_cleanHeadingLine)
      .join('\n')
      .trim();

  String _cleanHeadingLine(String line) {
    final trimmed = line.trim();
    for (var level = 6; level >= 2; level -= 1) {
      final marks = '=' * level;
      final prefix = '$marks ';
      final suffix = ' $marks';
      if (!trimmed.startsWith(prefix) || !trimmed.endsWith(suffix)) continue;
      final body = trimmed
          .substring(prefix.length, trimmed.length - suffix.length)
          .trim();
      if (body.isEmpty || body.contains('==')) return line;
      return '\n\n$body.\n\n';
    }
    return line;
  }

  Future<void> _openAsDocument(int selectedSection) async {
    final l10n = AppLocalizations.of(context);
    final article = _article;
    if (article == null) return;
    final selectedText = _selectedText(selectedSection);
    if (selectedText.isEmpty) return;

    var documentName = article.title;
    if (selectedSection > 0) {
      documentName += ' - ${article.sections[selectedSection - 1].title}';
    }
    final content = '$selectedText\n\n${l10n.source(l10n.treccaniTitle)}\n${article.url}';

    try {
      final document = await DocumentLibraryService().createTextDocument(
        name: '$documentName.txt',
        content: content,
        isTemporary: true,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/documents/reader'),
          builder: (_) => DocumentReaderScreen(document: document),
        ),
      );
    } catch (_) {
      if (mounted) {
        showStatusMessage(
          context,
          '${l10n.saveError}: ${l10n.technicalErrorGeneric}',
        );
      }
    }
  }
}
