import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  test('Simplified Chinese ARB covers every app message', () {
    final template = _arb('lib/l10n/app_it.arb');
    final chinese = _arb('lib/l10n/app_zh_CN.arb');
    expect(chinese['@@locale'], 'zh_CN');
    expect(_messageKeys(chinese), _messageKeys(template));
    expect(_messageKeys(chinese).length, 1016);
  });

  test('Simplified Chinese is a real selectable locale', () {
    final generated = File('lib/l10n/app_localizations.dart').readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final appSettings =
        File('lib/services/app_settings_service.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    expect(generated, contains("Locale('zh', 'CN')"));
    expect(generated, contains('AppLocalizationsZhCn'));
    expect(settings, contains("value: 'zh_CN'"));
    expect(appSettings, contains("'zh_CN'"));
    expect(main, contains("Locale('zh', 'CN')"));

    const expectedNames = <String, String>{
      'it': 'Cinese semplificato',
      'en': 'Simplified Chinese',
      'es': 'Chino simplificado',
      'fr': 'Chinois simplifié',
      'de': 'Vereinfachtes Chinesisch',
      'pl': 'Chiński uproszczony',
      'cs': 'Zjednodušená čínština',
      'pt': 'Chinês simplificado',
      'pt_BR': 'Chinês simplificado',
      'zh_CN': '简体中文',
    };
    for (final entry in expectedNames.entries) {
      final arb = _arb('lib/l10n/app_${entry.key}.arb');
      expect(arb['simplifiedChineseLanguageName'], entry.value,
          reason: entry.key);
    }
  });

  test('calendar contains 365 Chinese saints and 128 Chinese quotes', () {
    final calendar = jsonDecode(
      File('assets/calendar/zh_CN.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final saints = calendar['saints'] as Map<String, dynamic>;
    final quotes = calendar['quotes'] as List<dynamic>;
    final holidays = calendar['holidays'] as Map<String, dynamic>;

    expect(calendar['locale'], 'zh_CN');
    expect(saints.length, 365);
    expect(quotes.length, 128);
    expect(holidays['1-1'], '元旦');
    expect(holidays['1-5'], '劳动节');
    expect(holidays['1-10'], '国庆节');
  });

  test('Chinese locale selects Chinese services and China defaults', () {
    final news = File('lib/screens/news_screen.dart').readAsStringSync();
    final newsService = File('lib/services/news_service.dart').readAsStringSync();
    final podcasts = File('lib/screens/podcast_screen.dart').readAsStringSync();
    final radio = File('lib/screens/radio_screen.dart').readAsStringSync();
    final routes = File('lib/screens/route_screen.dart').readAsStringSync();
    final routeService = File('lib/services/route_service.dart').readAsStringSync();
    final tmdb = File('lib/services/tmdb_service.dart').readAsStringSync();
    final wikipedia = File('lib/screens/wikipedia_screen.dart').readAsStringSync();
    final gutenberg = File('lib/screens/gutenberg_screen.dart').readAsStringSync();

    expect(news, contains("'zh_CN' => NewsLanguage.chineseSimplified"));
    expect(news, contains("NewsLanguage.chineseSimplified => 'zh-Hans'"));
    expect(newsService, contains("NewsLanguage.chineseSimplified => 'zh-CN'"));
    expect(newsService, contains("NewsLanguage.chineseSimplified => 'CN'"));
    expect(podcasts, contains("case 'zh_CN':"));
    expect(podcasts, contains("return 'cn';"));
    expect(radio, contains("'zh_CN' => 'zh'"));
    expect(radio, contains("'zh_CN' => 'cn'"));
    expect(routes, contains("'zh_CN' => 'cn'"));
    expect(routeService, contains("return 'CHN';"));
    expect(tmdb, contains("'zh' => 'zh-CN'"));
    expect(wikipedia, contains("'zh_CN' => 'zh'"));
    expect(gutenberg, contains("'zh_CN' => 'zh'"));
  });

  test('Chinese news and iOS resources are present', () {
    final sources = File(
      'lib/services/news_sources/simplified_chinese_news_sources.dart',
    ).readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final permission =
        File('ios/Runner/zh-Hans.lproj/InfoPlist.strings').readAsStringSync();

    expect(sources, contains('hl=zh-CN&gl=CN&ceid=CN:zh-Hans'));
    expect(sources, contains('BBC 中文'));
    expect(sources, contains('Solidot'));
    expect(info, contains('<string>zh-Hans</string>'));
    expect(permission, contains('相机'));
    expect(permission, contains('日历'));
    expect(permission, contains('通讯录'));
  });

  test('all podcast categories have a Chinese label', () {
    final model = File('lib/models/podcast.dart').readAsStringSync();
    final service = File('lib/services/podcast_service.dart').readAsStringSync();
    expect(model, contains('final String? chineseName;'));
    expect(model, contains("'zh' || 'zh_CN' => chineseName"));
    expect(RegExp(r'PodcastCategory\(').allMatches(service).length, 111);
    expect(RegExp(r'chineseName:').allMatches(service).length, 111);
  });

  test('Chinese changelog is complete for every release', () {
    final decoded = jsonDecode(File('assets/changelog.json').readAsStringSync())
        as List<dynamic>;
    for (final raw in decoded) {
      final entry = raw as Map<String, dynamic>;
      final english = entry['en'] as List<dynamic>;
      final chinese = entry['zh_CN'] as List<dynamic>;
      expect(chinese.length, english.length, reason: entry['version'].toString());
      expect(chinese, isNotEmpty);
    }
  });

  test('Chinese generated localization matches all APIs and placeholders', () {
    final generated =
        File('lib/l10n/app_localizations_zh.dart').readAsStringSync();
    expect(RegExp(r'^\s*@override\s*$', multiLine: true).allMatches(generated).length,
        1016);
    expect(generated, contains('class AppLocalizationsZhCn'));
    expect(generated, contains("routeDurationHoursMinutes(int hours, int minutes)"));
    expect(generated, contains(r"'${hours} 小时 ${minutes} 分钟'"));
  });

  test('Chinese dynamic error localization is wired into shared screens', () {
    final labels =
        File('lib/l10n/localized_dynamic_labels.dart').readAsStringSync();
    final documents =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();
    final editor =
        File('lib/screens/document_editor_screen.dart').readAsStringSync();
    final news = File('lib/screens/news_screen.dart').readAsStringSync();
    final podcasts = File('lib/screens/podcast_screen.dart').readAsStringSync();
    final radio = File('lib/screens/radio_player_screen.dart').readAsStringSync();
    final radioSearch =
        File('lib/screens/radio_search_results_screen.dart').readAsStringSync();
    final wikipedia =
        File('lib/screens/wikipedia_screen.dart').readAsStringSync();

    expect(labels, isNot(contains('localizeTechnicalError')));
    expect(labels, isNot(contains('_localizeChineseTechnicalError')));
    for (final source in [
      documents,
      editor,
      news,
      podcasts,
      radio,
      radioSearch,
      wikipedia,
    ]) {
      expect(source, isNot(contains('localizeTechnicalError')));
      expect(source, contains('technicalErrorGeneric'));
    }
  });

  test('Chinese calendar text is actually Chinese', () {
    final calendar = jsonDecode(
      File('assets/calendar/zh_CN.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final saintValues =
        (calendar['saints'] as Map<String, dynamic>).values.cast<String>();
    final quoteValues = (calendar['quotes'] as List<dynamic>).cast<String>();

    expect(saintValues.length, 365);
    for (final value in saintValues) {
      expect(RegExp(r'[\u3400-\u9FFF]').hasMatch(value), isTrue,
          reason: value);
    }
    expect(quoteValues.length, 128);
    for (final value in quoteValues) {
      expect(RegExp(r'[\u3400-\u9FFF]').hasMatch(value), isTrue,
          reason: value);
    }
  });

}
