import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'radio pagination stays adjustable while remote source totals remain unknown',
    () {
      final source =
          File('lib/screens/radio_search_results_screen.dart').readAsStringSync();
      final service = File('lib/services/radio_service.dart').readAsStringSync();
      final adapter =
          File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
      final native = File('ios/Runner/SonarpadNativeAccessibleView.swift')
          .readAsStringSync();

      final selectorStart = source.indexOf('Widget _buildPageSelector(');
      final buildStart = source.indexOf('@override\n  Widget build', selectorStart);
      final selectorBlock = source.substring(selectorStart, buildStart);

      expect(selectorBlock, contains("id: 'radio_page_selector'"));
      expect(selectorBlock, contains("kind: 'slider'"));
      expect(selectorBlock, contains("accessibilityLabel: ''"));
      expect(selectorBlock, contains('value: pageLabel'));
      expect(selectorBlock, contains('valueLabel: pageLabel'));
      expect(selectorBlock, contains('sliderValue: pageNumber.toDouble()'));
      expect(selectorBlock, contains('sliderMin: 1'));
      expect(selectorBlock, contains('page.hasNext ? pageNumber + 1 : pageNumber'));
      expect(selectorBlock, contains('sliderStep: 1'));
      expect(selectorBlock, contains('sliderIncreasedValueLabel:'));
      expect(selectorBlock, contains('sliderDecreasedValueLabel:'));
      expect(selectorBlock, contains('showVerticalScrollIndicator: false'));
      expect(
        selectorBlock,
        contains("key: const ValueKey('radio_page_selector_shared')"),
      );
      expect(selectorBlock, contains('radioPageCurrent'));
      expect(selectorBlock, isNot(contains('radioPageOf(')));
      expect(selectorBlock, isNot(contains('totalPages')));

      // The page control loads only the requested neighboring page. The
      // service keeps already displayed pages stable and fetches more remote
      // source pages lazily when required.
      expect(selectorBlock, contains('unawaited(_loadPage(requestedPage'));
      expect(service, contains('class RadioSearchSession'));
      expect(service, contains('targetForLookahead'));
      expect(service, contains('_loadNextBatch()'));
      expect(service, contains('New batches are appended so pages already shown never'));

      expect(source, contains("ValueKey('radio_previous_page')"));
      expect(source, contains("ValueKey('radio_next_page')"));
      expect(source, contains('page.hasPrevious'));
      expect(source, contains('page.hasNext'));
      expect(
        source,
        contains("key: const ValueKey('shared-radio-results')"),
      );
      expect(
        source,
        isNot(contains(r"shared-radio-results-$currentPage")),
      );
      expect(
        source,
        contains("AccessibleListController(debugName: 'radio-results')"),
      );
      expect(source, contains("debugTag: 'radio-results'"));
      expect(source, contains('_resultsAccessibleListController.scrollTo('));
      expect(source, contains('animated: false'));

      expect(adapter, contains('slider: true'));
      expect(adapter, contains('onIncrease: enabled'));
      expect(adapter, contains('onDecrease: enabled'));
      expect(adapter, contains('child: ExcludeSemantics('));

      expect(native, contains('cell.isAccessibilityElement = !exposeNativeSlider'));
      expect(native, contains('cell.accessibilityValue = spokenValue'));
      final adjustStart = native.indexOf(
        'private func adjustSlider(at indexPath: IndexPath',
      );
      final adjustEnd = native.indexOf(
        'private func formatSliderValue',
        adjustStart,
      );
      final adjustBlock = native.substring(adjustStart, adjustEnd);
      expect(adjustBlock, isNot(contains('reloadRows')));
      expect(adjustBlock, contains('recoverAdjustedSliderFocusIfNeeded'));
    },
  );
}
