import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_preferences.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_collections.dart';
import 'package:sonarpad_mobile_starter/services/media_cutter_seek_step_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'only explicit preferences are exported, converter destination stays local',
    () async {
      SharedPreferences.setMockInitialValues({
        'sonarpad_sonartube_search_type': 'videos',
        'sonarpad_weather_city': 'Roma',
        'sonarpad_converter_preferences': jsonEncode({
          'format': 'flac',
          'destination': 'share',
          'private_path': 'secret',
        }),
        'api_key': 'secret',
        'sonarpad_report_contact': 'private',
        'sonarpad_weather_recent_cities': 'history',
      });
      final rows = await CloudSyncPreferences.read();
      expect(rows.map((r) => r['id']).toSet(), {
        'sonartube.search_type',
        'weather.city',
        'converter.format',
      });
      expect(jsonEncode(rows), isNot(contains('secret')));
      await CloudSyncPreferences.write([
        {
          'id': 'converter.format',
          'data': {'value': 'mp3'},
        },
      ]);
      final prefs = await SharedPreferences.getInstance();
      final converter = jsonDecode(
        prefs.getString('sonarpad_converter_preferences')!,
      );
      expect(converter['destination'], 'share');
      expect(converter['private_path'], 'secret');
      expect(converter['format'], 'mp3');
    },
  );
  test(
    'remote mode uses the existing cutter persistence, unknown settings ignored',
    () async {
      await CloudSyncPreferences.write([
        {
          'id': 'cutter.mode',
          'data': {'value': 'advanced'},
        },
        {
          'id': 'cutter.seek_ms',
          'data': {'value': 30000},
        },
        {
          'id': 'future.preference',
          'data': {'value': true},
        },
      ]);
      expect(await MediaCutterSeekStepPreferences.loadMode(), 'advanced');
      expect(
        await MediaCutterSeekStepPreferences.load(),
        const Duration(seconds: 30),
      );
      await MediaCutterSeekStepPreferences.saveMode('guided');
      expect(
        (await CloudSyncPreferences.read()).firstWhere(
          (r) => r['id'] == 'cutter.mode',
        )['data'],
        {'value': 'guided'},
      );
    },
  );
  test('invalid known preferences fail before changing local values', () async {
    await MediaCutterSeekStepPreferences.saveMode('guided');
    await expectLater(
      CloudSyncPreferences.write([
        {
          'id': 'cutter.mode',
          'data': {'value': 'advanced'},
        },
        {
          'id': 'reader.tts_speed',
          'data': {'value': 900},
        },
      ]),
      throwsFormatException,
    );
    expect(await MediaCutterSeekStepPreferences.loadMode(), 'guided');
    expect(
      CloudSyncPreferences.specs['home.order']!.accepts(
        List.filled(64, 'x' * 80),
      ),
      false,
    );
  });
  test(
    'preference-only application preserves favorites and unrelated preferences',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('sonarpad_radio_favorites', []);
      await prefs.setString('api_key', 'local');
      await CloudSyncCollections().write({
        'preferences': [
          {
            'id': 'weather.city',
            'data': {'value': 'Milano'},
          },
        ],
      });
      expect(prefs.getStringList('sonarpad_radio_favorites'), isEmpty);
      expect(prefs.getString('api_key'), 'local');
      expect(prefs.getString('sonarpad_weather_city'), 'Milano');
    },
  );
}
