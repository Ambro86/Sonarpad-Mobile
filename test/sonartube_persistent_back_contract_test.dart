import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube keeps Back reachable outside long native scrolling lists', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('persistentTopAction: _isCollection'));
    expect(
      RegExp(r"id: 'persistent_back'").allMatches(source).length,
      greaterThanOrEqualTo(1),
    );
    expect(source, contains('onActivate: () => Navigator.pop(context)'));
    expect(source, contains('UniversalPersistentNavigationButton('));
  });

  test('shared renderer serializes the persistent route action to UIKit', () {
    final adapter = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();

    expect(adapter, contains('final AccessibleListRow? persistentTopAction;'));
    expect(adapter, contains("'persistentTopAction': widget.persistentTopAction!.toMap()"));
    expect(adapter, contains('persistentTopAction.id == id'));
  });

  test('UIKit places persistent Back before the scrolling table', () {
    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(native, contains('SonarpadPersistentAccessibilityActionElement'));
    expect(native, contains('map["persistentTopAction"]'));
    expect(native, contains('rootView.accessibilityElements = [element, tableView]'));
    expect(native, contains('arguments: ["type": "activate", "id": row.id]'));
  });
}
