import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/utils/imported_file_display_name.dart';

void main() {
  const uuid = '81EB17C7-440A-4C79-9D87-123456789ABC';
  test(
    'legacy imports display the Unicode name without the generated prefix',
    () {
      expect(
        importedFileDisplayName(
          '/tmp/sonarpad_cloud_import/${uuid}_Città 🎵.mp4',
        ),
        'Città 🎵.mp4',
      );
    },
  );
  test('isolated imports retain real names even if they start with a UUID', () {
    final name = '${uuid}_originale.mp3';
    expect(
      importedFileDisplayName('/tmp/sonarpad_cloud_import/$uuid/$name'),
      name,
    );
    expect(importedFileDisplayName('/Documents/$name'), name);
    expect(
      importedFileDisplayName('/tmp/sonarpad_cloud_import/nome_reale.wav'),
      'nome_reale.wav',
    );
  });
  test('different imported paths retain the same original filename', () {
    expect(
      importedFileDisplayName('/tmp/sonarpad_cloud_import/one/Clip.mp4'),
      'Clip.mp4',
    );
    expect(
      importedFileDisplayName('/tmp/sonarpad_cloud_import/two/Clip.mp4'),
      'Clip.mp4',
    );
  });
  test('native importers isolate files by directory, not by renaming them', () {
    final swift = File(
      'ios/Runner/SonarpadCloudFilePicker.swift',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/ambro86/sonarpad/SonarpadCloudFilePicker.kt',
    ).readAsStringSync();
    expect(
      swift,
      contains('let target = itemDirectory.appendingPathComponent(safeName)'),
    );
    expect(swift, contains('copiedDirectories.append(itemDirectory)'));
    expect(swift, contains('removeItem(at: directory)'));
    expect(swift, isNot(contains(r'\(UUID().uuidString)_\(safeName)')));
    expect(
      kotlin,
      contains('val itemDirectory = File(dir, UUID.randomUUID().toString())'),
    );
    expect(kotlin, contains('File(itemDirectory, name.ifBlank'));
    expect(
      kotlin,
      contains('tempDirectories.forEach { it.deleteRecursively() }'),
    );
  });
}
