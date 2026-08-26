import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'radio pagination uses the proven shared adjustable slider without losing focus',
    () {
      final source =
          File('lib/screens/radio_search_results_screen.dart').readAsStringSync();
      final adapter =
          File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
      final native = File('ios/Runner/SonarpadNativeAccessibleView.swift')
          .readAsStringSync();

      final selectorStart = source.indexOf('Widget _buildPageSelector(');
      final buildStart = source.indexOf('@override\n  Widget build', selectorStart);
      final selectorBlock = source.substring(selectorStart, buildStart);

      expect(selectorBlock, contains("id: 'radio_page_selector'"));
      expect(selectorBlock, contains("kind: 'slider'"));
      expect(selectorBlock, contains('sliderValue: pageNumber.toDouble()'));
      expect(selectorBlock, contains('sliderMin: 1'));
      expect(selectorBlock, contains('sliderMax: totalPages.toDouble()'));
      expect(selectorBlock, contains('sliderStep: 1'));
      expect(selectorBlock, contains('sliderIncreasedValueLabel:'));
      expect(selectorBlock, contains('sliderDecreasedValueLabel:'));
      expect(selectorBlock, contains('showVerticalScrollIndicator: false'));
      expect(
        selectorBlock,
        contains("key: const ValueKey('radio_page_selector_shared')"),
      );
      expect(selectorBlock, isNot(contains('nativeSliderAccessibilityElement: true')));

      // Slider changes do not create a status overlay: the adjustable element
      // itself announces the next page and therefore remains the focused node.
      expect(
        selectorBlock,
        contains('_changePage(requestedPage, totalPages, announce: false);'),
      );

      // Keep the page selector outside the results list. The results may be
      // rebuilt for another page without replacing the focused slider.
      final columnStart = source.indexOf('return Column(', buildStart);
      final resultListStart = source.indexOf(
        'child: useSharedAccessibleViewModel',
        columnStart,
      );
      final topOfColumn = source.substring(columnStart, resultListStart);
      expect(
        topOfColumn,
        contains('_buildPageSelector(l10n, currentPage, totalPages)'),
      );

      // Previous/Next remain available as the second navigation method.
      expect(source, contains("ValueKey('radio_previous_page')"));
      expect(source, contains("ValueKey('radio_next_page')"));

      // Flutter uses the same single Semantics adjustable node as Settings.
      expect(adapter, contains('slider: true'));
      expect(adapter, contains('onIncrease: enabled'));
      expect(adapter, contains('onDecrease: enabled'));
      expect(adapter, contains('child: ExcludeSemantics('));

      // UIKit keeps the table cell as the adjustable element and changes its
      // value in place, with the existing focus-recovery protection.
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
