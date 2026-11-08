import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// The public platform interface is supplied by path_provider.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'package:sonarpad_mobile_starter/services/app_cache_service.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:sonarpad_mobile_starter/services/media_export_destination_service.dart';
import 'package:sonarpad_mobile_starter/utils/app_logger.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(root.path, 'support');
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(root.path, 'documents');
  @override
  Future<String?> getApplicationCachePath() async => p.join(root.path, 'cache');
  @override
  Future<String?> getTemporaryPath() async => p.join(root.path, 'temporary');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('sonarpad_ad_result_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
  });

  tearDown(() async {
    await AppLogger.readLogs();
    PathProviderPlatform.instance = originalPaths;
    await root.delete(recursive: true);
  });

  test(
    'completed audio and project survive cache deletion and startup cleanup',
    () async {
      final directory =
          await MediaExportDestinationService.createAudioDescriptionDirectory();
      final audio = await File(
        p.join(directory.path, 'film.mp3'),
      ).writeAsBytes([1, 2, 3]);
      final project = await File(
        p.join(directory.path, 'film.sonarpad-ad.json'),
      ).writeAsString('{"schema":"test"}');
      final cache = await AppCacheService.directory(
        AppCacheService.mediaExportsFolder,
      );
      await File(p.join(cache.path, 'temporary.mp3')).writeAsBytes([4, 5]);
      await Directory(p.join(root.path, 'cache')).delete(recursive: true);
      await AppCacheService.cleanupAtStartup();

      expect(await audio.readAsBytes(), [1, 2, 3]);
      expect(await project.readAsString(), '{"schema":"test"}');
      expect(p.isWithin(p.join(root.path, 'support'), directory.path), isTrue);
    },
  );

  test(
    'successful export keeps the saved audio after staging cleanup',
    () async {
      final directory =
          await MediaExportDestinationService.createAudioDescriptionDirectory();
      final audio = await File(
        p.join(directory.path, 'film.mp3'),
      ).writeAsBytes([1, 2, 3]);
      final library = DocumentLibraryService();
      final destination = MediaExportDestinationService(library: library);
      await destination.saveInSonarpadAudiodescriptions(audio.path);
      final document = library.documents.singleWhere((item) => !item.isFolder);
      final savedPath = await library.resolveFilePath(document);

      await AiAudioDescriptionService.cleanupResult(
        AiAudioDescriptionResult(
          mp3Path: audio.path,
          generatedDescriptions: 1,
          insertedDescriptions: 1,
          excludedDescriptions: 0,
        ),
      );

      expect(await directory.exists(), isFalse);
      expect(await File(savedPath).readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'failed destination write leaves the generated audio available',
    () async {
      final directory =
          await MediaExportDestinationService.createAudioDescriptionDirectory();
      final audio = await File(
        p.join(directory.path, 'film.mp3'),
      ).writeAsBytes([1, 2, 3]);
      // A file occupying the document directory makes the real copy fail.
      await File(p.join(root.path, 'documents')).writeAsString('blocked');
      await expectLater(
        MediaExportDestinationService().saveInSonarpadAudiodescriptions(
          audio.path,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await audio.readAsBytes(), [1, 2, 3]);
    },
  );
}
