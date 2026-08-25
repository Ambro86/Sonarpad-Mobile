import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detected local-news city is pushed into the shared UIKit model immediately', () {
    final source = File('lib/screens/news_screen.dart').readAsStringSync();

    expect(source, contains("final detectedCity = loc?['city'] ?? '';"));
    expect(
      source,
      contains(
        'final city = savedCity.trim().isNotEmpty ? savedCity.trim() : detectedCity;',
      ),
    );
    expect(source, contains('setState(() {\n        _localCityController.text = city;'));
    expect(source, contains('value: _localCityController.text'));
  });

  test('automatic geolocation remains dynamic unless the user explicitly updates the city', () {
    final source = File('lib/screens/news_screen.dart').readAsStringSync();

    expect(source, contains('await _settings.setNewsLocalCity(city);'));
    expect(source, contains('Future<void> _reloadLocalCategory() async'));
    expect(source, isNot(contains('setNewsLocalCity(detectedCity)')));
  });
}
