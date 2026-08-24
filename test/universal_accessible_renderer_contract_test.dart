import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen code does not branch directly on the iOS native renderer', () {
    final roots = [Directory('lib/screens'), Directory('lib/widgets')];
    final violations = <String>[];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('universal_accessible_view.dart') ||
            entity.path.endsWith('native_ios_accessible_view.dart')) {
          continue;
        }
        final text = entity.readAsStringSync();
        const forbidden = [
          'useNativeIosAccessibleViews',
          'NativeIosAccessibleList(',
          'NativeIosAccessibleGrid(',
          'NativeIosListRow(',
          'NativeIosListSection(',
          "native_ios_accessible_view.dart",
        ];
        for (final token in forbidden) {
          if (text.contains(token)) {
            violations.add('${entity.path}: $token');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Platform selection must stay inside universal_accessible_view.dart. '
          'Screens describe shared accessible models instead.',
    );
  });

  test('legacy Flutter UI is controlled by one global shared-model switch', () {
    final adapter = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();
    expect(adapter, contains('SONARPAD_ACCESSIBLE_RENDERER'));
    expect(adapter, contains("defaultValue: 'native'"));
    expect(adapter, contains("accessibleRendererMode == 'flutter'"));
    expect(adapter, contains("accessibleRendererMode == 'native'"));
  });

  test('UIKit accessibility labels include row subtitles by default', () {
    final nativeRenderer = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(nativeRenderer, contains('var effectiveAccessibilityLabel: String'));
    expect(nativeRenderer, contains('return "\\(title), \\(subtitle)"'));
    expect(
      nativeRenderer,
      contains('cell.accessibilityLabel = row.effectiveAccessibilityLabel'),
    );
    expect(
      nativeRenderer,
      isNot(
        contains(
          'cell.accessibilityLabel = row.accessibilityLabel ?? row.title',
        ),
      ),
    );
  });

  test('every scrollable screen is covered by the shared accessible model', () {
    final roots = [Directory('lib/screens'), Directory('lib/widgets')];
    final uncovered = <String>[];
    const scrollTokens = [
      'ListView',
      'GridView',
      'CustomScrollView',
      'SingleChildScrollView',
    ];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('universal_accessible_view.dart') ||
            entity.path.endsWith('native_ios_accessible_view.dart')) {
          continue;
        }
        final text = entity.readAsStringSync();
        final isScrollable = scrollTokens.any((token) => text.contains(token));
        if (!isScrollable) continue;
        final covered =
            text.contains('useSharedAccessibleViewModel') ||
            text.contains('UniversalAccessibleList(') ||
            text.contains('UniversalAccessibleGrid(');
        if (!covered) uncovered.add(entity.path);
      }
    }

    expect(
      uncovered,
      isEmpty,
      reason:
          'Scrollable screens must participate in the shared model so '
          'Android and iOS do not drift apart.',
    );
  });
}
