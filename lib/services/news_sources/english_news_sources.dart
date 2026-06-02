import 'news_rss_source.dart';

final englishNewsSources = [
  NewsRssSource(
    name: 'Google News English',
    uri: Uri.parse('https://news.google.com/rss?hl=en&gl=US&ceid=US:en'),
    categories: [
      NewsRssCategory(
          name: 'My City',
          uri: Uri.parse('https://news.google.com/'),
          isLocal: true),
      NewsRssCategory(
          name: 'US',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/NATION?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(
          name: 'World',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(
          name: 'Business',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(
          name: 'Science & Tech',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(
          name: 'Entertainment',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(
          name: 'Sports',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=en&gl=US&ceid=US:en')),
      NewsRssCategory(
          name: 'Health',
          uri: Uri.parse(
              'https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=en&gl=US&ceid=US:en')),
    ],
  ),
  NewsRssSource(
      name: 'BBC News',
      uri: Uri.parse('https://feeds.bbci.co.uk/news/rss.xml')),
  NewsRssSource(
      name: 'CNN Top Stories',
      uri: Uri.parse('http://rss.cnn.com/rss/cnn_topstories.rss')),
  NewsRssSource(
      name: 'NYT > Top Stories',
      uri: Uri.parse('http://feeds.nytimes.com/nyt/rss/HomePage')),
  NewsRssSource(
      name: 'World news The Guardian',
      uri: Uri.parse('https://www.theguardian.com/world/rss')),
  NewsRssSource(
      name: 'Al Jazeera – Breaking News',
      uri: Uri.parse('https://www.aljazeera.com/xml/rss/all.xml')),
  NewsRssSource(
      name: 'Sky News – Home',
      uri: Uri.parse('https://feeds.skynews.com/feeds/rss/home.xml')),
  NewsRssSource(
      name: 'Financial Times – Home',
      uri: Uri.parse('https://www.ft.com/rss/home')),
  NewsRssSource(
      name: 'NPR – News', uri: Uri.parse('https://feeds.npr.org/1001/rss.xml')),
  NewsRssSource(
      name: 'Reddit – World News',
      uri: Uri.parse('https://www.reddit.com/r/worldnews/.rss')),
  NewsRssSource(
      name: 'CNBC – Top News',
      uri: Uri.parse('https://www.cnbc.com/id/100003114/device/rss/rss.html')),
  NewsRssSource(
      name: 'Wall Street Journal – World News',
      uri: Uri.parse(
          'https://feeds.content.dowjones.io/public/rss/RSSWorldNews')),
  NewsRssSource(
      name: 'Dow Jones – World News',
      uri: Uri.parse('https://feeds.a.dj.com/rss/RSSWorldNews.xml')),
  NewsRssSource(
      name: 'Investing.com – News',
      uri: Uri.parse('https://www.investing.com/rss/news.rss')),
  NewsRssSource(
      name: 'Seeking Alpha – Market News',
      uri: Uri.parse('https://seekingalpha.com/feed.xml')),
  NewsRssSource(
      name: 'Forbes – Innovation',
      uri: Uri.parse('https://www.forbes.com/innovation/feed2/')),
  NewsRssSource(
      name: 'New York Times – World News',
      uri: Uri.parse('https://rss.nytimes.com/services/xml/rss/nyt/World.xml')),
  NewsRssSource(
      name: 'Los Angeles Times – World News',
      uri: Uri.parse('https://www.latimes.com/world/rss2.0.xml')),
  NewsRssSource(
      name: 'TIME – Latest Stories', uri: Uri.parse('https://time.com/feed/')),
  NewsRssSource(
      name: 'The Atlantic – All Articles',
      uri: Uri.parse('https://www.theatlantic.com/feed/all')),
  NewsRssSource(
      name: 'Vox – Latest Stories',
      uri: Uri.parse('https://www.vox.com/rss/index.xml')),
  NewsRssSource(
      name: 'Wired – Latest', uri: Uri.parse('https://www.wired.com/feed/rss')),
  NewsRssSource(
      name: 'TechCrunch – Startups & Tech',
      uri: Uri.parse('https://techcrunch.com/feed/')),
  NewsRssSource(
      name: 'The Verge – All Stories',
      uri: Uri.parse('https://www.theverge.com/rss/index.xml')),
  NewsRssSource(
      name: 'Ars Technica – All Content',
      uri: Uri.parse('http://feeds.arstechnica.com/arstechnica/index')),
  NewsRssSource(
      name: 'Engadget – Latest',
      uri: Uri.parse('https://www.engadget.com/rss.xml')),
  NewsRssSource(
      name: 'MIT Technology Review – Latest',
      uri: Uri.parse('https://www.technologyreview.com/feed/')),
  NewsRssSource(
      name: 'ZDNet – News',
      uri: Uri.parse('https://www.zdnet.com/news/rss.xml')),
  NewsRssSource(
      name: 'CNET – News', uri: Uri.parse('https://www.cnet.com/rss/news/')),
  NewsRssSource(
      name: 'MacRumors – All Stories',
      uri: Uri.parse('https://www.macrumors.com/macrumors.xml')),
  NewsRssSource(
      name: 'Lifehacker – Tips & Guides',
      uri: Uri.parse('https://lifehacker.com/rss')),
  NewsRssSource(
      name: 'Hacker News – Front Page',
      uri: Uri.parse('https://hnrss.org/frontpage')),
  NewsRssSource(
      name: 'Product Hunt – Daily Feed',
      uri: Uri.parse('https://www.producthunt.com/feed')),
  NewsRssSource(
      name: 'Stack Overflow Blog',
      uri: Uri.parse('https://stackoverflow.blog/feed/')),
  NewsRssSource(
      name: 'GitHub Blog', uri: Uri.parse('https://github.blog/feed/')),
  NewsRssSource(
      name: 'NASA – Breaking News',
      uri: Uri.parse('https://www.nasa.gov/rss/dyn/breaking_news.rss')),
  NewsRssSource(
      name: 'Science Magazine – Current News',
      uri: Uri.parse('https://www.science.org/rss/news_current.xml')),
  NewsRssSource(
      name: 'New Scientist – Home Feed',
      uri: Uri.parse('https://www.newscientist.com/feed/home/')),
];
