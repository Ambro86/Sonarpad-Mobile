import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/route_screen.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  testWidgets(
    'transit exposes now or selected hour and minute in shared accessible model',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RouteScreen(),
        ),
      );
      await tester.pumpAndSettle();
      UniversalAccessibleList model() => tester.widget<UniversalAccessibleList>(
        find.byType(UniversalAccessibleList).first,
      );
      List<AccessibleListRow> rows() =>
          model().sections.expand((s) => s.rows).toList();
      Future<void> pick(String id, String value) async {
        await model().onEvent!(
          AccessibleListEvent(type: 'picker', id: id, value: value),
        );
        await tester.pumpAndSettle();
      }

      expect(rows().any((r) => r.id == 'departure_mode'), isFalse);
      await pick('profile', 'transit');
      expect(rows().singleWhere((r) => r.id == 'departure_mode').value, 'now');
      expect(rows().any((r) => r.id == 'departure_hour'), isFalse);
      await pick('departure_mode', 'at');
      await pick('departure_hour', '18');
      await pick('departure_minute', '35');
      expect(rows().singleWhere((r) => r.id == 'departure_hour').value, '18');
      expect(rows().singleWhere((r) => r.id == 'departure_minute').value, '35');
      expect(
        rows().singleWhere((r) => r.id == 'departure_zone').value,
        'Europe/Rome',
      );
      await pick('departure_mode', 'now');
      expect(rows().any((r) => r.id == 'departure_hour'), isFalse);
      await pick('profile', 'walking');
      expect(rows().any((r) => r.id == 'departure_mode'), isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
