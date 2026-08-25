import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disposable app data is routed through application cache', () {
    final cacheService =
        File('lib/services/app_cache_service.dart').readAsStringSync();
    expect(cacheService, contains('getApplicationCacheDirectory()'));
    expect(cacheService, contains("mediaExportsFolder = 'media_exports'"));
    expect(cacheService, contains("aifaFolder = 'aifa_cache'"));
    expect(
      cacheService,
      contains("parafarmaciFolder = 'parafarmaci_cache'"),
    );
    expect(cacheService, contains("tvFolder = 'tv_cache'"));
    expect(cacheService, contains("epubIndexFolder = 'epub_index_cache'"));
    expect(
      cacheService,
      contains("audiobookExportsFolder = 'sonarpad_audiobook_exports'"),
    );
  });

  test(
    'startup removes legacy backed-up cache locations and stale exports',
    () {
      final cacheService =
          File('lib/services/app_cache_service.dart').readAsStringSync();
      final main = File('lib/main.dart').readAsStringSync();

      expect(main, contains('await AppCacheService.cleanupAtStartup()'));
      expect(cacheService, contains('_cleanupLegacyDocumentsArtifacts'));
      expect(cacheService, contains('_cleanupLegacySupportCaches'));
      expect(cacheService, contains('_deleteDirectoryEntriesOlderThan'));
      expect(cacheService, contains('Debug_Farmaco_'));
    },
  );

  test('legacy cache folders are never recovered as user documents', () {
    final library =
        File('lib/services/document_library_service.dart').readAsStringSync();
    expect(library, contains("lower == 'aifa_cache'"));
    expect(library, contains("lower == 'parafarmaci_cache'"));
    expect(library, contains('_isLegacyTechnicalDirectory(doc)'));
  });

  test('AIFA and parafarmaco generated files no longer use Documents', () {
    final aifa = File('lib/services/aifa_service.dart').readAsStringSync();
    final para =
        File('lib/services/parafarmaco_service.dart').readAsStringSync();

    expect(aifa, contains('AppCacheService.aifaFolder'));
    expect(para, contains('AppCacheService.parafarmaciFolder'));
    expect(aifa, isNot(contains('getApplicationDocumentsDirectory')));
    expect(para, isNot(contains('getApplicationDocumentsDirectory')));
  });

  test(
    'media staging and resumable audiobook jobs avoid Application Support',
    () {
      final cutter =
          File('lib/screens/media_cutter_screen.dart').readAsStringSync();
      final convert =
          File('lib/screens/convert_media_screen.dart').readAsStringSync();
      final audiobook =
          File('lib/services/audiobook_export_service.dart').readAsStringSync();

      expect(cutter, contains('AppCacheService.mediaExportsFolder'));
      expect(convert, contains('AppCacheService.mediaExportsFolder'));
      expect(audiobook, contains('AppCacheService.audiobookExportsFolder'));
      expect(convert, isNot(contains('getApplicationSupportDirectory')));
      expect(audiobook, isNot(contains('getApplicationSupportDirectory')));
    },
  );

  test('debug recognition photos are temporary and deleted after sharing', () {
    final source =
        File('lib/screens/drug_recognition_screen.dart').readAsStringSync();
    expect(source, contains('getTemporaryDirectory()'));
    expect(source, contains('await debugFile.delete()'));
    expect(
      source,
      isNot(
        contains(
          'final dir = await getApplicationDocumentsDirectory();\n'
          '      final targetPath',
        ),
      ),
    );
  });
}
