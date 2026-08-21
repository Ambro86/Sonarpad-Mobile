import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LA7 Play root excludes live TV and keeps catch-up plus programs', () {
    final source = File('lib/services/la7_play_service.dart').readAsStringSync();
    final rootStart = source.indexOf('La7PlayPage rootPage()');
    final rootEnd = source.indexOf('Future<La7PlayPage> loadPage', rootStart);
    final root = source.substring(rootStart, rootEnd);
    expect(root, contains("title: 'Rivedi LA7'"));
    expect(root, contains("title: 'Programmi'"));
    expect(root, isNot(contains('Dirette')));
    expect(root, isNot(contains('live')));
  });

  test('LA7 Play uses the same Italian and code gate as RaiPlay', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final screen = File('lib/screens/la7_play_screen.dart').readAsStringSync();
    expect(home, contains("if (_isRaiPlayValid && isItalian)"));
    expect(home, contains("label: 'LA7 Play'"));
    expect(screen, contains("language != 'it'"));
    expect(screen, contains('_service.isSecretCodeValid(code)'));
  });

  test('LA7 Play navigation uses Material pages and shared accessible rows', () {
    final source = File('lib/screens/la7_play_screen.dart').readAsStringSync();
    expect(source, contains('MaterialPageRoute<void>('));
    expect(source, contains('Scaffold('));
    expect(source, contains('UniversalAccessibleList('));
    expect(source, isNot(contains('useNativeIosAccessibleViews')));
    expect(source, isNot(contains('NativeIosAccessibleList')));
  });

  test('LA7 Play search field lives directly on the root page', () {
    final source = File('lib/screens/la7_play_screen.dart').readAsStringSync();
    expect(source, contains("id: 'search_query'"));
    expect(source, contains("labelText: 'Cerca su LA7 Play'"));
    expect(source, contains("textInputAction: TextInputAction.search"));
    expect(source, contains("RouteSettings(name: '/la7play/search-results')"));
    expect(source, contains("domain: 'la7play'"));
    expect(source, isNot(contains("'/la7play/search-form'")));
    expect(source, isNot(contains('La7PlaySearchScreen')));
  });

  test('LA7 Play service ports Mac catch-up programs search and VOD resolver', () {
    final source = File('lib/services/la7_play_service.dart').readAsStringSync();
    expect(source, contains("static const _rivedi = 'https://www.la7.it/rivedila7/0/la7'"));
    expect(source, contains("static const _programmi = 'https://www.la7.it/programmi'"));
    expect(source, contains("static const _tuttiProgrammi = 'https://www.la7.it/tutti-i-programmi'"));
    expect(source, contains('_programSearchClips'));
    expect(source, contains('_programEpisodes'));
    expect(source, contains('resolveVod'));
    expect(source.toLowerCase(), contains('widevine'));
  });
}
