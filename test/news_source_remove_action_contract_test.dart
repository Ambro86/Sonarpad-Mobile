import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each news source exposes one remove action with the correct behavior', () {
    final screen = File('lib/screens/news_screen.dart').readAsStringSync();
    final service = File('lib/services/news_service.dart').readAsStringSync();
    final communityAddStart =
        screen.indexOf('Future<void> _addToLibrary(NewsRssSource source)');
    final communityBuildStart =
        screen.indexOf('  @override\n  Widget build', communityAddStart);

    expect(communityAddStart, greaterThanOrEqualTo(0));
    expect(communityBuildStart, greaterThan(communityAddStart));
    final communityAddBlock =
        screen.substring(communityAddStart, communityBuildStart);
    expect(communityAddBlock, contains('await _service.addCustomSource('));

    expect(
      screen,
      contains("id: source.isCustom ? 'delete' : 'hide'"),
    );
    expect(screen, contains('label: l10n.deleteNewsSource'));
    expect(screen, isNot(contains('label: l10n.hide')));
    expect(
      screen,
      isNot(
        contains(
          "if (source.isCustom && !source.isFolder)\n"
          "            AccessibleCustomAction(id: 'delete'",
        ),
      ),
    );
    expect(
      screen,
      contains('await service.hideSource(language, source);'),
    );
    expect(
      screen,
      contains('await service.removeCustomSource(language, source.name);'),
    );
    expect(service, contains('Future<void> hideSource('));
    expect(service, contains('Future<void> removeCustomSource('));
  });

  test('the single Italian action is named Rimuovi', () {
    final arb = File('lib/l10n/app_it.arb').readAsStringSync();
    final generated =
        File('lib/l10n/app_localizations_it.dart').readAsStringSync();

    expect(arb, contains('"deleteNewsSource": "Rimuovi"'));
    expect(generated, contains("String get deleteNewsSource => 'Rimuovi';"));
  });
}
