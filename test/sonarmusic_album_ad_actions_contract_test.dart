import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File('lib/screens/sonarmusic_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');

  test('album content does not add a duplicate or empty VoiceOver title row', () {
    expect(screen, isNot(contains("id: 'collection_title'")));
    expect(screen, contains('if (_description?.trim().isNotEmpty == true)'));
    expect(screen, contains("id: 'play_all'"));
    expect(screen, contains("id: 'shuffle'"));
    expect(screen, contains('final fetchedTitle = result.title?.trim()'));
  });

  test('songs and music videos have AI audio description in both rotors', () {
    expect(screen, contains('if (!_canSave(item)) return;'));
    expect(screen, isNot(contains("_canSave(item) && item.kind == 'video'")));
    expect(screen, isNot(contains("_canSave(item) || item.kind != 'video'")));
    expect(screen, contains(RegExp(
      r'CustomSemanticsAction\(\s*label:\s*'
      r'AppLocalizations\.of\(context\)\.audioDescriptionCreateAiTitle\s*\)',
    )));
    expect(screen, contains("id: 'create_ai_audiodescription', label: l10n.audioDescriptionCreateAiTitle"));
    expect(screen, contains("case 'create_ai_audiodescription': await _createAd(item);"));
    expect(screen, contains('createAiAudiodescriptionFromSonarTube(context,'));
    expect(screen, contains("AppLocalizations.of(context).localeName == 'it'"));
    expect(screen, contains('RecordingFeatureAccess.isUnlocked()'));
  });
}
