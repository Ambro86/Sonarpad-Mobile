import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TV program details uses the same fixed AppBar Back as other screens', () {
    final source = File('lib/screens/tv_channel_screen.dart').readAsStringSync();

    final start = source.indexOf('Future<void> showTvProgramDetailsDialog(');
    final end = source.indexOf('class TvChannelScreen', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);

    expect(method, contains('Dialog.fullscreen('));
    expect(method, contains('appBar: AppBar('));
    expect(method, contains('automaticallyImplyLeading: false'));
    expect(method, contains('leading: BackButton('));
    expect(
      method,
      contains("key: const ValueKey('tv_program_details_back_semantics')"),
    );
    expect(method, contains('onPressed: () => Navigator.pop(dialogContext)'));
    expect(method, isNot(contains("id: 'back'")));
  });

  test('TV program details keeps title and description in the shared model', () {
    final source = File('lib/screens/tv_channel_screen.dart').readAsStringSync();

    expect(source, contains("ValueKey('tv_program_details_title_semantics')"));
    expect(
      source,
      contains("ValueKey('tv_program_details_description_semantics')"),
    );
    expect(source, isNot(contains("initialFocusId: 'back'")));
    expect(source, contains("debugTag: 'tv_program_details'"));
    expect(source, contains("id: 'title'"));
    expect(source, contains("id: 'description'"));
  });
}
