import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings exposes Save in the top AppBar on iOS and Android', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(source, contains('appBar: AppBar('));
    expect(source, contains('actions: ['));
    expect(source, contains('label: l10n.saveSettings'));
    expect(source, contains('onPressed: _loading || _isSaving ? null : _saveAndClose'));
    expect(source, contains("child: Text(\n                  _isSaving ? l10n.settingsVerifyCodeAndSave : l10n.save,"));
  });

  test('top Save reuses existing save logic and closes only after success', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(source, contains('Future<void> _saveAndClose() async'));
    expect(source, contains('await _save(showConfirmation: false);'));
    expect(source, contains('if (!mounted || _hasUnsavedChanges) return;'));
    expect(source, contains('Navigator.of(context).pop(_appLanguage);'));
  });

  test('Settings no longer duplicates Save at the bottom of either renderer', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(source, isNot(contains("id: 'save'")));
    expect(
      source,
      isNot(contains('onPressed: _isSaving ? null : () => _save(),')),
    );
  });
}
