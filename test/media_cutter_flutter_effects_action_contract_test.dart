import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Media Cutter keeps effect actions on the focused Flutter semantics node',
    () {
      final source = File(
        'lib/screens/media_cutter_screen.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final renderer = File(
        'lib/widgets/universal_accessible_view.dart',
      ).readAsStringSync();

      final guidedStart = source.indexOf("id: 'guided_summary'");
      final guidedEnd = source.indexOf("] else ...[", guidedStart);
      final guidedBlock = source.substring(guidedStart, guidedEnd);
      expect(
        guidedBlock,
        matches(RegExp(r"AccessibleCustomAction\(\s*id: 'effects'")),
      );
      expect(guidedBlock, contains('mergeFlutterCustomActions: true'));

      final partStart = source.indexOf("id: 'part_\${visibleParts");
      final partEnd =
          source.indexOf('mergeFlutterCustomActions: true', partStart) +
          'mergeFlutterCustomActions: true'.length;
      final partBlock = source.substring(partStart, partEnd);
      expect(
        partBlock,
        matches(RegExp(r"AccessibleCustomAction\(\s*id: 'effects'")),
      );
      expect(partBlock, contains('mergeFlutterCustomActions: true'));

      expect(
        renderer,
        contains('final shouldMergeCustomActions = row.actions.isNotEmpty'),
      );
      expect(
        renderer,
        contains('(isAndroidPlatform || row.mergeFlutterCustomActions)'),
      );
      expect(renderer, contains('if (shouldMergeCustomActions)'));
      expect(renderer, contains('return MergeSemantics(child: semantics);'));
    },
  );
}
