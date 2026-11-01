import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/news_screen.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';

Widget app({NewsLanguage? initialLanguage}) => MaterialApp(
  locale: const Locale('it'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: NewsScreen(initialLanguage: initialLanguage),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('selected news language survives closing and reopening', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final picker = find.byType(DropdownButtonFormField<NewsLanguage>);
    expect(
      tester.widget<DropdownButtonFormField<NewsLanguage>>(picker).initialValue,
      NewsLanguage.italian,
    );
    tester.widget<DropdownButtonFormField<NewsLanguage>>(picker).onChanged!(
      NewsLanguage.english,
    );
    await tester.pumpAndSettle();
    expect(await NewsService().loadSelectedLanguage(), NewsLanguage.english);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      tester.widget<DropdownButtonFormField<NewsLanguage>>(picker).initialValue,
      NewsLanguage.english,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'explicit language takes priority without overwriting preference',
    (tester) async {
      await NewsService().saveSelectedLanguage(NewsLanguage.english);
      await tester.pumpWidget(app(initialLanguage: NewsLanguage.french));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<NewsLanguage>>(
              find.byType(DropdownButtonFormField<NewsLanguage>),
            )
            .initialValue,
        NewsLanguage.french,
      );
      expect(await NewsService().loadSelectedLanguage(), NewsLanguage.english);
    },
  );

  testWidgets('unknown saved language falls back to interface language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'news_selected_language': 'invalid',
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<NewsLanguage>>(
            find.byType(DropdownButtonFormField<NewsLanguage>),
          )
          .initialValue,
      NewsLanguage.italian,
    );
  });
}
