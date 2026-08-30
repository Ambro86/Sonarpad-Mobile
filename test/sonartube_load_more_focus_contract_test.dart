import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube load more focuses the first appended row renderer-neutrally', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('final firstAppendedIndex = _items.length;'));
    expect(source, contains('shouldFocusFirstAppendedItem = true;'));
    expect(source, contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(
      source,
      contains("_accessibleListController.focusTo(\n      'item_\$firstAppendedIndex',"),
    );

    const forbiddenNativeScreenTokens = [
      'useNativeIosAccessibleViews',
      'NativeIosAccessibleList(',
      'NativeIosListRow(',
      "native_ios_accessible_view.dart",
    ];
    for (final token in forbiddenNativeScreenTokens) {
      expect(
        source,
        isNot(contains(token)),
        reason: 'SonarTube must leave Flutter/UIKit selection to the shared adapter.',
      );
    }
  });
  test('Material SonarTube load more focuses the first appended result', () {
    final source = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(source, contains('_loadMoreFocusIndex = firstAppendedIndex;'));
    expect(source, contains('_focusFirstAppendedMaterialResult(firstAppendedIndex)'));
    expect(source, contains('Scrollable.ensureVisible('));
    expect(source, contains('sendSemanticsEvent(const FocusSemanticEvent())'));
    expect(source, contains("debugLabel: 'sonartube_load_more_target'"));
    expect(source, contains('return itemIndex == _loadMoreFocusIndex'));
  });

  test('UIKit retries an ignored SonarTube load-more focus exactly once', () {
    final swift = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();
    final shared = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();

    expect(shared, contains('widget.debugTag ?? widget.controller?.debugName'));
    expect(swift, contains('self.debugTag == "sonartube"'));
    expect(swift, contains('mode == "inPlaceJump"'));
    expect(swift, contains('id.hasPrefix("item_")'));
    expect(swift, contains('ONE_SHOT_FOCUS_FALLBACK'));
    expect(swift, contains('let isSonarTubeOneShotRecovery ='));
    expect(
      swift,
      contains('if isSonarTubeOneShotRecovery || isDocumentOneShotRecovery'),
    );
    expect(
      swift,
      contains('let retryUsesLayoutChanged ='),
      reason: 'SonarTube keeps the strong screenChanged retry while structural document returns choose layoutChanged only when VoiceOver is still inside the native table.',
    );
    expect(
      swift,
      contains('UIAccessibility.post(notification: retryNotification, argument: retryTarget)'),
    );
  });

}
