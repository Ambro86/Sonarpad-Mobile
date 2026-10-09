import 'package:shared_preferences/shared_preferences.dart';

class HomeItemIds {
  static const documents = 'documents';
  static const calendar = 'calendar';
  static const news = 'news';
  static const weather = 'weather';
  static const podcasts = 'podcasts';
  static const sonarTube = 'sonartube';
  static const sonarMusic = 'sonarmusic';
  static const createAiAudioDescription = 'create_ai_audiodescription';
  static const convertMedia = 'convert_media';
  static const mediaCutter = 'media_cutter';
  static const mediaJoin = 'media_join';
  static const cinema = 'cinema';
  static const radio = 'radio';
  static const tv = 'tv';
  static const raiPlaySound = 'raiplaysound';
  static const raiPlay = 'raiplay';
  static const la7Play = 'la7play';
  static const audioDescriptions = 'audiodescriptions';
  static const sonarpadAudioDescriptions = 'sonarpad_audiodescriptions';
  static const wikipedia = 'wikipedia';
  static const treccani = 'treccani';
  static const voiceDictionary = 'voice_dictionary';
  static const digitalLibrary = 'bdciechi';
  static const route = 'route';
  static const openingHours = 'orari_apertura';
  static const directory = 'italiaonline';
  static const pharmacy = 'aifa';
  static const settings = 'settings';
  static const info = 'info';

  static const List<String> defaultFlatOrder = [
    documents,
    calendar,
    news,
    weather,
    podcasts,
    sonarTube,
    sonarMusic,
    createAiAudioDescription,
    convertMedia,
    mediaCutter,
    mediaJoin,
    cinema,
    radio,
    tv,
    raiPlaySound,
    raiPlay,
    la7Play,
    audioDescriptions,
    sonarpadAudioDescriptions,
    wikipedia,
    treccani,
    voiceDictionary,
    digitalLibrary,
    route,
    openingHours,
    directory,
    pharmacy,
    settings,
    info,
  ];

  static const Set<String> alwaysVisible = {settings, info};

  static const List<String> readingOrder = [
    documents,
    wikipedia,
    treccani,
    news,
    digitalLibrary,
  ];

  static const List<String> mediaOrder = [
    radio,
    podcasts,
    sonarTube,
    sonarMusic,
    createAiAudioDescription,
    convertMedia,
    mediaCutter,
    mediaJoin,
    cinema,
    tv,
    raiPlay,
    la7Play,
    raiPlaySound,
    audioDescriptions,
    sonarpadAudioDescriptions,
  ];

  static const List<String> utilityOrder = [
    calendar,
    voiceDictionary,
    weather,
    route,
    openingHours,
    directory,
    pharmacy,
  ];
}

class HomeCustomizationService {
  static const _hiddenItemsKey = 'sonarpad_home_hidden_item_ids_v1';
  static const _itemOrderKey = 'sonarpad_home_item_order_v1';
  static const _categoryOrderKeyPrefix = 'sonarpad_home_category_order_v1_';

  Future<Set<String>> loadHiddenItemIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_hiddenItemsKey) ?? const <String>[]).toSet()
      ..removeAll(HomeItemIds.alwaysVisible);
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hiddenItemsKey);
    await prefs.remove(_itemOrderKey);
    final categoryKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(_categoryOrderKeyPrefix))
        .toList(growable: false);
    for (final key in categoryKeys) {
      await prefs.remove(key);
    }
  }

  Future<void> setItemVisible(String id, bool visible) async {
    if (HomeItemIds.alwaysVisible.contains(id)) return;
    final prefs = await SharedPreferences.getInstance();
    final hidden = (prefs.getStringList(_hiddenItemsKey) ?? const <String>[])
        .toSet();
    if (visible) {
      hidden.remove(id);
    } else {
      hidden.add(id);
    }
    hidden.removeAll(HomeItemIds.alwaysVisible);
    await prefs.setStringList(_hiddenItemsKey, hidden.toList(growable: false));
  }

  Future<List<String>> loadItemOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_itemOrderKey) ?? const <String>[];
    final result = <String>[];
    for (final id in stored) {
      if (HomeItemIds.defaultFlatOrder.contains(id) && !result.contains(id)) {
        result.add(id);
      }
    }
    _insertTreccaniAfterWikipediaIfMissing(result);
    _insertSonarMusicAfterTubeIfMissing(result);
    for (final id in HomeItemIds.defaultFlatOrder) {
      if (!result.contains(id)) result.add(id);
    }
    return result;
  }

  Future<void> saveItemOrder(List<String> order) async {
    final normalized = <String>[];
    for (final id in order) {
      if (HomeItemIds.defaultFlatOrder.contains(id) &&
          !normalized.contains(id)) {
        normalized.add(id);
      }
    }
    for (final id in HomeItemIds.defaultFlatOrder) {
      if (!normalized.contains(id)) normalized.add(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_itemOrderKey, normalized);
  }

  List<String> visibleOrderedIds({
    required List<String> fullOrder,
    required Set<String> availableIds,
    required Set<String> hiddenIds,
  }) {
    return fullOrder
        .where(
          (id) =>
              availableIds.contains(id) &&
              (!hiddenIds.contains(id) || HomeItemIds.alwaysVisible.contains(id)),
        )
        .toList(growable: false);
  }


  void _insertSonarMusicAfterTubeIfMissing(List<String> order) {
    if (order.contains(HomeItemIds.sonarMusic)) return;
    final tubeIndex = order.indexOf(HomeItemIds.sonarTube);
    if (tubeIndex >= 0) {
      order.insert(tubeIndex + 1, HomeItemIds.sonarMusic);
    }
  }

  void _insertTreccaniAfterWikipediaIfMissing(List<String> order) {
    if (order.contains(HomeItemIds.treccani)) return;
    final wikipediaIndex = order.indexOf(HomeItemIds.wikipedia);
    if (wikipediaIndex >= 0) {
      order.insert(wikipediaIndex + 1, HomeItemIds.treccani);
    }
  }

  Future<List<String>> loadCategoryOrder({
    required String categoryId,
    required List<String> defaultOrder,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getStringList('$_categoryOrderKeyPrefix$categoryId') ??
            const <String>[];
    final result = <String>[];
    for (final id in stored) {
      if (defaultOrder.contains(id) && !result.contains(id)) {
        result.add(id);
      }
    }
    if (defaultOrder.contains(HomeItemIds.treccani)) {
      _insertTreccaniAfterWikipediaIfMissing(result);
    }
    if (defaultOrder.contains(HomeItemIds.sonarMusic)) {
      _insertSonarMusicAfterTubeIfMissing(result);
    }
    for (final id in defaultOrder) {
      if (!result.contains(id)) result.add(id);
    }
    return result;
  }

  Future<void> saveCategoryOrder({
    required String categoryId,
    required List<String> order,
    required List<String> defaultOrder,
  }) async {
    final normalized = <String>[];
    for (final id in order) {
      if (defaultOrder.contains(id) && !normalized.contains(id)) {
        normalized.add(id);
      }
    }
    for (final id in defaultOrder) {
      if (!normalized.contains(id)) normalized.add(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_categoryOrderKeyPrefix$categoryId', normalized);
  }

  List<String> visibleCategoryIds({
    required List<String> categoryOrder,
    required Set<String> availableIds,
    required Set<String> hiddenIds,
  }) {
    return categoryOrder
        .where((id) => availableIds.contains(id) && !hiddenIds.contains(id))
        .toList(growable: false);
  }

  Future<List<String>> moveVisibleCategoryItem({
    required String categoryId,
    required List<String> defaultOrder,
    required String itemId,
    required int newVisibleIndex,
    required Set<String> availableIds,
    required Set<String> hiddenIds,
  }) async {
    final categoryOrder = await loadCategoryOrder(
      categoryId: categoryId,
      defaultOrder: defaultOrder,
    );
    final visible = visibleCategoryIds(
      categoryOrder: categoryOrder,
      availableIds: availableIds,
      hiddenIds: hiddenIds,
    );
    final currentIndex = visible.indexOf(itemId);
    if (currentIndex < 0) return categoryOrder;

    final reorderedVisible = List<String>.from(visible)..removeAt(currentIndex);
    final target = newVisibleIndex.clamp(0, reorderedVisible.length).toInt();
    reorderedVisible.insert(target, itemId);

    var visibleCursor = 0;
    final merged = <String>[];
    for (final id in categoryOrder) {
      final isVisible = availableIds.contains(id) && !hiddenIds.contains(id);
      if (isVisible) {
        merged.add(reorderedVisible[visibleCursor++]);
      } else {
        merged.add(id);
      }
    }
    await saveCategoryOrder(
      categoryId: categoryId,
      order: merged,
      defaultOrder: defaultOrder,
    );
    return merged;
  }

  Future<List<String>> moveVisibleItem({
    required String itemId,
    required int newVisibleIndex,
    required Set<String> availableIds,
    required Set<String> hiddenIds,
  }) async {
    final fullOrder = await loadItemOrder();
    final visible = visibleOrderedIds(
      fullOrder: fullOrder,
      availableIds: availableIds,
      hiddenIds: hiddenIds,
    );
    final currentIndex = visible.indexOf(itemId);
    if (currentIndex < 0) return fullOrder;

    final reorderedVisible = List<String>.from(visible)..removeAt(currentIndex);
    final target = newVisibleIndex.clamp(0, reorderedVisible.length).toInt();
    reorderedVisible.insert(target, itemId);

    var visibleCursor = 0;
    final merged = <String>[];
    for (final id in fullOrder) {
      final isVisible = availableIds.contains(id) &&
          (!hiddenIds.contains(id) || HomeItemIds.alwaysVisible.contains(id));
      if (isVisible) {
        merged.add(reorderedVisible[visibleCursor++]);
      } else {
        merged.add(id);
      }
    }
    await saveItemOrder(merged);
    return merged;
  }
}
