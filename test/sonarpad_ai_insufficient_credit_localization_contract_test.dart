import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sonarpad AI insufficient credit is a typed localized user error', () {
    final service = File('lib/services/ai_audiodescription_service.dart').readAsStringSync();
    final screen = File('lib/screens/create_ai_audiodescription_screen.dart').readAsStringSync();
    final localizations = File('lib/l10n/app_localizations.dart').readAsStringSync();

    expect(service, contains('class SonarpadAiInsufficientCreditException'));
    expect(service, contains("_sonarpadErrorCode(response.body) == 'insufficient_credit'"));
    expect(service, contains("_sonarpadErrorCode(generate.body) == 'insufficient_credit'"));
    expect(screen, contains('error is SonarpadAiInsufficientCreditException'));
    expect(screen, contains('audioDescriptionSonarpadInsufficientCredit'));
    expect(screen, contains('cancelled || noCheckpoint || deviceLimit || insufficientCredit'));
    expect(localizations, contains('String get audioDescriptionSonarpadInsufficientCredit;'));

    const arbFiles = <String>[
      'app_cs.arb', 'app_de.arb', 'app_en.arb', 'app_es.arb', 'app_fr.arb',
      'app_it.arb', 'app_pl.arb', 'app_pt.arb', 'app_pt_BR.arb', 'app_ro.arb',
      'app_uk.arb', 'app_zh.arb', 'app_zh_CN.arb',
    ];
    for (final name in arbFiles) {
      final arb = File('lib/l10n/$name').readAsStringSync();
      expect(arb, contains('"audioDescriptionSonarpadInsufficientCredit"'), reason: name);
    }
  });
}
