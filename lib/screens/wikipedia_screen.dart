import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/wikipedia_service.dart';

class WikipediaScreen extends StatefulWidget {
  const WikipediaScreen({super.key});

  @override
  State<WikipediaScreen> createState() => _WikipediaScreenState();
}

class _WikipediaScreenState extends State<WikipediaScreen> {
  final _service = WikipediaService();
  final _controller = TextEditingController();
  Future<List<WikipediaSearchResult>>? _results;
  WikipediaArticle? _article;
  bool _importing = false;
  Object? _importError;
  String _language = 'it';
  int _selectedSection = 0;

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
    setState(() {
      _article = null;
      _importError = null;
      _selectedSection = 0;
      _results = _service.search(q, lang: _language);
    });
  }

  Future<void> _import(WikipediaSearchResult result) async {
    setState(() {
      _article = null;
      _importing = true;
      _importError = null;
      _selectedSection = 0;
    });
    try {
      final article =
          await _service.importArticle(result.pageId, lang: _language);
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
                _article = null;
                _results = null;
                _importError = null;
                _selectedSection = 0;
              });
            },
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _search, child: Text(l10n.search)),
          const SizedBox(height: 16),
          if (_importing)
            Center(
                child: CircularProgressIndicator(
                    semanticsLabel: l10n.wikipediaImporting)),
          if (_importError != null) Text(l10n.error(_importError!)),
          if (_results != null && _article == null)
            FutureBuilder<List<WikipediaSearchResult>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                      child: CircularProgressIndicator(
                          semanticsLabel: l10n.wikipediaSearch));
                }
                if (snapshot.hasError) return Text(l10n.error(snapshot.error!));
                if ((snapshot.data ?? const []).isEmpty) {
                  return Text(l10n.noWikipediaResults);
                }
                return Column(
                  children: (snapshot.data ?? const [])
                      .map((r) => ListTile(
                          title: Text(r.title), onTap: () => _import(r)))
                      .toList(),
                );
              },
            ),
          if (_article != null) ...[
            Text(_article!.title,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedSection,
              decoration: InputDecoration(labelText: l10n.wikipediaImportMode),
              items: [
                DropdownMenuItem(
                    value: 0, child: Text(l10n.wikipediaImportWholeArticle)),
                for (var i = 0; i < _article!.sections.length; i += 1)
                  DropdownMenuItem(
                      value: i + 1,
                      child: Text(_sectionLabel(_article!.sections[i]))),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedSection = value);
              },
            ),
            const SizedBox(height: 12),
            SelectableText(_selectedText),
          ],
        ],
      ),
    );
  }

  String get _selectedText {
    final article = _article;
    if (article == null || _selectedSection == 0) {
      return article?.text ?? '';
    }
    return article.sections[_selectedSection - 1].text;
  }

  String _sectionLabel(WikipediaArticleSection section) {
    final indent = section.level <= 2 ? '' : '  ' * (section.level - 2);
    return '$indent${section.title}';
  }
}
