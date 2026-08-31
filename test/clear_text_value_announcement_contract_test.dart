import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clear text/search announces the removed value everywhere', () {
    final shared = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();
    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();
    final weather = File('lib/screens/weather_screen.dart').readAsStringSync();
    final sonarTube =
        File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final dropbox =
        File('lib/screens/dropbox_browser_screen.dart').readAsStringSync();

    expect(shared, contains('void announceClearedEditableText('));
    expect(shared, contains('l10n.clearedTextAnnouncement(trimmed)'));
    expect(shared, contains('l10n.textDeletedAnnouncement'));
    expect(shared, contains("if (event.type == 'textCleared')"));
    expect(shared, contains('secure: row.secure'));
    expect(
      shared,
      contains('final previousValue = controller.text;'),
    );

    expect(native, contains('var onCleared: ((String, String) -> Void)?'));
    expect(native, contains('let previousValue = field.text ?? ""'));
    expect(native, contains('onCleared?(rowId, previousValue)'));
    expect(native, contains('["type": "textCleared", "id": id, "value": previousValue]'));

    for (final source in [weather, sonarTube, dropbox]) {
      expect(source, contains('final previousValue ='));
      expect(source, contains('announceClearedEditableText(context, previousValue)'));
    }
  });

  test('clear announcement localization exists in every ARB', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_(?:it|en|fr|es|pt|pt_BR|pl|cs|de|uk|zh|zh_CN)\.arb$')
            .hasMatch(file.path))
        .toList(growable: false);

    expect(arbFiles, hasLength(12));
    for (final file in arbFiles) {
      final source = file.readAsStringSync();
      expect(source, contains('"clearedTextAnnouncement"'), reason: file.path);
      expect(source, contains('"textDeletedAnnouncement"'), reason: file.path);
    }
  });
}
