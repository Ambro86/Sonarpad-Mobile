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
    if (_startsWith(bytes, const [0xFF, 0xFE, 0x00, 0x00])) {
      return _decodeUtf32(bytes.sublist(4), Endian.little);
    }
    if (_startsWith(bytes, const [0x00, 0x00, 0xFE, 0xFF])) {
      return _decodeUtf32(bytes.sublist(4), Endian.big);
    }
    if (_startsWith(bytes, const [0xFF, 0xFE])) {
      return _decodeUtf16(bytes.sublist(2), Endian.little);
    }
    if (_startsWith(bytes, const [0xFE, 0xFF])) {
      return _decodeUtf16(bytes.sublist(2), Endian.big);
    }
    final utf16Guess = _tryDecodeUtf16WithoutBom(bytes);
    if (utf16Guess != null) return utf16Guess;

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

  static String _decodeUtf32(List<int> bytes, Endian endian) {
    final buffer = StringBuffer();
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      final codePoint = endian == Endian.little
          ? bytes[i] |
              (bytes[i + 1] << 8) |
              (bytes[i + 2] << 16) |
              (bytes[i + 3] << 24)
          : (bytes[i] << 24) |
              (bytes[i + 1] << 16) |
              (bytes[i + 2] << 8) |
              bytes[i + 3];
      if (codePoint >= 0 && codePoint <= 0x10FFFF) {
        buffer.writeCharCode(codePoint);
      }
    }
    return buffer.toString();
  }

  static String _chooseAnsiDecoding(List<int> bytes) {
    final cp1250Text = _decodeSingleByte(bytes, _windows1250);
    final cp1252Text = _decodeSingleByte(bytes, _windows1252);
    final cp1250Score = _centralEuropeanCharScore(cp1250Text);
    final cp1252Score = _westernEuropeanCharScore(cp1252Text);
    final cp1252CeScore = _centralEuropeanCharScore(cp1252Text);

    String chosen;
    if (cp1250Score >= 2 && cp1250Score > cp1252CeScore) {
      chosen = cp1250Text;
    } else if (cp1252Score > 0 && cp1250Score == 0) {
      chosen = cp1252Text;
    } else if (_replacementLikeScore(cp1252Text) >
        _replacementLikeScore(cp1250Text)) {
      chosen = cp1250Text;
    } else {
      chosen = cp1252Text;
    }
    final foreign = _chooseForeignSingleByteDecoding(
      bytes,
      chosen,
      protectedCentralEuropeanScore:
          chosen == cp1250Text ? cp1250Score : 0,
    );
    return foreign ?? chosen;
  }

  static String? _tryDecodeUtf16WithoutBom(List<int> bytes) {
    if (bytes.length < 4 || bytes.length.isOdd) return null;
    var evenZeroes = 0;
    var oddZeroes = 0;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != 0) continue;
      if (i.isEven) {
        evenZeroes++;
      } else {
        oddZeroes++;
      }
    }
    final pairs = bytes.length ~/ 2;
    if (oddZeroes > pairs ~/ 3 && evenZeroes <= pairs ~/ 10) {
      return _decodeUtf16(bytes, Endian.little);
    }
    if (evenZeroes > pairs ~/ 3 && oddZeroes <= pairs ~/ 10) {
      return _decodeUtf16(bytes, Endian.big);
    }
    return null;
  }

  static String? _chooseForeignSingleByteDecoding(
    List<int> bytes,
    String currentText, {
    int protectedCentralEuropeanScore = 0,
  }) {
    final currentForeignScore = _foreignScriptScore(currentText);
    final currentReplacementScore = _replacementLikeScore(currentText);
    final candidates = [
      _DecodedCandidate(
        _decodeSingleByte(bytes, _windows1251),
        _cyrillicCharScore,
        rawScore: _rawCyrillicCharScore,
        minScore: 6,
        requireDominantScript: true,
      ),
      _DecodedCandidate(
        _decodeSingleByte(bytes, _windows1253),
        _greekCharScore,
        rawScore: _rawGreekCharScore,
        minScore: 6,
        requireDominantScript: true,
      ),
      _DecodedCandidate(
        _decodeSingleByte(bytes, _windows1254),
        _turkishCharScore,
        minScore: 3,
      ),
      _DecodedCandidate(
        _decodeSingleByte(bytes, _windows1255),
        _hebrewCharScore,
        rawScore: _rawHebrewCharScore,
        minScore: 3,
        requireDominantScript: true,
        requiredCodePoint: 0x20AA,
      ),
      _DecodedCandidate(
        _decodeSingleByte(bytes, _windows1256),
        _arabicCharScore,
        rawScore: _rawArabicCharScore,
        minScore: 3,
        requireDominantScript: true,
      ),
    ];

    _DecodedCandidate? best;
    var bestScore = 0;
    for (final candidate in candidates) {
      final replacementScore = _replacementLikeScore(candidate.text);
      if (replacementScore > 2 && replacementScore >= currentReplacementScore) {
        continue;
      }
      final score = candidate.score(candidate.text);
      if (score < candidate.minScore) continue;
      if (candidate.requireDominantScript &&
          !candidate.hasDominantScript(candidate.text)) {
        continue;
      }
      if (score > bestScore ||
          score == bestScore &&
              best != null &&
              candidate.rawScriptScore > best.rawScriptScore) {
        best = candidate;
        bestScore = score;
      }
    }

    if (best == null || bestScore <= currentForeignScore) {
      return null;
    }
    if (protectedCentralEuropeanScore >= 2 &&
        bestScore <= protectedCentralEuropeanScore + 2) {
      return null;
    }
    return best.text;
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

  static int _foreignScriptScore(String text) =>
      _cyrillicCharScore(text) +
      _greekCharScore(text) +
      _turkishCharScore(text) +
      _hebrewCharScore(text) +
      _arabicCharScore(text) +
      _balticCharScore(text);

  static int _cyrillicCharScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (_isCyrillic(codeUnit)) {
        score++;
        if (_commonCyrillicChars.contains(codeUnit)) score++;
      }
    }
    return score;
  }

  static int _greekCharScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (_isGreek(codeUnit)) {
        score++;
        if (_commonGreekChars.contains(codeUnit)) score++;
      }
    }
    return score;
  }

  static int _turkishCharScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (_turkishChars.contains(codeUnit)) score++;
    }
    return score;
  }

  static int _balticCharScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (_balticChars.contains(codeUnit)) score++;
    }
    return score;
  }

  static int _hebrewCharScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (_isHebrew(codeUnit)) score += 2;
      if (codeUnit == 0x20AA) score += 3;
    }
    return score;
  }

  static int _arabicCharScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (_isArabic(codeUnit)) score += 2;
    }
    return score;
  }

  static int _rawCyrillicCharScore(String text) =>
      _countCodeUnitsWhere(text, _isCyrillic);

  static int _rawGreekCharScore(String text) =>
      _countCodeUnitsWhere(text, _isGreek);

  static int _rawHebrewCharScore(String text) =>
      _countCodeUnitsWhere(text, _isHebrew);

  static int _rawArabicCharScore(String text) =>
      _countCodeUnitsWhere(text, _isArabic);

  static int _countCodeUnitsWhere(String text, bool Function(int) test) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (test(codeUnit)) score++;
    }
    return score;
  }

  static bool _isCyrillic(int codeUnit) =>
      codeUnit >= 0x0400 && codeUnit <= 0x04FF;

  static bool _isGreek(int codeUnit) =>
      codeUnit >= 0x0370 && codeUnit <= 0x03FF;

  static bool _isHebrew(int codeUnit) =>
      codeUnit >= 0x0590 && codeUnit <= 0x05FF;

  static bool _isArabic(int codeUnit) =>
      codeUnit >= 0x0600 && codeUnit <= 0x06FF;

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
    String text;
    try {
      // extractText() senza parametri estrae tutto il documento.
      text = PdfTextExtractor(document).extractText().trim();
    } finally {
      document.dispose();
    }
    text = _repairPdfTextExtractionArtifacts(text).trim();
    if (text.isEmpty) {
      dev.log('Nessun testo estratto. Tento fallback OCR...');
      return await _extractPdfOcr(path);
    }
    return ExtractionResult(text: text);
  }

  String _repairPdfTextExtractionArtifacts(String text) {
    if (!_looksLikeSevenPrefixPdfArtifact(text)) return text;

    var repaired = text;

    // Alcuni PDF con font embedded/encoding non standard vengono estratti da
    // Syncfusion con artefatti ricorrenti: la lettera b diventa 7b, la y
    // diventa 7y e il numero 7 può diventare varianti come 77yTb o 77yi.bl.
    // Il PDF è testuale, quindi non va mandato in OCR: ripariamo solo questo
    // pattern molto riconoscibile e solo quando è dominante nel documento.
    const replacements = <String, String>{
      '77yi.bl': '7l',
      '77yi.b': '7',
      '77yTbl': '7l',
      '77yTb': '7',
      '77yiTb': '7',
      '77yNb': '7',
    };

    for (final entry in replacements.entries) {
      repaired = repaired.replaceAll(entry.key, entry.value);
    }

    repaired = repaired.replaceAllMapped(
      RegExp(r'7([bByY])'),
      (match) => match.group(1)!,
    );

    dev.log('DocumentTextExtractor: riparati artefatti di estrazione PDF');
    return repaired;
  }

  bool _looksLikeSevenPrefixPdfArtifact(String text) {
    if (text.length < 500) return false;

    final sevenBeforeLetters = RegExp(r'7[bByY]').allMatches(text).length;
    if (sevenBeforeLetters < 20) return false;

    final plainSevenCount = RegExp(r'7').allMatches(text).length;
    if (plainSevenCount == 0) return false;

    final ratio = sevenBeforeLetters / plainSevenCount;
    return ratio >= 0.20;
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
    final body = StringBuffer();
    _appendEpubSpineContent(book, body);

    final chapters = book.Chapters;
    if (body.toString().trim().isEmpty && chapters != null) {
      for (final chapter in chapters) {
        _appendChapter(chapter, body);
      }
    }

    final buffer = StringBuffer();
    final title = book.Title?.trim();
    if (title != null && title.isNotEmpty) {
      buffer.writeln(title);
      buffer.writeln();
    }
    buffer.write(body.toString());

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
      _appendCleanEpubHtml(html, buffer);
    }
    final subChapters = chapter.SubChapters;
    if (subChapters != null) {
      for (final sub in subChapters) {
        _appendChapter(sub, buffer);
      }
    }
  }

  void _appendEpubSpineContent(EpubBook book, StringBuffer buffer) {
    final content = book.Content?.Html;
    if (content == null || content.isEmpty) return;

    final manifestItems = book.Schema?.Package?.Manifest?.Items ?? const [];
    final spineItems = book.Schema?.Package?.Spine?.Items ?? const [];
    final orderedHrefs = <String>[];
    for (final spineItem in spineItems) {
      final idRef = spineItem.IdRef;
      if (idRef == null || idRef.isEmpty) continue;
      for (final manifestItem in manifestItems) {
        if (manifestItem.Id == idRef &&
            manifestItem.Href != null &&
            manifestItem.Href!.isNotEmpty) {
          orderedHrefs.add(manifestItem.Href!);
          break;
        }
      }
    }

    final seen = <String>{};
    final hrefs = orderedHrefs.isEmpty ? content.keys : orderedHrefs;
    for (final href in hrefs) {
      final file = content[href] ?? content[p.basename(href)];
      final html = file?.Content;
      if (html == null || html.isEmpty || !seen.add(href)) continue;
      _appendCleanEpubHtml(html, buffer);
    }
  }

  void _appendCleanEpubHtml(String html, StringBuffer buffer) {
    final text = _stripHtml(html);
    var wrote = false;
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          _isEpubMetadataNoiseLine(trimmed) ||
          (trimmed.startsWith('part') && trimmed.length <= 12)) {
        continue;
      }
      buffer.writeln(trimmed);
      wrote = true;
    }
    if (wrote) buffer.writeln();
  }

  bool _isEpubMetadataNoiseLine(String line) {
    final normalized = _collapseWhitespace(line);
    final lower = normalized.toLowerCase();
    return lower == 'epub r1.0' || lower == 'epub base r2.1';
  }

  String _collapseWhitespace(String value) {
    final buffer = StringBuffer();
    var previousWasWhitespace = true;
    for (final codeUnit in value.codeUnits) {
      final isWhitespace = codeUnit == 0x20 ||
          codeUnit == 0x09 ||
          codeUnit == 0x0A ||
          codeUnit == 0x0D;
      if (isWhitespace) {
        if (!previousWasWhitespace) buffer.write(' ');
      } else {
        buffer.writeCharCode(codeUnit);
      }
      previousWasWhitespace = isWhitespace;
    }
    return buffer.toString().trim();
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

class _DecodedCandidate {
  final String text;
  final int Function(String text) score;
  final int Function(String text)? rawScore;
  final int minScore;
  final bool requireDominantScript;
  final int? requiredCodePoint;

  const _DecodedCandidate(
    this.text,
    this.score, {
    this.rawScore,
    this.minScore = 3,
    this.requireDominantScript = false,
    this.requiredCodePoint,
  });

  int get rawScriptScore {
    final raw = rawScore;
    return raw == null ? score(text) : raw(text);
  }

  bool hasDominantScript(String value) {
    final raw = rawScore;
    if (raw == null) return true;
    final required = requiredCodePoint;
    if (required != null && !value.runes.contains(required)) return false;
    final scriptCount = raw(value);
    final letters = value.runes.where(_isLetterCodePoint).length;
    if (letters == 0) return false;
    return scriptCount * 3 >= letters * 2;
  }
}

bool _isLetterCodePoint(int codePoint) =>
    codePoint >= 0x0041 && codePoint <= 0x005A ||
    codePoint >= 0x0061 && codePoint <= 0x007A ||
    codePoint >= 0x00C0 && codePoint <= 0x02AF ||
    codePoint >= 0x0370 && codePoint <= 0x03FF ||
    codePoint >= 0x0400 && codePoint <= 0x04FF ||
    codePoint >= 0x0590 && codePoint <= 0x05FF ||
    codePoint >= 0x0600 && codePoint <= 0x06FF ||
    codePoint >= 0x0100 && codePoint <= 0x017F;

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

const _turkishChars = <int>{
  0x011E,
  0x011F,
  0x0130,
  0x0131,
  0x015E,
  0x015F,
};

const _balticChars = <int>{
  0x0100,
  0x0101,
  0x0104,
  0x0105,
  0x010C,
  0x010D,
  0x0112,
  0x0113,
  0x0116,
  0x0117,
  0x0118,
  0x0119,
  0x0122,
  0x0123,
  0x012A,
  0x012B,
  0x012E,
  0x012F,
  0x0136,
  0x0137,
  0x013B,
  0x013C,
  0x0141,
  0x0142,
  0x0143,
  0x0144,
  0x0145,
  0x0146,
  0x014C,
  0x014D,
  0x0156,
  0x0157,
  0x0160,
  0x0161,
  0x016A,
  0x016B,
  0x0172,
  0x0173,
  0x0179,
  0x017A,
  0x017B,
  0x017C,
  0x017D,
  0x017E,
};

const _commonCyrillicChars = <int>{
  0x0410,
  0x0415,
  0x0418,
  0x041D,
  0x041E,
  0x0420,
  0x0421,
  0x0422,
  0x0430,
  0x0435,
  0x0438,
  0x043D,
  0x043E,
  0x0440,
  0x0441,
  0x0442,
};

const _commonGreekChars = <int>{
  0x0391,
  0x0395,
  0x0397,
  0x0399,
  0x039A,
  0x039C,
  0x039D,
  0x039F,
  0x03A1,
  0x03A3,
  0x03A4,
  0x03B1,
  0x03B5,
  0x03B7,
  0x03B9,
  0x03BA,
  0x03BC,
  0x03BD,
  0x03BF,
  0x03C1,
  0x03C3,
  0x03C4,
};

const _windows1251 = <int?>[
  0x0402,
  0x0403,
  0x201A,
  0x0453,
  0x201E,
  0x2026,
  0x2020,
  0x2021,
  0x20AC,
  0x2030,
  0x0409,
  0x2039,
  0x040A,
  0x040C,
  0x040B,
  0x040F,
  0x0452,
  0x2018,
  0x2019,
  0x201C,
  0x201D,
  0x2022,
  0x2013,
  0x2014,
  null,
  0x2122,
  0x0459,
  0x203A,
  0x045A,
  0x045C,
  0x045B,
  0x045F,
  0x00A0,
  0x040E,
  0x045E,
  0x0408,
  0x00A4,
  0x0490,
  0x00A6,
  0x00A7,
  0x0401,
  0x00A9,
  0x0404,
  0x00AB,
  0x00AC,
  0x00AD,
  0x00AE,
  0x0407,
  0x00B0,
  0x00B1,
  0x0406,
  0x0456,
  0x0491,
  0x00B5,
  0x00B6,
  0x00B7,
  0x0451,
  0x2116,
  0x0454,
  0x00BB,
  0x0458,
  0x0405,
  0x0455,
  0x0457,
  0x0410,
  0x0411,
  0x0412,
  0x0413,
  0x0414,
  0x0415,
  0x0416,
  0x0417,
  0x0418,
  0x0419,
  0x041A,
  0x041B,
  0x041C,
  0x041D,
  0x041E,
  0x041F,
  0x0420,
  0x0421,
  0x0422,
  0x0423,
  0x0424,
  0x0425,
  0x0426,
  0x0427,
  0x0428,
  0x0429,
  0x042A,
  0x042B,
  0x042C,
  0x042D,
  0x042E,
  0x042F,
  0x0430,
  0x0431,
  0x0432,
  0x0433,
  0x0434,
  0x0435,
  0x0436,
  0x0437,
  0x0438,
  0x0439,
  0x043A,
  0x043B,
  0x043C,
  0x043D,
  0x043E,
  0x043F,
  0x0440,
  0x0441,
  0x0442,
  0x0443,
  0x0444,
  0x0445,
  0x0446,
  0x0447,
  0x0448,
  0x0449,
  0x044A,
  0x044B,
  0x044C,
  0x044D,
  0x044E,
  0x044F,
];

const _windows1253 = <int?>[
  0x20AC,
  null,
  0x201A,
  0x0192,
  0x201E,
  0x2026,
  0x2020,
  0x2021,
  null,
  0x2030,
  null,
  0x2039,
  null,
  null,
  null,
  null,
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
  null,
  0x203A,
  null,
  null,
  null,
  null,
  0x00A0,
  0x0385,
  0x0386,
  0x00A3,
  0x00A4,
  0x00A5,
  0x00A6,
  0x00A7,
  0x00A8,
  0x00A9,
  null,
  0x00AB,
  0x00AC,
  0x00AD,
  0x00AE,
  0x2015,
  0x00B0,
  0x00B1,
  0x00B2,
  0x00B3,
  0x0384,
  0x00B5,
  0x00B6,
  0x00B7,
  0x0388,
  0x0389,
  0x038A,
  0x00BB,
  0x038C,
  0x00BD,
  0x038E,
  0x038F,
  0x0390,
  0x0391,
  0x0392,
  0x0393,
  0x0394,
  0x0395,
  0x0396,
  0x0397,
  0x0398,
  0x0399,
  0x039A,
  0x039B,
  0x039C,
  0x039D,
  0x039E,
  0x039F,
  0x03A0,
  0x03A1,
  null,
  0x03A3,
  0x03A4,
  0x03A5,
  0x03A6,
  0x03A7,
  0x03A8,
  0x03A9,
  0x03AA,
  0x03AB,
  0x03AC,
  0x03AD,
  0x03AE,
  0x03AF,
  0x03B0,
  0x03B1,
  0x03B2,
  0x03B3,
  0x03B4,
  0x03B5,
  0x03B6,
  0x03B7,
  0x03B8,
  0x03B9,
  0x03BA,
  0x03BB,
  0x03BC,
  0x03BD,
  0x03BE,
  0x03BF,
  0x03C0,
  0x03C1,
  0x03C2,
  0x03C3,
  0x03C4,
  0x03C5,
  0x03C6,
  0x03C7,
  0x03C8,
  0x03C9,
  0x03CA,
  0x03CB,
  0x03CC,
  0x03CD,
  0x03CE,
  null,
];

const _windows1254 = <int?>[
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
  null,
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
  null,
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
  0x011E,
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
  0x0130,
  0x015E,
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
  0x011F,
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
  0x0131,
  0x015F,
  0x00FF,
];

const _windows1255 = <int?>[
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
  null,
  0x2039,
  null,
  null,
  null,
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
  null,
  0x203A,
  null,
  null,
  null,
  null,
  0x00A0,
  0x00A1,
  0x00A2,
  0x00A3,
  0x20AA,
  0x00A5,
  0x00A6,
  0x00A7,
  0x00A8,
  0x00A9,
  0x00D7,
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
  0x00F7,
  0x00BB,
  0x00BC,
  0x00BD,
  0x00BE,
  0x00BF,
  0x05B0,
  0x05B1,
  0x05B2,
  0x05B3,
  0x05B4,
  0x05B5,
  0x05B6,
  0x05B7,
  0x05B8,
  0x05B9,
  null,
  0x05BB,
  0x05BC,
  0x05BD,
  0x05BE,
  0x05BF,
  0x05C0,
  0x05C1,
  0x05C2,
  0x05C3,
  0x05F0,
  0x05F1,
  0x05F2,
  0x05F3,
  0x05F4,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  0x05D0,
  0x05D1,
  0x05D2,
  0x05D3,
  0x05D4,
  0x05D5,
  0x05D6,
  0x05D7,
  0x05D8,
  0x05D9,
  0x05DA,
  0x05DB,
  0x05DC,
  0x05DD,
  0x05DE,
  0x05DF,
  0x05E0,
  0x05E1,
  0x05E2,
  0x05E3,
  0x05E4,
  0x05E5,
  0x05E6,
  0x05E7,
  0x05E8,
  0x05E9,
  0x05EA,
  null,
  null,
  0x200E,
  0x200F,
  null,
];

const _windows1256 = <int?>[
  0x20AC,
  0x067E,
  0x201A,
  0x0192,
  0x201E,
  0x2026,
  0x2020,
  0x2021,
  0x02C6,
  0x2030,
  0x0679,
  0x2039,
  0x0152,
  0x0686,
  0x0698,
  0x0688,
  0x06AF,
  0x2018,
  0x2019,
  0x201C,
  0x201D,
  0x2022,
  0x2013,
  0x2014,
  0x06A9,
  0x2122,
  0x0691,
  0x203A,
  0x0153,
  0x200C,
  0x200D,
  0x06BA,
  0x00A0,
  0x060C,
  0x00A2,
  0x00A3,
  0x00A4,
  0x00A5,
  0x00A6,
  0x00A7,
  0x00A8,
  0x00A9,
  0x06BE,
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
  0x061B,
  0x00BB,
  0x00BC,
  0x00BD,
  0x00BE,
  0x061F,
  0x06C1,
  0x0621,
  0x0622,
  0x0623,
  0x0624,
  0x0625,
  0x0626,
  0x0627,
  0x0628,
  0x0629,
  0x062A,
  0x062B,
  0x062C,
  0x062D,
  0x062E,
  0x062F,
  0x0630,
  0x0631,
  0x0632,
  0x0633,
  0x0634,
  0x0635,
  0x0636,
  0x00D7,
  0x0637,
  0x0638,
  0x0639,
  0x063A,
  0x0640,
  0x0641,
  0x0642,
  0x0643,
  0x00E0,
  0x0644,
  0x00E2,
  0x0645,
  0x0646,
  0x0647,
  0x0648,
  0x00E7,
  0x00E8,
  0x00E9,
  0x00EA,
  0x00EB,
  0x0649,
  0x064A,
  0x00EE,
  0x00EF,
  0x064B,
  0x064C,
  0x064D,
  0x064E,
  0x00F4,
  0x064F,
  0x0650,
  0x00F7,
  0x0651,
  0x00F9,
  0x0652,
  0x00FB,
  0x00FC,
  0x200E,
  0x200F,
  0x06D2,
];

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
