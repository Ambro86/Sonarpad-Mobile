import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom RSS articles route only their known media links internally', () {
    final source = File('lib/screens/news_webview_screen.dart').readAsStringSync();
    expect(source, contains('if (!widget.article.allowInternalMediaLinks) return null;'));
    expect(source, contains('for (final link in widget.article.mediaLinks)'));
    expect(source, contains('if (_sameNormalizedUrl(link.url, url)) return link;'));
    expect(source, contains("RouteSettings(name: '/news/media/audio')"));
    expect(source, contains("RouteSettings(name: '/news/media/pdf')"));
    expect(source, contains("RouteSettings(name: '/news/media/sonartube')"));
    expect(source, contains('PodcastEpisodePlayerScreen('));
    expect(source, contains('DocumentReaderScreen(document: document)'));
    expect(source, contains('startWithVideoThenRestorePreference: true'));
    expect(source,
        contains('MEDIA_OPEN_GUARD duplicate ignored source=news-article'));
  });

  test('ordinary news articles cannot auto-open arbitrary embedded media', () {
    final source = File('lib/screens/news_webview_screen.dart').readAsStringSync();
    expect(source, isNot(contains('NewsArticleMediaLink.tryParse(request.url)')));
    expect(source, isNot(contains('_knownArticleMediaLink(request.url)')));
    expect(
      source,
      contains('!widget.article.allowInternalMediaLinks ||\n        !_isKnownArticleMediaLink(link.url)'),
    );
    expect(
      source,
      contains('mediaLinks: widget.article.allowInternalMediaLinks'),
    );
  });
}
