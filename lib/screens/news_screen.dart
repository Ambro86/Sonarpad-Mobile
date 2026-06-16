import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/app_settings_service.dart';
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
      final code = AppLocalizations.of(context).localeName;
      _language = switch (code) {
        'en' => NewsLanguage.english,
        'fr' => NewsLanguage.french,
        'es' => NewsLanguage.spanish,
        'pt' => NewsLanguage.portuguese,
        'pl' => NewsLanguage.polish,
        'cs' => NewsLanguage.czech,
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
          language: _language!,
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
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).newsSourceName,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).newsSourceUrlOrSearch,
              ),
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
        SnackBar(
            content: Text('${AppLocalizations.of(context).errorPrefix}: $e')),
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
            tooltip: l10n.addCustomNewsSource,
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
    required this.language,
    this.initialUri,
    this.title,
  });

  final NewsRssSource source;
  final NewsLanguage language;
  final Uri? initialUri;
  final String? title;

  @override
  State<_NewsSourceArticlesScreen> createState() =>
      _NewsSourceArticlesScreenState();
}

class _NewsSourceArticlesScreenState extends State<_NewsSourceArticlesScreen> {
  final _service = NewsService();
  final _settings = AppSettingsService();
  final _localCityController = TextEditingController();
  late Future<List<NewsArticle>> _future;
  late Uri _currentUri;

  @override
  void initState() {
    super.initState();
    _currentUri = widget.initialUri ?? widget.source.uri;
    _future = _buildFuture();
  }

  @override
  void dispose() {
    _localCityController.dispose();
    super.dispose();
  }

  void _openCategory(Uri uri, String title) {
    if (uri == _currentUri) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/news/source/category'),
        builder: (_) => _NewsSourceArticlesScreen(
          source: widget.source,
          language: widget.language,
          initialUri: uri,
          title: title,
        ),
      ),
    );
  }

  Future<List<NewsArticle>> _buildFuture() {
    final cat = widget.source.categories
        ?.where((c) => c.uri == _currentUri)
        .firstOrNull;
    final categorySourceName = widget.title ?? widget.source.name;
    if (cat != null && cat.isLocal) {
      return _fetchLocalCategory(categorySourceName);
    }
    return _service.fetchSourceNews(NewsRssSource(
      name: categorySourceName,
      uri: _currentUri,
    ));
  }

  void _fetch() {
    setState(() {
      _future = _buildFuture();
    });
  }

  Future<void> _refresh() async {
    _fetch();
    await _future;
  }

  Future<void> _reloadLocalCategory() async {
    final city = _localCityController.text.trim();
    if (city.isEmpty) return;
    await _settings.setNewsLocalCity(city);
    if (!mounted) return;
    setState(_fetch);
  }

  Future<List<NewsArticle>> _fetchLocalCategory(String categorySourceName) async {
    final lang = widget.language.code;
    final savedCity = await _settings.getNewsLocalCity();
    final loc = await _service.getUserLocationData();
    final detectedCity = loc?['city'] ?? '';
    final country = loc?['countryCode'] ?? _defaultCountryCode(widget.language);
    final city = savedCity.trim().isNotEmpty ? savedCity.trim() : detectedCity;
    if (mounted &&
        _localCityController.text.trim().isEmpty &&
        city.isNotEmpty) {
      _localCityController.text = city;
      _localCityController.selection =
          TextSelection.collapsed(offset: city.length);
    }
    if (city.isNotEmpty) {
      final searchUri = Uri.parse(
          'https://news.google.com/rss/search?q=${Uri.encodeComponent(city)}&hl=$lang&gl=$country&ceid=$country:$lang');
      return _service.fetchSourceNews(
          NewsRssSource(name: categorySourceName, uri: searchUri));
    }
    // Fallback to top news if location fails
    return _service.fetchSourceNews(
        NewsRssSource(name: categorySourceName, uri: widget.source.uri));
  }

  String _defaultCountryCode(NewsLanguage language) => switch (language) {
        NewsLanguage.english => 'US',
        NewsLanguage.french => 'FR',
        NewsLanguage.spanish => 'ES',
        NewsLanguage.portuguese => 'PT',
        NewsLanguage.polish => 'PL',
        NewsLanguage.czech => 'CZ',
        NewsLanguage.italian => 'IT',
      };

  @override
  Widget build(BuildContext context) {
    final showCategories = widget.initialUri == null;
    final currentCategory = widget.source.categories
        ?.where((c) => c.uri == _currentUri)
        .firstOrNull;
    final isLocalCategory = currentCategory?.isLocal == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? widget.source.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context).update,
            onPressed: _fetch,
          ),
        ],
      ),
      body: Column(
        children: [
          if (showCategories &&
              widget.source.categories != null &&
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
                        _openCategory(
                          widget.source.uri,
                          widget.source.name,
                        );
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
                            _openCategory(
                              cat.uri,
                              '${widget.source.name}: ${cat.name}',
                            );
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          if (isLocalCategory)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _localCityController,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context).newsLocalCityLabel,
                      hintText:
                          AppLocalizations.of(context).newsLocalCityHint,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _reloadLocalCategory(),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _reloadLocalCategory,
                    child: Text(AppLocalizations.of(context).update),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _NewsArticleList(
                future: _future,
                language: widget.language,
                sourceName: widget.title ?? widget.source.name,
              ),
            ),
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
        final newPos = await showDialog<int>(
          context: context,
          builder: (_) => _PositionSliderDialog(
            currentIndex: index,
            sources: sources,
          ),
        );
        if (newPos != null && newPos != index) {
          list.insert(newPos, item);
          await service.saveSourcesOrder(language, list);
          onSourcesChanged();
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${AppLocalizations.of(context).errorPrefix}: $e')),
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
            key: ValueKey('news_source_semantics_${source.name}'),
            container: true,
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
                CustomSemanticsAction(label: l10n.deleteNewsSource): () =>
                    _handleAction(context, _NewsSourceAction.delete, index),
            },
            child: ListTile(
              key: ValueKey('news_source_${source.name}'),
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
    final targetSources = [
      for (var i = 0; i < widget.sources.length; i++)
        if (i != widget.currentIndex) widget.sources[i],
    ];
    final maxPosition = targetSources.length;

    String positionLabel(int position) {
      if (position >= targetSources.length) {
        return l10n.positionLabelLast;
      }
      final targetName = targetSources[position].name;
      return l10n.positionLabel(position + 1, targetName);
    }

    void setPosition(int position) {
      setState(() {
        _value = position.clamp(0, maxPosition).toDouble();
      });
    }

    final label = positionLabel(pos);
    final increasedPosition = pos < maxPosition ? pos + 1 : maxPosition;
    final decreasedPosition = pos > 0 ? pos - 1 : 0;

    return AlertDialog(
      title: Text(l10n.moveToPosition),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Semantics(
            slider: true,
            label: l10n.moveToPosition,
            value: label,
            increasedValue: positionLabel(increasedPosition),
            decreasedValue: positionLabel(decreasedPosition),
            onIncrease: pos < maxPosition ? () => setPosition(pos + 1) : null,
            onDecrease: pos > 0 ? () => setPosition(pos - 1) : null,
            child: ExcludeSemantics(
              child: Slider(
                value: _value,
                min: 0,
                max: maxPosition.toDouble(),
                divisions: maxPosition > 0 ? maxPosition : null,
                label: (pos + 1).toString(),
                onChanged: (val) {
                  setState(() {
                    _value = val;
                  });
                },
              ),
            ),
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

class _NewsArticleList extends StatefulWidget {
  const _NewsArticleList({
    required this.future,
    required this.language,
    required this.sourceName,
  });

  final Future<List<NewsArticle>> future;
  final NewsLanguage language;
  final String sourceName;

  @override
  State<_NewsArticleList> createState() => _NewsArticleListState();
}

class _NewsArticleListState extends State<_NewsArticleList> {
  final _service = NewsService();
  Set<String> _readUris = {};
  bool _loadingRead = true;

  @override
  void initState() {
    super.initState();
    _loadReadArticles();
  }

  Future<void> _loadReadArticles() async {
    final list = await _service.getReadArticles(widget.language, widget.sourceName);
    if (!mounted) return;
    setState(() {
      _readUris = list.map((e) => e.id).toSet();
      _loadingRead = false;
    });
  }

  void _openReadArticles() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReadArticlesScreen(
          language: widget.language,
          sourceName: widget.sourceName,
        ),
      ),
    ).then((_) => _loadReadArticles());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<NewsArticle>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || _loadingRead) {
          return Center(
            child: CircularProgressIndicator(
              semanticsLabel: l10n.loadingNews,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text(l10n.error(snapshot.error!)));
        }
        final allArticles = snapshot.data ?? const [];
        final articles = allArticles.where((a) => !_readUris.contains(a.id)).toList();
        final itemCount = articles.length + (_readUris.isNotEmpty ? 1 : 0);

        if (itemCount == 0) {
          return Center(child: Text(l10n.noNewsFound));
        }

        return ListView.separated(
          itemCount: itemCount,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (_readUris.isNotEmpty && index == 0) {
              return ListTile(
                key: const ValueKey('news_read_articles'),
                leading: const Icon(Icons.history),
                title: Text(l10n.newsReadArticles),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openReadArticles,
              );
            }
            final articleIndex = _readUris.isNotEmpty ? index - 1 : index;
            final article = articles[articleIndex];
            final summaryTrimmed = article.summary.trim();
            final titleTrimmed = article.title.trim();
            final isSummaryDuplicate = summaryTrimmed.isNotEmpty &&
                (summaryTrimmed == titleTrimmed ||
                 summaryTrimmed.contains(titleTrimmed) ||
                 titleTrimmed.contains(summaryTrimmed));
            final subtitleText = isSummaryDuplicate
                ? article.source
                : '${article.source}. ${article.summary}';

            return ListTile(
              key: ValueKey('news_article_${article.id}'),
              title: Text(article.title),
              subtitle: Text(
                subtitleText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                final navigator = Navigator.of(context);
                await _service.addReadArticle(
                  widget.language,
                  widget.sourceName,
                  article,
                );
                if (!mounted) return;
                setState(() {
                  _readUris = {..._readUris, article.id};
                });
                await navigator.push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/news/article'),
                    builder: (_) => NewsWebViewScreen(
                      article: article,
                      language: widget.language,
                      readSourceName: widget.sourceName,
                    ),
                  ),
                );
                if (!mounted) return;
                await _loadReadArticles();
              },
            );
          },
        );
      },
    );
  }
}

class _ReadArticlesScreen extends StatefulWidget {
  final NewsLanguage language;
  final String sourceName;

  const _ReadArticlesScreen({required this.language, required this.sourceName});

  @override
  State<_ReadArticlesScreen> createState() => _ReadArticlesScreenState();
}

class _ReadArticlesScreenState extends State<_ReadArticlesScreen> {
  final _service = NewsService();
  List<NewsArticle> _articles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.getReadArticles(widget.language, widget.sourceName);
    if (!mounted) return;
    setState(() {
      _articles = list;
      _loading = false;
    });
  }

  Future<void> _deleteArticle(NewsArticle article) async {
    await _service.removeReadArticle(
      widget.language,
      widget.sourceName,
      article.id,
    );
    await _load();
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.confirmClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearHistory),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _service.clearReadArticles(widget.language, widget.sourceName);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newsReadArticles),
        actions: [
          if (_articles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: l10n.clearHistory,
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? Center(child: Text(l10n.noNewsFound))
              : ListView.separated(
                  itemCount: _articles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final article = _articles[index];
                    final summaryTrimmed = article.summary.trim();
                    final titleTrimmed = article.title.trim();
                    final isSummaryDuplicate = summaryTrimmed.isNotEmpty &&
                        (summaryTrimmed == titleTrimmed ||
                         summaryTrimmed.contains(titleTrimmed) ||
                         titleTrimmed.contains(summaryTrimmed));
                    final subtitleText = isSummaryDuplicate
                        ? article.source
                        : '${article.source}. ${article.summary}';

                    return Semantics(
                      key: ValueKey('news_read_article_semantics_${article.id}'),
                      container: true,
                      customSemanticsActions: {
                        CustomSemanticsAction(label: l10n.deleteItem): () =>
                            _deleteArticle(article),
                      },
                      child: ListTile(
                        key: ValueKey('news_read_article_${article.id}'),
                        title: Text(article.title),
                        subtitle: Text(
                          subtitleText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.deleteItem,
                          onPressed: () => _deleteArticle(article),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/news/article'),
                            builder: (_) => NewsWebViewScreen(
                              article: article,
                              language: widget.language,
                              readSourceName: widget.sourceName,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
