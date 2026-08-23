import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/models/radio_station.dart';
import 'package:sonarpad_mobile_starter/services/radio_service.dart';

RadioStation station(String name) => RadioStation(
      name: name,
      streamUrl: 'https://stream.example/$name',
      languageCode: 'it',
      stationUuid: 'uuid-$name',
    );

void main() {
  group('Radio favorites order persistence', () {
    test('explicit alphabetical/manual order survives a later stale save', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RadioService();
      final alpha = station('Alpha');
      final beta = station('Beta');
      final zeta = station('Zeta');

      await service.saveFavorites([zeta, alpha, beta]);
      await service.saveFavorites([alpha, beta, zeta], updateOrder: true);

      // Simulates another Radio screen that still owns the old in-memory list.
      await service.saveFavorites([zeta, alpha, beta]);

      final loaded = await service.loadFavorites();
      expect(loaded.map((item) => item.name), ['Alpha', 'Beta', 'Zeta']);
    });

    test('new favorites append without destroying the chosen order', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RadioService();
      final alpha = station('Alpha');
      final beta = station('Beta');
      final zeta = station('Zeta');
      final gamma = station('Gamma');

      await service.saveFavorites([zeta, alpha, beta]);
      await service.saveFavorites([alpha, beta, zeta], updateOrder: true);
      await service.saveFavorites([zeta, alpha, beta, gamma]);

      final loaded = await service.loadFavorites();
      expect(
        loaded.map((item) => item.name),
        ['Alpha', 'Beta', 'Zeta', 'Gamma'],
      );
    });

    test('manual move writes the new order explicitly', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RadioService();
      final alpha = station('Alpha');
      final beta = station('Beta');
      final zeta = station('Zeta');

      await service.saveFavorites([alpha, beta, zeta]);
      await service.saveFavorites([zeta, alpha, beta], updateOrder: true);

      final loaded = await service.loadFavorites();
      expect(loaded.map((item) => item.name), ['Zeta', 'Alpha', 'Beta']);
    });
  });
}
