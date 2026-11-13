import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_bookmarks_screen.dart';
import 'package:sonarpad_mobile_starter/services/podcast_bookmarks_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'bookmark manager has independent entries and confirmed removal $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        configureAccessibleRendererRuntime(useFlutterOnIos: true);
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          configureAccessibleRendererRuntime(useFlutterOnIos: false);
        });
        SharedPreferences.setMockInitialValues({});
        final service = PodcastBookmarksService();
        const first = 'https://example.org/a.mp3';
        const second = 'https://example.org/b.mp3';
        await service.register(first, 'Episodio uno', 'a');
        await service.save(first, 123);
        await service.register(second, 'Episodio due', 'b');
        await service.save(second, 456);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastBookmarksScreen(),
          ),
        );
        await tester.pumpAndSettle();
        List<AccessibleListRow> rows() => tester
            .widget<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList),
            )
            .sections
            .single
            .rows;
        final firstRow = rows().singleWhere((r) => r.id == first);
        expect(firstRow.subtitle, '0:02:03');
        expect(firstRow.onActivate, isNotNull);
        expect(firstRow.actions.single.id, 'remove');
        expect(firstRow.visualActions.single.id, 'remove');
        final cancel = firstRow.onCustomAction!('remove');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        await cancel;
        expect(await service.position(first), 123);
        final remove = firstRow.onCustomAction!('remove');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elimina'));
        await tester.pumpAndSettle();
        await remove;
        expect(rows().single.id, second);
        expect(await service.position(first), 0);
        expect(await service.position(second), 456);
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
        configureAccessibleRendererRuntime(useFlutterOnIos: false);
      },
    );
  }
}
