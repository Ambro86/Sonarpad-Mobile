import 'news_rss_source.dart';

// Official RSS/Atom URLs and their verification evidence are recorded in
// tool/turkish_news_feed_verification.json. Category labels resolve from ARB.
final turkishNewsSources = [
  NewsRssSource(
    name: 'Google News',
    uri: Uri.parse('https://news.google.com/rss?hl=tr&gl=TR&ceid=TR:tr'),
    categories: [
      NewsRssCategory(
        name: 'My City',
        label: NewsRssCategoryLabel.myCity,
        uri: Uri.parse('https://news.google.com/'),
        isLocal: true,
      ),
      for (final topic in const [
        ('Turkey', 'NATION', NewsRssCategoryLabel.turkey),
        ('World', 'WORLD', NewsRssCategoryLabel.world),
        ('Business', 'BUSINESS', NewsRssCategoryLabel.business),
        ('Technology', 'TECHNOLOGY', NewsRssCategoryLabel.technology),
        ('Entertainment', 'ENTERTAINMENT', NewsRssCategoryLabel.entertainment),
        ('Sports', 'SPORTS', NewsRssCategoryLabel.sports),
        ('Health', 'HEALTH', NewsRssCategoryLabel.health),
      ])
        NewsRssCategory(
          name: topic.$1,
          label: topic.$3,
          uri: Uri.parse(
            'https://news.google.com/news/rss/headlines/section/topic/${topic.$2}?hl=tr&gl=TR&ceid=TR:tr',
          ),
        ),
    ],
  ),
  NewsRssSource(
    name: 'Anadolu Ajansı',
    uri: Uri.parse('https://www.aa.com.tr/tr/rss/default?cat=guncel'),
  ),
  NewsRssSource(
    name: 'TRT Haber',
    uri: Uri.parse('https://www.trthaber.com/sondakika_articles.rss'),
    categories: [
      for (final category in const [
        ('World', 'dunya', NewsRssCategoryLabel.world),
        ('Business', 'ekonomi', NewsRssCategoryLabel.business),
        ('Sports', 'spor', NewsRssCategoryLabel.sports),
      ])
        NewsRssCategory(
          name: category.$1,
          label: category.$3,
          uri: Uri.parse(
            'https://www.trthaber.com/${category.$2}_articles.rss',
          ),
        ),
    ],
  ),
  NewsRssSource(
    name: 'NTV',
    uri: Uri.parse('https://www.ntv.com.tr/son-dakika.rss'),
    categories: [
      for (final category in const [
        ('Turkey', 'turkiye', NewsRssCategoryLabel.turkey),
        ('World', 'dunya', NewsRssCategoryLabel.world),
        ('Business', 'ekonomi', NewsRssCategoryLabel.business),
        ('Sports', 'sporskor', NewsRssCategoryLabel.sports),
      ])
        NewsRssCategory(
          name: category.$1,
          label: category.$3,
          uri: Uri.parse('https://www.ntv.com.tr/${category.$2}.rss'),
        ),
    ],
  ),
  NewsRssSource(
    name: 'Habertürk',
    uri: Uri.parse('https://www.haberturk.com/rss'),
    categories: [
      NewsRssCategory(
        name: 'World',
        label: NewsRssCategoryLabel.world,
        uri: Uri.parse('https://www.haberturk.com/rss/kategori/dunya.xml'),
      ),
      NewsRssCategory(
        name: 'Business',
        label: NewsRssCategoryLabel.business,
        uri: Uri.parse('https://www.haberturk.com/rss/ekonomi.xml'),
      ),
      NewsRssCategory(
        name: 'Sports',
        label: NewsRssCategoryLabel.sports,
        uri: Uri.parse('https://www.haberturk.com/rss/spor.xml'),
      ),
    ],
  ),
  NewsRssSource(
    name: 'Hürriyet',
    uri: Uri.parse('https://www.hurriyet.com.tr/rss/anasayfa'),
  ),
  NewsRssSource(
    name: 'Cumhuriyet',
    uri: Uri.parse('https://www.cumhuriyet.com.tr/rss'),
  ),
  NewsRssSource(
    name: 'Sözcü',
    uri: Uri.parse('https://www.sozcu.com.tr/feeds-haberler'),
  ),
  NewsRssSource(
    name: 'Sabah',
    uri: Uri.parse('https://www.sabah.com.tr/rss/anasayfa.xml'),
  ),
  NewsRssSource(
    name: 'BirGün',
    uri: Uri.parse('https://www.birgun.net/rss/home'),
  ),
  NewsRssSource(
    name: 'Ensonhaber',
    uri: Uri.parse('https://www.ensonhaber.com/rss/ensonhaber.xml'),
  ),
];
