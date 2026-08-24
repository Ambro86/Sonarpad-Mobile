import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('news sharing prefers the final publisher URL over the RSS URL', () {
    final source = File('lib/screens/news_webview_screen.dart').readAsStringSync();

    expect(source, contains('_resolvedArticleUrlForReader'));
    expect(source, contains('_allowedMainArticleUrl'));
    expect(source, contains('await _controller.currentUrl()'));
    expect(source, contains('resolveArticleUrlForSharing(widget.article.link)'));
    expect(source, contains('SharePlus.instance.share'));
    expect(source, contains(r"text: '${widget.article.title}\n$url'"));
    expect(source, isNot(contains('Share.share(widget.article.link')));
  });

  test('NewsService exposes a share resolver for Google News article links', () {
    final source = File('lib/services/news_service.dart').readAsStringSync();

    expect(source, contains('Future<String> resolveArticleUrlForSharing(String url)'));
    expect(source, contains('await _resolveArticleUrl(original)'));
    expect(source, contains("if (_isHttpUrl(resolved) && !_isGoogleNewsArticleUrl(resolved))"));
  });
}
