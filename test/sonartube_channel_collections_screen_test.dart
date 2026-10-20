import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/sonartube_screen.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  for (final category in ['courses', 'podcasts']) {
    testWidgets('channel $category opens a collection and returns to channel', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final requests = <String>[];
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        enableDirectNavigation: false,
        client: MockClient((request) async {
          final kind = request.url.queryParameters['kind'] ?? '';
          requests.add(kind);
          return http.Response(jsonEncode({
            'ok': true,
            'page': 1,
            'items': kind == 'channel_$category' ? [{
              'kind': 'playlist', 'id': 'PLcollection001', 'title': 'Collection example',
              'url': 'https://www.youtube.com/playlist?list=PLcollection001',
            }] : [],
          }), 200);
        }),
      );
        await tester.pumpWidget(MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SonarTubeScreen(
          collection: const SonarTubeItem(kind: SonarTubeItemKind.channel,
            id: 'UCabcdefghijklmnopqrstuv', title: 'Channel example',
            url: 'https://www.youtube.com/channel/UCabcdefghijklmnopqrstuv'),
          service: service,
        ),
      ));
      await tester.pumpAndSettle();
      final button = find.byKey(ValueKey('sonartube_channel_$category'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(requests, contains('channel_$category'));
      expect(find.text('Collection example'), findsWidgets);
      await tester.tap(find.text('Collection example').first);
      await tester.pumpAndSettle();
      expect(requests.last, 'playlist');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Collection example'), findsWidgets);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Channel example'), findsWidgets);
    });
  }
}
