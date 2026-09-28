import 'news_rss_source.dart';

final romanianNewsSources = [
  NewsRssSource(
    name: 'Google News România',
    uri: Uri.parse('https://news.google.com/rss?hl=ro&gl=RO&ceid=RO:ro'),
    categories: [
      NewsRssCategory(
        name: 'Orașul meu',
        uri: Uri.parse('https://news.google.com/'),
        isLocal: true,
      ),
      NewsRssCategory(
        name: 'România',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/NATION?hl=ro&gl=RO&ceid=RO:ro',
        ),
      ),
      NewsRssCategory(
        name: 'Lume',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=ro&gl=RO&ceid=RO:ro',
        ),
      ),
      NewsRssCategory(
        name: 'Afaceri',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=ro&gl=RO&ceid=RO:ro',
        ),
      ),
      NewsRssCategory(
        name: 'Știință și tehnologie',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=ro&gl=RO&ceid=RO:ro',
        ),
      ),
      NewsRssCategory(
        name: 'Divertisment',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=ro&gl=RO&ceid=RO:ro',
        ),
      ),
      NewsRssCategory(
        name: 'Sport',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=ro&gl=RO&ceid=RO:ro',
        ),
      ),
      NewsRssCategory(
        name: 'Sănătate',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=ro&gl=RO&ceid=RO:ro',
        ),
      ),
    ],
  ),
  NewsRssSource(
    name: 'Digi24',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Adigi24.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
  NewsRssSource(
    name: 'Știrile ProTV',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Astirileprotv.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
  NewsRssSource(
    name: 'HotNews',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Ahotnews.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
  NewsRssSource(
    name: 'AGERPRES',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Aagerpres.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
  NewsRssSource(
    name: 'G4Media',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Ag4media.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
  NewsRssSource(
    name: 'Libertatea',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Alibertatea.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
  NewsRssSource(
    name: 'Adevărul',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Aadevarul.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
  NewsRssSource(
    name: 'Observator News',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Aobservatornews.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
  NewsRssSource(
    name: 'Profit.ro',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Aprofit.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
  NewsRssSource(
    name: 'Recorder',
    uri: Uri.parse('https://news.google.com/rss/search?q=site%3Arecorder.ro&hl=ro&gl=RO&ceid=RO:ro'),
  ),
];
