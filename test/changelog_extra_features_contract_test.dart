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


  test('0.4.0 includes readable Edge labels and direct news sharing in every language', () {
    final decoded = jsonDecode(File('assets/changelog.json').readAsStringSync());
    final entries = (decoded as List).cast<Map<String, dynamic>>();
    final entry = entries.firstWhere((item) => item['version'] == '0.4.0');

    final edgeSnippets = <String, String>{
      'it': 'etichette più umane e meno tecniche',
      'en': 'more human-friendly and less technical labels',
      'fr': 'libellés plus naturels et moins techniques',
      'es': 'etiquetas más claras y menos técnicas',
      'pt': 'etiquetas mais naturais e menos técnicas',
      'pt_BR': 'rótulos mais naturais e menos técnicos',
      'pl': 'bardziej zrozumiałe i mniej techniczne etykiety',
      'cs': 'přirozenější a méně technické',
      'de': 'verständlicheren und weniger technischen Bezeichnungen',
      'zh_CN': '标签更加自然易懂',
      'uk': 'зрозумілішими та менш технічними',
    };
    final shareSnippets = <String, String>{
      'it': 'azioni secondarie',
      'en': 'secondary actions',
      'fr': 'actions secondaires',
      'es': 'acciones secundarias',
      'pt': 'ações secundárias',
      'pt_BR': 'ações secundárias',
      'pl': 'akcji dodatkowych',
      'cs': 'vedlejších akcí',
      'de': 'sekundären Aktionen',
      'zh_CN': '辅助操作',
      'uk': 'додаткові дії',
    };

    for (final language in edgeSnippets.keys) {
      final changes = (entry[language] as List).cast<String>();
      expect(changes.any((change) => change.contains(edgeSnippets[language]!)), isTrue);
      expect(changes.any((change) => change.contains(shareSnippets[language]!)), isTrue);
    }

    final news = File('lib/screens/news_screen.dart').readAsStringSync();
    expect(news, contains("id: 'share'"));
    expect(news, contains('label: l10n.shareArticle'));
    expect(news, contains("event.type == 'customAction' && event.action == 'share'"));
    expect(news, contains('CustomSemanticsAction(label: l10n.shareArticle)'));
    expect(news, contains('_shareArticle(article)'));
  });

  test('0.4.0 includes document rename from secondary actions in every language', () {
    final decoded = jsonDecode(File('assets/changelog.json').readAsStringSync());
    final entries = (decoded as List).cast<Map<String, dynamic>>();
    final entry = entries.firstWhere((item) => item['version'] == '0.4.0');

    final renameSnippets = <String, String>{
      'it': 'rinominare i documenti',
      'en': 'rename documents',
      'fr': 'renommer les documents',
      'es': 'renombrar documentos',
      'pt': 'renomear documentos',
      'pt_BR': 'renomear documentos',
      'pl': 'zmiany nazw dokumentów',
      'cs': 'přejmenovat dokumenty',
      'de': 'Dokumente können jetzt umbenannt werden',
      'zh_CN': '重命名文档',
      'uk': 'перейменовувати документи',
    };

    for (final item in renameSnippets.entries) {
      final changes = (entry[item.key] as List).cast<String>();
      expect(changes.any((change) => change.contains(item.value)), isTrue);
    }
  });

  test('0.4.0 keeps VoiceOver three-finger note on iOS and TalkBack long press on Android', () {
    final decoded = jsonDecode(File('assets/changelog.json').readAsStringSync());
    final entries = (decoded as List).cast<Map<String, dynamic>>();
    final entry = entries.firstWhere((item) => item['version'] == '0.4.0');

    final threeFingerSnippets = <String, String>{
      'it': 'gesto a tre dita di VoiceOver',
      'en': 'three-finger gesture',
      'fr': 'geste VoiceOver à trois doigts',
      'es': 'gesto de tres dedos de VoiceOver',
      'pt': 'gesto de três dedos do VoiceOver',
      'pt_BR': 'gesto de três dedos do VoiceOver',
      'pl': 'gestem VoiceOver trzema palcami',
      'cs': 'tříprstým gestem VoiceOveru',
      'de': 'Drei-Finger-Geste von VoiceOver',
      'zh_CN': 'VoiceOver 的三指手势',
      'uk': 'жестом VoiceOver трьома пальцями',
    };
    final androidLongPressSnippets = <String, String>{
      'it': 'doppio tap trattenuto',
      'en': 'double tap and hold',
      'fr': 'double appui prolongé',
      'es': 'doble toque mantenido',
      'pt': 'duplo toque prolongado',
      'pt_BR': 'toque duplo prolongado',
      'pl': 'podwójne stuknięcie z przytrzymaniem',
      'cs': 'dvojitým klepnutím s podržením',
      'de': 'Doppeltippen und Halten',
      'zh_CN': '双击并按住',
      'uk': 'подвійним дотиком з утриманням',
    };
    final iosLongPressSnippets = <String, String>{
      'it': 'doppio tap trattenuto',
      'en': 'double tap and hold',
      'fr': 'double appui prolongé',
      'es': 'doble toque mantenido',
      'pt': 'duplo toque prolongado',
      'pt_BR': 'toque duplo prolongado',
      'pl': 'podwójnym stuknięciem z przytrzymaniem',
      'cs': 'dvojitým klepnutím s podržením',
      'de': 'Doppeltippen und Halten',
      'zh_CN': '双击并按住',
      'uk': 'подвійним дотиком з утриманням',
    };
    final ios = (entry['ios'] as Map<String, dynamic>);
    final android = (entry['android'] as Map<String, dynamic>);

    for (final language in threeFingerSnippets.keys) {
      final base = (entry[language] as List).cast<String>().join('\n');
      final iosText = (ios[language] as List).cast<String>().join('\n');
      final androidText = (android[language] as List).cast<String>().join('\n');
      expect(base, isNot(contains(threeFingerSnippets[language]!)));
      expect(base, isNot(contains(androidLongPressSnippets[language]!)));
      expect(iosText, contains(threeFingerSnippets[language]!));
      expect(iosText, contains('VoiceOver'));
      expect(iosText, contains(iosLongPressSnippets[language]!));
      expect(androidText, contains('TalkBack'));
      expect(androidText, contains(androidLongPressSnippets[language]!));
    }

    final service = File('lib/services/changelog_service.dart').readAsStringSync();
    expect(service, contains("readPlatformChanges('ios')"));
    expect(service, contains("readPlatformChanges('android')"));
    expect(service, contains('TargetPlatform.iOS'));
    expect(service, contains('TargetPlatform.android'));
    expect(service, contains('platform: defaultTargetPlatform'));
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
