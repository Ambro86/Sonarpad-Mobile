import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ItaliaOnline exposes Pagine Bianche and Gialle as selected choices', () {
    final source = File(
      'lib/screens/italiaonline_screen.dart',
    ).readAsStringSync();

    expect(source, contains("id: 'kind_pagine_bianche'"));
    expect(source, contains("title: 'Pagine Bianche'"));
    expect(
      source,
      contains('selected: _kind == DirectoryKind.pagineBianche'),
    );
    expect(source, contains("id: 'kind_pagine_gialle'"));
    expect(source, contains("title: 'Pagine Gialle'"));
    expect(
      source,
      contains('selected: _kind == DirectoryKind.pagineGialle'),
    );
    expect(source, isNot(contains("title: 'Elenco',\n                    kind: 'picker'")));
  });
}
