import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';

void main() {
  group('TvService preferiti', () {
    test('riapre il canale corrente invece dello stream salvato', () async {
      SharedPreferences.setMockInitialValues({
        'sonarpad_tv_favorites': jsonEncode([
          {
            'name': 'Canale Test',
            'url': 'https://stream.example/vecchio.m3u8',
            'category': 'Nazionali',
            'tvg_id': 'canale.test.it',
          },
        ]),
      });
      final current = TvChannel(
        name: 'Canale Test aggiornato',
        url: 'https://stream.example/nuovo.m3u8',
        category: 'Nazionali',
        tvgId: 'canale.test.it',
      );

      final favorites = await TvService().loadFavorites(
        currentChannels: [current],
      );

      expect(favorites.single, same(current));
      expect(favorites.single.url, 'https://stream.example/nuovo.m3u8');

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('sonarpad_tv_favorites')!;
      expect(stored, isNot(contains('vecchio.m3u8')));
      expect((jsonDecode(stored) as List).single, isNot(contains('url')));
    });

    test('salva soltanto riferimenti stabili senza URL', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TvService();
      await service.saveFavorites([
        TvChannel(
          name: 'Rai Test',
          url: 'https://stream.example/live.m3u8',
          category: 'Nazionali',
          tvgId: 'rai.test.it',
          tvgName: 'Rai Test',
          streamResolver: 'rai',
          resolverChannelId: '123',
        ),
      ]);

      final prefs = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(prefs.getString('sonarpad_tv_favorites')!) as List;
      final reference = Map<String, dynamic>.from(stored.single as Map);

      expect(reference['name'], 'Rai Test');
      expect(reference['tvg_id'], 'rai.test.it');
      expect(reference.containsKey('url'), isFalse);
      expect(reference.containsKey('category'), isFalse);
    });
  });
}
