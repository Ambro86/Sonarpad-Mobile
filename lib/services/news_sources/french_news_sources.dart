import 'news_rss_source.dart';

final frenchNewsSources = [
  NewsRssSource(
    name: 'Google News France',
    uri: Uri.parse('https://news.google.com/rss?hl=fr&gl=FR&ceid=FR:fr'),
    categories: [
      NewsRssCategory(name: 'Ma ville', uri: Uri.parse('https://news.google.com/'), isLocal: true),
      NewsRssCategory(name: 'France', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/NATION?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(name: 'Monde', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(name: 'Économie', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(name: 'Science & Tech', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(name: 'Divertissement', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(name: 'Sports', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(name: 'Santé', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=fr&gl=FR&ceid=FR:fr')),
    ],
  ),
];
