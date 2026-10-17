import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every file-selection screen uses the cancellable cloud picker', () {
    const screenFiles = [
      'documents_screen.dart',
      'create_ai_audiodescription_screen.dart',
      'audio_description_project_editor_screen.dart',
      'media_cutter_screen.dart',
      'media_cutter_add_track_screen.dart',
      'media_join_screen.dart',
      'convert_media_screen.dart',
      'podcast_screen.dart',
      'news_screen.dart',
      'pyannote_parity_test_screen.dart',
    ];
    for (final name in screenFiles) {
      final source = File('lib/screens/$name').readAsStringSync();
      expect(source, contains('CloudFilePicker.pickFiles('), reason: name);
      expect(source, isNot(contains(RegExp(r'\bFilePicker\.pickFiles\('))), reason: name);
    }
  });

  test('file picker provides a real accessible progress and cancel dialog', () {
    final source =
        File('lib/services/cloud_file_picker_service.dart').readAsStringSync();
    expect(source, contains('ValueListenableBuilder<_CloudCopyProgress>'));
    expect(source, contains('LinearProgressIndicator(value: fraction)'));
    expect(source, contains('Semantics('));
    expect(source, contains("_channel.invokeMethod<void>('cancel')"));
    expect(source, contains('total <= 0 ? null'));
    expect(source, contains('l10n.cloudFilePickerLoading'));
    final italian = jsonDecode(File('lib/l10n/app_it.arb').readAsStringSync())
        as Map<String, dynamic>;
    expect(italian['cloudFilePickerLoading'], 'Caricamento del file in corso');
  });

  test('Android streams cloud bytes and cleans cancelled imports', () {
    final source = File(
      'android/app/src/main/kotlin/com/ambro86/sonarpad/SonarpadCloudFilePicker.kt',
    ).readAsStringSync();
    expect(source, contains('Intent.ACTION_OPEN_DOCUMENT'));
    expect(source, contains('contentResolver.openInputStream(uri)'));
    expect(source, contains('cancelled.get()'));
    expect(source, contains('tempFiles.forEach { it.delete() }'));
  });

  test('iOS uses provider-coordinated reads and supports cancellation', () {
    final source =
        File('ios/Runner/SonarpadCloudFilePicker.swift').readAsStringSync();
    expect(source, contains('NSFileCoordinator'));
    expect(source, contains('startAccessingSecurityScopedResource()'));
    expect(source, contains('coordinator?.cancel()'));
    expect(source, contains('CloudCopyError.incomplete'));
  });

  test('0.5.1 release notes remain populated without Markdown bold', () {
    final data = jsonDecode(File('assets/changelog.json').readAsStringSync())
        as List<dynamic>;
    final latest = data.cast<Map<String, dynamic>>().singleWhere(
      (entry) => entry['version'] == '0.5.1',
    );
    expect(latest['version'], '0.5.1');
    for (final locale in [
      'it', 'en', 'fr', 'es', 'pt', 'pt_BR', 'pl', 'cs', 'de',
      'zh_CN', 'uk', 'ro',
    ]) {
      final entries = (latest[locale] as List<dynamic>).cast<String>();
      expect(entries.last, isNot(contains('**')), reason: locale);
      expect(entries.last, isNotEmpty, reason: locale);
    }
  });
  test('iOS waits for actual dismissal and never invents provider progress', () {
    final dart = File('lib/services/cloud_file_picker_service.dart').readAsStringSync();
    final swift = File('ios/Runner/SonarpadCloudFilePicker.swift').readAsStringSync();
    expect(dart, isNot(contains('minimumVisibility')));
    expect(dart, contains('dialogTimer?.cancel()'));
    expect(dart, contains("stage: 'done'"));
    expect(dart, contains('importCompleted = true;'));
    expect(dart, contains('await route.completed;'));
    expect(dart, contains('navigator.removeRoute(route)'));
    expect(dart, contains('l10n.cloudFilePickerCopying'));
    expect(swift, isNot(contains('asyncAfter')));
    expect(swift, contains('afterPickerDismissal'));
    expect(swift, contains('controller.transitionCoordinator'));
    expect(swift, contains('self.beginCopy(urls, requestId: requestId)'));
    expect(swift, contains('guard activeRequestId == requestId'));
    expect(swift, contains('"selection_received"'));
    expect(swift, contains('"picker_presented"'));
    expect(swift, contains('"picker_dismissed"'));
    expect(swift, contains('NSFileCoordinator'));
  });
}
