import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/route_result_screen.dart').readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  test('route details expose the open route action', () {
    expect(source, contains("id: 'open_route'"));
    expect(source, contains('title: l10n.routeOpenAction'));
    expect(source, contains('onPressed: _openRoute'));
  });

  test('iOS offers Apple Maps and installed Google Maps', () {
    expect(source, contains("canLaunchUrl(Uri.parse('comgooglemaps://'))"));
    expect(source, contains('CupertinoActionSheet'));
    expect(source, contains('l10n.routeAppleMapsAction'));
    expect(source, contains('l10n.routeGoogleMapsAction'));
    expect(plist, contains('<string>comgooglemaps</string>'));
  });

  test('external maps receive route endpoints and travel mode', () {
    expect(source, contains("'origin': _coordinate(widget.from)"));
    expect(source, contains("'destination': _coordinate(widget.to)"));
    expect(source, contains("'travelmode': _googleTravelMode()"));
    expect(source, contains("'mode': _appleTravelMode()"));
    expect(source, contains("RouteProfile.cycling => 'cycling'"));
    expect(source, contains("RouteProfile.cycling => 'bicycling'"));
  });
}
