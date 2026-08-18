import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/document_library_service.dart';
import '../services/poetrydb_service.dart';
import 'document_reader_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class PoetryDbScreen extends StatefulWidget {
  final String? parentId;

  const PoetryDbScreen({super.key, this.parentId});

  @override
  State<PoetryDbScreen> createState() => _PoetryDbScreenState();
}

class _PoetryDbScreenState extends State<PoetryDbScreen> {
  final _controller = TextEditingController();
  PoetryDbSearchField _field = PoetryDbSearchField.title;

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
        settings: const RouteSettings(name: '/poetrydb/results'),
        builder: (_) => _PoetryDbResultsScreen(
          query: query,
          field: _field,
          parentId: widget.parentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PoetryDB')),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [AccessibleListSection(rows: [
                AccessibleListRow(id: 'query', title: l10n.poetryDbSearchLabel, kind: 'textField', value: _controller.text),
                AccessibleListRow(
                  id: 'field',
                  title: l10n.poetryDbSearchBy,
                  kind: 'picker',
                  value: _field.name,
                  options: [
                    AccessibleOption(value: PoetryDbSearchField.title.name, label: l10n.poetryDbSearchByTitle),
                    AccessibleOption(value: PoetryDbSearchField.author.name, label: l10n.poetryDbSearchByAuthor),
                  ],
                ),
                AccessibleListRow(id: 'search', title: l10n.search, kind: 'button'),
              ])],
              onEvent: (event) {
                if (event.id == 'query' && event.type == 'textChanged') {
                  _controller.text = event.value?.toString() ?? '';
                } else if (event.id == 'field' && event.type == 'picker') {
                  final value = event.value?.toString();
                  final found = PoetryDbSearchField.values.where((e) => e.name == value);
                  if (found.isNotEmpty) setState(() => _field = found.first);
                } else if (event.id == 'search' && event.type == 'activate') {
                  _search();
                }
              },
            )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: l10n.poetryDbSearchLabel),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<PoetryDbSearchField>(
            initialValue: _field,
            decoration: InputDecoration(labelText: l10n.poetryDbSearchBy),
            items: [
              DropdownMenuItem(
                value: PoetryDbSearchField.title,
                child: Text(l10n.poetryDbSearchByTitle),
              ),
              DropdownMenuItem(
                value: PoetryDbSearchField.author,
                child: Text(l10n.poetryDbSearchByAuthor),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _field = value);
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

class _PoetryDbResultsScreen extends StatefulWidget {
  final String query;
  final PoetryDbSearchField field;
  final String? parentId;

  const _PoetryDbResultsScreen({
    required this.query,
    required this.field,
    required this.parentId,
  });

  @override
  State<_PoetryDbResultsScreen> createState() => _PoetryDbResultsScreenState();
}

class _PoetryDbResultsScreenState extends State<_PoetryDbResultsScreen> {
  final _service = PoetryDbService();
  late final Future<List<PoetryDbPoem>> _poems;

  @override
  void initState() {
    super.initState();
    _poems = _service.search(widget.query, field: widget.field);
  }

  Future<void> _importPoem(PoetryDbPoem poem) async {
    try {
      final library = DocumentLibraryService();
      await library.load();
      final doc = await library.createTextDocument(
        name: '${poem.title} - ${poem.author}.txt',
        content: poem.toDocumentText(),
        parentId: widget.parentId,
      );
      await library.add(doc);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/documents/reader'),
          builder: (_) => DocumentReaderScreen(document: doc),
        ),
      );
    } catch (error) {
      if (!mounted) return;
            showStatusMessage(context, AppLocalizations.of(context).error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchResults)),
      body: FutureBuilder<List<PoetryDbPoem>>(
        future: _poems,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.loading,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.error(snapshot.error!)));
          }
          final poems = snapshot.data ?? const [];
          if (poems.isEmpty) {
            return Center(child: Text(l10n.poetryDbNoPoemsFound));
          }
          if (useSharedAccessibleViewModel) {
            return UniversalAccessibleList(
              sections: [AccessibleListSection(rows: [
                for (var i = 0; i < poems.length; i++)
                  AccessibleListRow(
                    id: 'poem_$i',
                    title: poems[i].title,
                    subtitle: poems[i].lineCount > 0
                        ? '${poems[i].author} - ${l10n.poetryDbLineCount(poems[i].lineCount)}'
                        : poems[i].author,
                  ),
              ])],
              onEvent: (event) {
                if (event.type != 'activate' || event.id == null) return;
                final i = int.tryParse(event.id!.replaceFirst('poem_', ''));
                if (i != null && i < poems.length) _importPoem(poems[i]);
              },
            );
          }
          return ListView.separated(
            itemCount: poems.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final poem = poems[index];
              final subtitle = poem.lineCount > 0
                  ? '${poem.author} - ${l10n.poetryDbLineCount(poem.lineCount)}'
                  : poem.author;
              return ListTile(
                title: Text(poem.title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importPoem(poem),
              );
            },
          );
        },
      ),
    );
  }
}
