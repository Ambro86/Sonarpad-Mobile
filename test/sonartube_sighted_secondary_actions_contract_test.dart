import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarTube secondary actions have sighted-only visual counterparts', () {
    final screen = File('lib/screens/sonartube_screen.dart').readAsStringSync();

    expect(screen, contains('List<AccessibleVisualAction> _sightedVisualActions'));
    expect(screen, contains("id: 'go_channel'"));
    expect(screen, contains("id: 'view_comments'"));
    expect(screen, contains("id: 'transcribe_video'"));
    expect(screen, contains("icon: 'channel'"));
    expect(screen, contains("icon: 'comments'"));
    expect(screen, contains("icon: 'transcript'"));
    expect(screen, contains('_buildSightedActionBar('));
    expect(screen, contains('return ExcludeSemantics('));
  });

  test('shared renderer hides visual action controls from screen readers', () {
    final shared = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();
    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(shared, contains('class AccessibleVisualAction'));
    expect(shared, contains('final List<AccessibleVisualAction> visualActions;'));
    expect(shared, contains("'visualActions': visualActions.map((e) => e.toMap()).toList()"));
    expect(shared, contains('Widget? _visualActionButtons(AccessibleListRow row)'));
    expect(shared, contains('return ExcludeSemantics('));

    expect(native, contains('var visualActions: [SonarpadNativeVisualAction]'));
    expect(native, contains('if !row.visualActions.isEmpty && row.enabled'));
    expect(native, contains('stack.isAccessibilityElement = false'));
    expect(native, contains('stack.accessibilityElementsHidden = true'));
    expect(native, contains('button.isAccessibilityElement = false'));
    expect(native, contains('button.accessibilityElementsHidden = true'));
    expect(native, contains('cell.accessibilityCustomActions = row.actions.map'));
  });
}
