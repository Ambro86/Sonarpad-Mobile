import 'package:flutter/material.dart';

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
    }
  }

  void _openSource(NewsRssSource source) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/news/source'),
        builder: (_) => _NewsSourceArticlesScreen(
          source: source,
          future: _service.fetchSourceNews(source),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.news),
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
                });
              },
            ),
          ),
          Expanded(
            child: _NewsSourceList(
              sources: _language!.rssSources,
              onSourceSelected: _openSource,
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
  State<_NewsSourceArticlesScreen> createState() => _NewsSourceArticlesScreenState();
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
    final cat = widget.source.categories?.where((c) => c.uri == _currentUri).firstOrNull;
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
    final loc = await _service.getUserLocationData();
    if (loc != null) {
      final city = loc['city']!;
      final lang = AppLocalizations.of(context).locale.languageCode;
      final country = loc['countryCode']!;
      final searchUri = Uri.parse('https://news.google.com/rss/search?q=${Uri.encodeComponent(city)}&hl=$lang&gl=$country&ceid=$country:$lang');
      return _service.fetchSourceNews(NewsRssSource(name: widget.source.name, uri: searchUri));
    }
    // Fallback to top news if location fails
    return _service.fetchSourceNews(NewsRssSource(name: widget.source.name, uri: widget.source.uri));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.source.name)),
      body: Column(
        children: [
          if (widget.source.categories != null && widget.source.categories!.isNotEmpty)
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
                  }).toList(),
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

class _NewsSourceList extends StatelessWidget {
  const _NewsSourceList({
    required this.sources,
    required this.onSourceSelected,
  });

  final List<NewsRssSource> sources;
  final ValueChanged<NewsRssSource> onSourceSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: sources.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final source = sources[index];
        return ListTile(
          title: Text(source.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSourceSelected(source),
        );
      },
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
