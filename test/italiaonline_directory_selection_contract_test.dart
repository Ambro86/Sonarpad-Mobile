import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Places, names and telephone search remain separate selected choices',
    () {
      final source = File(
        'lib/screens/italiaonline_screen.dart',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

      expect(source, contains("id: 'kind_pagine_bianche'"));
      expect(source, contains("title: 'Ricerca nominativi'"));
      expect(
        source,
        contains('selected: _kind == DirectoryKind.pagineBianche && !_reverse'),
      );
      expect(source, contains("id: 'kind_pagine_gialle'"));
      expect(source, contains("'Luoghi e attività'"));
      expect(
        source,
        contains('selected: _kind == DirectoryKind.pagineGialle && !_reverse'),
      );
      expect(source, contains("id: 'kind_phone'"));
      expect(source, contains("title: 'Cerca un numero di telefono'"));
      expect(source, contains('selected: _reverse'));
      expect(source, isNot(contains("kind: 'toggle'")));
      expect(
        source,
        isNot(contains("title: 'Elenco',\n                    kind: 'picker'")),
      );
    },
  );
}
