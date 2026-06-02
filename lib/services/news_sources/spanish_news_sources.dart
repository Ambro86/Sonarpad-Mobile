import 'news_rss_source.dart';

final spanishNewsSources = [
  NewsRssSource(
    name: 'Google News España',
    uri: Uri.parse('https://news.google.com/rss?hl=es&gl=ES&ceid=ES:es'),
    categories: [
      NewsRssCategory(
          name: 'Mi ciudad',
          uri: Uri.parse('https://news.google.com/'),
          isLocal: true),
      NewsRssCategory(
          name: 'España',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/NATION?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(
          name: 'Mundo',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(
          name: 'Negocios',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(
          name: 'Ciencia y Tecnología',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(
          name: 'Entretenimiento',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(
          name: 'Deportes',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=es&gl=ES&ceid=ES:es')),
      NewsRssCategory(
          name: 'Salud',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=es&gl=ES&ceid=ES:es')),
    ],
  ),
  NewsRssSource(
      name: 'EL PAÍS – Portada',
      uri: Uri.parse(
          'https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada')),
  NewsRssSource(
      name: 'El Mundo – Portada',
      uri: Uri.parse('http://estaticos.elmundo.es/elmundo/rss/portada.xml')),
  NewsRssSource(
      name: 'RTVE Noticias – Temas noticias',
      uri: Uri.parse('https://www.rtve.es/rss/temas_noticias.xml')),
  NewsRssSource(
      name: 'RTVE Noticias – España',
      uri: Uri.parse('https://www.rtve.es/rss/temas_espana.xml')),
  NewsRssSource(
      name: 'RTVE Noticias – Mundo',
      uri: Uri.parse('https://www.rtve.es/rss/temas_mundo.xml')),
  NewsRssSource(
      name: 'La Vanguardia – Portada',
      uri: Uri.parse('https://www.lavanguardia.com/rss/home.xml')),
  NewsRssSource(
      name: 'La Vanguardia – Internacional',
      uri: Uri.parse('https://www.lavanguardia.com/rss/internacional.xml')),
  NewsRssSource(
      name: 'La Vanguardia – Economía',
      uri: Uri.parse('https://www.lavanguardia.com/rss/economia.xml')),
  NewsRssSource(
      name: 'El Confidencial – España',
      uri: Uri.parse('https://rss.elconfidencial.com/espana/')),
  NewsRssSource(
      name: 'El Confidencial – Mundo',
      uri: Uri.parse('https://rss.elconfidencial.com/mundo/')),
  NewsRssSource(
      name: 'elDiario.es – Portada',
      uri: Uri.parse('https://www.eldiario.es/rss/')),
  NewsRssSource(
      name: 'El HuffPost (España) – Portada',
      uri: Uri.parse('https://www.huffingtonpost.es/feeds/index.xml')),
  NewsRssSource(
      name: 'Expansión – Portada',
      uri: Uri.parse('https://e00-expansion.uecdn.es/rss/portada.xml')),
  NewsRssSource(
      name: 'MARCA – Portada',
      uri: Uri.parse('https://e00-marca.uecdn.es/rss/portada.xml')),
  NewsRssSource(
      name: 'Xataka – Tecnología',
      uri: Uri.parse('https://feeds.weblogssl.com/xataka2')),
  NewsRssSource(
      name: '20minutos – Portada',
      uri: Uri.parse('https://www.20minutos.es/rss/')),
];
