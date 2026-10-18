import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/convert_media_screen.dart';
import 'package:sonarpad_mobile_starter/services/persistent_form_preferences.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  testWidgets('accessible converter restores changes after closing without converting',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    Future<void> open() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ConvertMediaScreen(),
      ));
      await tester.pumpAndSettle();
    }

    UniversalAccessibleList form() =>
        tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
    Future<void> change(String id, Object value, {String type = 'picker'}) async {
      await form().onEvent!(AccessibleListEvent(type: type, id: id, value: value));
      await tester.pumpAndSettle();
    }

    await open();
    await change('bitrate', '256', type: 'textChanged');
    await change('format', 'ogg');
    await change('ogg', '8');
    await change('format', 'flac');
    await change('flac', '12');
    await change('format', 'wav');
    await change('wav', 'float32');
    await change('destination', 'documents');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await open();
    final rows = form().sections.expand((section) => section.rows);
    expect(rows.singleWhere((row) => row.id == 'format').value, 'wav');
    expect(rows.singleWhere((row) => row.id == 'wav').value, 'float32');
    expect(rows.singleWhere((row) => row.id == 'destination').value, 'documents');
    final saved = await PersistentFormPreferences().loadConverter();
    expect(saved.bitrate, 256);
    expect(saved.oggQuality, 8);
    expect(saved.flacCompression, 12);

    await change('destination', 'ask');
    await change('format', 'mp3');
    await change('bitrate', '', type: 'textChanged');
    expect((await PersistentFormPreferences().loadConverter()).bitrate, 256);
    expect((await PersistentFormPreferences().loadConverter()).destination,
        MediaExportPreference.ask);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
