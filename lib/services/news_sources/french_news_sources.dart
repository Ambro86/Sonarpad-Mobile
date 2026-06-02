import 'news_rss_source.dart';

final frenchNewsSources = [
  NewsRssSource(
    name: 'Google News France',
    uri: Uri.parse('https://news.google.com/rss?hl=fr&gl=FR&ceid=FR:fr'),
    categories: [
      NewsRssCategory(
          name: 'Ma ville',
          uri: Uri.parse('https://news.google.com/'),
          isLocal: true),
      NewsRssCategory(
          name: 'France',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/NATION?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(
          name: 'Monde',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(
          name: 'Économie',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(
          name: 'Science & Tech',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(
          name: 'Divertissement',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(
          name: 'Sports',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=fr&gl=FR&ceid=FR:fr')),
      NewsRssCategory(
          name: 'Santé',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=fr&gl=FR&ceid=FR:fr')),
    ],
  ),
  NewsRssSource(
      name: 'Le Monde', uri: Uri.parse('https://www.lemonde.fr/rss/une.xml')),
  NewsRssSource(
      name: 'Le Figaro',
      uri: Uri.parse('https://www.lefigaro.fr/rss/figaro_actualites.xml')),
  NewsRssSource(
      name: 'France Info',
      uri: Uri.parse('https://www.francetvinfo.fr/titres.rss')),
  NewsRssSource(
      name: 'Libération',
      uri: Uri.parse('http://rss.liberation.fr/rss/latest/')),
  NewsRssSource(
      name: 'Les Échos',
      uri:
          Uri.parse('https://services.lesechos.fr/rss/les-echos-economie.xml')),
  NewsRssSource(
      name: 'L\'Express',
      uri: Uri.parse('https://www.lexpress.fr/rss/alaune.xml')),
  NewsRssSource(
      name: '20 Minutes',
      uri: Uri.parse('https://www.20minutes.fr/feeds/rss-une.xml')),
  NewsRssSource(
      name: 'BFM TV', uri: Uri.parse('https://www.bfmtv.com/rss/news-24-7/')),
  NewsRssSource(
      name: 'La Croix', uri: Uri.parse('https://www.la-croix.com/RSS/UNIVERS')),
  NewsRssSource(
      name: 'L\'Humanité', uri: Uri.parse('https://www.humanite.fr/rss')),
  NewsRssSource(
      name: 'Science et Avenir',
      uri: Uri.parse('https://www.sciencesetavenir.fr/rss.xml')),
  NewsRssSource(
      name: 'Presse-Citron',
      uri: Uri.parse('https://www.presse-citron.net/feed/')),
  NewsRssSource(
      name: 'Frandroid', uri: Uri.parse('https://www.frandroid.com/feed')),
  NewsRssSource(
      name: 'Numerama', uri: Uri.parse('https://www.numerama.com/feed/')),
  NewsRssSource(
      name: 'ZDNet France',
      uri: Uri.parse('https://www.zdnet.fr/feeds/rss/actualites/')),
  NewsRssSource(
      name: 'Clubic', uri: Uri.parse('https://www.clubic.com/feed/news.rss')),
  NewsRssSource(
      name: 'Gamekult', uri: Uri.parse('https://www.gamekult.com/feed.xml')),
  NewsRssSource(
      name: 'Allociné', uri: Uri.parse('https://www.allocine.fr/rss/news.xml')),
  NewsRssSource(
      name: 'L\'Équipe',
      uri: Uri.parse(
          'https://news.google.com/rss/search?q=site%3Alequipe.fr&hl=fr&gl=FR&ceid=FR:fr')),
  NewsRssSource(
      name: 'Eurosport',
      uri: Uri.parse(
          'https://news.google.com/rss/search?q=site%3Aeurosport.fr&hl=fr&gl=FR&ceid=FR:fr')),
];
