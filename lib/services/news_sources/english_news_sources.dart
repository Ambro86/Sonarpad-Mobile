import 'news_rss_source.dart';

final englishNewsSources = [
  NewsRssSource(
    name: 'Google News English',
    uri: Uri.parse('https://news.google.com/rss?hl=en&gl=US&ceid=US:en'),
    categories: [
      NewsRssCategory(name: 'My City', uri: Uri.parse('https://news.google.com/'), isLocal: true),
      NewsRssCategory(name: 'US', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/NATION?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(name: 'World', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(name: 'Business', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(name: 'Science & Tech', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(name: 'Entertainment', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(name: 'Sports', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(name: 'Health', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=en&gl=US&ceid=US:en')),
    ],
  ),
];
