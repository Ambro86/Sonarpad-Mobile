import 'news_rss_source.dart';

final germanNewsSources = [
  NewsRssSource(
    name: 'Google News Deutschland',
    uri: Uri.parse('https://news.google.com/rss?hl=de&gl=DE&ceid=DE:de'),
    categories: [
      NewsRssCategory(
        name: 'Meine Stadt',
        uri: Uri.parse('https://news.google.com/'),
        isLocal: true,
      ),
      NewsRssCategory(
        name: 'Deutschland',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/NATION?hl=de&gl=DE&ceid=DE:de'),
      ),
      NewsRssCategory(
        name: 'Welt',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=de&gl=DE&ceid=DE:de'),
      ),
      NewsRssCategory(
        name: 'Wirtschaft',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=de&gl=DE&ceid=DE:de'),
      ),
      NewsRssCategory(
        name: 'Wissenschaft & Technik',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=de&gl=DE&ceid=DE:de'),
      ),
      NewsRssCategory(
        name: 'Unterhaltung',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=de&gl=DE&ceid=DE:de'),
      ),
      NewsRssCategory(
        name: 'Sport',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=de&gl=DE&ceid=DE:de'),
      ),
      NewsRssCategory(
        name: 'Gesundheit',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=de&gl=DE&ceid=DE:de'),
      ),
    ],
  ),
  NewsRssSource(
    name: 'Tagesschau',
    uri: Uri.parse('https://www.tagesschau.de/xml/rss2/'),
  ),
  NewsRssSource(
    name: 'ZDFheute',
    uri: Uri.parse('https://www.zdf.de/rss/zdf/nachrichten'),
  ),
  NewsRssSource(
    name: 'Deutschlandfunk Nachrichten',
    uri: Uri.parse('https://www.deutschlandfunk.de/nachrichten-100.xml'),
  ),
  NewsRssSource(
    name: 'Deutsche Welle Deutsch',
    uri: Uri.parse('https://rss.dw.com/xml/rss-de-all'),
  ),
  NewsRssSource(
    name: 'DER SPIEGEL',
    uri: Uri.parse('https://www.spiegel.de/schlagzeilen/index.rss'),
  ),
  NewsRssSource(
    name: 'ZEIT ONLINE',
    uri: Uri.parse('https://newsfeed.zeit.de/index'),
  ),
  NewsRssSource(
    name: 'Frankfurter Allgemeine Zeitung',
    uri: Uri.parse('https://www.faz.net/rss/aktuell/'),
  ),
  NewsRssSource(
    name: 'Süddeutsche Zeitung',
    uri: Uri.parse('https://rss.sueddeutsche.de/rss/Topthemen'),
  ),
  NewsRssSource(
    name: 'Neue Zürcher Zeitung',
    uri: Uri.parse('https://www.nzz.ch/recent.rss'),
  ),
  NewsRssSource(
    name: 'DER STANDARD',
    uri: Uri.parse('https://www.derstandard.at/rss'),
  ),
  NewsRssSource(
    name: 'heise online',
    uri: Uri.parse('https://www.heise.de/rss/heise-atom.xml'),
  ),
  NewsRssSource(
    name: 'Golem.de',
    uri: Uri.parse('https://rss.golem.de/rss.php?feed=RSS2.0'),
  ),
  NewsRssSource(
    name: 'Netzpolitik.org',
    uri: Uri.parse('https://netzpolitik.org/feed/'),
  ),
  NewsRssSource(
    name: 'Spektrum.de',
    uri: Uri.parse('https://www.spektrum.de/alias/rss/spektrum-de-rss-feed/996406'),
  ),

];
