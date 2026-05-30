// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarpad_mobile_starter/main.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Home screen shows localized actions',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'sonarpad_app_language': 'it',
      'sonarpad_home_grouping_enabled': true,
    });
    await tester.pumpWidget(const SonarpadApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Documenti', skipOffstage: false), findsOneWidget);
    expect(find.text('Radio', skipOffstage: false), findsOneWidget);
    expect(find.text('Notizie', skipOffstage: false), findsOneWidget);
    expect(find.text('Podcast', skipOffstage: false), findsOneWidget);
    expect(find.text('Impostazioni', skipOffstage: false), findsOneWidget);
  });
}
