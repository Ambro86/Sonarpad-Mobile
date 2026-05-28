import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:epubx/epubx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart' as xml_pkg;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Risultato dell'estrazione testo da un documento.
class ExtractionResult {
  /// Testo estratto. Vuoto se l'estrazione non è riuscita.
  final String text;

  /// Messaggio di errore/info da mostrare all'utente. Null se ok.
  final String? error;

  const ExtractionResult({required this.text, this.error});
}

/// Servizio che estrae il testo da documenti di vari formati.
///
/// Formati con estrazione completa:
/// - TXT, MD, RTF → lettura diretta del file
/// - HTML, HTM    → strip tag HTML
/// - PDF          → [syncfusion_flutter_pdf] PdfTextExtractor
/// - DOCX / DOC   → unzip (archive) + parsing XML word/document.xml
/// - EPUB         → [epubx] EpubReader + strip HTML dei capitoli
class DocumentTextExtractor {
  Future<String> _readTextFileSafe(String path) async {
    final bytes = await File(path).readAsBytes();
    return decodeDocumentTextBytes(bytes);
  }

  static String decodeDocumentTextBytes(List<int> bytes) {
    if (_startsWith(bytes, const [0xEF, 0xBB, 0xBF])) {
      return _repairUtf8Mojibake(utf8.decode(bytes.sublist(3)));
    }
    if (_startsWith(bytes, const [0xFF, 0xFE])) {
      return _decodeUtf16(bytes.sublist(2), Endian.little);
    }
    if (_startsWith(bytes, const [0xFE, 0xFF])) {
      return _decodeUtf16(bytes.sublist(2), Endian.big);
    }

    try {
      return _repairUtf8Mojibake(utf8.decode(bytes));
    } on FormatException {
      dev.log('Fallback ANSI best-effort per documento testuale');
      return _chooseAnsiDecoding(bytes);
    }
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static String _decodeUtf16(List<int> bytes, Endian endian) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final unit = endian == Endian.little
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1];
      units.add(unit);
    }
    return String.fromCharCodes(units);
  }

  static String _chooseAnsiDecoding(List<int> bytes) {
    final cp1250Text = _decodeSingleByte(bytes, _windows1250);
    final cp1252Text = _decodeSingleByte(bytes, _windows1252);
    final cp1250Score = _centralEuropeanCharScore(cp1250Text);
    final cp1252Score = _westernEuropeanCharScore(cp1252Text);
    final cp1252CeScore = _centralEuropeanCharScore(cp1252Text);

    if (cp1250Score >= 2 && cp1250Score > cp1252CeScore) {
      return cp1250Text;
    }
    if (cp1252Score > 0 && cp1250Score == 0) {
      return cp1252Text;
    }
    if (_replacementLikeScore(cp1252Text) > _replacementLikeScore(cp1250Text)) {
      return cp1250Text;
    }
    return cp1252Text;
  }

  static String _decodeSingleByte(List<int> bytes, List<int?> table) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      if (byte < 0x80) {
        buffer.writeCharCode(byte);
      } else {
        buffer.writeCharCode(table[byte - 0x80] ?? 0xFFFD);
      }
    }
    return buffer.toString();
  }

  static int _centralEuropeanCharScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (_centralEuropeanChars.contains(codeUnit)) score++;
    }
    return score;
  }

  static int _westernEuropeanCharScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (_westernEuropeanChars.contains(codeUnit)) score++;
    }
    return score;
  }

  static int _replacementLikeScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (codeUnit == 0xFFFD ||
          codeUnit < 0x20 &&
              codeUnit != 0x0A &&
              codeUnit != 0x0D &&
              codeUnit != 0x09) {
        score++;
      }
    }
    return score;
  }

  static String _repairUtf8Mojibake(String text) {
    final originalScore = _utf8MojibakeScore(text);
    if (originalScore == 0) return text;

    final bytes = <int>[];
    var encodable = true;
    for (final codeUnit in text.codeUnits) {
      final encoded = _windows1252Encode(codeUnit);
      if (encoded == null) {
        encodable = false;
        break;
      }
      bytes.add(encoded);
    }
    if (encodable) {
      try {
        final repaired = utf8.decode(bytes);
        if (_utf8MojibakeScore(repaired) < originalScore) {
          return repaired;
        }
      } on FormatException {
        // Keep fallback replacements below.
      }
    }

    return text
        .replaceAll('â€™', '’')
        .replaceAll('â€˜', '‘')
        .replaceAll('â€œ', '“')
        .replaceAll('â€', '”')
        .replaceAll('â€“', '–')
        .replaceAll('â€”', '—')
        .replaceAll('â€¦', '…')
        .replaceAll('Â ', ' ')
        .replaceAll('Ã ', 'à')
        .replaceAll('Ã¨', 'è')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã¬', 'ì')
        .replaceAll('Ã²', 'ò')
        .replaceAll('Ã¹', 'ù')
        .replaceAll('Ã€', 'À')
        .replaceAll('Ãˆ', 'È')
        .replaceAll('Ã‰', 'É')
        .replaceAll('ÃŒ', 'Ì')
        .replaceAll('Ã’', 'Ò')
        .replaceAll('Ã™', 'Ù');
  }

  static int _utf8MojibakeScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (codeUnit == 0x00C3 ||
          codeUnit == 0x00C2 ||
          codeUnit == 0x00E2 ||
          codeUnit == 0x20AC ||
          codeUnit == 0x2122 ||
          codeUnit == 0x0153 ||
          codeUnit == 0x017E) {
        score++;
      }
    }
    return score;
  }

  static int? _windows1252Encode(int codeUnit) {
    if (codeUnit < 0x80) return codeUnit;
    for (var i = 0; i < _windows1252.length; i++) {
      if (_windows1252[i] == codeUnit) return i + 0x80;
    }
    return null;
  }

  Future<ExtractionResult> extract({
    required String path,
    required String extension,
  }) async {
    try {
      switch (extension) {
        case 'txt':
        case 'md':
        case 'rtf':
          return ExtractionResult(text: await _readTextFileSafe(path));

        case 'html':
        case 'htm':
          final raw = await _readTextFileSafe(path);
          return ExtractionResult(text: _stripHtml(raw));

        case 'pdf':
          return await _extractPdf(path);

        case 'docx':
        case 'doc':
          return await _extractDocx(path);

        case 'epub':
          return await _extractEpub(path);

        default:
          return ExtractionResult(
            text: '',
            error: 'Formato .${extension.toUpperCase()} non supportato '
                "per l'estrazione del testo.",
          );
      }
    } catch (e) {
      dev.log('DocumentTextExtractor: errore per $path: $e');
      return ExtractionResult(
        text: '',
        error: 'Errore durante la lettura del file: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PDF — syncfusion_flutter_pdf
  // ---------------------------------------------------------------------------

  Future<ExtractionResult> _extractPdf(String path) async {
    final bytes = await File(path).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final String text;
    try {
      // extractText() senza parametri estrae tutto il documento.
      text = PdfTextExtractor(document).extractText().trim();
    } finally {
      document.dispose();
    }
    if (text.isEmpty) {
      dev.log('Nessun testo estratto. Tento fallback OCR...');
      return await _extractPdfOcr(path);
    }
    return ExtractionResult(text: text);
  }

  Future<ExtractionResult> _extractPdfOcr(String path) async {
    pdfx.PdfDocument? doc;
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final buffer = StringBuffer();

    try {
      doc = await pdfx.PdfDocument.openFile(path);
      final pagesCount = doc.pagesCount;
      final maxPages =
          pagesCount > 20 ? 20 : pagesCount; // Limitiamo a 20 per performance

      final tempDir = await getTemporaryDirectory();

      for (int i = 1; i <= maxPages; i++) {
        final page = await doc.getPage(i);
        // Render per OCR. Usiamo un ingrandimento (es 2x) per la qualità.
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.jpeg,
        );
        await page.close();

        if (pageImage != null) {
          final tempFile = File(p.join(tempDir.path, 'ocr_page_$i.jpg'));
          await tempFile.writeAsBytes(pageImage.bytes);

          final inputImage = InputImage.fromFile(tempFile);
          final recognizedText = await textRecognizer.processImage(inputImage);
          buffer.writeln(recognizedText.text);
          buffer.writeln(); // Spazio tra pagine

          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }

      final ocrText = buffer.toString().trim();
      if (ocrText.isEmpty) {
        return const ExtractionResult(
          text: '',
          error:
              'Nessun testo trovato nel documento, neanche tramite scansione visiva OCR.',
        );
      }
      return ExtractionResult(text: ocrText);
    } catch (e) {
      return ExtractionResult(
        text: '',
        error: 'Errore durante la scansione OCR del PDF: $e',
      );
    } finally {
      await textRecognizer.close();
      // Nota: doc non ha un dispose esplicito su alcune vecchie versioni pdfx,
      // ma proviamo a chiuderlo se necessario. In pdfx doc viene gestito in automatico
      // o con doc.close().
      try {
        // doc.close(); non supportato in pdfx.PdfDocument ma è document_ref internamente
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // DOCX — archive + xml
  // ---------------------------------------------------------------------------

  Future<ExtractionResult> _extractDocx(String path) async {
    final bytes = await File(path).readAsBytes();
    // DOCX è un archivio ZIP: il testo principale è in word/document.xml
    final archive = ZipDecoder().decodeBytes(bytes);
    final docEntry = archive.findFile('word/document.xml');
    if (docEntry == null) {
      return const ExtractionResult(
        text: '',
        error: 'Struttura DOCX non valida: word/document.xml non trovato.',
      );
    }
    final xmlString =
        utf8.decode(docEntry.content as List<int>, allowMalformed: true);
    final document = xml_pkg.XmlDocument.parse(xmlString);
    final buffer = StringBuffer();
    // I run di testo sono in <w:t>; i paragrafi in <w:p>.
    for (final paragraph in document.findAllElements('w:p')) {
      final line =
          paragraph.findAllElements('w:t').map((e) => e.innerText).join('');
      if (line.isNotEmpty) buffer.writeln(line);
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      return const ExtractionResult(
        text: '',
        error: 'Nessun testo trovato nel documento DOCX.',
      );
    }
    return ExtractionResult(text: text);
  }

  // ---------------------------------------------------------------------------
  // EPUB — epubx
  // ---------------------------------------------------------------------------

  Future<ExtractionResult> _extractEpub(String path) async {
    final bytes = await File(path).readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final buffer = StringBuffer();
    final chapters = book.Chapters;
    if (chapters != null) {
      for (final chapter in chapters) {
        _appendChapter(chapter, buffer);
      }
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      return const ExtractionResult(
        text: '',
        error: "Nessun testo trovato nell'EPUB.",
      );
    }
    return ExtractionResult(text: text);
  }

  void _appendChapter(EpubChapter chapter, StringBuffer buffer) {
    final html = chapter.HtmlContent;
    if (html != null && html.isNotEmpty) {
      buffer.writeln(_stripHtml(html));
      buffer.writeln();
    }
    final subChapters = chapter.SubChapters;
    if (subChapters != null) {
      for (final sub in subChapters) {
        _appendChapter(sub, buffer);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Utilità condivise
  // ---------------------------------------------------------------------------

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}

const _centralEuropeanChars = <int>{
  0x011B,
  0x0161,
  0x010D,
  0x0159,
  0x017E,
  0x00FD,
  0x00E1,
  0x00ED,
  0x00E9,
  0x016F,
  0x00FA,
  0x0148,
  0x010F,
  0x0165,
  0x011A,
  0x0160,
  0x010C,
  0x0158,
  0x017D,
  0x00DD,
  0x00C1,
  0x00CD,
  0x00C9,
  0x016E,
  0x00DA,
  0x0147,
  0x010E,
  0x0164,
  0x0105,
  0x0107,
  0x0119,
  0x0142,
  0x0144,
  0x00F3,
  0x015B,
  0x017A,
  0x017C,
  0x0104,
  0x0106,
  0x0118,
  0x0141,
  0x0143,
  0x00D3,
  0x015A,
  0x0179,
  0x017B,
};

const _westernEuropeanChars = <int>{
  0x00E0,
  0x00E8,
  0x00EC,
  0x00F2,
  0x00F9,
  0x00C0,
  0x00C8,
  0x00CC,
  0x00D2,
  0x00D9,
  0x00E1,
  0x00E9,
  0x00ED,
  0x00F3,
  0x00FA,
  0x00C1,
  0x00C9,
  0x00CD,
  0x00D3,
  0x00DA,
  0x00E2,
  0x00EA,
  0x00EE,
  0x00F4,
  0x00FB,
  0x00C2,
  0x00CA,
  0x00CE,
  0x00D4,
  0x00DB,
  0x00E3,
  0x00F5,
  0x00C3,
  0x00D5,
  0x00E7,
  0x00C7,
  0x00F1,
  0x00D1,
};

const _windows1250 = <int?>[
  0x20AC,
  null,
  0x201A,
  null,
  0x201E,
  0x2026,
  0x2020,
  0x2021,
  null,
  0x2030,
  0x0160,
  0x2039,
  0x015A,
  0x0164,
  0x017D,
  0x0179,
  null,
  0x2018,
  0x2019,
  0x201C,
  0x201D,
  0x2022,
  0x2013,
  0x2014,
  null,
  0x2122,
  0x0161,
  0x203A,
  0x015B,
  0x0165,
  0x017E,
  0x017A,
  0x00A0,
  0x02C7,
  0x02D8,
  0x0141,
  0x00A4,
  0x0104,
  0x00A6,
  0x00A7,
  0x00A8,
  0x00A9,
  0x015E,
  0x00AB,
  0x00AC,
  0x00AD,
  0x00AE,
  0x017B,
  0x00B0,
  0x00B1,
  0x02DB,
  0x0142,
  0x00B4,
  0x00B5,
  0x00B6,
  0x00B7,
  0x00B8,
  0x0105,
  0x015F,
  0x00BB,
  0x013D,
  0x02DD,
  0x013E,
  0x017C,
  0x0154,
  0x00C1,
  0x00C2,
  0x0102,
  0x00C4,
  0x0139,
  0x0106,
  0x00C7,
  0x010C,
  0x00C9,
  0x0118,
  0x00CB,
  0x011A,
  0x00CD,
  0x00CE,
  0x010E,
  0x0110,
  0x0143,
  0x0147,
  0x00D3,
  0x00D4,
  0x0150,
  0x00D6,
  0x00D7,
  0x0158,
  0x016E,
  0x00DA,
  0x0170,
  0x00DC,
  0x00DD,
  0x0162,
  0x00DF,
  0x0155,
  0x00E1,
  0x00E2,
  0x0103,
  0x00E4,
  0x013A,
  0x0107,
  0x00E7,
  0x010D,
  0x00E9,
  0x0119,
  0x00EB,
  0x011B,
  0x00ED,
  0x00EE,
  0x010F,
  0x0111,
  0x0144,
  0x0148,
  0x00F3,
  0x00F4,
  0x0151,
  0x00F6,
  0x00F7,
  0x0159,
  0x016F,
  0x00FA,
  0x0171,
  0x00FC,
  0x00FD,
  0x0163,
  0x02D9,
];

const _windows1252 = <int?>[
  0x20AC,
  null,
  0x201A,
  0x0192,
  0x201E,
  0x2026,
  0x2020,
  0x2021,
  0x02C6,
  0x2030,
  0x0160,
  0x2039,
  0x0152,
  null,
  0x017D,
  null,
  null,
  0x2018,
  0x2019,
  0x201C,
  0x201D,
  0x2022,
  0x2013,
  0x2014,
  0x02DC,
  0x2122,
  0x0161,
  0x203A,
  0x0153,
  null,
  0x017E,
  0x0178,
  0x00A0,
  0x00A1,
  0x00A2,
  0x00A3,
  0x00A4,
  0x00A5,
  0x00A6,
  0x00A7,
  0x00A8,
  0x00A9,
  0x00AA,
  0x00AB,
  0x00AC,
  0x00AD,
  0x00AE,
  0x00AF,
  0x00B0,
  0x00B1,
  0x00B2,
  0x00B3,
  0x00B4,
  0x00B5,
  0x00B6,
  0x00B7,
  0x00B8,
  0x00B9,
  0x00BA,
  0x00BB,
  0x00BC,
  0x00BD,
  0x00BE,
  0x00BF,
  0x00C0,
  0x00C1,
  0x00C2,
  0x00C3,
  0x00C4,
  0x00C5,
  0x00C6,
  0x00C7,
  0x00C8,
  0x00C9,
  0x00CA,
  0x00CB,
  0x00CC,
  0x00CD,
  0x00CE,
  0x00CF,
  0x00D0,
  0x00D1,
  0x00D2,
  0x00D3,
  0x00D4,
  0x00D5,
  0x00D6,
  0x00D7,
  0x00D8,
  0x00D9,
  0x00DA,
  0x00DB,
  0x00DC,
  0x00DD,
  0x00DE,
  0x00DF,
  0x00E0,
  0x00E1,
  0x00E2,
  0x00E3,
  0x00E4,
  0x00E5,
  0x00E6,
  0x00E7,
  0x00E8,
  0x00E9,
  0x00EA,
  0x00EB,
  0x00EC,
  0x00ED,
  0x00EE,
  0x00EF,
  0x00F0,
  0x00F1,
  0x00F2,
  0x00F3,
  0x00F4,
  0x00F5,
  0x00F6,
  0x00F7,
  0x00F8,
  0x00F9,
  0x00FA,
  0x00FB,
  0x00FC,
  0x00FD,
  0x00FE,
  0x00FF,
];
