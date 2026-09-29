import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen code does not branch directly on the iOS native renderer', () {
    final roots = [Directory('lib/screens'), Directory('lib/widgets')];
    final violations = <String>[];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('universal_accessible_view.dart') ||
            entity.path.endsWith('native_ios_accessible_view.dart')) {
          continue;
        }
        final text = entity.readAsStringSync();
        const forbidden = [
          'useNativeIosAccessibleViews',
          'NativeIosAccessibleList(',
          'NativeIosAccessibleGrid(',
          'NativeIosListRow(',
          'NativeIosListSection(',
          "native_ios_accessible_view.dart",
        ];
        for (final token in forbidden) {
          if (text.contains(token)) {
            violations.add('${entity.path}: $token');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Platform selection must stay inside universal_accessible_view.dart. '
          'Screens describe shared accessible models instead.',
    );
  });

  test('legacy Flutter UI is controlled by one global shared-model switch', () {
    final adapter = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();
    expect(adapter, contains('SONARPAD_ACCESSIBLE_RENDERER'));
    expect(adapter, contains("defaultValue: 'native'"));
    expect(adapter, contains("accessibleRendererMode == 'flutter'"));
    expect(adapter, contains("accessibleRendererMode == 'native'"));
  });

  test('UIKit accessibility labels include row subtitles by default', () {
    final nativeRenderer = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(nativeRenderer, contains('var effectiveAccessibilityLabel: String'));
    expect(nativeRenderer, contains('return "\\(title), \\(subtitle)"'));
    expect(
      nativeRenderer,
      contains('cell.accessibilityLabel = row.effectiveAccessibilityLabel'),
    );
    expect(
      nativeRenderer,
      isNot(
        contains(
          'cell.accessibilityLabel = row.accessibilityLabel ?? row.title',
        ),
      ),
    );
  });

  test('every scrollable screen is covered by the shared accessible model', () {
    final roots = [Directory('lib/screens'), Directory('lib/widgets')];
    final uncovered = <String>[];
    const scrollTokens = [
      'ListView',
      'GridView',
      'CustomScrollView',
      'SingleChildScrollView',
    ];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('universal_accessible_view.dart') ||
            entity.path.endsWith('native_ios_accessible_view.dart')) {
          continue;
        }
        final text = entity.readAsStringSync();
        final isScrollable = scrollTokens.any((token) => text.contains(token));
        if (!isScrollable) continue;
        final covered =
            text.contains('useSharedAccessibleViewModel') ||
            text.contains('UniversalAccessibleList(') ||
            text.contains('UniversalAccessibleGrid(');
        if (!covered) uncovered.add(entity.path);
      }
    }

    expect(
      uncovered,
      isEmpty,
      reason:
          'Scrollable screens must participate in the shared model so '
          'Android and iOS do not drift apart.',
    );
  });

  test('every production AppBar uses Sonarpad Back/Home navigation', () {
    final roots = [Directory('lib/screens'), Directory('lib/widgets')];
    final violations = <String>[];
    final rawAppBarPattern = RegExp(r'(^|[^A-Za-z0-9_])AppBar\(');
    var wrappedAppBars = 0;

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('universal_accessible_view.dart')) continue;
        final text = entity.readAsStringSync();
        wrappedAppBars += 'SonarpadAppBar('.allMatches(text).length;
        final withoutWrapped = text.replaceAll('SonarpadAppBar(', '');
        if (rawAppBarPattern.hasMatch(withoutWrapped)) {
          violations.add(entity.path);
        }
      }
    }

    expect(wrappedAppBars, greaterThan(100));
    expect(
      violations,
      isEmpty,
      reason: 'Route AppBars must use SonarpadAppBar so every Back control '
          'gets the Home custom action and the sighted-only Home button.',
    );
  });

  test('Sonarpad Back exposes Home as a custom screen-reader action', () {
    final adapter = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();

    expect(adapter, contains("const String sonarpadGoHomeActionId = 'go_to_home'"));
    expect(adapter, contains('CustomSemanticsAction(label: l10n.goToHome)'));
    expect(adapter, contains('action: () => goToSonarpadHome(context)'));
    expect(adapter, contains('Navigator.of(context, rootNavigator: true)'));
    expect(adapter, contains('navigator.popUntil((route) => route.isFirst)'));
    expect(adapter, contains('if (hasBackNavigation) const SonarpadVisualHomeButton()'));
    expect(adapter, contains('class SonarpadVisualHomeButton'));
    expect(adapter, contains('return ExcludeSemantics('));
  });

  test('non-AppBar Back controls also expose Home without duplicate semantics', () {
    final letterPicker = File(
      'lib/widgets/letter_jump_option_picker_screen.dart',
    ).readAsStringSync();
    final raiPlaySound = File(
      'lib/screens/raiplaysound_screen.dart',
    ).readAsStringSync();
    final podcastPlayer = File(
      'lib/screens/podcast_episode_player_screen.dart',
    ).readAsStringSync();
    final radioPlayer = File(
      'lib/screens/radio_player_screen.dart',
    ).readAsStringSync();
    final aifa = File(
      'lib/screens/aifa_confezioni_screen.dart',
    ).readAsStringSync();
    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    for (final source in [letterPicker, raiPlaySound]) {
      expect(source, contains('id: sonarpadGoHomeActionId'));
      expect(source, contains("icon: 'home'"));
      expect(source, contains('SonarpadVisualHomeButton(compact: true)'));
    }
    for (final source in [podcastPlayer, radioPlayer, aifa]) {
      expect(source, contains('SonarpadBackSemantics('));
      expect(source, contains('SonarpadVisualHomeButton('));
    }
    expect(native, contains('case "home": return "house"'));
  });

  test('Go to Home is localized in every ARB locale', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList(growable: false);
    expect(arbFiles, isNotEmpty);
    for (final file in arbFiles) {
      final text = file.readAsStringSync();
      expect(text, contains('"goToHome"'), reason: file.path);
    }
  });

}
