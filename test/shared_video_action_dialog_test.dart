import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/widgets/shared_video_action_dialog.dart';

void main() {
  for (final choice in <String, SharedVideoAction?>{
    'Apri video': SharedVideoAction.play,
    'Crea audiodescrizione IA': SharedVideoAction.describe,
    'Annulla': null,
  }.entries) {
    testWidgets('shared video: ${choice.key}', (tester) async {
      SharedVideoAction? selected;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showSharedVideoActionDialog(
                    context,
                    filename: 'Vacanza 100%.mov',
                  );
                  completed = true;
                },
                child: const Text('Share'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(find.text('Vacanza 100%.mov'), findsOneWidget);
      // Resolve the translated AD action instead of tying this test to its copy.
      final context = tester.element(find.byType(SimpleDialog));
      final label = choice.value == SharedVideoAction.describe
          ? AppLocalizations.of(context).audioDescriptionCreateAiTitle
          : choice.key;
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(selected, choice.value);
      expect(find.byType(SimpleDialog), findsNothing);
    });
  }
}
