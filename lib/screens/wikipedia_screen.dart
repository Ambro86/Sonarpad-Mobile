import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/wikipedia_service.dart';
import '../services/document_library_service.dart';
import '../services/recent_searches_service.dart';
import 'document_reader_screen.dart';
import 'recent_searches_screen.dart';

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
      final code = AppLocalizations.of(context).locale.languageCode;
      _language = code == 'es'
          ? 'es'
          : (code == 'fr' ? 'fr' : (code == 'en' ? 'en' : 'it'));
    }
  }

  static const _languages = [
    ('it', 'Italiano'),
    ('en', 'English'),
    ('es', 'Español'),
    ('pt', 'Português'),
    ('fr', 'Français'),
    ('de', 'Deutsch'),
    ('uk', 'Українська'),
    ('lt', 'Lietuvių'),
    ('sv', 'Svenska'),
    ('vi', 'Tiếng Việt'),
    ('cs', 'Čeština'),
    ('pl', 'Polski'),
    ('sr', 'Srpski'),
    ('ru', 'Русский'),
    ('zh', '中文'),
    ('hi', 'हिन्दी'),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).articleNotFound)),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context).errorOpening}: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importFromWikipedia)),
      body: ListView(
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
                .map((entry) => DropdownMenuItem(
                    value: entry.$1, child: Text('${entry.$2} (${entry.$1})')))
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
                  builder: (ctx) => const RecentSearchesScreen(
                    title: 'Articoli recenti',
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
            return Center(child: Text(l10n.error(snapshot.error!)));
          }
          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return Center(child: Text(l10n.noWikipediaResults));
          }
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_importing)
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.wikipediaImporting,
              ),
            ),
          if (_importError != null) Text(l10n.error(_importError!)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).saveError}: $e')),
        );
      }
    }
  }
}
