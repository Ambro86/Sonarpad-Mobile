import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('news category picker does not expose the RSS URL to VoiceOver', () {
    final source = File('lib/screens/news_screen.dart').readAsStringSync();

    expect(source, contains("id: 'category'"));
    expect(source, contains('value: _currentUri.toString()'));
    expect(source, contains("valueLabel: ''"));
  });
}
