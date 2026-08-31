import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/document_text_extractor.dart';
import 'package:sonarpad_mobile_starter/utils/epub_index_remapper.dart';

void main() {
  test('remaps a split TOC target locally instead of matching a later duplicate', () {
    final originalChunks = <String>[
      'Prefazione molto lunga con testo unico che resta identico prima della modifica.',
      'GIORNATA I La prima giornata del Decameron e inaugurata da una lunga introduzione che continua nel paragrafo.',
      'Testo successivo molto lungo e univoco che resta identico dopo il punto modificato.',
      'Altro contenuto del libro completamente diverso e sufficientemente lungo per essere una buona ancora.',
      'SOMMARIO Introduzione DECAMERON Proemio GIORNATA I GIORNATA II GIORNATA III e molte altre voci del libro.',
    ];
    final editedChunks = <String>[
      originalChunks[0],
      'GIORNATA I La prima giornata del Decameron e inaugurata',
      'da una lunga introduzione che continua nel paragrafo.',
      originalChunks[2],
      originalChunks[3],
      originalChunks[4],
    ];

    final result = remapEpubIndexToEditedChunks(
      originalEntries: const <DocumentTableOfContentsEntry>[
        DocumentTableOfContentsEntry(
          title: 'GIORNATA PRIMA',
          chunkIndex: 1,
        ),
      ],
      originalChunks: originalChunks,
      editedChunks: editedChunks,
    );

    expect(result.entries, hasLength(1));
    expect(result.entries.single.chunkIndex, anyOf(1, 2));
    expect(result.entries.single.chunkIndex, isNot(5));
    expect(result.skippedCount, 0);
  });

  test('skips an unsafe target instead of searching globally by title', () {
    final originalChunks = <String>[
      'Ancora iniziale molto lunga e assolutamente unica per stabilizzare la prima parte del documento.',
      'Capitolo completamente riscritto e quindi non piu riconoscibile nel testo modificato.',
      ...List<String>.generate(
        60,
        (i) => 'Contenuto originale intermedio numero $i che verra completamente sostituito e non coincide.',
      ),
      'Ancora finale molto lunga e assolutamente unica per stabilizzare la parte finale del documento.',
    ];
    final editedChunks = <String>[
      originalChunks.first,
      ...List<String>.generate(
        60,
        (i) => 'Testo modificato differente numero $i senza corrispondenza con il contenuto originale precedente.',
      ),
      'SOMMARIO Capitolo completamente riscritto e altri titoli ripetuti lontano dalla posizione corretta.',
      originalChunks.last,
    ];

    final result = remapEpubIndexToEditedChunks(
      originalEntries: const <DocumentTableOfContentsEntry>[
        DocumentTableOfContentsEntry(title: 'Capitolo', chunkIndex: 1),
      ],
      originalChunks: originalChunks,
      editedChunks: editedChunks,
    );

    expect(result.entries, isEmpty);
    expect(result.skippedCount, 1);
  });
  test('skips a deleted TOC target between tight anchors', () {
    final originalChunks = <String>[
      'Ancora prima molto lunga e univoca che rimane identica nel documento modificato.',
      'Titolo capitolo e testo che vengono eliminati completamente dalla copia modificata.',
      'Ancora dopo molto lunga e univoca che rimane identica nel documento modificato.',
    ];
    final editedChunks = <String>[
      originalChunks[0],
      originalChunks[2],
    ];

    final result = remapEpubIndexToEditedChunks(
      originalEntries: const <DocumentTableOfContentsEntry>[
        DocumentTableOfContentsEntry(title: 'Capitolo eliminato', chunkIndex: 1),
      ],
      originalChunks: originalChunks,
      editedChunks: editedChunks,
    );

    expect(result.entries, isEmpty);
    expect(result.skippedCount, 1);
  });

}
