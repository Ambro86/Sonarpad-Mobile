import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/news_service.dart';
import '../services/news_sources/news_rss_source.dart';
import 'news_webview_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _service = NewsService();
  NewsLanguage? _language;
  List<NewsRssSource>? _sources;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_language == null) {
      final code = AppLocalizations.of(context).locale.languageCode;
      _language = switch (code) {
        'en' => NewsLanguage.english,
        'fr' => NewsLanguage.french,
        'es' => NewsLanguage.spanish,
        _ => NewsLanguage.italian,
      };
      _loadSources();
    }
  }

  Future<void> _loadSources() async {
    if (_language == null) return;
    final sources = await _service.getOrderedSources(_language!);
    if (mounted) {
      setState(() {
        _sources = sources;
      });
    }
  }

  void _openSource(NewsRssSource source) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/news/source'),
        builder: (_) => _NewsSourceArticlesScreen(
          source: source,
        ),
      ),
    );
  }

  Future<void> _restoreSources() async {
    if (_language == null) return;
    await _service.restoreHiddenSources(_language!);
    await _loadSources();
  }

  Future<void> _addCustomSource() async {
    if (_language == null) return;
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).addRssSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome testata/sito'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(labelText: 'URL feed RSS'),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).add),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameCtrl.text.trim();
    final url = urlCtrl.text.trim();
    if (name.isEmpty || url.isEmpty) return;

    try {
      await _service.addCustomSource(_language!, name, url);
      await _loadSources();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).errorPrefix}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.news),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Aggiungi sorgente RSS personalizzata',
            onPressed: _addCustomSource,
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.restoreHiddenSources,
            onPressed: _restoreSources,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<NewsLanguage>(
              initialValue: _language,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.newsLanguage),
              items: NewsLanguage.values
                  .map(
                    (lang) => DropdownMenuItem(
                      value: lang,
                      child: Text(lang.label(l10n)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _language = value;
                  _sources = null;
                });
                _loadSources();
              },
            ),
          ),
          Expanded(
            child: _sources == null
                ? const Center(child: CircularProgressIndicator())
                : _NewsSourceList(
                    sources: _sources!,
                    language: _language!,
                    service: _service,
                    onSourceSelected: _openSource,
                    onSourcesChanged: _loadSources,
                  ),
          ),
        ],
      ),
    );
  }
}

class _NewsSourceArticlesScreen extends StatefulWidget {
  const _NewsSourceArticlesScreen({
    required this.source,
  });

  final NewsRssSource source;

  @override
  State<_NewsSourceArticlesScreen> createState() =>
      _NewsSourceArticlesScreenState();
}

class _NewsSourceArticlesScreenState extends State<_NewsSourceArticlesScreen> {
  final _service = NewsService();
  late Future<List<NewsArticle>> _future;
  late Uri _currentUri;

  @override
  void initState() {
    super.initState();
    _currentUri = widget.source.uri;
    _fetch();
  }

  void _fetch() {
    final cat = widget.source.categories
        ?.where((c) => c.uri == _currentUri)
        .firstOrNull;
    if (cat != null && cat.isLocal) {
      _future = _fetchLocalCategory(cat);
    } else {
      _future = _service.fetchSourceNews(NewsRssSource(
        name: widget.source.name,
        uri: _currentUri,
      ));
    }
  }

  Future<List<NewsArticle>> _fetchLocalCategory(NewsRssCategory cat) async {
    final lang = AppLocalizations.of(context).locale.languageCode;
    final loc = await _service.getUserLocationData();
    if (loc != null) {
      final city = loc['city']!;
      final country = loc['countryCode']!;
      final searchUri = Uri.parse(
          'https://news.google.com/rss/search?q=${Uri.encodeComponent(city)}&hl=$lang&gl=$country&ceid=$country:$lang');
      return _service.fetchSourceNews(
          NewsRssSource(name: widget.source.name, uri: searchUri));
    }
    // Fallback to top news if location fails
    return _service.fetchSourceNews(
        NewsRssSource(name: widget.source.name, uri: widget.source.uri));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.source.name)),
      body: Column(
        children: [
          if (widget.source.categories != null &&
              widget.source.categories!.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(AppLocalizations.of(context).newsCategoryTop),
                    selected: _currentUri == widget.source.uri,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _currentUri = widget.source.uri;
                          _fetch();
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ...widget.source.categories!.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat.name),
                        selected: _currentUri == cat.uri,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _currentUri = cat.uri;
                              _fetch();
                            });
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          Expanded(
            child: _NewsArticleList(future: _future),
          ),
        ],
      ),
    );
  }
}

enum _NewsSourceAction { moveUp, moveDown, moveToPosition, hide, delete }

class _NewsSourceList extends StatelessWidget {
  const _NewsSourceList({
    required this.sources,
    required this.language,
    required this.service,
    required this.onSourceSelected,
    required this.onSourcesChanged,
  });

  final List<NewsRssSource> sources;
  final NewsLanguage language;
  final NewsService service;
  final ValueChanged<NewsRssSource> onSourceSelected;
  final VoidCallback onSourcesChanged;

  void _handleAction(
      BuildContext context, _NewsSourceAction action, int index) async {
    try {
      if (action == _NewsSourceAction.hide) {
        await service.hideSource(language, sources[index]);
        onSourcesChanged();
        return;
      }
      if (action == _NewsSourceAction.delete) {
        await service.removeCustomSource(language, sources[index].name);
        onSourcesChanged();
        return;
      }

      final list = List<NewsRssSource>.from(sources);
      final item = list.removeAt(index);

      if (action == _NewsSourceAction.moveUp && index > 0) {
        list.insert(index - 1, item);
        await service.saveSourcesOrder(language, list);
        onSourcesChanged();
      } else if (action == _NewsSourceAction.moveDown && index < list.length) {
        list.insert(index + 1, item);
        await service.saveSourcesOrder(language, list);
        onSourcesChanged();
      } else if (action == _NewsSourceAction.moveToPosition) {
        list.insert(index, item); // put it back temporarily
        final newPos = await showDialog<int>(
          context: context,
          builder: (_) => _PositionSliderDialog(
            currentIndex: index,
            sources: list,
          ),
        );
        if (newPos != null && newPos != index) {
          final toMove = list.removeAt(index);
          list.insert(newPos, toMove);
          await service.saveSourcesOrder(language, list);
          onSourcesChanged();
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).errorPrefix}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      itemCount: sources.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final source = sources[index];
        final isFirst = index == 0;
        final isLast = index == sources.length - 1;

        return MergeSemantics(
          child: Semantics(
            customSemanticsActions: {
              if (!isFirst)
                CustomSemanticsAction(label: l10n.moveUp): () =>
                    _handleAction(context, _NewsSourceAction.moveUp, index),
              if (!isLast)
                CustomSemanticsAction(label: l10n.moveDown): () =>
                    _handleAction(context, _NewsSourceAction.moveDown, index),
              CustomSemanticsAction(label: l10n.moveToPosition): () =>
                  _handleAction(
                      context, _NewsSourceAction.moveToPosition, index),
              CustomSemanticsAction(label: l10n.hide): () =>
                  _handleAction(context, _NewsSourceAction.hide, index),
              if (source.isCustom)
                CustomSemanticsAction(label: 'Elimina sorgente'): () =>
                    _handleAction(context, _NewsSourceAction.delete, index),
            },
            child: ListTile(
              title: Text(source.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSourceSelected(source),
            ),
          ),
        );
      },
    );
  }
}

class _PositionSliderDialog extends StatefulWidget {
  final int currentIndex;
  final List<NewsRssSource> sources;

  const _PositionSliderDialog(
      {required this.currentIndex, required this.sources});

  @override
  State<_PositionSliderDialog> createState() => _PositionSliderDialogState();
}

class _PositionSliderDialogState extends State<_PositionSliderDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentIndex.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pos = _value.toInt();

    String label;
    if (pos == widget.sources.length - 1) {
      label = l10n.positionLabelLast;
    } else {
      final targetIndex = pos >= widget.currentIndex ? pos + 1 : pos;
      final targetName = targetIndex < widget.sources.length
          ? widget.sources[targetIndex].name
          : '';
      label = l10n.positionLabel(pos + 1, targetName);
    }

    return AlertDialog(
      title: Text(l10n.moveToPosition),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Slider(
            value: _value,
            min: 0,
            max: (widget.sources.length - 1).toDouble(),
            divisions:
                widget.sources.length > 1 ? widget.sources.length - 1 : 1,
            label: (pos + 1).toString(),
            onChanged: (val) {
              setState(() {
                _value = val;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, pos),
          child: Text(AppLocalizations.of(context).ok),
        ),
      ],
    );
  }
}

class _NewsArticleList extends StatelessWidget {
  const _NewsArticleList({
    required this.future,
  });

  final Future<List<NewsArticle>> future;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<NewsArticle>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(
              semanticsLabel: l10n.loadingNews,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text(l10n.error(snapshot.error!)));
        }
        final articles = snapshot.data ?? const [];
        if (articles.isEmpty) {
          return Center(child: Text(l10n.noNewsFound));
        }
        return ListView.separated(
          itemCount: articles.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final article = articles[index];
            return ListTile(
              title: Text(article.title),
              subtitle: Text(
                '${article.source}. ${article.summary}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/news/article'),
                  builder: (_) => NewsWebViewScreen(article: article),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
