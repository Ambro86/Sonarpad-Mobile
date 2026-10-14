import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/sonartube_player_actions_settings_screen.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

Widget _app(Widget home, {GlobalKey<NavigatorState>? navigatorKey}) =>
    MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  final platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });

  testWidgets('route titles are headings and Back stays a separate button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _app(
          const Scaffold(appBar: SonarpadAppBar(title: Text('Sonarpad'))),
          navigatorKey: navigator,
        ),
      );
      expect(
        tester
            .getSemantics(find.text('Sonarpad'))
            .getSemanticsData()
            .headingLevel,
        1,
      );
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(
              appBar: SonarpadAppBar(title: Text('Dettaglio')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text('Dettaglio'))
            .getSemanticsData()
            .headingLevel,
        1,
      );
      final back = tester
          .getSemantics(find.byType(SonarpadBackButton))
          .getSemanticsData();
      expect(back.flagsCollection.isButton, isTrue);
      expect(back.flagsCollection.isHeader, isFalse);
      await tester.tap(find.byType(SonarpadBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Sonarpad'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  }, variant: platforms);

  testWidgets('content headings keep their role with custom Flutter children', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
    try {
      const rows = [
        AccessibleListRow(id: 'title', title: 'Titolo', kind: 'header'),
        AccessibleListRow(
          id: 'custom_title',
          title: 'Titolo personalizzato',
          kind: 'header',
          flutterChild: Text('Titolo personalizzato'),
        ),
        AccessibleListRow(id: 'text', title: 'Testo normale', kind: 'text'),
      ];
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: UniversalAccessibleList(
              sections: [AccessibleListSection(rows: rows)],
            ),
          ),
        ),
      );
      for (final title in ['Titolo', 'Titolo personalizzato']) {
        expect(
          tester.getSemantics(find.text(title)).getSemanticsData().headingLevel,
          1,
        );
      }
      expect(
        tester
            .getSemantics(find.text('Testo normale'))
            .getSemanticsData()
            .headingLevel,
        0,
      );
      // UIKit receives the same heading role through the shared model.
      expect(rows[0].toMap()['kind'], 'header');
      expect(rows[1].toMap()['kind'], 'header');
    } finally {
      configureAccessibleRendererRuntime(useFlutterOnIos: false);
      semantics.dispose();
    }
  }, variant: platforms);

  testWidgets('SonarTube settings exposes its title once as a heading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
    try {
      await tester.pumpWidget(
        _app(const SonarTubePlayerActionsSettingsScreen()),
      );
      await tester.pumpAndSettle();
      final context = tester.element(
        find.byType(SonarTubePlayerActionsSettingsScreen),
      );
      final title = AppLocalizations.of(context).settingsSonarTubePlayerActions;
      final heading = find.bySemanticsLabel(title);
      expect(heading, findsOneWidget);
      expect(tester.getSemantics(heading).getSemanticsData().headingLevel, 1);
    } finally {
      configureAccessibleRendererRuntime(useFlutterOnIos: false);
      semantics.dispose();
    }
  }, variant: platforms);
}
