import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/home_customization_service.dart';
import 'package:sonarpad_mobile_starter/utils/home_item_catalog.dart';

void main() {
  test('Romanian phase 3 translates almost the entire ARB catalog', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    final ro = jsonDecode(File('lib/l10n/app_ro.arb').readAsStringSync())
        as Map<String, dynamic>;
    final keys = en.keys.where((key) => !key.startsWith('@')).toList();
    final translated = keys.where((key) => en[key] != ro[key]).length;

    expect(ro['@@locale'], 'ro');
    expect(translated, greaterThanOrEqualTo(1180));
    expect(ro['documents'], 'Documente');
    expect(ro['mediaCutterTitle'], 'Taie fișier media');
    expect(ro['convertMediaTitle'], 'Convertește media');
    expect(ro['cinemaTitle'], 'Filme la cinema');
    expect(ro['voiceDictionaryTitle'], 'Dicționar de pronunție');
    expect(ro['concertsTitle'], 'Concerte și evenimente');
  });

  test('Romanian keeps Italian-only home services hidden', () {
    final ids = availableHomeItemIds(
      isItalian: false,
      isTvCodeValid: true,
      isRaiPlayValid: true,
      isRaiPlaySoundCodeValid: true,
    );

    expect(ids, isNot(contains(HomeItemIds.tv)));
    expect(ids, isNot(contains(HomeItemIds.raiPlay)));
    expect(ids, isNot(contains(HomeItemIds.la7Play)));
    expect(ids, isNot(contains(HomeItemIds.raiPlaySound)));
    expect(ids, isNot(contains(HomeItemIds.audioDescriptions)));
    expect(ids, isNot(contains(HomeItemIds.sonarpadAudioDescriptions)));
    expect(ids, isNot(contains(HomeItemIds.digitalLibrary)));
    expect(ids, isNot(contains(HomeItemIds.openingHours)));
    expect(ids, isNot(contains(HomeItemIds.directory)));
    expect(ids, isNot(contains(HomeItemIds.pharmacy)));

    expect(ids, contains(HomeItemIds.documents));
    expect(ids, contains(HomeItemIds.createAiAudioDescription));
    expect(ids, contains(HomeItemIds.radio));
    expect(ids, contains(HomeItemIds.podcasts));
    expect(ids, contains(HomeItemIds.route));
  });

  test('Italian visibility behavior is unchanged', () {
    final ids = availableHomeItemIds(
      isItalian: true,
      isTvCodeValid: true,
      isRaiPlayValid: true,
      isRaiPlaySoundCodeValid: true,
    );

    expect(ids, contains(HomeItemIds.tv));
    expect(ids, contains(HomeItemIds.raiPlay));
    expect(ids, contains(HomeItemIds.la7Play));
    expect(ids, contains(HomeItemIds.raiPlaySound));
    expect(ids, contains(HomeItemIds.audioDescriptions));
    expect(ids, contains(HomeItemIds.sonarpadAudioDescriptions));
  });
}
