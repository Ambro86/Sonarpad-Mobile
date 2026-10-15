import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/utils/book_preview_segments.dart';
import 'package:sonarpad_mobile_starter/widgets/book_preview_content.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

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
    'preview exposes separate reading nodes in order',
    (tester) async {
      final semantics = tester.ensureSemantics();
      configureAccessibleRendererRuntime(useFlutterOnIos: true);
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
        final shared = find.byType(UniversalAccessibleList);
        if (shared.evaluate().isNotEmpty) {
          final rows = tester
              .widget<UniversalAccessibleList>(shared)
              .sections
              .single
              .rows;
          expect(rows.map((row) => row.title).toList(), [
            introduction,
            excerpt,
          ]);
        }
      } finally {
        configureAccessibleRendererRuntime(useFlutterOnIos: false);
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
