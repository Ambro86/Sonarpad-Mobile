import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/dropbox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sonarpad/dropbox_auth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('first folder listing retries a temporary server error', () async {
    SharedPreferences.setMockInitialValues({
      'dropbox_access_token': 'test-token',
    });
    final service = DropboxService();
    await service.init();
    var calls = 0;
    final entries = await http.runWithClient(
      () => service.listFolder(''),
      () => MockClient((request) async {
        expect(request.url.path, '/2/files/list_folder');
        if (++calls == 1) return http.Response('', 503);
        return http.Response('{"entries":[{"name":"Example"}]}', 200);
      }),
    );
    expect(calls, 2);
    expect(entries.single['name'], 'Example');
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group(platform.name, () {
      setUp(() => debugDefaultTargetPlatformOverride = platform);
      test(
        'Native SDK credentials persist and restore through existing service',
        () async {
          messenger.setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'authenticate');
            return {
              'access_token': 'test-access',
              'refresh_token': 'test-refresh',
            };
          });
          final service = DropboxService();
          expect(await service.authenticate(), isTrue);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('dropbox_refresh_token'), 'test-refresh');
          final restored = DropboxService();
          await restored.init();
          expect(restored.isAuthenticated, isTrue);
          await restored.logout();
          expect(prefs.containsKey('dropbox_access_token'), isFalse);
          expect(prefs.containsKey('dropbox_refresh_token'), isFalse);
        },
      );

      test(
        'cancel does not replace an existing account or start a second login',
        () async {
          SharedPreferences.setMockInitialValues({
            'dropbox_access_token': 'existing',
          });
          var calls = 0;
          messenger.setMockMethodCallHandler(channel, (_) async {
            calls++;
            return null;
          });
          final service = DropboxService();
          await service.init();
          expect(await service.authenticate(), isFalse);
          expect(calls, 1);
          expect(service.isAuthenticated, isTrue);
          expect(
            (await SharedPreferences.getInstance()).getString(
              'dropbox_access_token',
            ),
            'existing',
          );
        },
      );

      test(
        'temporary login failure retries once and stores the credential',
        () async {
          var calls = 0;
          messenger.setMockMethodCallHandler(channel, (_) async {
            if (++calls == 1) throw PlatformException(code: 'auth_unavailable');
            return {'access_token': 'after-retry'};
          });
          final service = DropboxService();
          expect(await service.authenticate(), isTrue);
          expect(service.isAuthenticated, isTrue);
          expect(calls, 2);
        },
      );

      test('new account cannot inherit the previous refresh token', () async {
        SharedPreferences.setMockInitialValues({
          'dropbox_refresh_token': 'old-account',
        });
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => {'access_token': 'new-account'},
        );
        expect(await DropboxService().authenticate(), isTrue);
        expect(
          (await SharedPreferences.getInstance()).containsKey(
            'dropbox_refresh_token',
          ),
          isFalse,
        );
      });

      test(
        'native failure and malformed credential do not persist a login',
        () async {
          for (final response in [
            null,
            {'access_token': ''},
          ]) {
            messenger.setMockMethodCallHandler(channel, (_) async {
              if (response == null) {
                throw PlatformException(code: 'auth_unavailable');
              }
              return response;
            });
            final service = DropboxService();
            expect(await service.authenticate(), isFalse);
            expect(service.isAuthenticated, isFalse);
            expect(
              (await SharedPreferences.getInstance()).containsKey(
                'dropbox_access_token',
              ),
              isFalse,
            );
          }
        },
      );
    });
  }
}
