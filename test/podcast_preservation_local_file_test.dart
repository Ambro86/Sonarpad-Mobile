import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/media_preservation_service.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getTemporaryPath() async => root.path;
  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('import receives the persistent podcast file, after temporary download cleanup', () async {
    final directory = await Directory.systemTemp.createTemp('podcast-import-test-');
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory);
    SharedPreferences.setMockInitialValues({});
    final bytes = List<int>.generate(2048, (i) => i % 256);
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response.bytes(bytes, 200, headers: {'content-type': 'audio/mpeg'});
    });
    try {
      String? saved;
      final result = await MediaPreservationService(client: client).preserveMp3(
        url: 'https://example.org/podcast.mp3', title: 'Episodio',
        fileName: 'Episodio.mp3', onSaved: (path) => saved = path,
      );
      expect(result, MediaPreservationResult.savedInSonarpad);
      expect(saved, isNotNull);
      expect(await File(saved!).readAsBytes(), bytes);
      expect(requests, 1);
      expect(directory.listSync().whereType<File>().where((file) => file.path.contains('sonarpad_preserve_')), isEmpty);
    } finally {
      client.close();
      PathProviderPlatform.instance = previous;
      await directory.delete(recursive: true);
    }
  });
}
