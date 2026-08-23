import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UIKit text fields never reuse their title as an implicit placeholder', () {
    final source =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(source, isNot(contains('row.placeholder ?? row.title')));
    expect(
      'cell.field.placeholder = row.placeholder'.allMatches(source).length,
      2,
      reason: 'Both initial cell configuration and row refresh must preserve a '
          'null placeholder instead of repeating the field title.',
    );
  });

  test('shared text-field rows do not explicitly repeat title as placeholder', () {
    final roots = [Directory('lib/screens'), Directory('lib/widgets')];
    final violations = <String>[];
    final rowPattern = RegExp(r'AccessibleListRow\(([\s\S]*?)\n\s*\)', multiLine: true);
    final fieldPattern = RegExp(r'''kind:\s*['"]textField['"]''');
    final titlePattern = RegExp(r'title:\s*([^,\n]+)');
    final placeholderPattern = RegExp(r'placeholder:\s*([^,\n]+)');

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final match in rowPattern.allMatches(source)) {
          final row = match.group(1)!;
          if (!fieldPattern.hasMatch(row)) continue;
          final title = titlePattern.firstMatch(row)?.group(1)?.trim();
          final placeholder =
              placeholderPattern.firstMatch(row)?.group(1)?.trim();
          if (title != null && placeholder != null && title == placeholder) {
            violations.add('${entity.path}: $title');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'A placeholder/hint may add information, but must not duplicate '
          'the accessible field title.',
    );
  });

  test('BD Ciechi search label has no spoken ellipsis', () {
    final source =
        File('lib/screens/bdciechi_dashboard_screen.dart').readAsStringSync();
    expect(source, contains('title: l10n.blindLibrarySearchCatalog'));
    expect(source, contains('labelText: l10n.blindLibrarySearchCatalog'));
    expect(source, isNot(contains('Cerca nel catalogo...')));
  });
}
