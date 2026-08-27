import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('documents expose rename as secondary and visual-only action', () {
    final source = File('lib/screens/documents_screen.dart').readAsStringSync();

    expect(source, contains("AccessibleCustomAction(id: 'rename', label: l10n.rename)"));
    expect(source, contains("id: 'rename'"));
    expect(source, contains("icon: 'edit'"));
    expect(source, contains("case 'rename': await _renameDocument(doc); break;"));
    expect(source, contains("CustomSemanticsAction(label: l10n.rename): onRename"));
    expect(source, contains("ValueKey('document_rename_\${doc.id}')"));
    expect(source, contains('Icons.edit_outlined'));
    expect(source, contains('child: ExcludeSemantics('));
  });

  test('document rename uses clean name screen and preserves file extension', () {
    final screen = File('lib/screens/document_rename_screen.dart').readAsStringSync();
    final service = File('lib/services/document_library_service.dart').readAsStringSync();

    expect(screen, contains('class DocumentRenameScreen'));
    expect(screen, contains("id: 'new_name'"));
    expect(screen, contains('title: l10n.newDocumentName'));
    expect(screen, contains("id: 'ok'"));
    expect(screen, contains("id: 'cancel'"));
    expect(service, contains('Future<DocumentItem?> renameDocument('));
    expect(service, contains("p.join(source.parent.path, '\$newDisplayName\$extension')"));
    expect(service, contains('throw const DocumentRenameConflictException();'));
    expect(service, contains('name: p.basename(renamedFile.path)'));
  });

  test('favorite radio and TV schedule actions are gated by extra feature access', () {
    final radio = File('lib/screens/favorite_radios_screen.dart').readAsStringSync();
    final tv = File('lib/screens/favorite_tvs_screen.dart').readAsStringSync();

    for (final source in [radio, tv]) {
      expect(source, contains('recordingFeatureUnlocked'));
      expect(source, contains("id: 'schedule_recording'"));
      expect(source, contains('radioScheduleDialogTitle'));
      expect(source, contains('AccessibleVisualAction('));
    }
    expect(radio, contains('showRadioScheduleRecordingAction(context, station)'));
    expect(tv, contains('showTvScheduleRecordingAction(context, channel)'));
  });

  test('TV recording surfaces stay hidden without the extra feature code', () {
    final tvMain = File('lib/screens/tv_screen.dart').readAsStringSync();
    final tvGuide = File('lib/screens/tv_channel_screen.dart').readAsStringSync();
    final tvRecordings = File('lib/screens/tv_recordings_screen.dart').readAsStringSync();
    final tvSchedule = File('lib/widgets/tv_recording_schedule_action.dart').readAsStringSync();
    final radioSchedule = File('lib/widgets/radio_recording_schedule_action.dart').readAsStringSync();
    final access = File('lib/services/recording_feature_access.dart').readAsStringSync();

    expect(tvMain, contains('bool _isRecordingFeatureUnlocked = false;'));
    expect(tvMain, contains('if (_isRecordingFeatureUnlocked)'));
    expect(tvMain, contains("id: '__recordings__'"));
    expect(tvMain, contains('recordingFeatureUnlocked: _isRecordingFeatureUnlocked'));
    expect(tvGuide, contains('if (_isRecordingFeatureUnlocked)'));
    expect(tvRecordings, contains('RecordingFeatureAccess.isUnlocked()'));
    expect(tvSchedule, contains('if (!await RecordingFeatureAccess.isUnlocked()) return;'));
    expect(radioSchedule, contains('if (!await RecordingFeatureAccess.isUnlocked()) return;'));
    expect(access, contains('if (trimmed.isEmpty) return false;'));
    expect(access, contains('TvService().isSecretCodeValid(trimmed)'));
    expect(access, contains('RaiPlayService().isSecretCodeValid(trimmed)'));
    expect(access, contains('RaiPlaySoundService().isSecretCodeValid(trimmed)'));
  });

  test('generated Brazilian Portuguese localization implements document rename labels', () {
    final source = File('lib/l10n/app_localizations_pt.dart').readAsStringSync();
    expect(RegExp(r'String get renameDocument').allMatches(source).length, 2);
    expect(RegExp(r'String get newDocumentName').allMatches(source).length, 2);
    expect(RegExp(r'String get documentNameAlreadyExists').allMatches(source).length, 2);
  });

  test('every locale contains document rename labels', () {
    const keys = [
      'renameDocument',
      'newDocumentName',
      'documentNameAlreadyExists',
    ];
    for (final entity in Directory('lib/l10n').listSync()) {
      if (entity is! File || !entity.path.endsWith('.arb')) continue;
      final data = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
      for (final key in keys) {
        expect(data.containsKey(key), isTrue, reason: '${entity.path} missing $key');
      }
    }
  });
}
