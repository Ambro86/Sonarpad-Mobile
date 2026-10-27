import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_screen.dart';
import 'package:sonarpad_mobile_starter/services/podcast_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

class _Paths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '${Directory.systemTemp.path}/sonarpad-podcast-test-no-directory';
}

void main() {
  testWidgets(
    'quick subscription keeps result identity and search, updates only actions',
    (tester) async {
      final oldPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        PathProviderPlatform.instance = oldPaths;
        debugDefaultTargetPlatformOverride = null;
      });
      SharedPreferences.setMockInitialValues({});
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        if (request.url.host == 'itunes.apple.com') {
          return http.Response(
            jsonEncode({
              'results': [
                for (var i = 1; i <= 2; i++)
                  {
                    'collectionName': 'Podcast $i',
                    'artistName': 'Autore',
                    'feedUrl': 'https://example.org/$i.xml',
                  },
              ],
            }),
            200,
          );
        }
        return http.Response('{"response":{"items":[]}}', 200);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastScreen(),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        UniversalAccessibleList list() => tester
            .widgetList<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList),
            )
            .last;
        await list().onEvent!(
          const AccessibleListEvent(
            type: 'textChanged',
            id: 'search_query',
            value: 'Podcast',
          ),
        );
        await list().onEvent!(
          const AccessibleListEvent(type: 'activate', id: 'search'),
        );
        await tester.pumpAndSettle();
        final before = list();
        final state = tester.state(find.byKey(before.key!));
        final ids = before.sections.single.rows.map((r) => r.id).toList();
        final networkRequests = requests;
        expect(ids, ['https://example.org/1.xml', 'https://example.org/2.xml']);
        expect(
          before.sections.single.rows.first.visualActions.single.id,
          'quick_subscribe',
        );
        final button = find.byTooltip('Iscrizione rapida').first;
        expect(
          find.ancestor(of: button, matching: find.byType(ExcludeSemantics)),
          findsWidgets,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(identical(tester.state(find.byKey(before.key!)), state), isTrue);
        expect(list().sections.single.rows.map((r) => r.id), ids);
        expect(list().sections.single.rows.first.actions.map((a) => a.label), [
          'Apri podcast',
        ]);
        expect(
          list().sections.single.rows.last.actions.map((a) => a.id),
          contains('quick_subscribe'),
        );
        expect(requests, networkRequests);
        await list().onEvent!(
          AccessibleListEvent(
            type: 'customAction',
            id: ids.last,
            action: 'quick_subscribe',
          ),
        );
        await tester.pumpAndSettle();
        expect(identical(tester.state(find.byKey(before.key!)), state), isTrue);
        expect((await PodcastService().loadSubscriptions()).length, 2);
        expect(requests, networkRequests);
        Navigator.of(tester.element(find.byKey(before.key!))).pop();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(
          list().sections
              .expand((s) => s.rows)
              .where((r) => r.id.startsWith('subscription_'))
              .length,
          2,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
