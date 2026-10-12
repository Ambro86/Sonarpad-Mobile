import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

const _backKey = ValueKey('detail_back');

Future<GlobalKey<NavigatorState>> _pumpNavigation(
  WidgetTester tester, {
  VoidCallback? onBack,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Text('Home principale')),
    ),
  );
  unawaited(
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Livello precedente')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: SonarpadAppBar(
            title: const Text('Dettaglio'),
            leading: SonarpadBackButton(
              key: _backKey,
              onPressed: onBack == null
                  ? null
                  : () {
                      onBack();
                      navigatorKey.currentState!.pop();
                    },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return navigatorKey;
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('Back actions on ${platform.name}', () {
      testWidgets('normal activation goes back once and honors its callback', (
        tester,
      ) async {
        var backCalls = 0;
        final navigatorKey = await _pumpNavigation(
          tester,
          onBack: () => backCalls++,
        );

        await tester.tap(find.byKey(_backKey));
        await tester.pumpAndSettle();

        expect(backCalls, 1);
        expect(find.text('Livello precedente'), findsOneWidget);
        expect(navigatorKey.currentState!.canPop(), isTrue);
        expect(find.byType(SimpleDialog), findsNothing);
      }, variant: TargetPlatformVariant({platform}));

      testWidgets('pointer hold opens Home menu without activating Back', (
        tester,
      ) async {
        var backCalls = 0;
        final navigatorKey = await _pumpNavigation(
          tester,
          onBack: () => backCalls++,
        );

        // Exercise the actual BackButton, including its built-in Tooltip. A
        // competing tooltip long press must not consume this gesture.
        await tester.longPress(find.byKey(_backKey));
        await tester.pumpAndSettle();
        expect(find.byType(SimpleDialog), findsOneWidget);
        expect(find.text('Vai alla Home'), findsOneWidget);
        expect(backCalls, 0);

        await tester.tap(find.text('Vai alla Home'));
        await tester.pumpAndSettle();
        expect(find.text('Home principale'), findsOneWidget);
        expect(navigatorKey.currentState!.canPop(), isFalse);
        expect(backCalls, 0);
      }, variant: TargetPlatformVariant({platform}));

      testWidgets('accessible hold opens one menu and can be dismissed', (
        tester,
      ) async {
        final navigatorKey = await _pumpNavigation(tester);
        final back = tester.getSemantics(find.byKey(_backKey));
        final data = back.getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.hasAction(SemanticsAction.longPress), isTrue);
        expect(
          data.customSemanticsActionIds!.map(
            (id) => CustomSemanticsAction.getAction(id)?.label,
          ),
          contains('Vai alla Home'),
        );

        back.owner!.performAction(back.id, SemanticsAction.longPress);
        back.owner!.performAction(back.id, SemanticsAction.longPress);
        await tester.pumpAndSettle();
        expect(find.byType(SimpleDialog), findsOneWidget);

        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(SimpleDialog), findsNothing);
        expect(find.text('Dettaglio'), findsOneWidget);

        // The existing flick/custom action still returns directly to Home.
        final restoredBack = tester.getSemantics(find.byKey(_backKey));
        final homeActionId = restoredBack
            .getSemanticsData()
            .customSemanticsActionIds!
            .singleWhere(
              (id) =>
                  CustomSemanticsAction.getAction(id)?.label == 'Vai alla Home',
            );
        restoredBack.owner!.performAction(
          restoredBack.id,
          SemanticsAction.customAction,
          homeActionId,
        );
        await tester.pumpAndSettle();
        expect(find.text('Home principale'), findsOneWidget);
        expect(navigatorKey.currentState!.canPop(), isFalse);
      }, variant: TargetPlatformVariant({platform}));

      testWidgets('screen reader normal activation retains Back behavior', (
        tester,
      ) async {
        var backCalls = 0;
        final navigatorKey = await _pumpNavigation(
          tester,
          onBack: () => backCalls++,
        );
        final back = tester.getSemantics(find.byKey(_backKey));

        back.owner!.performAction(back.id, SemanticsAction.tap);
        await tester.pumpAndSettle();

        expect(backCalls, 1);
        expect(find.text('Livello precedente'), findsOneWidget);
        expect(navigatorKey.currentState!.canPop(), isTrue);
        expect(find.byType(SimpleDialog), findsNothing);
      }, variant: TargetPlatformVariant({platform}));
    });
  }
}
