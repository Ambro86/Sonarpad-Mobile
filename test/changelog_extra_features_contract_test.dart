import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0.4.0 Italian extra changelog entries stay code-gated', () {
    final decoded = jsonDecode(File('assets/changelog.json').readAsStringSync());
    final entries = (decoded as List).cast<Map<String, dynamic>>();
    final entry = entries.firstWhere((item) => item['version'] == '0.4.0');

    final extras = (entry['it_extra'] as List).cast<String>();
    expect(extras, hasLength(7));
    expect(extras[0], contains('Aggiunte le registrazioni programmate di Radio e TV'));
    expect(extras[1], contains('recupero della lista dei canali'));
    expect(extras[2], contains('canali regionali e nazionali'));
    expect(extras[3], contains('leggere la trama di ogni programma'));
    expect(extras[4], contains('audiodescrizioni e i contenuti di RaiPlay Sound'));
    expect(extras[5], contains('Aggiunto La7 Play'));
    expect(extras[6], contains('Riproduci diretta'));

    for (final language in const [
      'en',
      'fr',
      'es',
      'pt',
      'pt_BR',
      'pl',
      'cs',
      'de',
      'uk',
      'zh_CN',
    ]) {
      final changes = (entry[language] as List).cast<String>().join('\n');
      expect(changes, isNot(contains('registrazioni programmate di Radio e TV')));
      expect(changes, isNot(contains('canali regionali e nazionali')));
      expect(changes, isNot(contains('leggere la trama di ogni programma')));
      expect(changes, isNot(contains('audiodescrizioni e i contenuti di RaiPlay Sound')));
      expect(changes, isNot(contains('Riproduci diretta')));
    }

    final publicItalian = (entry['it'] as List).cast<String>().join('\n');
    for (final extra in extras) {
      expect(publicItalian, isNot(contains(extra)));
    }
  });

  test('0.4.0 includes the fullscreen video fix in every language', () {
    final decoded = jsonDecode(File('assets/changelog.json').readAsStringSync());
    final entries = (decoded as List).cast<Map<String, dynamic>>();
    final entry = entries.firstWhere((item) => item['version'] == '0.4.0');

    final expectedOptionNames = <String, String>{
      'it': 'Video orizzontale a schermo intero',
      'en': 'Landscape full-screen video',
      'fr': 'Vidéo horizontale en plein écran',
      'es': 'Vídeo horizontal a pantalla completa',
      'pt': 'Vídeo horizontal em ecrã inteiro',
      'pt_BR': 'Vídeo horizontal em tela cheia',
      'pl': 'Wideo poziome na pełnym ekranie',
      'cs': 'Vodorovné video přes celou obrazovku',
      'de': 'Video im Querformat als Vollbild',
      'zh_CN': '横屏全屏视频',
      'uk': 'Відео на весь екран у горизонтальній орієнтації',
    };

    for (final option in expectedOptionNames.entries) {
      final changes = (entry[option.key] as List).cast<String>().join('\n');
      expect(changes, contains('SonarTube'));
      expect(changes, contains(option.value));
    }
  });

  test('changelog resolves Italian extras only after validating Sonarpad code', () {
    final service = File('lib/services/changelog_service.dart').readAsStringSync();
    expect(service, contains("json['it_extra']"));
    expect(service, contains("languageCode == 'it'"));
    expect(service, contains('hasSonarpadExtraAccess()'));
    expect(service, contains('AppSettingsService().getTvSecretCode()'));
    expect(service, contains('TvService().isSecretCodeValid(code)'));
    expect(service, contains('RaiPlayService().isSecretCodeValid(code)'));
    expect(service, contains('RaiPlaySoundService().isSecretCodeValid(code)'));
    expect(service, contains('includeItalianExtras: includeItalianExtras'));

    final screen = File('lib/screens/changelog_screen.dart').readAsStringSync();
    expect(screen, contains('visibleChangesFor(entry, languageCode)'));
  });
}
