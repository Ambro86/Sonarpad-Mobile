import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/route_screen.dart').readAsStringSync();

  test('route shared pickers expose localized selected values to UIKit', () {
    expect(source, contains('valueLabel: countryValueLabel'));
    expect(source, contains('valueLabel: profileValueLabel'));
    expect(source, contains('valueLabel: preferenceValueLabel'));

    expect(
      source,
      contains('RouteProfile.driving => l10n.routeDriving'),
    );
    expect(
      source,
      contains('RouteProfile.walking => l10n.routeWalking'),
    );
    expect(
      source,
      contains('RoutePreference.fastest => l10n.routeFastest'),
    );
    expect(
      source,
      contains('RoutePreference.shortest => l10n.routeShortest'),
    );
  });

  test('Flutter route dropdowns keep localized labels', () {
    expect(
      source,
      contains('value: RouteProfile.driving, child: Text(l10n.routeDriving)'),
    );
    expect(
      source,
      contains('value: RouteProfile.walking, child: Text(l10n.routeWalking)'),
    );
    expect(source, contains('child: Text(l10n.routeFastest)'));
    expect(source, contains('child: Text(l10n.routeShortest)'));
  });
}
