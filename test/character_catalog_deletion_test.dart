import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
  @override
  Future<String?> getApplicationSupportPath() async => root.path;
  @override
  Future<String?> getTemporaryPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform original;
  late AiAudioDescriptionService service;
  const characters = <Map<String, Object?>>[
    {'id': '1', 'name': 'Alice', 'description': 'Red coat'},
  ];
  setUp(() async {
    root = await Directory.systemTemp.createTemp('catalog-deletion-');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    SharedPreferences.setMockInitialValues({});
    // Real folders, spaced to avoid the library's clock-based IDs colliding
    // on Windows hosts with a coarse wall clock.
    final library = DocumentLibraryService();
    final parent = await library.createFolder('Audiodescriptions');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await library.createFolder('Catalogs', parentId: parent.id);
    service = AiAudioDescriptionService();
  });
  tearDown(() async {
    PathProviderPlatform.instance = original;
    await root.delete(recursive: true);
  });

  test('deleting one library catalog hides its private copy and preserves others', () async {
    await service.saveCharacterCatalog('First', characters);
    await service.saveCharacterCatalog('Second', characters);
    expect(await service.listCharacterCatalogs(), ['First', 'Second']);
    final library = DocumentLibraryService();
    await library.load();
    await library.remove(library.documents.singleWhere((d) => d.name == 'First.json').id);
    expect(await service.listCharacterCatalogs(), ['Second']);
    expect(await service.loadCharacterCatalog('First'), isEmpty);
    expect(await service.loadCharacterCatalog('Second'), isNotEmpty);
    expect(await File('${root.path}/Audiodescriptions/Catalogs/First.json').exists(), isTrue);
  });

  test('deleting Catalogs or its parent also hides old copies on next launch', () async {
    for (final folder in ['Catalogs', 'Audiodescriptions']) {
      await service.saveCharacterCatalog('First', characters);
      final library = DocumentLibraryService();
      await library.load();
      await library.remove(library.documents.singleWhere((d) => d.isFolder && d.name == folder).id);
      final reopened = AiAudioDescriptionService();
      expect(await reopened.listCharacterCatalogs(), isEmpty);
      expect(await reopened.loadCharacterCatalog('First'), isEmpty);
    }
  });

  test('recreating a deleted catalog does not resurrect its old characters', () async {
    await service.saveCharacterCatalog('First', characters);
    final library = DocumentLibraryService();
    await library.load();
    await library.remove(library.documents.singleWhere((d) => d.name == 'First.json').id);
    await service.saveCharacterCatalog('First', [
      {'id': '2', 'name': 'Bob', 'description': 'Blue coat'},
    ]);
    expect(await service.listCharacterCatalogs(), ['First']);
    expect((await service.loadCharacterCatalog('First')).map((c) => c['name']), ['Bob']);
  });
}
