import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/convert_media_screen.dart';
import 'package:sonarpad_mobile_starter/services/cloud_file_picker_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  testWidgets(
    'converter exposes original media and image names to accessibility',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      CloudFilePicker.debugUseNativePicker = true;
      final messenger = tester.binding.defaultBinaryMessenger;
      const commands = MethodChannel('sonarpad/cloud_file_picker');
      const events = MethodChannel('sonarpad/cloud_file_picker_progress');
      var name = 'Città e musica.wav';
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(
        commands,
        (_) async => [
          {
            'path':
                '/tmp/sonarpad_cloud_import/81EB17C7-440A-4C79-9D87-123456789ABC_$name',
            'name': name,
            'size': 100,
          },
        ],
      );
      addTearDown(() {
        CloudFilePicker.debugUseNativePicker = null;
        messenger.setMockMethodCallHandler(commands, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ConvertMediaScreen(),
        ),
      );
      await tester.pumpAndSettle();
      UniversalAccessibleList form() =>
          tester.widget(find.byType(UniversalAccessibleList));
      Future<void> event(String id, String type, [String? value]) async {
        await tester.runAsync(() async {
          await form().onEvent!(
            AccessibleListEvent(id: id, type: type, value: value),
          );
        });
        await tester.pumpAndSettle();
      }

      await event('input', 'activate');
      expect(
        form().sections
            .expand((s) => s.rows)
            .singleWhere((r) => r.id == 'input')
            .subtitle,
        name,
      );
      await event('format', 'picker', 'mp4');
      name = 'Copertina perché.png';
      await event('image', 'activate');
      expect(
        form().sections
            .expand((s) => s.rows)
            .singleWhere((r) => r.id == 'image')
            .subtitle,
        name,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
