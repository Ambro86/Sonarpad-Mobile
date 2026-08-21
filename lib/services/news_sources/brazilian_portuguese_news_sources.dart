import 'news_rss_source.dart';

final brazilianPortugueseNewsSources = [
  NewsRssSource(
    name: 'Google Notícias Brasil',
    uri: Uri.parse('https://news.google.com/rss?hl=pt-BR&gl=BR&ceid=BR:pt-419'),
    categories: [
      NewsRssCategory(name: 'Minha cidade', uri: Uri.parse('https://news.google.com/'), isLocal: true),
      NewsRssCategory(name: 'Brasil', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/NATION?hl=pt-BR&gl=BR&ceid=BR:pt-419')),
      NewsRssCategory(name: 'Mundo', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=pt-BR&gl=BR&ceid=BR:pt-419')),
      NewsRssCategory(name: 'Negócios', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=pt-BR&gl=BR&ceid=BR:pt-419')),
      NewsRssCategory(name: 'Ciência e tecnologia', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=pt-BR&gl=BR&ceid=BR:pt-419')),
      NewsRssCategory(name: 'Entretenimento', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=pt-BR&gl=BR&ceid=BR:pt-419')),
      NewsRssCategory(name: 'Esportes', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=pt-BR&gl=BR&ceid=BR:pt-419')),
      NewsRssCategory(name: 'Saúde', uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=pt-BR&gl=BR&ceid=BR:pt-419')),
    ],
  ),
  NewsRssSource(name: 'Agência Brasil', uri: Uri.parse('https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml')),
  NewsRssSource(name: 'CNN Brasil - Últimas notícias', uri: Uri.parse('https://www.cnnbrasil.com.br/ultimas-noticias/feed/')),
  NewsRssSource(name: 'G1 - Últimas notícias', uri: Uri.parse('https://g1.globo.com/rss/g1/')),
  NewsRssSource(name: 'Folha de S.Paulo - Em cima da hora', uri: Uri.parse('https://feeds.folha.uol.com.br/emcimadahora/rss091.xml')),
  NewsRssSource(name: 'UOL Notícias', uri: Uri.parse('https://rss.uol.com.br/feed/noticias.xml')),
  NewsRssSource(name: 'Tecnoblog', uri: Uri.parse('https://tecnoblog.net/feed/')),
  NewsRssSource(name: 'Canaltech', uri: Uri.parse('https://canaltech.com.br/rss/')),
  NewsRssSource(name: 'Olhar Digital', uri: Uri.parse('https://olhardigital.com.br/feed/')),
];
