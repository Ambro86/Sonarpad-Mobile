import 'package:flutter/foundation.dart';
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
