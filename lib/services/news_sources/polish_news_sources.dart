import 'news_rss_source.dart';

final polishNewsSources = [
  NewsRssSource(
    name: 'Google News Polska',
    uri: Uri.parse('https://news.google.com/rss?hl=pl&gl=PL&ceid=PL:pl'),
    categories: [
      NewsRssCategory(
        name: 'Moje miasto',
        uri: Uri.parse('https://news.google.com/'),
        isLocal: true,
      ),
      NewsRssCategory(
        name: 'Polska',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/NATION?hl=pl&gl=PL&ceid=PL:pl',
        ),
      ),
      NewsRssCategory(
        name: 'Świat',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=pl&gl=PL&ceid=PL:pl',
        ),
      ),
      NewsRssCategory(
        name: 'Biznes',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=pl&gl=PL&ceid=PL:pl',
        ),
      ),
      NewsRssCategory(
        name: 'Nauka i technologia',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=pl&gl=PL&ceid=PL:pl',
        ),
      ),
      NewsRssCategory(
        name: 'Rozrywka',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=pl&gl=PL&ceid=PL:pl',
        ),
      ),
      NewsRssCategory(
        name: 'Sport',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=pl&gl=PL&ceid=PL:pl',
        ),
      ),
      NewsRssCategory(
        name: 'Zdrowie',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=pl&gl=PL&ceid=PL:pl',
        ),
      ),
    ],
  ),
  NewsRssSource(
    name: 'Polsat News',
    uri: Uri.parse('https://www.polsatnews.pl/rss/wszystkie.xml'),
  ),
  NewsRssSource(
    name: 'TVN24',
    uri: Uri.parse('https://www.tvn24.pl/najnowsze.xml'),
  ),
  NewsRssSource(
    name: 'Interia Wiadomości',
    uri: Uri.parse('https://wydarzenia.interia.pl/feed'),
  ),
  NewsRssSource(
    name: 'Fakt',
    uri: Uri.parse('https://fakt.pl/rss'),
  ),
  NewsRssSource(
    name: 'Wprost',
    uri: Uri.parse('https://www.wprost.pl/rss'),
  ),
  NewsRssSource(
    name: "Spider's Web",
    uri: Uri.parse('https://spidersweb.pl/feed'),
  ),
  NewsRssSource(
    name: 'Antyweb',
    uri: Uri.parse('https://antyweb.pl/feed'),
  ),
  NewsRssSource(
    name: 'Onet Wiadomości',
    uri: Uri.parse('https://wiadomosci.onet.pl/rss'),
  ),
  NewsRssSource(
    name: 'Wirtualna Polska',
    uri: Uri.parse('https://wiadomosci.wp.pl/rss.xml'),
  ),
];
