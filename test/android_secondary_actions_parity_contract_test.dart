import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android merges every action row into the TalkBack focus node', () {
    final renderer = File(
      'lib/widgets/universal_accessible_view.dart',
    ).readAsStringSync();

    expect(
      renderer,
      contains('final shouldMergeCustomActions = row.actions.isNotEmpty &&'),
    );
    expect(
      renderer,
      contains('(isAndroidPlatform || row.mergeFlutterCustomActions)'),
    );
    expect(renderer, contains('return MergeSemantics(child: semantics);'));
    expect(
      renderer,
      contains('customSemanticsActions: {'),
      reason: 'The merged TalkBack node must keep the original row actions.',
    );
    expect(
      renderer,
      contains('onLongPress: (isAndroidPlatform || isIosPlatform)'),
      reason: 'Long press must open the same row.actions menu.',
    );
  });

  test('core shared lists define the same secondary actions used by UIKit', () {
    final documents = File('lib/screens/documents_screen.dart').readAsStringSync();
    final tv = File('lib/screens/tv_screen.dart').readAsStringSync();
    final sonarTube = File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final radio = File(
      'lib/screens/radio_search_results_screen.dart',
    ).readAsStringSync();
    final news = File('lib/screens/news_screen.dart').readAsStringSync();

    expect(documents, contains("AccessibleCustomAction(id: 'rename', label: l10n.rename)"));
    expect(documents, contains("id: 'remove',"));
    expect(documents, contains("AccessibleCustomAction(id: 'export', label: l10n.exportDocument)"));

    expect(tv, contains("id: 'favorite',"));
    expect(tv, contains('label: AppLocalizations.of(context).tvPlayLive'));

    expect(sonarTube, contains("AccessibleCustomAction(id: 'favorite', label: favoriteLabel)"));
    expect(sonarTube, contains("id: 'go_channel',"));
    expect(sonarTube, contains("id: 'view_comments',"));
    expect(sonarTube, contains("id: 'transcribe_video',"));

    expect(radio, contains("id: 'favorite',"));
    expect(radio, contains("id: 'play_record',"));

    expect(news, contains("id: 'share',"));
    expect(news, contains('label: l10n.shareArticle'));
  });

  test('screens with secondary actions stay on the shared accessibility model', () {
    final roots = [Directory('lib/screens'), Directory('lib/widgets')];
    final violations = <String>[];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('universal_accessible_view.dart') ||
            entity.path.endsWith('.bac') ||
            entity.path.contains('.before_')) {
          continue;
        }
        final source = entity.readAsStringSync();
        final exposesSecondaryActions =
            source.contains('AccessibleCustomAction(') ||
            source.contains('CustomSemanticsAction(');
        if (!exposesSecondaryActions) continue;

        final usesSharedModel = source.contains('useSharedAccessibleViewModel') ||
            source.contains('UniversalAccessibleList(') ||
            source.contains('UniversalAccessibleGrid(');
        if (!usesSharedModel) violations.add(entity.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Action-bearing screens must use the shared model so Android TalkBack '
          'and iOS UIKit consume the same action definitions.',
    );
  });

  test('iOS native renderer still owns UIKit custom actions unchanged', () {
    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(native, contains('cell.accessibilityCustomActions = row.actions.map'));
    expect(native, contains('UIAction(title: action.label)'));
  });
}
