import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Notizie')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<NewsLanguage>(
              value: _language,
              decoration: const InputDecoration(labelText: 'Lingua notizie'),
              items: NewsLanguage.values
                  .map((lang) => DropdownMenuItem(value: lang, child: Text(lang.label)))
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
                  return const Center(child: CircularProgressIndicator(semanticsLabel: 'Caricamento notizie'));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Errore: ${snapshot.error}'));
                }
                final articles = snapshot.data ?? const [];
                if (articles.isEmpty) return const Center(child: Text('Nessuna notizia trovata'));
                return ListView.separated(
                  itemCount: articles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final article = articles[index];
                    return ListTile(
                      title: Text(article.title),
                      subtitle: Text('${article.source}. ${article.summary}', maxLines: 3, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article, language: _language)),
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
