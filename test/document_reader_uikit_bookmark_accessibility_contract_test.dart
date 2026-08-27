import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UIKit document bookmarks stay visual without a VoiceOver suffix', () {
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
      contains("subtitle: isBookmarked ? '🔖' : null"),
    );
    expect(
      sharedDocumentList,
      contains('accessibilityLabel: _chunks[i]'),
    );
    expect(sharedDocumentList, isNot(contains('useNativeIosAccessibleViews')));

    final native = File(
      'ios/Runner/SonarpadNativeAccessibleView.swift',
    ).readAsStringSync();
    expect(
      native,
      contains(
        'if let accessibilityLabel = accessibilityLabel {\n'
        '      return accessibilityLabel\n'
        '    }',
      ),
    );
  });
}
