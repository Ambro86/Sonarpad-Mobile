import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../services/wikipedia_service.dart';
import '../services/document_library_service.dart';
import '../models/document_item.dart';
import 'document_reader_screen.dart';

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
  bool _hideKeyboardWhenResultsArrive = false;
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
    FocusScope.of(context).unfocus();
    setState(() {
      _article = null;
      _importError = null;
      _hideKeyboardWhenResultsArrive = true;
      _selectedSection = 0;
      _results = _service.search(q, lang: _language);
    });
  }

  void _hideKeyboardForSearchResults() {
    if (!_hideKeyboardWhenResultsArrive) return;
    _hideKeyboardWhenResultsArrive = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
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
                _hideKeyboardForSearchResults();
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
            const SizedBox(height: 24),
            Semantics(
              hint:
                  'Salva l\'articolo nella libreria e avvia la lettura con Edge TTS',
              child: FilledButton.icon(
                onPressed: _importToLibrary,
                icon: const Icon(Icons.download),
                label: const Text('Importa e leggi',
                    style: TextStyle(fontSize: 18)),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _selectedText {
    final article = _article;
    if (article == null || _selectedSection == 0) {
      return _cleanWikipediaHeadingMarks(article?.text ?? '');
    }
    return _cleanWikipediaHeadingMarks(
        article.sections[_selectedSection - 1].text);
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

  Future<void> _importToLibrary() async {
    final article = _article;
    if (article == null) return;
    final text = _selectedText;
    if (text.isEmpty) return;

    String docName = article.title;
    if (_selectedSection > 0) {
      docName += ' - ${article.sections[_selectedSection - 1].title}';
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = docName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName =
          'wiki_${DateTime.now().microsecondsSinceEpoch}_$safeName.txt';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(text);

      final doc = DocumentItem(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        name: docName,
        path: file.path,
        extension: 'txt',
        addedAt: DateTime.now(),
        isTemporary: true,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/documents/reader'),
          builder: (_) => DocumentReaderScreen(document: doc),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio: $e')),
        );
      }
    }
  }
}
