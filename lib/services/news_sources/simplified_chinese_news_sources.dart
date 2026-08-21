import 'news_rss_source.dart';

final simplifiedChineseNewsSources = [
  NewsRssSource(
    name: 'Google 新闻',
    uri: Uri.parse(
      'https://news.google.com/rss?hl=zh-CN&gl=CN&ceid=CN:zh-Hans',
    ),
    categories: [
      NewsRssCategory(
        name: '我的城市',
        uri: Uri.parse('https://news.google.com/'),
        isLocal: true,
      ),
      NewsRssCategory(
        name: '中国',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/NATION?hl=zh-CN&gl=CN&ceid=CN:zh-Hans',
        ),
      ),
      NewsRssCategory(
        name: '国际',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=zh-CN&gl=CN&ceid=CN:zh-Hans',
        ),
      ),
      NewsRssCategory(
        name: '财经',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=zh-CN&gl=CN&ceid=CN:zh-Hans',
        ),
      ),
      NewsRssCategory(
        name: '科技',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=zh-CN&gl=CN&ceid=CN:zh-Hans',
        ),
      ),
      NewsRssCategory(
        name: '娱乐',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=zh-CN&gl=CN&ceid=CN:zh-Hans',
        ),
      ),
      NewsRssCategory(
        name: '体育',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=zh-CN&gl=CN&ceid=CN:zh-Hans',
        ),
      ),
      NewsRssCategory(
        name: '健康',
        uri: Uri.parse(
          'https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=zh-CN&gl=CN&ceid=CN:zh-Hans',
        ),
      ),
    ],
  ),
  NewsRssSource(
    name: 'BBC 中文',
    uri: Uri.parse('https://feeds.bbci.co.uk/zhongwen/simp/rss.xml'),
  ),
  NewsRssSource(
    name: 'Solidot',
    uri: Uri.parse('https://www.solidot.org/index.rss'),
  ),
];
