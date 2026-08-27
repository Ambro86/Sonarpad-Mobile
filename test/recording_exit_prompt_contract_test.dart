import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active recording asks whether to stop or continue before leaving player', () {
    final player =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(player, contains('Future<void> _requestPlayerExit() async'));
    expect(player, contains('if (!_recording)'));
    expect(player, contains('barrierDismissible: false'));
    expect(player, contains('content: Text(l10n.recordingExitPrompt)'));
    expect(player, contains('child: Text(l10n.stopRecording)'));
    expect(player, contains('child: Text(l10n.continueRecording)'));
    expect(player, contains('await _stopRecordingNow(showMessage: false)'));
    expect(
      player,
      contains('canPop: !_recording || _allowExitWithActiveRecording'),
    );
    expect(player, contains('onPressed: _requestPlayerExit'));
  });

  test('every locale contains recording exit prompt labels', () {
    for (final entity in Directory('lib/l10n').listSync()) {
      if (entity is! File || !entity.path.endsWith('.arb')) continue;
      final arb = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
      expect(
        (arb['recordingExitPrompt'] as String?)?.trim(),
        isNotEmpty,
        reason: '${entity.path}: recordingExitPrompt',
      );
      expect(
        (arb['continueRecording'] as String?)?.trim(),
        isNotEmpty,
        reason: '${entity.path}: continueRecording',
      );
    }
  });
}
