import 'news_rss_source.dart';

final italianNewsSources = [
  NewsRssSource(
    name: 'Google News Italia',
    uri: Uri.parse('https://news.google.com/rss?hl=it&gl=IT&ceid=IT:it'),
    categories: [
      NewsRssCategory(name: 'La mia città', uri: Uri.parse('https://news.google.com/'), isLocal: true),
      NewsRssCategory(name: 'Italia', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/NATION?hl=it&gl=IT&ceid=IT:it')),
      NewsRssCategory(name: 'Dal mondo', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=it&gl=IT&ceid=IT:it')),
      NewsRssCategory(name: 'Affari', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=it&gl=IT&ceid=IT:it')),
      NewsRssCategory(name: 'Scienza e tecnologia', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=it&gl=IT&ceid=IT:it')),
      NewsRssCategory(name: 'Intrattenimento', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=it&gl=IT&ceid=IT:it')),
      NewsRssCategory(name: 'Sport', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=it&gl=IT&ceid=IT:it')),
      NewsRssCategory(name: 'Salute', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=it&gl=IT&ceid=IT:it')),
    ],
  ),
  NewsRssSource(
    name: 'Corriere della Sera',
    uri: Uri.parse('https://xml2.corriereobjects.it/feed-hp/homepage.xml'),
  ),
  NewsRssSource(
    name: 'La Repubblica',
    uri: Uri.parse('https://www.repubblica.it/rss/homepage/rss2.0.xml'),
  ),
  NewsRssSource(
    name: 'ANSA',
    uri: Uri.parse('https://www.ansa.it/sito/ansait_rss.xml'),
  ),
  NewsRssSource(
    name: 'Il Sole 24 Ore',
    uri: Uri.parse('http://www.ilsole24ore.com/rss/primapagina.xml'),
  ),
  NewsRssSource(
    name: 'La Stampa',
    uri: Uri.parse('https://www.lastampa.it/rss/copertina.xml'),
  ),
  NewsRssSource(
    name: 'Adnkronos',
    uri: Uri.parse('https://www.adnkronos.com/RSS_PrimaPagina.xml'),
  ),
  NewsRssSource(
    name: 'Tgcom24',
    uri: Uri.parse('http://www.tgcom24.mediaset.it/rss/homepage.xml'),
  ),
  NewsRssSource(
    name: 'Il Fatto Quotidiano',
    uri: Uri.parse('https://www.ilfattoquotidiano.it/feed/'),
  ),
  NewsRssSource(
    name: 'Fanpage',
    uri: Uri.parse('https://www.fanpage.it/feed/'),
  ),
  NewsRssSource(
    name: 'Open',
    uri: Uri.parse('https://www.open.online/feed/'),
  ),
  NewsRssSource(
    name: 'Internazionale',
    uri: Uri.parse('https://www.internazionale.it/rss'),
  ),
  NewsRssSource(
    name: 'Affaritaliani',
    uri: Uri.parse(
      'https://www.affaritaliani.it/static/rss/rssGadget.aspx?idchannel=1',
    ),
  ),
  NewsRssSource(
    name: 'HuffPost Italia',
    uri: Uri.parse('https://www.huffingtonpost.it/rss'),
  ),
  NewsRssSource(
    name: 'DDay',
    uri: Uri.parse('https://www.dday.it/rss'),
  ),
  NewsRssSource(
    name: 'HDblog',
    uri: Uri.parse('https://www.hdblog.it/feed/'),
  ),
  NewsRssSource(
    name: 'HWUpgrade',
    uri: Uri.parse('https://www.hwupgrade.it/rss/news.xml'),
  ),
  NewsRssSource(
    name: 'Tom\'s Hardware Italia',
    uri: Uri.parse('https://www.tomshw.it/feed/'),
  ),
  NewsRssSource(
    name: 'Everyeye',
    uri: Uri.parse('https://www.everyeye.it/rss/news/'),
  ),
  NewsRssSource(
    name: 'GameSource',
    uri: Uri.parse('https://www.gamesource.it/feed/'),
  ),
  NewsRssSource(
    name: 'Aranzulla',
    uri: Uri.parse('https://www.aranzulla.it/feed/'),
  ),
  NewsRssSource(
    name: 'Calcio e Finanza',
    uri: Uri.parse('https://www.calcioefinanza.it/feed/'),
  ),
  NewsRssSource(
    name: 'La Gazzetta dello Sport',
    uri: Uri.parse('https://www.gazzetta.it/dynamic-feed/rss/section/last.xml'),
  ),
  NewsRssSource(
    name: 'Corriere dello Sport',
    uri: Uri.parse('https://www.corrieredellosport.it/rss/'),
  ),
  NewsRssSource(
    name: 'Motorsport Italia',
    uri: Uri.parse('https://www.motorsport.com/rss/f1/news/'),
  ),
  NewsRssSource(
    name: 'AlVolante',
    uri: Uri.parse('https://www.alvolante.it/rss.xml'),
  ),
  NewsRssSource(
    name: 'Motori.it',
    uri: Uri.parse('https://www.motori.it/rss/'),
  ),
  NewsRssSource(
    name: 'StartMag',
    uri: Uri.parse('https://www.startmag.it/feed/'),
  ),
  NewsRssSource(
    name: 'Formiche',
    uri: Uri.parse('https://www.formiche.net/feed/'),
  ),
  NewsRssSource(
    name: 'Linkiesta',
    uri: Uri.parse('https://www.linkiesta.it/feed/'),
  ),
  NewsRssSource(
    name: 'Il Foglio',
    uri: Uri.parse('https://www.ilfoglio.it/rss.xml'),
  ),
  NewsRssSource(
    name: 'Il Giornale',
    uri: Uri.parse('https://www.ilgiornale.it/rss.xml'),
  ),
  NewsRssSource(
    name: 'Il Riformista',
    uri: Uri.parse('https://www.ilriformista.it/feed/'),
  ),
  NewsRssSource(
    name: 'Quotidiano.net',
    uri: Uri.parse('https://www.quotidiano.net/rss'),
  ),
];
