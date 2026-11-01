import 'news_rss_source.dart';

/// Initial Dutch news catalogue. Additional publishers will follow in phase 2.
final dutchNewsSources = <NewsRssSource>[
  NewsRssSource(
    name: 'Google Nieuws Nederland',
    uri: Uri.parse('https://news.google.com/rss?hl=nl&gl=NL&ceid=NL:nl'),
    categories: [
      NewsRssCategory(name: 'Mijn stad', uri: Uri.parse('https://news.google.com/'), isLocal: true),
      NewsRssCategory(name: 'Nederland', uri: Uri.parse('https://news.google.com/rss/headlines/section/topic/NATION?hl=nl&gl=NL&ceid=NL:nl')),
      NewsRssCategory(name: 'Wereld', uri: Uri.parse('https://news.google.com/rss/headlines/section/topic/WORLD?hl=nl&gl=NL&ceid=NL:nl')),
      NewsRssCategory(name: 'Economie', uri: Uri.parse('https://news.google.com/rss/headlines/section/topic/BUSINESS?hl=nl&gl=NL&ceid=NL:nl')),
      NewsRssCategory(name: 'Technologie', uri: Uri.parse('https://news.google.com/rss/headlines/section/topic/TECHNOLOGY?hl=nl&gl=NL&ceid=NL:nl')),
      NewsRssCategory(name: 'Sport', uri: Uri.parse('https://news.google.com/rss/headlines/section/topic/SPORTS?hl=nl&gl=NL&ceid=NL:nl')),
    ],
  ),
];
