import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opened news articles expose TXT sharing beside save and link share', () {
    final source = File('lib/screens/news_webview_screen.dart').readAsStringSync();

    final saveIndex = source.indexOf('onPressed: _saveArticle');
    final linkShareIndex = source.indexOf('onPressed: _shareArticle,');
    final txtShareIndex = source.indexOf('onPressed: _shareArticleAsTxt');
    final readIndex = source.indexOf('onPressed: _speaking ? null : _readArticle');

    expect(saveIndex, greaterThanOrEqualTo(0));
    expect(linkShareIndex, greaterThan(saveIndex));
    expect(txtShareIndex, greaterThan(linkShareIndex));
    expect(readIndex, greaterThan(txtShareIndex));
    expect(source, contains('tooltip: l10n.shareArticleAsTxt'));
  });

  test('TXT sharing exports the reader text as a real shareable txt file', () {
    final source = File('lib/screens/news_webview_screen.dart').readAsStringSync();

    expect(source, contains('Future<void> _shareArticleAsTxt() async'));
    expect(source, contains('await getTemporaryDirectory()'));
    expect(source, contains("files: [XFile(file.path)]"));
    expect(source, contains('await file.writeAsString(buffer.toString(), flush: true)'));
    expect(source, contains('final url = await _shareableArticleUrl()'));
    expect(source, contains('..writeln(readerText)'));
    expect(source, contains('..writeln(url)'));
  });

  test('every locale localizes the TXT article share action', () {
    for (final entity in Directory('lib/l10n').listSync()) {
      if (entity is! File || !entity.path.endsWith('.arb')) continue;
      final data = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
      expect(
        (data['shareArticleAsTxt'] as String?)?.trim().isNotEmpty,
        isTrue,
        reason: entity.path,
      );
    }
  });
}
