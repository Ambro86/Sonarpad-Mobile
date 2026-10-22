import 'package:sonarpad_mobile_starter/screens/sonartube_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_library_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_favorites_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/widgets/favorite_reorder.dart';
import 'package:sonarpad_mobile_starter/screens/sonarmusic_screen.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

SonarMusicItem music(String id) =>
    SonarMusicItem(kind: 'artist', id: id, browseId: id, title: id);
SonarTubeItem tube(String id) => SonarTubeItem(
  kind: SonarTubeItemKind.channel,
  id: id,
  title: id,
  url: 'https://www.youtube.com/channel/$id',
);
Widget app(Widget home) => MaterialApp(
  locale: const Locale('it'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'music reorder persists and preserves new entries without resurrecting deleted ones',
    () async {
      final library = SonarMusicLibraryService();
      for (final id in ['Zeta', 'Diego', 'Anna']) {
        await library.toggle(music(id));
      }
      await library.reorderFavorites([
        'artist:Zeta',
        'artist:removed',
        'artist:Diego',
        'artist:Zeta',
      ]);
      expect((await SonarMusicLibraryService().favorites()).map((e) => e.id), [
        'Zeta',
        'Diego',
        'Anna',
      ]);
    },
  );
  test('tube reorder persists and preserves metadata', () async {
    final library = SonarTubeFavoritesService();
    for (final id in ['Zeta', 'Diego', 'Anna']) {
      await library.toggleFavorite(tube(id));
    }
    await library.reorderFavorites([
      library.itemKey(tube('Anna')),
      library.itemKey(tube('Zeta')),
    ]);
    final items = await SonarTubeFavoritesService().loadFavorites();
    expect(items.map((e) => e.id), ['Anna', 'Zeta', 'Diego']);
    expect(items.first.title, 'Anna');
  });
  for (final action in ['move_up', 'move_down', 'sort_favorites']) {
    testWidgets('$action moves the selected entry or sorts', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final result = await reorderFavorites(
        context,
        ['Zeta', 'Diego', 'Anna'],
        1,
        action,
        (s) => s,
      );
      expect(
        result,
        action == 'move_up'
            ? ['Diego', 'Zeta', 'Anna']
            : action == 'move_down'
            ? ['Zeta', 'Anna', 'Diego']
            : ['Anna', 'Diego', 'Zeta'],
      );
    });
  }
  testWidgets('position picker names the destination, confirms and cancels', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final pending = reorderFavorites(
      context,
      ['Anna', 'Diego Fusaro', 'Zeta'],
      0,
      'move_position',
      (s) => s,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Diego Fusaro'), findsOneWidget);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
    await tester.pump();
    expect(find.textContaining('Zeta'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(await pending, ['Diego Fusaro', 'Anna', 'Zeta']);
    final cancel = reorderFavorites(
      context,
      ['Anna', 'Diego'],
      0,
      'move_position',
      (s) => s,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(await cancel, isNull);
  });
  testWidgets(
    'first and last entries expose only valid moves; visual controls are excluded',
    (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (c) {
              final l = AppLocalizations.of(c);
              expect(
                favoriteReorderActions(l, 0, 2).map((a) => a.id),
                isNot(contains('move_up')),
              );
              expect(
                favoriteReorderActions(l, 1, 2).map((a) => a.id),
                isNot(contains('move_down')),
              );
              return favoriteReorderButtons(l, 0, 2, (_) {});
            },
          ),
        ),
      );
      expect(
        find.ancestor(
          of: find.byType(IconButton).first,
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    },
  );
  testWidgets(
    'music favorite action saves order and keeps the moved item available',
    (tester) async {
      final library = SonarMusicLibraryService();
      await library.toggle(music('Zeta'));
      await library.toggle(music('Diego'));
      await tester.pumpWidget(
        app(SonarMusicScreen(libraryType: 'favorites', library: library)),
      );
      await tester.pumpAndSettle();
      var list = tester.widget<UniversalAccessibleList>(
        find.byType(UniversalAccessibleList),
      );
      final row = list.sections
          .expand((s) => s.rows)
          .singleWhere((r) => r.title == 'Diego');
      expect(
        row.actions.map((a) => a.id),
        containsAll(['move_down', 'move_position', 'sort_favorites']),
      );
      expect(
        row.visualActions.map((a) => a.id),
        containsAll(['move_down', 'move_position', 'sort_favorites']),
      );
      list.onEvent!(
        AccessibleListEvent(
          type: 'customAction',
          id: row.id,
          action: 'move_down',
        ),
      );
      await tester.pumpAndSettle();
      expect((await library.favorites()).map((e) => e.id), ['Zeta', 'Diego']);
    },
  );
  testWidgets('tube favorite action persists order with secondary and visual controls', (tester) async {
    final library=SonarTubeFavoritesService();
    await library.toggleFavorite(tube('Zeta'));await library.toggleFavorite(tube('Diego'));
    await tester.pumpWidget(app(SonarTubeScreen(favoritesService:library)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sonartube_favorites_button')));
    await tester.pumpAndSettle();
    final list=tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList).last);
    final row=list.sections.expand((s)=>s.rows).singleWhere((r)=>r.title=='Zeta');
    expect(row.actions.map((a)=>a.id),containsAll(['move_down','move_position','sort_favorites']));
    expect(row.visualActions.map((a)=>a.id),containsAll(['move_down','move_position','sort_favorites']));
    list.onEvent!(AccessibleListEvent(type:'customAction',id:row.id,action:'move_down'));
    await tester.pumpAndSettle();
    expect((await library.loadFavorites()).map((e)=>e.id),['Diego','Zeta']);
  });

}
