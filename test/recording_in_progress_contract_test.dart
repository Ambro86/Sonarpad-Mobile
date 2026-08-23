import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global recording service exposes active output state', () {
    final source =
        File('lib/services/global_recording_service.dart').readAsStringSync();
    expect(source, contains('enum GlobalRecordingOutputState'));
    expect(source, contains('GlobalRecordingOutputState outputStateFor(File file)'));
    expect(source, contains('activeOutput.path != file.path'));
    expect(source, contains('GlobalRecordingOutputState.scheduledRecording'));
  });

  test('TV and radio recordings label and block the active output', () {
    for (final path in [
      'lib/screens/tv_recordings_screen.dart',
      'lib/screens/radio_recordings_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('_globalRecordingService.addListener('), reason: path);
      expect(source, contains('_globalRecordingService.removeListener('), reason: path);
      expect(source, contains('scheduledRecordingInProgressStatus'), reason: path);
      expect(source, contains('recordingCannotOpenWhileInProgress'), reason: path);
      expect(source, contains('value: _recordingStatus('), reason: path);
      expect(source, contains('subtitle: status == null ? null : Text(status)'), reason: path);
      expect(
        source,
        contains('if (_recordingState(file) != GlobalRecordingOutputState.none)'),
        reason: path,
      );
    }
  });

  test('every locale contains recording-in-progress messages', () {
    final files = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(file.path));
    for (final file in files) {
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in [
        'recordingInProgressStatus',
        'scheduledRecordingInProgressStatus',
        'recordingCannotOpenWhileInProgress',
      ]) {
        expect((arb[key] as String?)?.trim(), isNotEmpty,
            reason: '${file.path}: $key');
      }
    }
  });
}
