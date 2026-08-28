import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android TalkBack long press opens existing shared secondary actions', () {
    final source = File('lib/widgets/universal_accessible_view.dart').readAsStringSync();

    expect(source, contains('Future<void> _showAndroidSecondaryActions(AccessibleListRow row)'));
    expect(source, contains('if (!isAndroidPlatform || row.actions.isEmpty || !mounted) return;'));
    expect(source, contains('onLongPress: isAndroidPlatform && row.actions.isNotEmpty'));
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

  test('iOS is not given the Android long-press shortcut', () {
    final source = File('lib/widgets/universal_accessible_view.dart').readAsStringSync();

    expect(
      source,
      contains('onLongPress: isAndroidPlatform && row.actions.isNotEmpty'),
    );
    expect(source, isNot(contains('onLongPress: isIosPlatform')));
  });
}
