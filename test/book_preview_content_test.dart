import 'package:flutter/material.dart';
import 'dart:ui' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/utils/book_preview_segments.dart';
import 'package:sonarpad_mobile_starter/widgets/book_preview_content.dart';

void main() {
  const introduction =
      'Target di lettura: Adulti\r\ngenere: Romanzo\r\n'
      'Riassunto di prova.\r\n'
      'Avvertenza: informazioni generate automaticamente tramite intelligenza artificiale.\r\n'
      '----------\r\n\r\n';
  test('AI introduction stays in one stop and excerpt in three', () {
    final excerpt = List.filled(
      180,
      'Questa è una frase del libro, con tutti gli accenti. ',
    ).join();
    final content = '$introduction$excerpt';
    final segments = splitBookPreview(content);
    expect(segments.length, 4);
    expect(segments.first, introduction);
    expect(segments.skip(1).join(), excerpt);
    expect(segments.join(), content);
    expect(segments.skip(1).every((part) => part.length < 4000), isTrue);
  });
  test('fallback, short previews, line endings and unbroken words', () {
    for (final text in [
      'Un testo breve.',
      List.filled(80, 'Una frase senza riassunto IA. ').join(),
      List.filled(100, 'Un paragrafo.\n\n').join(),
      List.filled(5000, '😀').join(),
      '${introduction}Un inizio breve.',
      introduction.replaceAll('\r\n', '\n'),
    ]) {
      final segments = splitBookPreview(text);
      expect(segments.join(), text);
      expect(segments.length, lessThanOrEqualTo(4));
      expect(segments.every((part) => part.trim().isNotEmpty), isTrue);
    }
    expect(splitBookPreview(''), isEmpty);
  });

  testWidgets(
    'long preview nodes survive forward and backward accessibility focus',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final text =
          '$introduction${List.filled(150, 'Un paragrafo di esempio abbastanza lungo.\n\n').join()}';
      final segments = splitBookPreview(text);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 240,
                child: BookPreviewContent(text: text),
              ),
            ),
          ),
        ),
      );
      final ids = [
        for (var i = 0; i < segments.length; i++)
          tester.getSemantics(find.byKey(ValueKey('preview_$i'))).id,
      ];
      for (final index in [0, 1, 2, 3, 2, 1, 0]) {
        tester.getSemantics(find.byKey(ValueKey('preview_$index'))).owner!.performAction(
          ids[index],
          SemanticsAction.didGainAccessibilityFocus,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byKey(ValueKey('preview_$index'))).id,
          ids[index],
        );
        expect(find.byKey(ValueKey('preview_$index')), findsOneWidget);
      }
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels, 0);
      semantics.dispose();
    },
  );
  testWidgets(
    'preview exposes separate reading nodes in order',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final excerpt = List.filled(30, 'Una frase di esempio. ').join();
      final content = '$introduction$excerpt';
      try {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: BookPreviewContent(text: content)),
          ),
        );
        await tester.pumpAndSettle();
        final first = tester.getSemantics(find.text(introduction));
        final second = tester.getSemantics(find.text(excerpt));
        expect(first.id, isNot(second.id));
        expect(first.label, introduction);
        expect(second.label, excerpt);
        expect(find.text(content), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}
