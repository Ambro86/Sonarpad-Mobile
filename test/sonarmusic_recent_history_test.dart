import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/sonarmusic_screen.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_library_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

const song = SonarMusicItem(kind: 'song', id: 'one', title: 'First song', videoId: 'one');
const video = SonarMusicItem(kind: 'video', id: 'one', title: 'First video', videoId: 'one');

void main() {
  test('resolved music title updates the same recent item and preserves metadata', () async {
    SharedPreferences.setMockInitialValues({});
    const original = SonarMusicItem(kind: 'song', id: 'url-video', videoId: 'url-video',
      title: 'YouTube Music', artist: 'Artist', artistId: 'artist-id', album: 'Album',
      albumId: 'album-id', duration: '3:00');
    final library = SonarMusicLibraryService();
    await library.remember(original);
    await library.remember(original.withResolvedTitle('Real title'));
    final saved = (await library.recent()).single;
    expect(saved.title, 'Real title');
    expect(saved.key, original.key);
    expect(saved.toJson(), {...original.toJson(), 'title': 'Real title'});
    expect(saved.withResolvedTitle('').title, 'Real title');
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
  });
  tearDown(() => configureAccessibleRendererRuntime(useFlutterOnIos: false));

  test('removing history preserves favorites and other media with the same ID', () async {
    final library = SonarMusicLibraryService();
    await library.remember(song);
    await library.remember(video);
    await library.toggle(song);
    await library.removeRecent(song);
    expect((await SonarMusicLibraryService().recent()).map((e) => e.key), [video.key]);
    await library.clearHistory();
    expect(await library.recent(), isEmpty);
    expect((await library.favorites()).single.key, song.key);
  });

  testWidgets('recent entries expose delete actions and clear requires confirmation', (tester) async {
    final library = SonarMusicLibraryService();
    await library.remember(song);
    await library.remember(video);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SonarMusicScreen(libraryType: 'recent', library: library),
    ));
    await tester.pumpAndSettle();
    final list = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
    final row = list.sections.expand((s) => s.rows).firstWhere((r) => r.id == 'item_0');
    expect(row.actions.any((a) => a.id == 'delete_recent'), isTrue);
    expect(row.visualActions.single.id, 'delete_recent');
    final deleteButton = find.byKey(ValueKey('sonarmusic_delete_recent_${video.key}'));
    expect(find.ancestor(of: deleteButton, matching: find.byType(ExcludeSemantics)), findsWidgets);
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect((await library.recent()).single.key, song.key);

    final clear = find.byKey(const ValueKey('sonarmusic_clear_history'));
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
    await tester.pumpAndSettle();
    expect(await library.recent(), hasLength(1));
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancella'));
    await tester.pumpAndSettle();
    expect(await library.recent(), isEmpty);
    expect(clear, findsNothing);
    expect(find.text(song.title), findsNothing);
  });
}
