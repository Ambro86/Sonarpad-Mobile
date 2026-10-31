import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/radio_service.dart';

void main() {
  for (final cached in [false, true]) {
    test(
      'corrects directory labels preserving query codes (cached: $cached)',
      () async {
        final items = [
          {'name': 'engilsh', 'stationcount': 145},
          {'name': 'engilsh uk', 'stationcount': 17},
          {'name': 'english', 'stationcount': 14405},
          {'name': 'american english', 'stationcount': 550},
        ];
        SharedPreferences.setMockInitialValues({
          if (cached)
            'sonarpad_radio_directory_languages': jsonEncode({
              'savedAt': DateTime.now().toIso8601String(),
              'items': items,
            }),
        });
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          expect(request.url.path, '/json/languages');
          return http.Response(jsonEncode(items), 200);
        });
        addTearDown(client.close);
        final options = await RadioService(
          client: client,
        ).loadDirectoryLanguages();
        expect(calls, cached ? 0 : 1);
        final corrected = options.singleWhere(
          (o) => o.code == 'language:engilsh',
        );
        expect(corrected.label, 'english');
        expect(corrected.stationCount, 145);
        expect(
          options.singleWhere((o) => o.code == 'language:engilsh%20uk').label,
          'english uk',
        );
        expect(options.where((o) => o.code == 'en'), hasLength(1));
        expect(
          options
              .singleWhere((o) => o.code == 'language:american%20english')
              .label,
          'american english',
        );
      },
    );
  }
}
