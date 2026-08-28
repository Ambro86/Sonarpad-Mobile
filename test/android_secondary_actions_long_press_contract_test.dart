import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TalkBack and VoiceOver long press open existing shared secondary actions', () {
    final source = File('lib/widgets/universal_accessible_view.dart').readAsStringSync();

    expect(source, contains('Future<void> _showSecondaryActions(AccessibleListRow row)'));
    expect(source, contains('if (!(isAndroidPlatform || isIosPlatform) || row.actions.isEmpty || !mounted)'));
    expect(source, contains('onLongPress: (isAndroidPlatform || isIosPlatform) && row.actions.isNotEmpty'));
    expect(source, contains('SimpleDialog('));
    expect(source, contains('for (final action in row.actions)'));
    expect(source, contains("type: 'customAction'"));
    expect(source, contains('action: actionId'));
  });

  test('shared Android rows such as Documents reuse the same shortcut', () {
    final renderer = File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final documents = File('lib/screens/documents_screen.dart').readAsStringSync();

    expect(renderer, contains('(isIosPlatform || isAndroidPlatform)'));
    expect(documents, contains('Widget _buildSharedAccessibleDocumentsList('));
    expect(documents, contains('actions: actions,'));
    expect(documents, contains("AccessibleCustomAction(id: 'rename', label: l10n.rename)"));
  });

  test('native iOS exposes the same actions through the VoiceOver long press context menu', () {
    final source = File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(source, contains('contextMenuConfigurationForRowAt indexPath: IndexPath'));
    expect(source, contains('UIAccessibility.isVoiceOverRunning'));
    expect(source, contains('UIContextMenuConfiguration('));
    expect(source, contains('UIAction(title: action.label)'));
    expect(source, contains('["type": "customAction", "id": rowId, "action": action.id]'));
    expect(source, contains('cell.accessibilityCustomActions = row.actions.map'));
  });
}
