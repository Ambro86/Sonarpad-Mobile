import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('radio and TV recordings announce successful deletion', () {
    for (final path in const [
      'lib/screens/radio_recordings_screen.dart',
      'lib/screens/tv_recordings_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('showStatusMessage('));
      expect(source, contains('l10n.recordingDeleted'));
      expect(source, contains('l10n.recordingsDeleted'));
      expect(source, contains('deletedCount == 1'));
      expect(source, contains('case RecordingSelectionAction.rename:'));
      expect(source, contains('_renameRecording(result.recordings.single)'));
    }
  });

  test('recording selection exposes rename only for one selected item', () {
    final source = File('lib/widgets/recording_selection_dialog.dart')
        .readAsStringSync();
    expect(source, contains('RecordingSelectionAction { share, rename, delete }'));
    expect(source, contains('if (selected.length == 1)'));
    expect(source, contains("ValueKey('recording_selection_rename')"));
    expect(source, contains('action: RecordingSelectionAction.rename'));
  });
}
