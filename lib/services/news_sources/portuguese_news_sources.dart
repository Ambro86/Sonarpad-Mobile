import 'news_rss_source.dart';

final portugueseNewsSources = [
  NewsRssSource(
    name: 'Google News Portugal',
    uri: Uri.parse('https://news.google.com/rss?hl=pt-PT&gl=PT&ceid=PT:pt-150'),
    categories: [
      NewsRssCategory(
        name: 'A minha cidade',
        uri: Uri.parse('https://news.google.com/'),
        isLocal: true,
      ),
      NewsRssCategory(
        name: 'Portugal',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/NATION?hl=pt-PT&gl=PT&ceid=PT:pt-150',
        ),
      ),
      NewsRssCategory(
        name: 'Mundo',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=pt-PT&gl=PT&ceid=PT:pt-150',
        ),
      ),
      NewsRssCategory(
        name: 'Negócios',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=pt-PT&gl=PT&ceid=PT:pt-150',
        ),
      ),
      NewsRssCategory(
        name: 'Ciência e tecnologia',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=pt-PT&gl=PT&ceid=PT:pt-150',
        ),
      ),
      NewsRssCategory(
        name: 'Entretenimento',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=pt-PT&gl=PT&ceid=PT:pt-150',
        ),
      ),
      NewsRssCategory(
        name: 'Desporto',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=pt-PT&gl=PT&ceid=PT:pt-150',
        ),
      ),
      NewsRssCategory(
        name: 'Saúde',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=pt-PT&gl=PT&ceid=PT:pt-150',
        ),
      ),
    ],
  ),
  NewsRssSource(
    name: 'Público',
    uri: Uri.parse('https://feeds.feedburner.com/PublicoRSS'),
  ),
  NewsRssSource(
    name: 'Observador',
    uri: Uri.parse('https://observador.pt/feed/'),
  ),
  NewsRssSource(
    name: 'RTP Notícias',
    uri: Uri.parse('https://www.rtp.pt/noticias/rss'),
  ),
  NewsRssSource(
    name: 'Correio da Manhã',
    uri: Uri.parse('https://www.cmjornal.pt/rss'),
  ),
  NewsRssSource(
    name: 'Jornal de Notícias',
    uri: Uri.parse('http://feeds.jn.pt/JN-ULTIMAS'),
  ),
  NewsRssSource(
    name: 'O Jornal Económico',
    uri: Uri.parse('https://jornaleconomico.sapo.pt/feed/'),
  ),
  NewsRssSource(
    name: 'Diário As Beiras',
    uri: Uri.parse('http://feeds.feedburner.com/asbeiras'),
  ),
];
