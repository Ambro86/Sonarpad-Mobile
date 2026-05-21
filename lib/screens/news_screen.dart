import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/news_service.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _service = NewsService();
  NewsLanguage _language = NewsLanguage.italian;
  late Future<List<NewsArticle>> _future = _service.fetchTopNews(_language);

  void _reload() {
    setState(() => _future = _service.fetchTopNews(_language));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.news)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<NewsLanguage>(
              initialValue: _language,
              decoration: InputDecoration(labelText: l10n.newsLanguage),
              items: NewsLanguage.values
                  .map((lang) => DropdownMenuItem(
                      value: lang, child: Text(lang.label(l10n))))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _language = value;
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<NewsArticle>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                      child: CircularProgressIndicator(
                          semanticsLabel: l10n.loadingNews));
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
                      subtitle: Text('${article.source}. ${article.summary}',
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => NewsDetailScreen(
                                article: article, language: _language)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
