import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home customization keeps settings and info always visible but reorderable', () {
    final service = File('lib/services/home_customization_service.dart').readAsStringSync();
    final screen = File('lib/screens/home_customization_screen.dart').readAsStringSync();

    expect(service, contains('static const Set<String> alwaysVisible = {settings, info};'));
    expect(screen, contains('!HomeItemIds.alwaysVisible.contains(id)'));
    expect(screen, contains('visibleOrderedIds('));
    expect(screen, contains("id: 'move_up'"));
    expect(screen, contains("id: 'move_down'"));
    expect(screen, contains("id: 'move_position'"));
    expect(screen, contains('positionLabel('));
  });

  test('home customization filters protected and Italy-only entries consistently', () {
    final catalog = File('lib/utils/home_item_catalog.dart').readAsStringSync();
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final customization = File('lib/screens/home_customization_screen.dart').readAsStringSync();

    expect(catalog, contains('if (isItalian)'));
    expect(catalog, contains('if (isTvCodeValid) ids.add(HomeItemIds.tv);'));
    expect(catalog, contains('if (isRaiPlayValid)'));
    expect(catalog, contains('if (isRaiPlaySoundCodeValid)'));
    expect(home, contains('availableHomeItemIds('));
    expect(customization, contains('availableHomeItemIds('));
  });

  test('settings exposes one home customization button instead of direct grouping toggle', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    expect(settings, contains("id: 'home_customization'"));
    expect(settings, contains('settingsHomeCustomization'));
    expect(settings, isNot(contains("id: 'home_grouping'")));
  });

  test('flat and grouped home keep independent saved orders', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final service = File('lib/services/home_customization_service.dart').readAsStringSync();
    expect(home, contains('loadHiddenItemIds()'));
    expect(home, contains('loadItemOrder()'));
    expect(home, contains("categoryId: 'reading'"));
    expect(home, contains("categoryId: 'media'"));
    expect(home, contains("categoryId: 'utilities'"));
    expect(home, contains('buttonsFor(_readingOrder)'));
    expect(home, contains('buttonsFor(_mediaOrder)'));
    expect(home, contains('buttonsFor(_utilityOrder)'));
    expect(service, contains('_categoryOrderKeyPrefix'));
    expect(service, contains('moveVisibleCategoryItem('));
  });

  test('grouped reorder stays inside each category and flat reorder remains global', () {
    final screen = File('lib/screens/home_customization_screen.dart').readAsStringSync();
    expect(screen, contains('groupingEnabled: _groupingEnabled'));
    expect(screen, contains('header: l10n.categoryReading'));
    expect(screen, contains('header: l10n.categoryMedia'));
    expect(screen, contains('header: l10n.categoryUtilities'));
    expect(screen, contains('_moveCategory('));
    expect(screen, contains('_moveFlat('));
    expect(screen, contains('moveVisibleCategoryItem('));
    expect(screen, contains('moveVisibleItem('));
    expect(screen, contains("id: 'reorder'"));
  });

  test('home customization can restore all defaults', () {
    final service = File('lib/services/home_customization_service.dart').readAsStringSync();
    final screen = File('lib/screens/home_customization_screen.dart').readAsStringSync();

    expect(service, contains('Future<void> resetToDefaults()'));
    expect(service, contains('await prefs.remove(_hiddenItemsKey);'));
    expect(service, contains('await prefs.remove(_itemOrderKey);'));
    expect(service, contains('key.startsWith(_categoryOrderKeyPrefix)'));
    expect(screen, contains("id: 'reset_defaults'"));
    expect(screen, contains('await _customization.resetToDefaults();'));
    expect(screen, contains('await _settings.setHomeGroupingEnabled(true);'));
    expect(screen, contains('homeResetDefaultsConfirmTitle'));
    expect(screen, contains('homeResetDefaultsConfirmMessage'));
  });

  test('all ARB locales contain home customization strings', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList();
    const keys = <String>{
      'settingsHomeCustomization',
      'settingsHomeCustomizationHint',
      'homeCategories',
      'homeCategoriesHint',
      'homeVisibleItems',
      'homeReorderItems',
      'homeResetDefaults',
      'homeResetDefaultsConfirmTitle',
      'homeResetDefaultsConfirmMessage',
      'homeResetDefaultsDone',
      'homeReorderTitle',
      'homeMoveItem',
      'homeDigitalLibrary',
      'homeTv',
      'homeRaiPlay',
      'homeLa7Play',
      'homeRaiPlaySound',
      'homeOpeningHours',
      'homeDirectory',
    };
    for (final file in arbFiles) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in keys) {
        expect(json.containsKey(key), isTrue, reason: '${file.path} missing $key');
      }
    }
  });

  test('0.5.0 changelog mentions home customization and reorder', () {
    final changelog = jsonDecode(File('assets/changelog.json').readAsStringSync()) as List<dynamic>;
    final latest = changelog.first as Map<String, dynamic>;
    expect(latest['version'], '0.5.0');
    expect(latest['date'], '2026-09-27');
    final italian = (latest['it'] as List<dynamic>).join('\n');
    expect(italian, contains('personalizzazione della schermata principale'));
    expect(italian, contains('Sposta alla posizione'));
    expect(italian, contains('all’interno di Lettura, Media e Utilità'));
    expect(italian, contains('Ripristina valori predefiniti'));
  });
}
