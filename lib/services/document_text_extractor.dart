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

import '../utils/document_unicode_normalizer.dart';

/// Risultato dell'estrazione testo da un documento.
class ExtractionResult {
  /// Testo estratto. Vuoto se l'estrazione non è riuscita.
  final String text;

  /// Messaggio di errore/info da mostrare all'utente. Null se ok.
  final String? error;

  const ExtractionResult({required this.text, this.error});
}

/// Voce dell'indice di un documento EPUB collegata al blocco di lettura.
class DocumentTableOfContentsEntry {
  final String title;
  final int chunkIndex;
  final int level;

  const DocumentTableOfContentsEntry({
    required this.title,
    required this.chunkIndex,
    this.level = 0,
  });
}

/// Servizio che estrae il testo da documenti di vari formati.
///
/// Formati con estrazione completa:
/// - TXT, MD     → lettura diretta del file
/// - RTF         → parsing RTF e conversione in testo leggibile
/// - HTML, HTM    → strip tag HTML
/// - PDF          → [syncfusion_flutter_pdf] PdfTextExtractor
/// - DOCX / DOC   → unzip (archive) + parsing XML word/document.xml
/// - EPUB         → [epubx] EpubReader + strip HTML dei capitoli
class DocumentTextExtractor {
  Future<String> _readTextFileSafe(String path) async {
    final bytes = await File(path).readAsBytes();
    return decodeDocumentTextBytes(bytes);
  }

  Future<String> _readRtfFileSafe(String path) async {
    final bytes = await File(path).readAsBytes();
    return decodeRtfDocumentTextBytes(bytes);
  }

  static String decodeRtfDocumentTextBytes(List<int> bytes) {
    String raw;
    if (_startsWith(bytes, const [0xEF, 0xBB, 0xBF])) {
      // Un BOM UTF-8 è un'indicazione esplicita dell'encoding del contenitore.
      // I control word e gli escape RTF restano ASCII, mentre eventuale testo
      // Unicode scritto direttamente nel file viene così preservato.
      raw = utf8.decode(bytes.sublist(3), allowMalformed: true);
    } else if (_startsWith(bytes, const [0xFF, 0xFE, 0x00, 0x00])) {
      raw = _decodeUtf32(bytes.sublist(4), Endian.little);
    } else if (_startsWith(bytes, const [0x00, 0x00, 0xFE, 0xFF])) {
      raw = _decodeUtf32(bytes.sublist(4), Endian.big);
    } else if (_startsWith(bytes, const [0xFF, 0xFE])) {
      raw = _decodeUtf16(bytes.sublist(2), Endian.little);
    } else if (_startsWith(bytes, const [0xFE, 0xFF])) {
      raw = _decodeUtf16(bytes.sublist(2), Endian.big);
    } else {
      raw = latin1.decode(bytes, allowInvalid: true);
      if (!raw.trimLeft().startsWith('{\\rtf')) {
        final utf16Guess = _tryDecodeUtf16WithoutBom(bytes);
        if (utf16Guess != null &&
            utf16Guess.trimLeft().startsWith('{\\rtf')) {
          raw = utf16Guess;
        }
      }
    }

    if (!raw.trimLeft().startsWith('{\\rtf')) {
      return decodeDocumentTextBytes(bytes);
    }
    return _normalizeRtfPlainText(_RtfPlainTextParser(raw).parse());
  }

  static String _normalizeRtfPlainText(String text) {
    return _normalizeDecodedText(
      text
          .replaceAll('\u0000', '')
          .replaceAll('\u00A0', ' ')
          .replaceAll(RegExp(r'[ \t]+\n'), '\n')
          .replaceAll(RegExp(r'\n[ \t]+'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim(),
    );
  }

  static String decodeDocumentTextBytes(List<int> bytes) {
    if (_startsWith(bytes, const [0xEF, 0xBB, 0xBF])) {
      return _normalizeDecodedText(utf8.decode(bytes.sublist(3)));
    }
    if (_startsWith(bytes, const [0xFF, 0xFE, 0x00, 0x00])) {
      return _normalizeDecodedText(_decodeUtf32(bytes.sublist(4), Endian.little));
    }
    if (_startsWith(bytes, const [0x00, 0x00, 0xFE, 0xFF])) {
      return _normalizeDecodedText(_decodeUtf32(bytes.sublist(4), Endian.big));
    }
    if (_startsWith(bytes, const [0xFF, 0xFE])) {
      return _normalizeDecodedText(_decodeUtf16(bytes.sublist(2), Endian.little));
    }
    if (_startsWith(bytes, const [0xFE, 0xFF])) {
      return _normalizeDecodedText(_decodeUtf16(bytes.sublist(2), Endian.big));
    }
    final utf16Guess = _tryDecodeUtf16WithoutBom(bytes);
    if (utf16Guess != null) return _normalizeDecodedText(utf16Guess);

    try {
      return _normalizeDecodedText(utf8.decode(bytes));
    } on FormatException {
      dev.log('Fallback ANSI best-effort per documento testuale');
      return _normalizeDecodedText(_chooseAnsiDecoding(bytes));
    }
  }

  static String _normalizeDecodedText(String text) {
    return normalizeDocumentUnicode(
      _repairItalianCp1250Mojibake(_repairUtf8Mojibake(text)),
    );
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
    if (_looksLikeItalianText(cp1252Text) &&
        _italianCp1250MojibakeScore(cp1250Text) >= 3) {
      // Alcuni TXT italiani della Biblioteca Digitale per i Ciechi sono in
      // Windows-1252. Se li si interpreta come Windows-1250, le vocali
      // accentate diventano caratteri cechi/polacchi, ad esempio:
      // sarà -> sarŕ, è -> č, lì -> lě, più -> piů.
      // In questo caso preferiamo Windows-1252, come fa il percorso BDCiechi.
      chosen = cp1252Text;
    } else if (cp1250Score >= 2 && cp1250Score > cp1252CeScore) {
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

  static String _repairItalianCp1250Mojibake(String text) {
    final score = _italianCp1250MojibakeScore(text);
    if (score < 3) return text;
    if (!_looksLikeItalianText(text)) return text;

    return text
        .replaceAll('Ŕ', 'À')
        .replaceAll('Č', 'È')
        .replaceAll('Ě', 'Ì')
        .replaceAll('Ň', 'Ò')
        .replaceAll('Ů', 'Ù')
        .replaceAll('ŕ', 'à')
        .replaceAll('č', 'è')
        .replaceAll('ě', 'ì')
        .replaceAll('ň', 'ò')
        .replaceAll('ů', 'ù');
  }

  static int _italianCp1250MojibakeScore(String text) {
    var score = 0;
    for (final codeUnit in text.codeUnits) {
      if (codeUnit == 0x0155 || // ŕ -> à
          codeUnit == 0x010D || // č -> è
          codeUnit == 0x011B || // ě -> ì
          codeUnit == 0x0148 || // ň -> ò
          codeUnit == 0x016F || // ů -> ù
          codeUnit == 0x0154 || // Ŕ -> À
          codeUnit == 0x010C || // Č -> È
          codeUnit == 0x011A || // Ě -> Ì
          codeUnit == 0x0147 || // Ň -> Ò
          codeUnit == 0x016E) { // Ů -> Ù
        score++;
      }
    }
    return score;
  }

  static bool _looksLikeItalianText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('biblioteca digitale per i ciechi')) return true;

    var score = 0;
    const markers = [
      ' che ',
      ' non ',
      ' per ',
      ' della ',
      ' delle ',
      ' degli ',
      ' alla ',
      ' nello ',
      ' sono ',
      ' aveva ',
      ' essere ',
      ' perché',
      ' pi ',
    ];
    for (final marker in markers) {
      if (lower.contains(marker)) score++;
    }
    return score >= 4;
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
    bool includeEpubFootnotesInText = false,
    String footnoteLabel = 'Nota a piè di pagina',
  }) async {
    try {
      switch (extension) {
        case 'txt':
        case 'md':
          return ExtractionResult(text: await _readTextFileSafe(path));

        case 'rtf':
          return ExtractionResult(text: await _readRtfFileSafe(path));

        case 'html':
        case 'htm':
          final raw = await _readTextFileSafe(path);
          return ExtractionResult(
            text: normalizeDocumentUnicode(_stripHtml(raw)),
          );

        case 'pdf':
          return await _extractPdf(path);

        case 'docx':
        case 'doc':
          return await _extractDocx(path);

        case 'epub':
          return await _extractEpub(
            path,
            includeFootnotesInText: includeEpubFootnotesInText,
            footnoteLabel: footnoteLabel,
          );

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
    return ExtractionResult(text: normalizeDocumentUnicode(text));
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
      return ExtractionResult(text: normalizeDocumentUnicode(ocrText));
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
    return ExtractionResult(text: normalizeDocumentUnicode(text));
  }


  Future<List<DocumentTableOfContentsEntry>> extractEpubTableOfContents({
    required String path,
    required List<String> chunks,
  }) async {
    if (chunks.isEmpty) return const [];
    final bytes = await File(path).readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final entries = <DocumentTableOfContentsEntry>[];

    // Prima leggiamo direttamente l'indice EPUB ufficiale (NCX/nav HTML).
    // Alcuni EPUB usano ancore interne come file.xhtml#title23: epubx espone
    // spesso il titolo, ma non sempre abbastanza contesto per ritrovare il
    // punto corretto nel testo estratto. La lettura diretta dell'archivio ZIP
    // permette di usare href + frammento e funziona meglio con indici lunghi.
    _collectEpubArchiveIndex(bytes, chunks, entries);

    final chapters = book.Chapters;
    if (chapters != null) {
      for (final chapter in chapters) {
        _collectEpubChapterIndex(chapter, chunks, entries, 0);
      }
    }

    if (entries.isEmpty) {
      _collectEpubHeadingIndex(book, chunks, entries);
    }

    final seen = <String>{};
    final deduped = <DocumentTableOfContentsEntry>[];
    for (final entry in entries) {
      final key = '${entry.chunkIndex}|${entry.title.toLowerCase()}';
      if (seen.add(key)) deduped.add(entry);
    }
    return deduped;
  }

  // ---------------------------------------------------------------------------
  // EPUB — epubx
  // ---------------------------------------------------------------------------


  void _collectEpubArchiveIndex(
    List<int> bytes,
    List<String> chunks,
    List<DocumentTableOfContentsEntry> entries,
  ) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final opfPath = _findEpubOpfPath(archive);
      if (opfPath == null || opfPath.isEmpty) return;

      final opfText = _readArchiveText(archive, opfPath);
      if (opfText == null || opfText.trim().isEmpty) return;
      final opf = xml_pkg.XmlDocument.parse(opfText);

      final manifestItems = <String, String>{};
      final mediaTypes = <String, String>{};
      final properties = <String, String>{};
      for (final item in opf.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id == null || id.isEmpty || href == null || href.isEmpty) {
          continue;
        }
        final resolved = _resolveEpubPath(opfPath, href);
        manifestItems[id] = resolved;
        mediaTypes[id] = item.getAttribute('media-type') ?? '';
        properties[id] = item.getAttribute('properties') ?? '';
      }

      final ncxPaths = <String>{};
      for (final spine in opf.findAllElements('spine')) {
        final tocId = spine.getAttribute('toc');
        final tocPath = tocId == null ? null : manifestItems[tocId];
        if (tocPath != null && tocPath.isNotEmpty) ncxPaths.add(tocPath);
      }
      for (final entry in manifestItems.entries) {
        final id = entry.key;
        final path = entry.value;
        final mediaType = mediaTypes[id] ?? '';
        final lower = path.toLowerCase();
        if (mediaType == 'application/x-dtbncx+xml' ||
            lower.endsWith('.ncx')) {
          ncxPaths.add(path);
        }
      }

      for (final ncxPath in ncxPaths) {
        final ncxText = _readArchiveText(archive, ncxPath);
        if (ncxText == null || ncxText.trim().isEmpty) continue;
        _collectEpubNcxIndex(archive, ncxPath, ncxText, chunks, entries);
      }

      // Se l'NCX ha già prodotto voci valide, manteniamo quell'ordine: è il
      // più fedele all'indice del libro. La nav HTML viene usata come ripiego.
      if (entries.isNotEmpty) return;

      final navPaths = <String>{};
      for (final entry in manifestItems.entries) {
        final id = entry.key;
        final path = entry.value;
        final prop = properties[id] ?? '';
        final lower = path.toLowerCase();
        if (prop.split(RegExp(r'\s+')).contains('nav') ||
            lower.contains('toc') ||
            lower.contains('indice') ||
            lower.contains('contents')) {
          if (lower.endsWith('.xhtml') ||
              lower.endsWith('.html') ||
              lower.endsWith('.htm')) {
            navPaths.add(path);
          }
        }
      }
      for (final navPath in navPaths) {
        final navText = _readArchiveText(archive, navPath);
        if (navText == null || navText.trim().isEmpty) continue;
        _collectEpubHtmlNavIndex(archive, navPath, navText, chunks, entries);
      }
    } catch (e, st) {
      dev.log(
        'DocumentTextExtractor: indice EPUB archivio non disponibile',
        error: e,
        stackTrace: st,
      );
    }
  }

  String? _findEpubOpfPath(Archive archive) {
    final containerText = _readArchiveText(archive, 'META-INF/container.xml');
    if (containerText == null || containerText.trim().isEmpty) return null;
    final container = xml_pkg.XmlDocument.parse(containerText);
    for (final rootfile in container.findAllElements('rootfile')) {
      final path = rootfile.getAttribute('full-path');
      if (path != null && path.trim().isNotEmpty) {
        return _normalizeEpubZipPath(Uri.decodeFull(path.trim()));
      }
    }
    return null;
  }

  void _collectEpubNcxIndex(
    Archive archive,
    String ncxPath,
    String ncxText,
    List<String> chunks,
    List<DocumentTableOfContentsEntry> entries,
  ) {
    final ncx = xml_pkg.XmlDocument.parse(ncxText);
    for (final navMap in ncx.findAllElements('navMap')) {
      for (final navPoint in _childElementsByLocalName(navMap, 'navPoint')) {
        _collectEpubNcxNavPoint(
          archive,
          ncxPath,
          navPoint,
          chunks,
          entries,
          0,
        );
      }
    }
  }

  void _collectEpubNcxNavPoint(
    Archive archive,
    String ncxPath,
    xml_pkg.XmlElement navPoint,
    List<String> chunks,
    List<DocumentTableOfContentsEntry> entries,
    int level,
  ) {
    final label = _cleanEpubTitle(_readEpubNcxLabel(navPoint));
    final content = _childElementsByLocalName(navPoint, 'content').firstOrNull;
    final src = content?.getAttribute('src') ?? '';
    if (label.isNotEmpty && src.trim().isNotEmpty) {
      _addEpubIndexEntryForReference(
        archive: archive,
        basePath: ncxPath,
        reference: src,
        title: label,
        level: level,
        chunks: chunks,
        entries: entries,
      );
    }

    for (final child in _childElementsByLocalName(navPoint, 'navPoint')) {
      _collectEpubNcxNavPoint(
        archive,
        ncxPath,
        child,
        chunks,
        entries,
        level + 1,
      );
    }
  }

  String _readEpubNcxLabel(xml_pkg.XmlElement navPoint) {
    final navLabel = _childElementsByLocalName(navPoint, 'navLabel').firstOrNull;
    final text = navLabel == null
        ? null
        : _childElementsByLocalName(navLabel, 'text').firstOrNull;
    return text?.innerText ?? '';
  }

  void _collectEpubHtmlNavIndex(
    Archive archive,
    String navPath,
    String navText,
    List<String> chunks,
    List<DocumentTableOfContentsEntry> entries,
  ) {
    final linkRegex = RegExp(
      r'''<a\b[^>]*href\s*=\s*(["\'])(.*?)\1[^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in linkRegex.allMatches(navText)) {
      final href = match.group(2) ?? '';
      final title = _cleanEpubTitle(_stripHtml(match.group(3) ?? ''));
      if (title.isEmpty || href.trim().isEmpty) continue;
      _addEpubIndexEntryForReference(
        archive: archive,
        basePath: navPath,
        reference: href,
        title: title,
        level: 0,
        chunks: chunks,
        entries: entries,
      );
    }
  }

  void _addEpubIndexEntryForReference({
    required Archive archive,
    required String basePath,
    required String reference,
    required String title,
    required int level,
    required List<String> chunks,
    required List<DocumentTableOfContentsEntry> entries,
  }) {
    final candidates = _epubTocCandidatesForReference(
      archive: archive,
      basePath: basePath,
      reference: reference,
      title: title,
    );
    final chunkIndex = _findChunkIndexForCandidates(chunks, candidates);
    if (chunkIndex == null) return;
    entries.add(
      DocumentTableOfContentsEntry(
        title: title,
        chunkIndex: chunkIndex,
        level: level.clamp(0, 3).toInt(),
      ),
    );
  }

  List<String> _epubTocCandidatesForReference({
    required Archive archive,
    required String basePath,
    required String reference,
    required String title,
  }) {
    final candidates = <String>[];
    final refParts = reference.split('#');
    final href = refParts.first.trim();
    final fragment = refParts.length > 1 ? refParts.sublist(1).join('#') : '';
    if (href.isNotEmpty) {
      final htmlPath = _resolveEpubPath(basePath, href);
      final html = _readArchiveText(archive, htmlPath);
      if (html != null && html.isNotEmpty) {
        if (fragment.isNotEmpty) {
          candidates.addAll(_epubFragmentCandidates(html, fragment));
        }
        candidates.addAll(_cleanEpubHtmlLines(html).take(6));
      }
    }
    if (title.isNotEmpty) candidates.add(title);
    return candidates;
  }

  List<String> _epubFragmentCandidates(String html, String fragment) {
    final variants = <String>{
      fragment,
      Uri.decodeComponent(fragment),
      Uri.decodeFull(fragment),
    };
    for (final variant in variants) {
      if (variant.isEmpty) continue;
      final escaped = RegExp.escape(variant);
      final attrRegex = RegExp(
        "(?:id|name)\\s*=\\s*([\"'])$escaped\\1",
        caseSensitive: false,
      );
      final match = attrRegex.firstMatch(html);
      if (match == null) continue;
      final tagStart = html.lastIndexOf('<', match.start);
      final start = tagStart >= 0 ? tagStart : match.start;
      final end = (start + 6000).clamp(0, html.length).toInt();
      final lines = _cleanEpubHtmlLines(html.substring(start, end));
      if (lines.isNotEmpty) return lines.take(8).toList();
    }
    return const [];
  }

  Iterable<xml_pkg.XmlElement> _childElementsByLocalName(
    xml_pkg.XmlElement element,
    String localName,
  ) {
    return element.children
        .whereType<xml_pkg.XmlElement>()
        .where((child) => child.name.local == localName);
  }

  String? _readArchiveText(Archive archive, String path) {
    final file = _findArchiveFile(archive, path);
    if (file == null || file.isFile == false) return null;
    final content = file.content;
    if (content is List<int>) {
      return utf8.decode(content, allowMalformed: true);
    }
    return null;
  }

  ArchiveFile? _findArchiveFile(Archive archive, String path) {
    final normalized = _normalizeEpubZipPath(path);
    for (final file in archive.files) {
      if (_normalizeEpubZipPath(file.name) == normalized) return file;
    }
    final basename = p.url.basename(normalized);
    for (final file in archive.files) {
      if (p.url.basename(_normalizeEpubZipPath(file.name)) == basename) {
        return file;
      }
    }
    return null;
  }

  String _resolveEpubPath(String basePath, String reference) {
    final pathOnly = reference.split('#').first.trim();
    if (pathOnly.isEmpty) return '';
    final decoded = Uri.decodeFull(pathOnly).replaceAll('\\', '/');
    final baseDir = p.url.dirname(_normalizeEpubZipPath(basePath));
    final resolved = baseDir == '.' || baseDir.isEmpty
        ? decoded
        : p.url.join(baseDir, decoded);
    return _normalizeEpubZipPath(p.url.normalize(resolved));
  }

  String _normalizeEpubZipPath(String path) {
    var value = path.replaceAll('\\', '/').trim();
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    return p.url.normalize(value);
  }

  void _collectEpubChapterIndex(
    EpubChapter chapter,
    List<String> chunks,
    List<DocumentTableOfContentsEntry> entries,
    int level,
  ) {
    final title = _cleanEpubTitle(chapter.Title ?? '');
    final lines = _cleanEpubHtmlLines(chapter.HtmlContent ?? '');
    final candidates = <String>[
      if (title.isNotEmpty) title,
      ...lines.where((line) => line.length >= 3).take(3),
    ];
    final chunkIndex = _findChunkIndexForCandidates(chunks, candidates);
    if (title.isNotEmpty && chunkIndex != null) {
      entries.add(
        DocumentTableOfContentsEntry(
          title: title,
          chunkIndex: chunkIndex,
          level: level.clamp(0, 3).toInt(),
        ),
      );
    }

    final subChapters = chapter.SubChapters;
    if (subChapters != null) {
      for (final sub in subChapters) {
        _collectEpubChapterIndex(sub, chunks, entries, level + 1);
      }
    }
  }

  void _collectEpubHeadingIndex(
    EpubBook book,
    List<String> chunks,
    List<DocumentTableOfContentsEntry> entries,
  ) {
    final content = book.Content?.Html;
    if (content == null || content.isEmpty) return;
    final headingRegex = RegExp(
      r'<h([1-3])[^>]*>(.*?)</h\1>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final html in _orderedEpubHtmlContents(book)) {
      for (final match in headingRegex.allMatches(html)) {
        final level = int.tryParse(match.group(1) ?? '1') ?? 1;
        final title = _cleanEpubTitle(_stripHtml(match.group(2) ?? ''));
        if (title.isEmpty) continue;
        final chunkIndex = _findChunkIndexForCandidates(chunks, [title]);
        if (chunkIndex == null) continue;
        entries.add(
          DocumentTableOfContentsEntry(
            title: title,
            chunkIndex: chunkIndex,
            level: (level - 1).clamp(0, 3).toInt(),
          ),
        );
      }
    }
  }

  List<String> _orderedEpubHtmlContents(EpubBook book) {
    final content = book.Content?.Html;
    if (content == null || content.isEmpty) return const [];

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
    final htmls = <String>[];
    final hrefs = orderedHrefs.isEmpty ? content.keys : orderedHrefs;
    for (final href in hrefs) {
      final file = content[href] ?? content[p.basename(href)];
      final html = file?.Content;
      if (html == null || html.isEmpty || !seen.add(href)) continue;
      htmls.add(html);
    }
    return htmls;
  }

  int? _findChunkIndexForCandidates(
    List<String> chunks,
    Iterable<String> candidates,
  ) {
    final normalizedChunks = chunks.map(_normalizeForSearch).toList();
    for (final candidate in candidates) {
      final normalized = _normalizeForSearch(candidate);
      if (normalized.length < 3) continue;
      final needles = <String>{
        normalized,
        if (normalized.length > 140) normalized.substring(0, 140).trim(),
      };
      for (final needle in needles) {
        if (needle.length < 3) continue;
        for (var i = 0; i < normalizedChunks.length; i++) {
          if (normalizedChunks[i].contains(needle)) return i;
        }
      }
    }
    return null;
  }

  String _normalizeForSearch(String value) =>
      _collapseWhitespace(normalizeDocumentUnicode(value)).toLowerCase();

  String _cleanEpubTitle(String value) {
    final title = _collapseWhitespace(normalizeDocumentUnicode(value));
    if (title.isEmpty || _isEpubMetadataNoiseLine(title)) return '';
    return title;
  }

  Future<ExtractionResult> _extractEpub(
    String path, {
    required bool includeFootnotesInText,
    required String footnoteLabel,
  }) async {
    final bytes = await File(path).readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final body = StringBuffer();
    if (includeFootnotesInText) {
      _appendEpubArchiveSpineContent(
        bytes,
        body,
        footnoteLabel: footnoteLabel,
      );
    }
    if (body.toString().trim().isEmpty) {
      _appendEpubSpineContent(book, body);
    }

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
    return ExtractionResult(text: normalizeDocumentUnicode(text));
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
    var wrote = false;
    for (final line in _cleanEpubHtmlLines(html)) {
      buffer.writeln(line);
      wrote = true;
    }
    if (wrote) buffer.writeln();
  }

  void _appendEpubArchiveSpineContent(
    List<int> bytes,
    StringBuffer buffer, {
    required String footnoteLabel,
  }) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final opfPath = _findEpubOpfPath(archive);
      if (opfPath == null || opfPath.isEmpty) return;

      final opfText = _readArchiveText(archive, opfPath);
      if (opfText == null || opfText.trim().isEmpty) return;
      final opf = xml_pkg.XmlDocument.parse(opfText);

      final manifestItems = <String, String>{};
      final mediaTypes = <String, String>{};
      for (final item in opf.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id == null || id.isEmpty || href == null || href.isEmpty) {
          continue;
        }
        manifestItems[id] = _resolveEpubPath(opfPath, href);
        mediaTypes[id] = item.getAttribute('media-type') ?? '';
      }

      final orderedPaths = <String>[];
      for (final itemref in opf.findAllElements('itemref')) {
        final idRef = itemref.getAttribute('idref');
        if (idRef == null || idRef.isEmpty) continue;
        final path = manifestItems[idRef];
        if (path == null || path.isEmpty) continue;
        final mediaType = mediaTypes[idRef] ?? '';
        final lower = path.toLowerCase();
        if (mediaType.contains('html') ||
            lower.endsWith('.xhtml') ||
            lower.endsWith('.html') ||
            lower.endsWith('.htm')) {
          orderedPaths.add(path);
        }
      }

      final seen = <String>{};
      final cache = <String, Map<String, String>>{};
      for (final htmlPath in orderedPaths) {
        if (!seen.add(_normalizeEpubZipPath(htmlPath))) continue;
        final html = _readArchiveText(archive, htmlPath);
        if (html == null || html.trim().isEmpty) continue;
        _appendCleanEpubHtmlWithFootnotes(
          html,
          buffer,
          archive: archive,
          htmlPath: htmlPath,
          footnoteLabel: footnoteLabel,
          footnoteCache: cache,
        );
      }
    } catch (e, st) {
      dev.log(
        'DocumentTextExtractor: note EPUB inline non disponibili',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _appendCleanEpubHtmlWithFootnotes(
    String html,
    StringBuffer buffer, {
    required Archive archive,
    required String htmlPath,
    required String footnoteLabel,
    required Map<String, Map<String, String>> footnoteCache,
  }) {
    final lines = _cleanEpubHtmlLinesWithFootnotes(
      html,
      archive: archive,
      htmlPath: htmlPath,
      footnoteLabel: footnoteLabel,
      footnoteCache: footnoteCache,
    );
    for (final line in lines) {
      // Quando l'opzione "includi note nel testo" è attiva, ogni blocco
      // estratto dall'EPUB deve diventare un paragrafo reale per il lettore
      // documenti e per il TTS. DocumentReaderScreen/EdgeTtsBridge dividono i
      // paragrafi su doppio a capo: se qui usiamo un solo a capo, il richiamo
      // e la riga "Nota a piè di pagina N: ..." possono finire nello stesso
      // chunk del paragrafo precedente o successivo.
      // La riga vuota dopo ogni blocco è intenzionale: mantiene le note
      // incluse come paragrafi separati e navigabili, senza unirle al testo.
      buffer.writeln(line);
      buffer.writeln();
    }
  }

  List<String> _cleanEpubHtmlLinesWithFootnotes(
    String html, {
    required Archive archive,
    required String htmlPath,
    required String footnoteLabel,
    required Map<String, Map<String, String>> footnoteCache,
  }) {
    // Prima passata testuale: su alcuni EPUB l'XML è formalmente valido, ma
    // la serializzazione dei tag vuoti usati come ancora (<a id="..."/>) può
    // rendere intermittente il collegamento tra richiamo e nota. La passata
    // regex lavora sull'HTML originale e mantiene l'ordine dei blocchi, quindi
    // recupera meglio casi come il Decameron BUR 2013.
    final regexLines = _cleanEpubHtmlLinesWithFootnotesByRegex(
      html,
      archive: archive,
      htmlPath: htmlPath,
      footnoteLabel: footnoteLabel,
      footnoteCache: footnoteCache,
    );
    if (regexLines.isNotEmpty) return regexLines;

    try {
      final document = xml_pkg.XmlDocument.parse(html);
      final footnotes = _epubFootnotesForHtml(
        archive: archive,
        htmlPath: htmlPath,
        html: html,
        cache: footnoteCache,
      );
      final lines = <String>[];
      final blockTags = {
        'p',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'li',
        'blockquote',
      };
      for (final element in document.descendants.whereType<xml_pkg.XmlElement>()) {
        final local = element.name.local.toLowerCase();
        if (!blockTags.contains(local)) continue;
        if (_isInsideEpubHeadOrFootnotes(element)) continue;
        final blockHtml = element.toXmlString();
        final text = _cleanEpubTextLine(_stripHtml(blockHtml));
        if (text.isEmpty) continue;
        lines.add(text);

        final seenRefs = <String>{};
        for (final ref in _extractEpubFootnoteReferences(blockHtml)) {
          final note = _lookupEpubFootnote(
            ref,
            archive: archive,
            currentHtmlPath: htmlPath,
            localFootnotes: footnotes,
            cache: footnoteCache,
          );
          if (note == null || note.text.isEmpty) continue;
          final key = '${note.id}|${note.text}';
          if (!seenRefs.add(key)) continue;
          final label = note.number.isEmpty
              ? footnoteLabel
              : '$footnoteLabel ${note.number}';
          lines.add('$label: ${note.text}');
        }
      }
      if (lines.isNotEmpty) return lines;
    } catch (_) {
      // Alcuni EPUB contengono HTML non perfettamente XML: in quel caso si
      // usa il parser testuale storico senza note inline.
    }
    return _cleanEpubHtmlLines(html);
  }

  List<String> _cleanEpubHtmlLinesWithFootnotesByRegex(
    String html, {
    required Archive archive,
    required String htmlPath,
    required String footnoteLabel,
    required Map<String, Map<String, String>> footnoteCache,
  }) {
    final footnotes = _epubFootnotesForHtml(
      archive: archive,
      htmlPath: htmlPath,
      html: html,
      cache: footnoteCache,
    );
    final contentHtml = _removeEpubFootnoteBlocksFromHtml(html);
    final blockRegex = RegExp(
      r'''<(p|h[1-6]|li|blockquote)\b[^>]*>.*?</\1>''',
      caseSensitive: false,
      dotAll: true,
    );
    final lines = <String>[];
    for (final match in blockRegex.allMatches(contentHtml)) {
      final blockHtml = match.group(0) ?? '';
      if (_looksLikeEpubFootnoteDefinitionBlock(blockHtml)) continue;
      final text = _cleanEpubTextLine(_stripHtml(blockHtml));
      if (text.isEmpty) continue;
      lines.add(text);

      final seenRefs = <String>{};
      for (final ref in _extractEpubFootnoteReferences(blockHtml)) {
        final note = _lookupEpubFootnote(
          ref,
          archive: archive,
          currentHtmlPath: htmlPath,
          localFootnotes: footnotes,
          cache: footnoteCache,
        );
        if (note == null || note.text.isEmpty) continue;
        final key = '${note.id}|${note.text}';
        if (!seenRefs.add(key)) continue;
        final label = note.number.isEmpty
            ? footnoteLabel
            : '$footnoteLabel ${note.number}';
        lines.add('$label: ${note.text}');
      }
    }
    return lines;
  }

  String _removeEpubFootnoteBlocksFromHtml(String html) {
    var cleaned = html;
    final containerRegex = RegExp(
      r'''<(?:div|section|aside)\b(?=[^>]*(?:class|epub:type|type|id)\s*=\s*(["\'])[^"\']*(?:footnotes|endnotes|footnote|endnote)[^"\']*\1)[^>]*>.*?</(?:div|section|aside)>''',
      caseSensitive: false,
      dotAll: true,
    );
    cleaned = cleaned.replaceAll(containerRegex, ' ');

    final paragraphRegex = RegExp(
      r'''<(?:p|li)\b(?=[^>]*(?:class|epub:type|type|id)\s*=\s*(["\'])[^"\']*(?:footnote|endnote|fn|ftn)[^"\']*\1)[^>]*>.*?</(?:p|li)>''',
      caseSensitive: false,
      dotAll: true,
    );
    return cleaned.replaceAll(paragraphRegex, ' ');
  }

  bool _looksLikeEpubFootnoteDefinitionBlock(String html) {
    final openingTag = RegExp(
      r'''^\s*<(?:p|li|div|section|aside)\b[^>]*(?:class|epub:type|type|id)\s*=\s*(["\'])[^"\']*(?:footnote|endnote|fn|ftn)[^"\']*\1''',
      caseSensitive: false,
      dotAll: true,
    );
    return openingTag.hasMatch(html);
  }

  String _cleanEpubTextLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty ||
        _isEpubMetadataNoiseLine(trimmed) ||
        (trimmed.startsWith('part') && trimmed.length <= 12)) {
      return '';
    }
    return trimmed;
  }

  bool _isInsideEpubHeadOrFootnotes(xml_pkg.XmlElement element) {
    xml_pkg.XmlElement? current = element;
    while (current != null) {
      final local = current.name.local.toLowerCase();
      if (local == 'head') return true;
      if (_isEpubFootnoteContainer(current)) return true;
      final parent = current.parent;
      current = parent is xml_pkg.XmlElement ? parent : null;
    }
    return false;
  }

  Map<String, String> _epubFootnotesForHtml({
    required Archive archive,
    required String htmlPath,
    required String html,
    required Map<String, Map<String, String>> cache,
  }) {
    final normalizedPath = _normalizeEpubZipPath(htmlPath);
    final cached = cache[normalizedPath];
    if (cached != null) return cached;
    final parsed = _extractEpubFootnotesFromHtml(html);
    cache[normalizedPath] = parsed;
    return parsed;
  }

  Map<String, String> _extractEpubFootnotesFromHtml(String html) {
    final result = <String, String>{};
    try {
      final document = xml_pkg.XmlDocument.parse(html);
      for (final element in document.descendants.whereType<xml_pkg.XmlElement>()) {
        if (_isSpecificEpubFootnoteDefinition(element)) {
          _addEpubFootnoteDefinition(result, element);
          continue;
        }

        // Alcuni EPUB, come Decameron Einaudi, hanno un contenitore
        // <div id="footnotes"> con dentro semplici <p> senza class="footnote".
        // Non dobbiamo associare l'intero contenitore a ogni nota: leggiamo
        // ogni blocco figlio separatamente.
        if (_isGenericEpubFootnoteContainer(element)) {
          for (final child in _childElementsByLocalName(element, 'p')) {
            _addEpubFootnoteDefinition(result, child);
          }
          for (final child in _childElementsByLocalName(element, 'div')) {
            _addEpubFootnoteDefinition(result, child);
          }
        }
      }
    } catch (_) {
      // Se il parsing XML fallisce, sotto resta comunque il fallback regex.
    }
    _extractEpubFootnotesWithRegex(html, result);
    return result;
  }

  void _addEpubFootnoteDefinition(
    Map<String, String> result,
    xml_pkg.XmlElement element,
  ) {
    final ids = _epubFootnoteIdsForElement(element);
    if (ids.isEmpty) return;
    final text = _cleanEpubFootnoteText(_stripHtml(element.toXmlString()));
    if (text.isEmpty) return;
    for (final id in ids) {
      result[id] = text;
    }
  }

  bool _isEpubFootnoteContainer(xml_pkg.XmlElement element) {
    return _isGenericEpubFootnoteContainer(element) ||
        _isSpecificEpubFootnoteDefinition(element);
  }

  bool _isGenericEpubFootnoteContainer(xml_pkg.XmlElement element) {
    final id = (element.getAttribute('id') ?? '').toLowerCase();
    final clazz = (element.getAttribute('class') ?? '').toLowerCase();
    final epubType = (element.getAttribute('epub:type') ??
            element.getAttribute('type') ??
            '')
        .toLowerCase();
    return id == 'footnotes' ||
        id == 'notes' ||
        clazz.split(RegExp(r'\s+')).contains('footnotes') ||
        epubType.split(RegExp(r'\s+')).contains('footnotes');
  }

  bool _isSpecificEpubFootnoteDefinition(xml_pkg.XmlElement element) {
    final id = (element.getAttribute('id') ?? '').toLowerCase();
    final name = (element.getAttribute('name') ?? '').toLowerCase();
    final clazz = (element.getAttribute('class') ?? '').toLowerCase();
    final epubType = (element.getAttribute('epub:type') ??
            element.getAttribute('type') ??
            '')
        .toLowerCase();
    if (_isGenericEpubFootnoteContainer(element)) return false;
    final classTokens = clazz.split(RegExp(r'\s+'));
    final typeTokens = epubType.split(RegExp(r'\s+'));
    return classTokens.contains('footnote') ||
        classTokens.contains('endnote') ||
        typeTokens.contains('footnote') ||
        typeTokens.contains('endnote') ||
        _looksLikeEpubFootnoteId(id) ||
        _looksLikeEpubFootnoteId(name) ||
        id.contains('footnote') ||
        id.contains('endnote') ||
        name.contains('footnote') ||
        name.contains('endnote');
  }

  bool _looksLikeEpubFootnoteId(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty || lower == 'footnotes' || lower == 'notes') {
      return false;
    }

    // Formati classici: fn1, ftn2, note3, int-fn4, ref_ftn_fn1423.
    if (RegExp(r'(^|[-_:.])(fn|ftn|note|endnote|noteref|n)\d+[a-z]?(?:$|[-_:.])')
        .hasMatch(lower)) {
      return true;
    }

    // Formati compatti usati da alcuni EPUB BUR: fm04fn2, p01introfn1.
    if (RegExp(r'(?:^|[a-z0-9])(fn|ftn|note|endnote)\d+[a-z]?$')
        .hasMatch(lower)) {
      return true;
    }

    return lower.startsWith('fn') || lower.startsWith('ftn');
  }

  List<String> _epubFootnoteIdsForElement(xml_pkg.XmlElement element) {
    final ids = <String>[];
    void addId(String? id) {
      if (id == null || id.trim().isEmpty) return;
      final value = id.trim();
      final lower = value.toLowerCase();
      if (lower.startsWith('ref_') || lower.startsWith('rfn')) return;
      if (lower.startsWith('ffn')) return;
      if (lower == 'footnotes' || lower == 'notes') return;
      if (!_looksLikeEpubFootnoteId(lower) &&
          !lower.contains('footnote') &&
          !lower.contains('endnote')) {
        return;
      }
      if (!ids.contains(value)) ids.add(value);
    }

    addId(element.getAttribute('id'));
    for (final child in element.descendants.whereType<xml_pkg.XmlElement>()) {
      final local = child.name.local.toLowerCase();
      if (local != 'a') continue;
      addId(child.getAttribute('id'));
      addId(child.getAttribute('name'));
    }
    return ids;
  }

  void _extractEpubFootnotesWithRegex(
    String html,
    Map<String, String> result,
  ) {
    final regex = RegExp(
      r'''<(?:div|p|aside|section)\b[^>]*(?:class|epub:type|id)\s*=\s*(["\'])[^"\']*(?:footnote|endnote|fn)[^"\']*\1[^>]*>(.*?)</(?:div|p|aside|section)>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in regex.allMatches(html)) {
      final block = match.group(0) ?? '';
      final idMatch = RegExp(
        r'''\b(?:id|name)\s*=\s*(["\'])([^"\']+)\1''',
        caseSensitive: false,
      ).firstMatch(block);
      final id = idMatch?.group(2)?.trim();
      if (id == null || id.isEmpty || !_looksLikeEpubFootnoteId(id)) {
        continue;
      }
      final text = _cleanEpubFootnoteText(_stripHtml(block));
      if (text.isNotEmpty) result[id] = text;
    }

    // Seconda passata: alcuni EPUB hanno note compatte tipo
    // <p class="footnote" id="fm04fn2">...</p>. Se prima è stato
    // catturato il contenitore esterno, questa passata sovrascrive con il
    // testo della singola nota, molto più preciso.
    final singleNoteRegex = RegExp(
      r'''<(p|li|div|aside|section)\b(?=[^>]*\b(?:id|name)\s*=\s*(["\'])([^"\']+)\2)[^>]*>.*?</\1>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in singleNoteRegex.allMatches(html)) {
      final block = match.group(0) ?? '';
      final id = match.group(3)?.trim();
      if (id == null || id.isEmpty || !_looksLikeEpubFootnoteId(id)) {
        continue;
      }
      final text = _cleanEpubFootnoteText(_stripHtml(block));
      if (text.isNotEmpty) result[id] = text;
    }
  }

  String _cleanEpubFootnoteText(String value) {
    var text = _collapseWhitespace(normalizeDocumentUnicode(value));
    text = text.replaceFirst(RegExp(r'^\s*[\*\d]+\s*[\.)]?\s*'), '');
    return text.trim();
  }

  List<_EpubFootnoteReference> _extractEpubFootnoteReferences(String html) {
    final refs = <_EpubFootnoteReference>[];
    final linkRegex = RegExp(
      r'''<a\b[^>]*href\s*=\s*(["\'])(.*?)\1[^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in linkRegex.allMatches(html)) {
      final href = match.group(2)?.trim() ?? '';
      if (!href.contains('#')) continue;
      final number = _collapseWhitespace(_stripHtml(match.group(3) ?? ''));
      refs.add(_EpubFootnoteReference(href: href, number: number));
    }
    return refs;
  }

  _ResolvedEpubFootnote? _lookupEpubFootnote(
    _EpubFootnoteReference ref, {
    required Archive archive,
    required String currentHtmlPath,
    required Map<String, String> localFootnotes,
    required Map<String, Map<String, String>> cache,
  }) {
    final parts = ref.href.split('#');
    final hrefPath = parts.first.trim();
    final rawFragment = parts.length > 1 ? parts.sublist(1).join('#') : '';
    if (rawFragment.isEmpty) return null;
    final fragmentVariants = <String>{
      rawFragment,
      Uri.decodeComponent(rawFragment),
      Uri.decodeFull(rawFragment),
    };

    Map<String, String> footnotes;
    if (hrefPath.isEmpty) {
      footnotes = localFootnotes;
    } else {
      final externalPath = _resolveEpubPath(currentHtmlPath, hrefPath);
      final externalHtml = _readArchiveText(archive, externalPath);
      if (externalHtml == null || externalHtml.trim().isEmpty) return null;
      footnotes = _epubFootnotesForHtml(
        archive: archive,
        htmlPath: externalPath,
        html: externalHtml,
        cache: cache,
      );
    }

    for (final fragment in fragmentVariants) {
      final text = footnotes[fragment];
      if (text != null && text.trim().isNotEmpty) {
        return _ResolvedEpubFootnote(
          id: fragment,
          number: ref.number,
          text: text.trim(),
        );
      }
    }
    return null;
  }

  List<String> _cleanEpubHtmlLines(String html) {
    final text = _stripHtml(html);
    final lines = <String>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          _isEpubMetadataNoiseLine(trimmed) ||
          (trimmed.startsWith('part') && trimmed.length <= 12)) {
        continue;
      }
      lines.add(trimmed);
    }
    return lines;
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
        // Molti EPUB ripetono <title>Nome opera</title> nell'head di ogni
        // file XHTML. Se non rimuoviamo l'head, quel titolo viene letto prima
        // di ogni capitolo, ad esempio "Decameron 1 Ser Cepparello".
        .replaceAll(
          RegExp(r'<head[^>]*>.*?</head>', dotAll: true, caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<title[^>]*>.*?</title>', dotAll: true, caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<script[^>]*>.*?</script>', dotAll: true, caseSensitive: false),
          ' ',
        )
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

class _EpubFootnoteReference {
  final String href;
  final String number;

  const _EpubFootnoteReference({
    required this.href,
    required this.number,
  });
}

class _ResolvedEpubFootnote {
  final String id;
  final String number;
  final String text;

  const _ResolvedEpubFootnote({
    required this.id,
    required this.number,
    required this.text,
  });
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

const _windows1257 = <int?>[
  0x20AC, null, 0x201A, null, 0x201E, 0x2026, 0x2020, 0x2021,
  null, 0x2030, null, 0x2039, null, 0x00A8, 0x02C7, 0x00B8,
  null, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  null, 0x2122, null, 0x203A, null, 0x00AF, 0x02DB, null,
  0x00A0, null, 0x00A2, 0x00A3, 0x00A4, null, 0x00A6, 0x00A7,
  0x00D8, 0x00A9, 0x0156, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00C6,
  0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7,
  0x00F8, 0x00B9, 0x0157, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x00E6,
  0x0104, 0x012E, 0x0100, 0x0106, 0x00C4, 0x00C5, 0x0118, 0x0112,
  0x010C, 0x00C9, 0x0179, 0x0116, 0x0122, 0x0136, 0x012A, 0x013B,
  0x0160, 0x0143, 0x0145, 0x00D3, 0x014C, 0x00D5, 0x00D6, 0x00D7,
  0x0172, 0x0141, 0x015A, 0x016A, 0x00DC, 0x017B, 0x017D, 0x00DF,
  0x0105, 0x012F, 0x0101, 0x0107, 0x00E4, 0x00E5, 0x0119, 0x0113,
  0x010D, 0x00E9, 0x017A, 0x0117, 0x0123, 0x0137, 0x012B, 0x013C,
  0x0161, 0x0144, 0x0146, 0x00F3, 0x014D, 0x00F5, 0x00F6, 0x00F7,
  0x0173, 0x0142, 0x015B, 0x016B, 0x00FC, 0x017C, 0x017E, 0x02D9,
];

const _windows1258 = <int?>[
  0x20AC, null, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
  0x02C6, 0x2030, null, 0x2039, 0x0152, null, null, null,
  null, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0x02DC, 0x2122, null, 0x203A, 0x0153, null, null, 0x0178,
  0x00A0, 0x00A1, 0x00A2, 0x00A3, 0x00A4, 0x00A5, 0x00A6, 0x00A7,
  0x00A8, 0x00A9, 0x00AA, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00AF,
  0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7,
  0x00B8, 0x00B9, 0x00BA, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x00BF,
  0x00C0, 0x00C1, 0x00C2, 0x0102, 0x00C4, 0x00C5, 0x00C6, 0x00C7,
  0x00C8, 0x00C9, 0x00CA, 0x00CB, 0x0300, 0x00CD, 0x00CE, 0x00CF,
  0x0110, 0x00D1, 0x0309, 0x00D3, 0x00D4, 0x01A0, 0x00D6, 0x00D7,
  0x00D8, 0x00D9, 0x00DA, 0x00DB, 0x00DC, 0x01AF, 0x0303, 0x00DF,
  0x00E0, 0x00E1, 0x00E2, 0x0103, 0x00E4, 0x00E5, 0x00E6, 0x00E7,
  0x00E8, 0x00E9, 0x00EA, 0x00EB, 0x0301, 0x00ED, 0x00EE, 0x00EF,
  0x0111, 0x00F1, 0x0323, 0x00F3, 0x00F4, 0x01A1, 0x00F6, 0x00F7,
  0x00F8, 0x00F9, 0x00FA, 0x00FB, 0x00FC, 0x01B0, 0x20AB, 0x00FF,
];

const _windows874 = <int?>[
  0x20AC, null, null, null, null, 0x2026, null, null,
  null, null, null, null, null, null, null, null,
  null, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  null, null, null, null, null, null, null, null,
  0x00A0, 0x0E01, 0x0E02, 0x0E03, 0x0E04, 0x0E05, 0x0E06, 0x0E07,
  0x0E08, 0x0E09, 0x0E0A, 0x0E0B, 0x0E0C, 0x0E0D, 0x0E0E, 0x0E0F,
  0x0E10, 0x0E11, 0x0E12, 0x0E13, 0x0E14, 0x0E15, 0x0E16, 0x0E17,
  0x0E18, 0x0E19, 0x0E1A, 0x0E1B, 0x0E1C, 0x0E1D, 0x0E1E, 0x0E1F,
  0x0E20, 0x0E21, 0x0E22, 0x0E23, 0x0E24, 0x0E25, 0x0E26, 0x0E27,
  0x0E28, 0x0E29, 0x0E2A, 0x0E2B, 0x0E2C, 0x0E2D, 0x0E2E, 0x0E2F,
  0x0E30, 0x0E31, 0x0E32, 0x0E33, 0x0E34, 0x0E35, 0x0E36, 0x0E37,
  0x0E38, 0x0E39, 0x0E3A, null, null, null, null, 0x0E3F,
  0x0E40, 0x0E41, 0x0E42, 0x0E43, 0x0E44, 0x0E45, 0x0E46, 0x0E47,
  0x0E48, 0x0E49, 0x0E4A, 0x0E4B, 0x0E4C, 0x0E4D, 0x0E4E, 0x0E4F,
  0x0E50, 0x0E51, 0x0E52, 0x0E53, 0x0E54, 0x0E55, 0x0E56, 0x0E57,
  0x0E58, 0x0E59, 0x0E5A, 0x0E5B, null, null, null, null,
];

const _cp437 = <int?>[
  0x00C7, 0x00FC, 0x00E9, 0x00E2, 0x00E4, 0x00E0, 0x00E5, 0x00E7,
  0x00EA, 0x00EB, 0x00E8, 0x00EF, 0x00EE, 0x00EC, 0x00C4, 0x00C5,
  0x00C9, 0x00E6, 0x00C6, 0x00F4, 0x00F6, 0x00F2, 0x00FB, 0x00F9,
  0x00FF, 0x00D6, 0x00DC, 0x00A2, 0x00A3, 0x00A5, 0x20A7, 0x0192,
  0x00E1, 0x00ED, 0x00F3, 0x00FA, 0x00F1, 0x00D1, 0x00AA, 0x00BA,
  0x00BF, 0x2310, 0x00AC, 0x00BD, 0x00BC, 0x00A1, 0x00AB, 0x00BB,
  0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556,
  0x2555, 0x2563, 0x2551, 0x2557, 0x255D, 0x255C, 0x255B, 0x2510,
  0x2514, 0x2534, 0x252C, 0x251C, 0x2500, 0x253C, 0x255E, 0x255F,
  0x255A, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256C, 0x2567,
  0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256B,
  0x256A, 0x2518, 0x250C, 0x2588, 0x2584, 0x258C, 0x2590, 0x2580,
  0x03B1, 0x00DF, 0x0393, 0x03C0, 0x03A3, 0x03C3, 0x00B5, 0x03C4,
  0x03A6, 0x0398, 0x03A9, 0x03B4, 0x221E, 0x03C6, 0x03B5, 0x2229,
  0x2261, 0x00B1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00F7, 0x2248,
  0x00B0, 0x2219, 0x00B7, 0x221A, 0x207F, 0x00B2, 0x25A0, 0x00A0,
];

const _cp850 = <int?>[
  0x00C7, 0x00FC, 0x00E9, 0x00E2, 0x00E4, 0x00E0, 0x00E5, 0x00E7,
  0x00EA, 0x00EB, 0x00E8, 0x00EF, 0x00EE, 0x00EC, 0x00C4, 0x00C5,
  0x00C9, 0x00E6, 0x00C6, 0x00F4, 0x00F6, 0x00F2, 0x00FB, 0x00F9,
  0x00FF, 0x00D6, 0x00DC, 0x00F8, 0x00A3, 0x00D8, 0x00D7, 0x0192,
  0x00E1, 0x00ED, 0x00F3, 0x00FA, 0x00F1, 0x00D1, 0x00AA, 0x00BA,
  0x00BF, 0x00AE, 0x00AC, 0x00BD, 0x00BC, 0x00A1, 0x00AB, 0x00BB,
  0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x00C1, 0x00C2, 0x00C0,
  0x00A9, 0x2563, 0x2551, 0x2557, 0x255D, 0x00A2, 0x00A5, 0x2510,
  0x2514, 0x2534, 0x252C, 0x251C, 0x2500, 0x253C, 0x00E3, 0x00C3,
  0x255A, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256C, 0x00A4,
  0x00F0, 0x00D0, 0x00CA, 0x00CB, 0x00C8, 0x0131, 0x00CD, 0x00CE,
  0x00CF, 0x2518, 0x250C, 0x2588, 0x2584, 0x00A6, 0x00CC, 0x2580,
  0x00D3, 0x00DF, 0x00D4, 0x00D2, 0x00F5, 0x00D5, 0x00B5, 0x00FE,
  0x00DE, 0x00DA, 0x00DB, 0x00D9, 0x00FD, 0x00DD, 0x00AF, 0x00B4,
  0x00AD, 0x00B1, 0x2017, 0x00BE, 0x00B6, 0x00A7, 0x00F7, 0x00B8,
  0x00B0, 0x00A8, 0x00B7, 0x00B9, 0x00B3, 0x00B2, 0x25A0, 0x00A0,
];

const _macRoman = <int?>[
  0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1,
  0x00E0, 0x00E2, 0x00E4, 0x00E3, 0x00E5, 0x00E7, 0x00E9, 0x00E8,
  0x00EA, 0x00EB, 0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3,
  0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9, 0x00FB, 0x00FC,
  0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF,
  0x00AE, 0x00A9, 0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8,
  0x221E, 0x00B1, 0x2264, 0x2265, 0x00A5, 0x00B5, 0x2202, 0x2211,
  0x220F, 0x03C0, 0x222B, 0x00AA, 0x00BA, 0x03A9, 0x00E6, 0x00F8,
  0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248, 0x2206, 0x00AB,
  0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153,
  0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA,
  0x00FF, 0x0178, 0x2044, 0x20AC, 0x2039, 0x203A, 0xFB01, 0xFB02,
  0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1,
  0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4,
  0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC,
  0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7,
];

class _RtfPlainTextParser {
  /// Destinazioni che contengono metadati, formattazione o dati non leggibili.
  ///
  /// Non vengono ignorati i contenitori `field`, `object` e `shp`, perché al
  /// loro interno possono esserci rispettivamente `fldrslt`, `result` e
  /// `shptxt`, cioè testo realmente visibile nel documento.
  static const _ignoredDestinations = <String>{
    'annotation',
    'atnauthor',
    'atndate',
    'atnid',
    'atnparent',
    'author',
    'buptim',
    'category',
    'colortbl',
    'colorschememapping',
    'comment',
    'company',
    'creatim',
    'datafield',
    'datastore',
    'doccomm',
    'docvar',
    'factoidname',
    'falt',
    'filetbl',
    'fldinst',
    'fontemb',
    'fontfile',
    'fonttbl',
    'footer',
    'footerf',
    'footerl',
    'footerr',
    'ftncn',
    'ftnsep',
    'ftnsepc',
    'aftncn',
    'aftnsep',
    'aftnsepc',
    'generator',
    'header',
    'headerf',
    'headerl',
    'headerr',
    'htmltag',
    'info',
    'keycode',
    'keywords',
    'latentstyles',
    'listoverridetable',
    'listtable',
    'manager',
    'mhtmltag',
    'mmathpr',
    'objalias',
    'objclass',
    'objdata',
    'objname',
    'objsect',
    'objtime',
    'operator',
    'panose',
    'pgp',
    'pict',
    'pnseclvl',
    'private',
    'propname',
    'protend',
    'protstart',
    'revtbl',
    'rsidtbl',
    'shpinst',
    'shppict',
    'sn',
    'sp',
    'stylesheet',
    'subject',
    'themedata',
    'title',
    'txe',
    'userprops',
    'xmlattrname',
    'xmlattrvalue',
    'xmlclose',
    'xmlname',
    'xmlnstbl',
    'xmlopen',
  };

  final String source;
  final StringBuffer _buffer = StringBuffer();
  final List<_RtfState> _stack = [_RtfState()];
  final Map<int, int> _fontCodePages = <int, int>{};

  int _index = 0;
  int _fallbackCharsToSkip = 0;
  int _binaryBytesToSkip = 0;
  int? _pendingHighSurrogate;
  int? _defaultFontNumber;

  final List<int> _pendingEncodedBytes = <int>[];
  int? _pendingEncodedCodePage;

  _RtfPlainTextParser(this.source);

  _RtfState get _state => _stack.last;

  String parse() {
    while (_index < source.length) {
      if (_binaryBytesToSkip > 0) {
        final available = source.length - _index;
        final amount = _binaryBytesToSkip < available
            ? _binaryBytesToSkip
            : available;
        _index += amount;
        _binaryBytesToSkip -= amount;
        continue;
      }

      final codeUnit = source.codeUnitAt(_index);
      switch (codeUnit) {
        case 0x7B: // {
          _flushPendingEncodedBytes();
          _fallbackCharsToSkip = 0;
          _openGroup();
          _index++;
          break;
        case 0x7D: // }
          _flushPendingEncodedBytes();
          _fallbackCharsToSkip = 0;
          _closeGroup();
          _index++;
          break;
        case 0x5C: // backslash
          _readControlOrEscapedCharacter();
          break;
        case 0x0D:
        case 0x0A:
          // Gli a-capo presenti nel sorgente RTF servono solo a impaginarlo.
          // I veri a-capo del documento sono \par, \line, \row ecc.
          _flushPendingEncodedBytes();
          _index++;
          break;
        default:
          _appendRawCharacter(codeUnit);
          _index++;
      }
    }
    _flushPendingEncodedBytes();
    _flushPendingHighSurrogate();
    return _buffer.toString();
  }

  void _openGroup() {
    final parent = _state;
    final child = parent.copyForChildGroup();

    // \upr contiene due gruppi: il primo è il fallback ANSI, il secondo è il
    // testo Unicode dentro una destinazione \*\ud. Un lettore Unicode deve
    // scegliere esclusivamente il secondo per evitare duplicazioni o perdita
    // di caratteri non rappresentabili nella code page ANSI.
    if (parent.uprNextChildIndex >= 0) {
      final childIndex = parent.uprNextChildIndex;
      parent.uprNextChildIndex++;
      if (parent.uprNextChildIndex > 1) {
        parent.uprNextChildIndex = -1;
      }
      if (childIndex == 0) {
        child.skipDestination = true;
      } else {
        child.allowUnicodeDestination = true;
        child.skipDestination = false;
      }
    }

    _stack.add(child);
  }

  void _closeGroup() {
    _flushPendingHighSurrogate();
    if (_stack.length <= 1) return;

    final closingState = _state;
    if (closingState.closeText.isNotEmpty &&
        !closingState.skipDestination &&
        !closingState.hidden &&
        !closingState.deleted) {
      _buffer.write(closingState.closeText);
    }
    _stack.removeLast();

    // Quando termina la tabella dei font, applica il font predefinito anche
    // agli RTF che non ripetono esplicitamente \fN all'inizio del corpo.
    // I sottogruppi dei singoli font ereditano la stessa destinazione, quindi
    // interveniamo soltanto quando stiamo uscendo davvero da fonttbl.
    if (closingState.destination == 'fonttbl' &&
        _state.destination != 'fonttbl') {
      final defaultFont = _defaultFontNumber;
      if (defaultFont != null) _selectFont(defaultFont);
    }
  }

  void _readControlOrEscapedCharacter() {
    _index++; // salta il backslash
    if (_index >= source.length) return;

    final marker = source.codeUnitAt(_index);
    if (marker == 0x27) { // '
      _readHexEncodedByte();
      return;
    }

    _flushPendingEncodedBytes();
    if (_isAsciiLetter(marker)) {
      _readControlWord();
      return;
    }

    _readEscapedSymbol(marker);
  }

  void _readHexEncodedByte() {
    _index++; // salta l'apostrofo
    if (_index + 1 >= source.length) {
      _index = source.length;
      return;
    }
    final hex = source.substring(_index, _index + 2);
    final value = int.tryParse(hex, radix: 16);
    _index += 2;
    if (value == null) return;
    if (_consumeUnicodeFallbackCharacter()) return;
    if (_state.skipDestination) return;
    _appendEncodedByte(value);
  }

  void _readControlWord() {
    final start = _index;
    while (_index < source.length && _isAsciiLetter(source.codeUnitAt(_index))) {
      _index++;
    }
    final word = source.substring(start, _index).toLowerCase();

    var sign = 1;
    if (_index < source.length) {
      final codeUnit = source.codeUnitAt(_index);
      if (codeUnit == 0x2D) { // -
        sign = -1;
        _index++;
      } else if (codeUnit == 0x2B) { // +
        _index++;
      }
    }

    int? number;
    final numberStart = _index;
    while (_index < source.length && _isAsciiDigit(source.codeUnitAt(_index))) {
      _index++;
    }
    if (_index > numberStart) {
      number = int.tryParse(source.substring(numberStart, _index));
      if (number != null) number *= sign;
    }

    // Uno spazio dopo un control word è un delimitatore e non fa parte del
    // testo. Gli altri caratteri delimitatori devono invece essere riletti.
    if (_index < source.length && source.codeUnitAt(_index) == 0x20) {
      _index++;
    }

    // Nel fallback ANSI successivo a \uN, ogni control word conta come un
    // solo carattere e non deve alterare lo stato del parser. \binN conta
    // come un carattere, ma richiede comunque di saltare i suoi N byte.
    if (_consumeUnicodeFallbackCharacter()) {
      if (word == 'bin') {
        _binaryBytesToSkip = number != null && number > 0 ? number : 0;
      }
      return;
    }

    _handleControlWord(word, number);
  }

  void _readEscapedSymbol(int marker) {
    _index++;

    // Anche un control symbol rappresenta un solo carattere di fallback.
    if (_consumeUnicodeFallbackCharacter()) {
      if (marker == 0x0D &&
          _index < source.length &&
          source.codeUnitAt(_index) == 0x0A) {
        _index++;
      }
      return;
    }

    switch (marker) {
      case 0x5C: // backslash
      case 0x7B: // {
      case 0x7D: // }
        _appendLiteralCharacter(marker);
        break;
      case 0x7E: // spazio non interrompibile
        _appendText(' ');
        break;
      case 0x5F: // trattino non interrompibile
        _appendText('-');
        break;
      case 0x2D: // trattino opzionale
        break;
      case 0x2A: // destinazione ignorable: il nome arriva subito dopo
        _state.ignorableDestinationPending = true;
        break;
      case 0x3A: // subentry in un indice
        _appendText(':');
        break;
      case 0x7C: // formula delimiter
        _appendText('|');
        break;
      case 0x0D:
        if (_index < source.length && source.codeUnitAt(_index) == 0x0A) {
          _index++;
        }
        break;
      case 0x0A:
        break;
      default:
        _appendLiteralCharacter(marker);
        break;
    }
  }

  void _handleControlWord(String word, int? number) {
    // \binN è seguito da N byte opachi. Possono contenere parentesi e
    // backslash: interpretarli come RTF romperebbe lo stack dei gruppi.
    if (word == 'bin') {
      _binaryBytesToSkip = number != null && number > 0 ? number : 0;
      return;
    }

    if (word == 'ansicpg' && number != null) {
      _state.ansiCodePage = number;
      if (_state.currentFontNumber == null) _state.codePage = number;
      return;
    }
    if (word == 'ansi') {
      _state.ansiCodePage = 1252;
      if (_state.currentFontNumber == null) _state.codePage = 1252;
      return;
    }
    if (word == 'mac') {
      _state.ansiCodePage = 10000;
      _state.codePage = 10000;
      return;
    }
    if (word == 'pc') {
      _state.ansiCodePage = 437;
      _state.codePage = 437;
      return;
    }
    if (word == 'pca') {
      _state.ansiCodePage = 850;
      _state.codePage = 850;
      return;
    }
    if (word == 'deff' && number != null) {
      _defaultFontNumber = number;
      return;
    }
    if (word == 'uc' && number != null) {
      _state.unicodeFallbackLength = number.clamp(0, 32).toInt();
      return;
    }

    // Metadati della tabella font: servono per decodificare correttamente gli
    // escape esadecimali, ma non devono comparire nel testo estratto.
    if (_state.destination == 'fonttbl') {
      if (word == 'f' && number != null) {
        _state.fontDefinitionNumber = number;
        _fontCodePages.putIfAbsent(number, () => _state.ansiCodePage);
        return;
      }
      if (word == 'fcharset' && number != null) {
        final fontNumber = _state.fontDefinitionNumber;
        if (fontNumber != null) {
          _fontCodePages[fontNumber] =
              _codePageForFontCharset(number, _state.ansiCodePage);
        }
        return;
      }
      if (word == 'cpg' && number != null) {
        final fontNumber = _state.fontDefinitionNumber;
        if (fontNumber != null) _fontCodePages[fontNumber] = number;
        return;
      }
    }

    if (word == 'f' || word == 'af') {
      if (number != null) _selectFont(number);
      return;
    }
    if (word == 'cpg' && number != null) {
      _state.codePage = number;
      return;
    }
    if (word == 'plain') {
      _state.hidden = false;
      _state.deleted = false;
      final defaultFont = _defaultFontNumber;
      if (defaultFont != null) {
        _selectFont(defaultFont);
      } else {
        _state.currentFontNumber = null;
        _state.codePage = _state.ansiCodePage;
      }
      return;
    }
    if (word == 'v') {
      _state.hidden = number == null || number != 0;
      return;
    }
    if (word == 'deleted') {
      _state.deleted = number == null || number != 0;
      return;
    }

    // \* dichiara una destinazione che un lettore può ignorare. Facciamo
    // eccezione per \ud quando è il ramo Unicode di \upr.
    if (_state.ignorableDestinationPending) {
      _state.ignorableDestinationPending = false;
      if (word == 'ud' && _state.allowUnicodeDestination) {
        _state.destination = 'ud';
        _state.skipDestination = false;
        return;
      }
      _state.destination = word;
      _state.skipDestination = true;
      return;
    }

    if (word == 'upr') {
      _state.uprNextChildIndex = 0;
      return;
    }
    if (word == 'ud') {
      if (!_state.allowUnicodeDestination) {
        _state.destination = 'ud';
      }
      return;
    }

    // Le vecchie caselle di testo possono trovarsi dentro una destinazione
    // ignorable \do. Il sottogruppo \dptxbxtext contiene però testo visibile.
    if (word == 'dptxbxtext') {
      _state.destination = word;
      _state.skipDestination = false;
      _appendText('\n');
      _state.closeText = '\n';
      return;
    }

    if (_ignoredDestinations.contains(word)) {
      _state.destination = word;
      _state.skipDestination = true;
      return;
    }
    if (_state.skipDestination) return;

    switch (word) {
      case 'u':
        if (number != null) _appendUnicodeCodeUnit(number);
        _fallbackCharsToSkip = _state.unicodeFallbackLength;
        break;
      case 'par':
      case 'line':
      case 'softline':
        _appendText('\n');
        break;
      case 'page':
      case 'sect':
      case 'column':
      case 'softpage':
        _appendText('\n\n');
        break;
      case 'tab':
        _appendCharacterControl('\t');
        break;
      case 'cell':
      case 'nestcell':
        _appendText('\t');
        break;
      case 'row':
      case 'nestrow':
        _appendText('\n');
        break;
      case 'emdash':
        _appendCharacterControl('—');
        break;
      case 'endash':
        _appendCharacterControl('–');
        break;
      case 'emspace':
      case 'enspace':
      case 'qmspace':
        _appendCharacterControl(' ');
        break;
      case 'bullet':
        _appendCharacterControl('•');
        break;
      case 'lquote':
        _appendCharacterControl('‘');
        break;
      case 'rquote':
        _appendCharacterControl('’');
        break;
      case 'ldblquote':
        _appendCharacterControl('“');
        break;
      case 'rdblquote':
        _appendCharacterControl('”');
        break;
      case 'ltrmark':
        _appendCharacterControl('\u200E');
        break;
      case 'rtlmark':
        _appendCharacterControl('\u200F');
        break;
      case 'zwj':
        _appendCharacterControl('\u200D');
        break;
      case 'zwnj':
        _appendCharacterControl('\u200C');
        break;
      case 'footnote':
      case 'endnote':
        _appendText(' (');
        _state.closeText = ')';
        break;
      case 'shptxt':
        _appendText('\n');
        _state.closeText = '\n';
        break;
      case 'chftn':
      case 'chftnsep':
      case 'chftnsepc':
      case 'chatn':
        // Marcatori automatici: il testo della nota viene conservato, il
        // simbolo numerico è gestito dal programma che ha creato l'RTF.
        break;
      default:
        // Formattazione (\b, \i, \fs24, \cf1, \pard...) intenzionalmente
        // ignorata: qui serve soltanto il testo leggibile.
        break;
    }
  }

  void _selectFont(int fontNumber) {
    _state.currentFontNumber = fontNumber;
    _state.codePage = _fontCodePages[fontNumber] ?? _state.ansiCodePage;
  }

  void _appendCharacterControl(String text) {
    if (_consumeUnicodeFallbackCharacter()) return;
    _appendText(text);
  }

  void _appendRawCharacter(int codeUnit) {
    if (_consumeUnicodeFallbackCharacter()) return;
    if (_state.skipDestination || _state.hidden || _state.deleted) return;
    if (codeUnit >= 0x80 && codeUnit <= 0xFF) {
      _appendEncodedByte(codeUnit);
    } else {
      _appendLiteralCharacter(codeUnit);
    }
  }

  void _appendEncodedByte(int value) {
    if (_state.skipDestination || _state.hidden || _state.deleted) return;
    final codePage = _state.codePage;
    if (_pendingEncodedCodePage != codePage) {
      _flushPendingEncodedBytes();
      _pendingEncodedCodePage = codePage;
    }
    _pendingEncodedBytes.add(value);

    // Le code page a byte singolo possono essere emesse subito. Le code page
    // UTF-8/asiatiche devono invece ricevere l'intera sequenza multibyte.
    if (!_isMultibyteCodePage(codePage)) {
      _flushPendingEncodedBytes();
    }
  }

  void _flushPendingEncodedBytes() {
    if (_pendingEncodedBytes.isEmpty) return;
    final bytes = List<int>.from(_pendingEncodedBytes);
    final codePage = _pendingEncodedCodePage ?? _state.codePage;
    _pendingEncodedBytes.clear();
    _pendingEncodedCodePage = null;

    final decoded = _decodeBytesForCodePage(bytes, codePage);
    if (decoded.isNotEmpty &&
        !_state.skipDestination &&
        !_state.hidden &&
        !_state.deleted) {
      _flushPendingHighSurrogate();
      _buffer.write(decoded);
    }
  }

  String _decodeBytesForCodePage(List<int> bytes, int codePage) {
    if (bytes.isEmpty) return '';
    if (codePage == 65001) {
      return utf8.decode(bytes, allowMalformed: true);
    }

    final table = _singleByteTableForCodePage(codePage);
    if (table != null) {
      return DocumentTextExtractor._decodeSingleByte(bytes, table);
    }

    // Le più comuni code page DBCS non hanno un codec nella libreria standard
    // di Dart. Conserviamo almeno l'ASCII e sostituiamo in modo esplicito le
    // sequenze non decodificabili, evitando testo Latin-1 ingannevole.
    if (_isMultibyteCodePage(codePage)) {
      final output = StringBuffer();
      for (final byte in bytes) {
        output.writeCharCode(byte < 0x80 ? byte : 0xFFFD);
      }
      return output.toString();
    }

    return DocumentTextExtractor._decodeSingleByte(bytes, _windows1252);
  }

  List<int?>? _singleByteTableForCodePage(int codePage) {
    switch (codePage) {
      case 437:
        return _cp437;
      case 850:
        return _cp850;
      case 874:
        return _windows874;
      case 10000:
        return _macRoman;
      case 1250:
        return _windows1250;
      case 1251:
        return _windows1251;
      case 1252:
        return _windows1252;
      case 1253:
        return _windows1253;
      case 1254:
        return _windows1254;
      case 1255:
        return _windows1255;
      case 1256:
        return _windows1256;
      case 1257:
        return _windows1257;
      case 1258:
        return _windows1258;
      default:
        return null;
    }
  }

  void _appendLiteralCharacter(int codeUnit) {
    _appendText(String.fromCharCode(codeUnit));
  }

  void _appendUnicodeCodeUnit(int value) {
    var codeUnit = value;
    if (codeUnit < 0) codeUnit += 65536;
    if (codeUnit < 0 || codeUnit > 0x10FFFF) return;

    if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
      _flushPendingHighSurrogate();
      _pendingHighSurrogate = codeUnit;
      return;
    }
    if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
      final high = _pendingHighSurrogate;
      if (high != null) {
        final fullCodePoint =
            0x10000 + ((high - 0xD800) << 10) + (codeUnit - 0xDC00);
        _pendingHighSurrogate = null;
        _appendText(String.fromCharCode(fullCodePoint));
      }
      return;
    }
    _flushPendingHighSurrogate();
    _appendText(String.fromCharCode(codeUnit));
  }

  void _flushPendingHighSurrogate() {
    // Un high surrogate isolato è un RTF malformato: non deve essere emesso né
    // combinato accidentalmente con un low surrogate molto più avanti.
    _pendingHighSurrogate = null;
  }

  void _appendText(String text) {
    if (text.isEmpty ||
        _state.skipDestination ||
        _state.hidden ||
        _state.deleted) {
      return;
    }
    _flushPendingEncodedBytes();
    _flushPendingHighSurrogate();
    _buffer.write(text);
  }

  bool _consumeUnicodeFallbackCharacter() {
    if (_fallbackCharsToSkip <= 0) return false;
    _fallbackCharsToSkip--;
    return true;
  }

  static bool _isMultibyteCodePage(int codePage) =>
      codePage == 65001 ||
      codePage == 932 ||
      codePage == 936 ||
      codePage == 949 ||
      codePage == 950 ||
      codePage == 1361;

  static int _codePageForFontCharset(int charset, int ansiCodePage) {
    switch (charset) {
      case 0:
      case 1:
        return ansiCodePage;
      case 77:
        return 10000;
      case 128:
        return 932;
      case 129:
        return 949;
      case 130:
        return 1361;
      case 134:
        return 936;
      case 136:
        return 950;
      case 161:
        return 1253;
      case 162:
        return 1254;
      case 163:
        return 1258;
      case 177:
        return 1255;
      case 178:
      case 179:
      case 180:
        return 1256;
      case 181:
        return 1255;
      case 186:
        return 1257;
      case 204:
        return 1251;
      case 222:
        return 874;
      case 238:
        return 1250;
      case 254:
        return 437;
      case 255:
        return 850;
      default:
        return ansiCodePage;
    }
  }

  static bool _isAsciiLetter(int codeUnit) =>
      codeUnit >= 0x41 && codeUnit <= 0x5A ||
      codeUnit >= 0x61 && codeUnit <= 0x7A;

  static bool _isAsciiDigit(int codeUnit) =>
      codeUnit >= 0x30 && codeUnit <= 0x39;
}

class _RtfState {
  int ansiCodePage;
  int codePage;
  int unicodeFallbackLength;
  int? currentFontNumber;
  int? fontDefinitionNumber;
  bool skipDestination;
  bool ignorableDestinationPending = false;
  bool allowUnicodeDestination = false;
  bool hidden;
  bool deleted;
  String? destination;
  String closeText = '';
  int uprNextChildIndex = -1;

  _RtfState({
    this.ansiCodePage = 1252,
    this.codePage = 1252,
    this.unicodeFallbackLength = 1,
    this.currentFontNumber,
    this.fontDefinitionNumber,
    this.skipDestination = false,
    this.hidden = false,
    this.deleted = false,
    this.destination,
  });

  _RtfState copyForChildGroup() => _RtfState(
        ansiCodePage: ansiCodePage,
        codePage: codePage,
        unicodeFallbackLength: unicodeFallbackLength,
        currentFontNumber: currentFontNumber,
        fontDefinitionNumber: fontDefinitionNumber,
        skipDestination: skipDestination,
        hidden: hidden,
        deleted: deleted,
        destination: destination,
      );
}
