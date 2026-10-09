import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SonarMusic uses the same Italian-language and code gate as SonarTube', () {
    final music = File('lib/screens/sonarmusic_screen.dart').readAsStringSync();
    final tube = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final saveGuard = RegExp(
      r'bool _canSave\(SonarMusicItem item\) =>([\s\S]*?);',
    ).firstMatch(music);

    expect(saveGuard, isNotNull);
    final conditions = saveGuard!.group(1)!;
    expect(conditions, contains('_unlocked'));
    expect(conditions, contains("AppLocalizations.of(context).localeName == 'it'"));
    expect(conditions, contains('item.playable'));
    expect(music, contains('RecordingFeatureAccess.isUnlocked()'));
    expect(tube, contains("l10n.localeName == 'it'"));
  });

  test('all SonarMusic save entry points share the same eligibility check', () {
    final music = File('lib/screens/sonarmusic_screen.dart').readAsStringSync();

    // The player, Flutter semantics, visual button and native iOS actions
    // are all hidden unless the same language-and-unlock gate succeeds.
    expect(RegExp(r'if \(_canSave\(item\)\)').allMatches(music).length, 4);
    expect(music, contains("PodcastPlayerExtraAction(id: 'save_media'"));
    expect(music, contains("CustomSemanticsAction(label: _label('save'))"));
    expect(music, contains("IconButton(tooltip: _label('save')"));
    expect(music, contains("AccessibleCustomAction(id: 'save_media'"));

    // Also check at invocation time: stale actions cannot bypass the gate.
    expect(music, contains('if (!_canSave(item)) return;'));
    expect(music, contains("case 'save_media': await _save(item);"));
    expect(music, contains('onPressed: () => _save(currentItem())'));
    expect(music, contains('saveSonarTubeMediaWithDestination(context,'));
  });
}
