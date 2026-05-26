import 'news_rss_source.dart';

final spanishNewsSources = [
  NewsRssSource(
    name: 'Google News España',
    uri: Uri.parse('https://news.google.com/rss?hl=es&gl=ES&ceid=ES:es'),
    categories: [
      NewsRssCategory(name: 'Mi ciudad', uri: Uri.parse('https://news.google.com/'), isLocal: true),
      NewsRssCategory(name: 'España', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/NATION?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(name: 'Mundo', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(name: 'Negocios', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(name: 'Ciencia y Tecnología', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(name: 'Entretenimiento', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(name: 'Deportes', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(name: 'Salud', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=es&gl=ES&ceid=ES:es')),
    ],
  ),
];
