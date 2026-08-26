import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TV and radio recordings expose rename as secondary and visual-only action', () {
    for (final path in [
      'lib/screens/tv_recordings_screen.dart',
      'lib/screens/radio_recordings_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains("AccessibleCustomAction(id: 'rename', label: l10n.rename)"),
        reason: path,
      );
      expect(source, contains('AccessibleVisualAction('), reason: path);
      expect(source, contains("id: 'rename'"), reason: path);
      expect(source, contains("icon: 'edit'"), reason: path);
      expect(
        source,
        contains('CustomSemanticsAction(label: l10n.rename)'),
        reason: path,
      );
      expect(source, contains('ExcludeSemantics('), reason: path);
      expect(source, contains('Icons.edit_outlined'), reason: path);
      expect(source, contains('_renameRecording(file)'), reason: path);
    }
  });

  test('recording rename uses a clean shared-accessible name screen with OK and Cancel', () {
    final source =
        File('lib/screens/recording_rename_screen.dart').readAsStringSync();

    expect(source, contains('class RecordingRenameScreen'));
    expect(source, contains("id: 'new_name'"));
    expect(source, contains("kind: 'textField'"));
    expect(source, contains("id: 'ok'"));
    expect(source, contains("id: 'cancel'"));
    expect(source, contains('title: l10n.newRecordingName'));
    expect(source, contains('title: l10n.ok'));
    expect(source, contains('title: l10n.cancel'));
    expect(source, contains('UniversalAccessibleList('));
  });

  test('rename preserves extension, avoids overwrite and blocks active recordings', () {
    for (final path in [
      'lib/screens/tv_recordings_screen.dart',
      'lib/screens/radio_recordings_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();

      expect(
        source,
        contains('_recordingState(file) != GlobalRecordingOutputState.none'),
        reason: path,
      );
      expect(
        source,
        contains('recordingCannotRenameWhileInProgress'),
        reason: path,
      );
      expect(source, contains('showAndRenameRecording('), reason: path);
    }

    final helper =
        File('lib/screens/recording_rename_screen.dart').readAsStringSync();
    expect(helper, contains('final extension = p.extension(file.path);'));
    expect(
      helper,
      contains("File(p.join(file.parent.path, '\$newName\$extension'))"),
    );
    expect(helper, contains('if (await target.exists())'));
    expect(helper, contains('recordingNameAlreadyExists'));
    expect(helper, contains('return await file.rename(target.path);'));
  });

  test('every locale contains recording rename labels', () {
    const keys = [
      'rename',
      'renameRecording',
      'newRecordingName',
      'recordingCannotRenameWhileInProgress',
      'recordingNameAlreadyExists',
    ];

    for (final entity in Directory('lib/l10n').listSync()) {
      if (entity is! File || !entity.path.endsWith('.arb')) continue;
      final data =
          jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
      for (final key in keys) {
        expect(data.containsKey(key), isTrue,
            reason: '${entity.path} missing $key');
      }
    }
  });

  test('native and Flutter visual action renderers know the edit icon', () {
    final dart =
        File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final swift =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(dart, contains("'edit' => Icons.edit_outlined"));
    expect(swift, contains('case "edit": return "pencil"'));
  });
}
