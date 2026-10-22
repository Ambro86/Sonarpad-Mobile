import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/services/activation_link_service.dart';
import 'package:sonarpad_mobile_starter/widgets/activation_link_dialog.dart';

void main() {
  // Synthetic credential only; exercise all reserved characters, including a trailing backslash.
  const code = 'TEST!#@|+%&=?/\\';

  test(
    'encoded email link preserves every character, including trailing backslash',
    () {
      final link = ActivationLinkService.linkForCode(code);
      expect(link.toString(), contains('%23'));
      expect(link.toString(), contains('%5C'));
      expect(link.hasFragment, isFalse);
      expect(
        ActivationLinkService.codeFromLink(Uri.parse(link.toString())),
        code,
      );
    },
  );

  test('percent sequences are decoded exactly once', () {
    final link = ActivationLinkService.linkForCode(r'TEST%23%5C+\');
    expect(
      ActivationLinkService.codeFromLink(Uri.parse(link.toString())),
      r'TEST%23%5C+\',
    );
  });

  test('reject malformed, ambiguous and unrelated links', () {
    for (final value in [
      'sonarpad://activate',
      'sonarpad://activate?code=',
      'sonarpad://activate?code=a&code=b',
      'sonarpad://activate?code=a#lost',
      'sonarpad://activate/other?code=a',
      'sonarpad://other?code=a',
      'https://activate?code=a',
      'sonarpad://user@activate?code=a',
      'sonarpad://activate:10?code=a',
      'sonarpad://activate?code=a%00b',
    ]) {
      expect(
        () => ActivationLinkService.codeFromLink(Uri.parse(value)),
        throwsFormatException,
      );
    }
  });

  test(
    'save occurs only after validation and notifies existing screens',
    () async {
      final validated = Completer<void>();
      String? saved;
      final before = ActivationLinkService.changes.value;
      final service = ActivationLinkService(
        validate: (value) {
          expect(value, code);
          return validated.future;
        },
        save: (value) async {
          saved = value;
        },
      );
      final task = service.activate(ActivationLinkService.linkForCode(code));
      expect(saved, isNull);
      validated.complete();
      await task;
      expect(saved, code);
      expect(ActivationLinkService.changes.value, before + 1);
    },
  );

  test('failed validation preserves previous code and allows retry', () async {
    String saved = 'previous';
    var failed = true;
    final service = ActivationLinkService(
      validate: (_) async {
        if (failed) throw StateError('validation unavailable');
      },
      save: (value) async {
        saved = value;
      },
    );
    final link = ActivationLinkService.linkForCode(code);
    await expectLater(service.activate(link), throwsStateError);
    expect(saved, 'previous');
    failed = false;
    await service.activate(link);
    expect(saved, code);
  });

  test('storage failure does not announce successful activation', () async {
    final before = ActivationLinkService.changes.value;
    final service = ActivationLinkService(
      validate: (_) async {},
      save: (_) async {
        throw StateError('storage unavailable');
      },
    );
    await expectLater(
      service.activate(ActivationLinkService.linkForCode(code)),
      throwsStateError,
    );
    expect(ActivationLinkService.changes.value, before);
  });

  testWidgets(
    'accessible progress becomes confirmation without showing the code',
    (tester) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ActivationLinkDialog(
            uri: ActivationLinkService.linkForCode(code),
            service: ActivationLinkService(
              validate: (_) => pending.future,
              save: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(code), findsNothing);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Valid code'), findsOneWidget);
      expect(
        find.text('The Sonarpad code is correct. Settings saved.'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsOneWidget);
    },
  );

  test(
    'native platforms register app-only activation and leave file handling separate',
    () {
      final android = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final ios = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        android,
        contains('android:scheme="sonarpad" android:host="activate"'),
      );
      expect(android, contains('flutter_deeplinking_enabled'));
      expect(ios, contains('<string>sonarpad</string>'));
      expect(ios, contains('<key>FlutterDeepLinkingEnabled</key>'));
    },
  );
}
