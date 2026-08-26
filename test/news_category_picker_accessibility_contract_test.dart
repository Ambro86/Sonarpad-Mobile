import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('news categories are direct selected buttons in the shared UIKit model', () {
    final source = File('lib/screens/news_screen.dart').readAsStringSync();
    final nativeSource = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(source, contains("id: 'category_top'"));
    expect(source, contains("id: 'category_\$index'"));
    expect(source, contains("kind: 'button'"));
    expect(source, contains('selected: _currentUri == widget.source.uri'));
    expect(
      RegExp(
        r'selected:\s*_currentUri\s*==\s*widget\.source\.categories!\[index\]\.uri',
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains("event.type != 'activate'"));
    expect(
      source,
      contains(
        "settings: const RouteSettings(name: '/news/source/category')",
      ),
    );
    expect(source, contains('final showCategories = widget.initialUri == null;'));
    expect(source, isNot(contains("id: 'category',")));
    expect(nativeSource, contains('if row.selected { traits.insert(.selected) }'));
  });
}
