import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Media Cutter and Convert Media choose destination only after processing', () {
    final cutter = File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    final convert = File('lib/screens/convert_media_screen.dart').readAsStringSync();

    for (final source in [cutter, convert]) {
      expect(source, contains('mediaProcessingCompleted'));
      expect(source, contains('saveInSonarpadDocuments'));
      expect(source, contains('SharePlus.instance.share'));
      expect(source, contains('barrierDismissible: false'));
      expect(source, isNot(contains('FilePicker.getDirectoryPath')));
      expect(source, isNot(contains("id: 'output'")));
    }

    expect(cutter, contains('mediaCutterSave'));
    expect(cutter, isNot(contains('l10n.mediaCutterProcess')));
    expect(cutter, contains('_createStagedOutputDirectory'));
    expect(convert, contains('_createStagedOutputPath'));
  });

  test('generated media is copied into Sonarpad Documents through one service', () {
    final source = File(
      'lib/services/media_export_destination_service.dart',
    ).readAsStringSync();

    expect(source, contains('DocumentLibraryService'));
    expect(source, contains('_library.importFile'));
    expect(source, contains('_library.add(document)'));
    expect(source, contains('resolveFilePath(document)'));
  });

  test('media cutter save confirmation is a localized OK dialog', () {
    final cutter = File('lib/screens/media_cutter_screen.dart').readAsStringSync();

    expect(cutter, contains("ValueKey('media_cutter_saved_ok')"));
    expect(cutter, contains('content: Text(l10n.exportSavedInSonarpad)'));
    expect(cutter, contains('child: Text(l10n.ok)'));
    expect(cutter, contains('barrierDismissible: false'));
    expect(cutter, isNot(contains('_showSnack(l10n.exportSavedInSonarpad)')));
  });

  test('every locale contains the new media destination labels', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(file.path));

    for (final file in arbFiles) {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(
        data['mediaProcessingCompleted'],
        isA<String>().having((value) => value.trim(), 'text', isNotEmpty),
        reason: file.path,
      );
      expect(
        data['saveInSonarpadDocuments'],
        isA<String>().having((value) => value.trim(), 'text', isNotEmpty),
        reason: file.path,
      );
      expect(
        data['mediaCutterSave'],
        isA<String>().having((value) => value.trim(), 'text', isNotEmpty),
        reason: file.path,
      );
    }
  });
}
