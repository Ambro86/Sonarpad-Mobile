import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/dropbox_browser_screen.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';

import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  testWidgets(
    'Back from an imported file returns to its Dropbox folder',
    (tester) async {
      configureAccessibleRendererRuntime(useFlutterOnIos: true);
      addTearDown(
        () => configureAccessibleRendererRuntime(useFlutterOnIos: false),
      );
      final root = Directory.systemTemp.createTempSync('dropbox-back-');
      final paths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(root.path);
      addTearDown(() {
        PathProviderPlatform.instance = paths;
        root.deleteSync(recursive: true);
      });
      SharedPreferences.setMockInitialValues({'dropbox_access_token': 'test'});
      final navigator = GlobalKey<NavigatorState>();
      final library = DocumentLibraryService();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: Text('Local library')),
            ),
          );
          navigator.currentState!.push<void>(
            MaterialPageRoute(
              builder: (_) => DropboxBrowserScreen(
                documentService: library,
                onOpenDocument: (doc) async {
                  await navigator.currentState!.push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          Scaffold(body: Text('Reading ${doc.name}')),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Books'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 750));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await tester.tap(find.text('chapter.txt'));
            for (var i = 0; library.documents.isEmpty && i < 100; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
          });
          await tester.pumpAndSettle();
          await tester.tap(find.text('Yes'));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          expect(find.textContaining('Reading chapter'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Books'), findsWidgets);
          expect(find.text('chapter.txt'), findsOneWidget);
        },
        () => MockClient((request) async {
          if (request.url.path == '/2/files/download')
            return http.Response('hello', 200);
          final root = jsonDecode(request.body)['path'] == '';
          return http.Response(
            jsonEncode({
              'entries': [
                if (root)
                  {'.tag': 'folder', 'name': 'Books', 'path_display': '/Books'}
                else
                  {
                    '.tag': 'file',
                    'name': 'chapter.txt',
                    'path_display': '/Books/chapter.txt',
                  },
              ],
            }),
            200,
          );
        }),
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
