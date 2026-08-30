import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recording selection does not rebuild the whole dialog on toggle', () {
    final source = File('lib/widgets/recording_selection_dialog.dart')
        .readAsStringSync();

    expect(source, contains('ValueNotifier<Set<String>>'));
    expect(source, contains('ValueListenableBuilder<Set<String>>'));
    expect(source, isNot(contains('StatefulBuilder(')));
    expect(source, isNot(contains('setDialogState(')));
    expect(source, contains("id: 'recording_\$i'"));
  });
}
