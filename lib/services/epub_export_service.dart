import 'dart:convert';

import 'package:archive/archive.dart';

/// Genera un EPUB 3 semplice e valido a partire da testo Unicode.
///
/// Tutti i file XML/XHTML vengono scritti in UTF-8, quindi accenti,
/// cirillico, caratteri cechi/polacchi e altri caratteri Unicode vengono
/// preservati nell'esportazione.
class EpubExportService {
  List<int> buildEpub(String text, {String title = 'Documento'}) {
    final archive = Archive();
    final safeTitle = _stripInvalidXmlCharacters(title.trim()).isEmpty
        ? 'Documento'
        : _stripInvalidXmlCharacters(title.trim());
    final identifier = 'urn:uuid:sonarpad-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final modified = '${DateTime.now().toUtc().toIso8601String().split('.').first}Z';

    void addText(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    // Il file mimetype deve essere il primo elemento del pacchetto EPUB.
    addText('mimetype', 'application/epub+zip');
    addText('META-INF/container.xml', _containerXml);
    addText('OEBPS/content.opf', _contentOpf(safeTitle, identifier, modified));
    addText('OEBPS/nav.xhtml', _navXhtml(safeTitle));
    addText('OEBPS/chapter1.xhtml', _chapterXhtml(safeTitle, text));
    addText('OEBPS/styles.css', _stylesCss);

    final bytes = ZipEncoder().encode(archive, level: 0);
    if (bytes == null) {
      throw StateError('Impossibile generare il pacchetto EPUB.');
    }
    return bytes;
  }

  String _chapterXhtml(String title, String text) {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u0000', '');
    final paragraphs = normalized
        .split('\n')
        .map(_paragraphXhtml)
        .join('\n');
    final escapedTitle = _escapeXmlText(title);

    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="it" lang="it">
<head>
  <meta charset="UTF-8" />
  <title>$escapedTitle</title>
  <link rel="stylesheet" type="text/css" href="styles.css" />
</head>
<body>
  <main>
    <h1>$escapedTitle</h1>
    $paragraphs
  </main>
</body>
</html>
''';
  }

  String _paragraphXhtml(String paragraph) {
    if (paragraph.isEmpty) {
      return '<p class="empty">&#160;</p>';
    }
    final escaped = _escapeXmlText(paragraph).replaceAll('\t', '&#160;&#160;&#160;&#160;');
    return '<p>$escaped</p>';
  }

  String _contentOpf(String title, String identifier, String modified) {
    final escapedTitle = _escapeXmlText(title);
    final escapedIdentifier = _escapeXmlText(identifier);
    return '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">$escapedIdentifier</dc:identifier>
    <dc:title>$escapedTitle</dc:title>
    <dc:language>it</dc:language>
    <dc:creator>Sonarpad</dc:creator>
    <meta property="dcterms:modified">$modified</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="style" href="styles.css" media-type="text/css"/>
  </manifest>
  <spine>
    <itemref idref="chapter1"/>
  </spine>
</package>
''';
  }

  String _navXhtml(String title) {
    final escapedTitle = _escapeXmlText(title);
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="it" lang="it">
<head>
  <meta charset="UTF-8" />
  <title>$escapedTitle</title>
</head>
<body>
  <nav epub:type="toc" xmlns:epub="http://www.idpf.org/2007/ops">
    <h1>$escapedTitle</h1>
    <ol>
      <li><a href="chapter1.xhtml">$escapedTitle</a></li>
    </ol>
  </nav>
</body>
</html>
''';
  }

  String get _containerXml => '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

  String get _stylesCss => '''body {
  font-family: sans-serif;
  line-height: 1.45;
  margin: 1em;
}
p {
  margin: 0 0 0.8em;
}
p.empty {
  margin: 0 0 0.8em;
}
''';

  String _escapeXmlText(String value) => _stripInvalidXmlCharacters(value)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _stripInvalidXmlCharacters(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final valid = rune == 0x09 ||
          rune == 0x0A ||
          rune == 0x0D ||
          (rune >= 0x20 && rune <= 0xD7FF) ||
          (rune >= 0xE000 && rune <= 0xFFFD) ||
          (rune >= 0x10000 && rune <= 0x10FFFF);
      if (valid) buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }
}
