import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/widgets/request_code_dialog.dart';

Future<void> open(
  WidgetTester tester,
  Future<bool> Function(String, String, String) launch,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => RequestCodeDialog(openMail: launch),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  for (final (index, value) in [
    'Example',
    'User',
    'example@example.org',
  ].indexed) {
    await tester.enterText(find.byType(TextField).at(index), value);
  }
}

void main() {
  testWidgets(
    'missing fields keep the form and values and focus the first empty field',
    (tester) async {
      var launches = 0;
      await open(tester, (_, _, _) async {
        launches++;
        return true;
      });
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(RequestCodeDialog), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField).first, 'Example');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).at(1))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(find.text('Example'), findsOneWidget);
      expect(launches, 0);
      await fill(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(launches, 1);
      expect(find.byType(RequestCodeDialog), findsNothing);
    },
  );

  for (final throwsError in [false, true]) {
    testWidgets(
      'mail launch failure stays open with persistent error: throws=$throwsError',
      (tester) async {
        var fail = true;
        await open(tester, (_, _, _) async {
          if (fail && throwsError) throw StateError('unavailable');
          return !fail;
        });
        await fill(tester);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.byType(RequestCodeDialog), findsOneWidget);
        expect(find.text('example@example.org'), findsOneWidget);
        final context = tester.element(find.byType(RequestCodeDialog));
        final l10n = AppLocalizations.of(context);
        expect(
          find.text(l10n.settingsMailOpenError(l10n.technicalErrorGeneric)),
          findsOneWidget,
        );
        fail = false;
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.byType(RequestCodeDialog), findsNothing);
      },
    );
  }

  testWidgets(
    'existing activation code does not prevent another request and stays saved',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'tvSecretCode': 'existing-test-code',
      });
      var launched = false;
      await open(tester, (name, surname, email) async {
        expect(name, 'Example');
        expect(surname, 'User');
        expect(email, 'example@example.org');
        launched = true;
        return true;
      });
      await fill(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(launched, isTrue);
      expect(
        await AppSettingsService().getTvSecretCode(),
        'existing-test-code',
      );
    },
  );
}
