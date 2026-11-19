import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/widgets/landscape_video_player.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'Fullscreen controls respect playback, touch and accessibility on ${platform.name}',
      (tester) async {
        Future<void> show({bool playing = true, bool reader = false}) =>
            tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(accessibleNavigation: reader),
                    child: LandscapeVideoPlayer(
                      surface: const ColoredBox(color: Colors.blue),
                      navigation: const [],
                      controls: Slider(value: .5, onChanged: (_) {}),
                      playing: playing,
                    ),
                  ),
                ),
              ),
            );
        final slider = find.byType(Slider);
        final hide = find.byTooltip('Hide video controls');
        final reveal = find.bySemanticsLabel('Show video controls');
        final semantics = tester.ensureSemantics();
        await show();
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        final drag = await tester.startGesture(tester.getCenter(slider));
        await tester.pump(const Duration(seconds: 5));
        expect(slider, findsOneWidget);
        await drag.up();
        await tester.pump(const Duration(seconds: 3));
        expect(slider, findsNothing);
        expect(reveal, findsOneWidget);
        await tester.tap(reveal);
        await tester.pump();
        expect(slider, findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await show(playing: false);
        await tester.pump(const Duration(seconds: 5));
        expect(slider, findsOneWidget);
        await show(reader: true);
        await tester.pump(const Duration(seconds: 8));
        expect(slider, findsOneWidget);
        await tester.tap(hide);
        await tester.pump();
        expect(slider, findsNothing);
        await tester.tap(reveal);
        await tester.pump(const Duration(seconds: 5));
        expect(slider, findsOneWidget);
        semantics.dispose();
      },
    );
  }
}
