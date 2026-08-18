import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../services/document_library_service.dart';
import '../services/gutendex_service.dart';
import '../utils/app_logger.dart';
import 'document_reader_screen.dart';
import '../utils/status_message.dart';
import 'package:sonarpad_mobile_starter/utils/accessibility_list_behavior.dart';

class GutenbergScreen extends StatefulWidget {
  final String? parentId;

  const GutenbergScreen({super.key, this.parentId});

  @override
  State<GutenbergScreen> createState() => _GutenbergScreenState();
}

class _GutenbergScreenState extends State<GutenbergScreen> {
  final _controller = TextEditingController();
  String _language = 'it';
  bool _languageInitialized = false;

  static const _languages = [
    ('it', 'Italiano'),
    ('en', 'English'),
    ('es', 'Español'),
    ('fr', 'Français'),
    ('de', 'Deutsch'),
    ('pt', 'Português'),
    ('pl', 'Polski'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_languageInitialized) return;
    _languageInitialized = true;
    final locale = AppLocalizations.of(context).localeName;
    if (_languages.any((entry) => entry.$1 == locale)) {
      _language = locale;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/gutenberg/results'),
        builder: (_) => _GutenbergResultsScreen(
          query: query,
          language: _language,
          parentId: widget.parentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Project Gutenberg')),
      body: ListView(
        scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: l10n.gutenbergSearchLabel,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: InputDecoration(labelText: l10n.sourceLanguageLabel),
            items: _languages
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.$1,
                    child: Text('${entry.$2} (${entry.$1})'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _language = value);
            },
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

class _GutenbergResultsScreen extends StatefulWidget {
  final String query;
  final String language;
  final String? parentId;

  const _GutenbergResultsScreen({
    required this.query,
    required this.language,
    required this.parentId,
  });

  @override
  State<_GutenbergResultsScreen> createState() =>
      _GutenbergResultsScreenState();
}

class _GutenbergResultsScreenState extends State<_GutenbergResultsScreen> {
  final _service = GutendexService();
  final _books = <GutendexBook>[];
  String? _nextPage;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? pageUrl}) async {
    setState(() {
      if (pageUrl == null) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await _service.searchBooks(
        widget.query,
        language: widget.language,
        pageUrl: pageUrl,
      );
      if (!mounted) return;
      setState(() {
        if (pageUrl == null) {
          _books
            ..clear()
            ..addAll(page.books);
        } else {
          _books.addAll(page.books);
        }
        _nextPage = page.next;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _openBook(GutendexBook book) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/gutenberg/book'),
        builder: (_) => _GutenbergBookScreen(
          book: book,
          parentId: widget.parentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchResults)),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.loading,
              ),
            );
          }
          if (_error != null) {
            return Center(child: Text(l10n.error(_error!)));
          }
          if (_books.isEmpty) {
            return Center(child: Text(l10n.noGutenbergBooksFound));
          }
          return ListView.separated(
            scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
            itemCount: _books.length + (_nextPage == null ? 0 : 1),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index >= _books.length) {
                return ListTile(
                  title: Text(_loadingMore ? l10n.loading : l10n.loadMore),
                  trailing: _loadingMore
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(Icons.expand_more),
                  onTap: _loadingMore || _nextPage == null
                      ? null
                      : () => _load(pageUrl: _nextPage),
                );
              }
              final book = _books[index];
              return ListTile(
                title: Text(book.title),
                subtitle: Text(book.authorLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openBook(book),
              );
            },
          );
        },
      ),
    );
  }
}

class _GutenbergBookScreen extends StatefulWidget {
  final GutendexBook book;
  final String? parentId;

  const _GutenbergBookScreen({required this.book, required this.parentId});

  @override
  State<_GutenbergBookScreen> createState() => _GutenbergBookScreenState();
}

class _GutenbergBookScreenState extends State<_GutenbergBookScreen> {
  final _service = GutendexService();
  bool _importing = false;

  Future<void> _importAndRead() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      await AppLogger.log(
        'Gutenberg import: start id=${widget.book.id} title="${widget.book.title}"',
      );
      final download = await _service.downloadForImport(widget.book);
      await AppLogger.log(
        'Gutenberg import: download ready fileName="${download.fileName}" '
        'isFile=${download.isFile} bytes=${download.bytes?.length ?? 0} '
        'textLength=${download.text?.length ?? 0}',
      );
      final library = DocumentLibraryService();
      await library.load();
      final doc = download.isFile
          ? await _importDownloadedFile(library, download)
          : await library.createTextDocument(
              name: download.fileName,
              content: download.text ?? '',
              parentId: widget.parentId,
            );
      await library.add(doc);
      await AppLogger.log(
        'Gutenberg import: saved document id="${doc.id}" name="${doc.name}" path="${doc.path}"',
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/documents/reader'),
          builder: (_) => DocumentReaderScreen(document: doc),
        ),
      );
    } catch (error) {
      await AppLogger.log('Gutenberg import: error $error');
      if (!mounted) return;
            showStatusMessage(context, AppLocalizations.of(context).error(error));
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<DocumentItem> _importDownloadedFile(
    DocumentLibraryService library,
    GutendexDownload download,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final ext = p.extension(download.fileName).isEmpty
        ? '.epub'
        : p.extension(download.fileName);
    final tempFile = File(
      p.join(
        tempDir.path,
        'gutenberg_${DateTime.now().microsecondsSinceEpoch}$ext',
      ),
    );
    await tempFile.writeAsBytes(download.bytes!);
    await AppLogger.log(
      'Gutenberg import: temp file="${tempFile.path}" size=${await tempFile.length()}',
    );
    return library.importFile(
      tempFile,
      originalName: download.fileName,
      parentId: widget.parentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final book = widget.book;
    final summary = book.summaries.isEmpty ? null : book.summaries.first;
    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: ListView(
        scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(book.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(book.authorLabel),
          if (book.languageLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.sourceLanguageValue(book.languageLabel)),
          ],
          if (summary != null && summary.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(summary),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _importing ? null : _importAndRead,
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.library_books),
            label: Text(_importing
                ? l10n.gutenbergImporting
                : l10n.gutenbergImportAndRead),
          ),
        ],
      ),
    );
  }
}
