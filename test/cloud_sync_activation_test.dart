import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/services/activation_link_service.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'invalid or absent remote activation preserves local settings',
    () async {
      final settings = AppSettingsService();
      await settings.setTvSecretCode('local-sentinel');
      final invalid = <Map<String, dynamic>>[
        {
          'id': 'activation.code',
          'data': {'value': 'invalid'},
        },
      ];
      expect(CloudSyncPreferences.project(invalid).isEmpty, isTrue);
      await CloudSyncPreferences.write(invalid);
      await CloudSyncPreferences.write([], baseline: invalid);
      expect(await settings.getTvSecretCode() == 'local-sentinel', isTrue);
      expect(
        (await CloudSyncPreferences.read()).any(
          (r) => r['id'] == 'activation.code',
        ),
        isFalse,
      );
    },
  );
  final fixture = Platform.environment['SONARPAD_ACTIVATION_TEST_FILE'];
  test(
    'desktop activation enables mobile, is exported, and notifies once',
    () async {
      final rows = (jsonDecode(File(fixture!).readAsStringSync()) as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      final activation = rows
          .where((r) => r['id'] == 'activation.code')
          .toList();
      expect(activation.length == 1, isTrue);
      final before = ActivationLinkService.changes.value;
      await CloudSyncPreferences.write(activation);
      final code = await AppSettingsService().getTvSecretCode();
      expect(code == activation.single['data']['value'], isTrue);
      expect(ActivationLinkService.changes.value == before + 1, isTrue);
      await CloudSyncPreferences.write(activation);
      expect(ActivationLinkService.changes.value == before + 1, isTrue);
      await CloudSyncPreferences.write([], baseline: activation);
      expect(await AppSettingsService().getTvSecretCode() == code, isTrue);
      final exported = await CloudSyncPreferences.read();
      expect(
        exported.any(
          (r) => r['id'] == 'activation.code' && r['data']['value'] == code,
        ),
        isTrue,
      );
    },
    skip: fixture == null ? 'Optional private local activation fixture' : false,
  );
}
