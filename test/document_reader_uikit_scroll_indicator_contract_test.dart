import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('document reader hides only the UIKit vertical scroll indicator', () {
    final reader =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();
    final sharedListStart =
        reader.indexOf('Widget _buildSharedAccessibleDocumentText(');
    final flutterChunksStart = reader.indexOf(
      'List<Widget> _buildChunkWidgets(',
      sharedListStart,
    );

    expect(sharedListStart, greaterThanOrEqualTo(0));
    expect(flutterChunksStart, greaterThan(sharedListStart));
    final sharedDocumentList =
        reader.substring(sharedListStart, flutterChunksStart);

    expect(
      sharedDocumentList,
      contains('showVerticalScrollIndicator: false'),
    );
    expect(
      sharedDocumentList,
      contains("debugTag: 'document'"),
    );

    final adapter =
        File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();

    expect(
      adapter,
      contains(
        "'showVerticalScrollIndicator': widget.showVerticalScrollIndicator",
      ),
    );
    expect(
      native,
      contains(
        'tableView.showsVerticalScrollIndicator = '
        'map["showVerticalScrollIndicator"] as? Bool ?? true',
      ),
    );
  });
}
