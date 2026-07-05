import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/tts/google_tts_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sonarpad_google_tts_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'getApplicationSupportDirectory' => tempDir.path,
        'getTemporaryDirectory' => tempDir.path,
        _ => null,
      };
    });
  });

  tearDown(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('loads Google TTS catalog', () async {
    final bridge = GoogleTtsBridge.instance;
    final catalog = await bridge.loadCatalog();
    expect(catalog.packages, isNotEmpty);
    expect(catalog.speakers, isNotEmpty);

    final package = catalog.packages.firstWhere(
      (package) => package.id == 'it-it-x-multi-seanet',
    );
    expect(package.compressedSize, greaterThan(1024 * 1024));
    expect(package.speakers, isNotEmpty);
  });

  test('installs and verifies a package file', () async {
    final bytes = List<int>.generate(4096, (index) => index % 251);
    final digest = sha256.convert(bytes).toString();

    final package = GoogleTtsVoicePackage(
      id: 'it-it-test',
      fileId: 'it-it-test-r1',
      url: 'https://example.invalid/it-it-test.zvoice',
      sha256Checksum: digest,
      compressedSize: bytes.length,
      speakers: const [
        GoogleTtsSpeaker(
          id: 'it-it-test:ita',
          packageId: 'it-it-test',
          language: 'it-IT',
          speaker: 'ita',
          name: 'Google italiano test',
          gender: 'female',
          highQuality: true,
        ),
      ],
    );

    final bridge = GoogleTtsBridge.instance;
    final file = await bridge.installPackageBytes(package, bytes);
    expect(await file.exists(), isTrue);
    expect(await file.length(), bytes.length);
    expect(await bridge.isPackageInstalled(package), isTrue);
  });
}
