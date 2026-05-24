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
  NewsLanguage _language = NewsLanguage.italian;
  NewsRssSource? _selectedSource;
  Future<List<NewsArticle>>? _future;

  void _openSource(NewsRssSource source) {
    setState(() {
      _selectedSource = source;
      _future = _service.fetchSourceNews(source);
    });
  }

  void _showSources() {
    setState(() {
      _selectedSource = null;
      _future = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedSource = _selectedSource;
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedSource?.name ?? l10n.news),
        leading: selectedSource == null
            ? null
            : BackButton(
                onPressed: _showSources,
              ),
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
                  _selectedSource = null;
                  _future = null;
                });
              },
            ),
          ),
          Expanded(
            child: selectedSource == null
                ? _NewsSourceList(
                    sources: _language.rssSources,
                    onSourceSelected: _openSource,
                  )
                : _NewsArticleList(
                    future: _future!,
                  ),
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
