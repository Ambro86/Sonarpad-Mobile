import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TV program details puts Back inside the shared UIKit model', () {
    final source = File('lib/screens/tv_channel_screen.dart').readAsStringSync();

    final start = source.indexOf('Future<void> showTvProgramDetailsDialog(');
    final end = source.indexOf('class TvChannelScreen', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);

    expect(method, contains("id: 'back'"));
    expect(method, contains("title: l10n.back"));
    expect(method, contains("kind: 'button'"));
    expect(method, contains("initialFocusId: 'back'"));
    expect(method, contains("debugTag: 'tv_program_details'"));
    expect(method, contains('onActivate: () => Navigator.pop(dialogContext)'));
  });

  test('TV program details keeps Flutter Back semantics and heading', () {
    final source = File('lib/screens/tv_channel_screen.dart').readAsStringSync();

    expect(source, contains("ValueKey('tv_program_details_back_semantics')"));
    expect(source, contains("ValueKey('tv_program_details_title_semantics')"));
    expect(source, contains("ValueKey('tv_program_details_description_semantics')"));
    expect(source, contains('autofocus: true'));
  });
}
