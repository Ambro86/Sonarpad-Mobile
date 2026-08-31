import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('news article routes RSS media to Sonarpad internal readers', () {
    final source = File('lib/screens/news_webview_screen.dart').readAsStringSync();
    expect(source, contains('NewsArticleMediaLink.tryParse(request.url)'));
    expect(source, contains("RouteSettings(name: '/news/media/audio')"));
    expect(source, contains("RouteSettings(name: '/news/media/pdf')"));
    expect(source, contains("RouteSettings(name: '/news/media/sonartube')"));
    expect(source, contains('PodcastEpisodePlayerScreen('));
    expect(source, contains('DocumentReaderScreen(document: document)'));
    expect(source, contains('startWithVideoThenRestorePreference: true'));
    expect(source,
        contains('MEDIA_OPEN_GUARD duplicate ignored source=news-article'));
  });
}
