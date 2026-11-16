import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/widgets/tmdb_selection_dialog.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'TMDB reaches series after 20 movies and allows cancellation on $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        configureAccessibleRendererRuntime(useFlutterOnIos: true);
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          configureAccessibleRendererRuntime(useFlutterOnIos: false);
        });
        int? selected;
        final options = [
          for (var i = 0; i < 20; i++) 'Film $i',
          'Capri (2006) — Serie TV',
          for (var i = 21; i < 40; i++) 'Serie $i',
        ];
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await showTmdbSelectionDialog(
                      context,
                      title: 'TMDB',
                      options: options,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final list = tester.widget<UniversalAccessibleList>(
          find.byType(UniversalAccessibleList),
        );
        expect(list.sections.single.rows.length, 40);
        expect(list.sections.single.rows[20].title, 'Capri (2006) — Serie TV');
        await tester.scrollUntilVisible(
          find.text('Capri (2006) — Serie TV'),
          300,
        );
        await tester.tap(find.text('Capri (2006) — Serie TV'));
        await tester.pumpAndSettle();
        expect(selected, 20);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        expect(selected, isNull);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
