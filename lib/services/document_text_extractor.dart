import 'dart:developer' as dev;
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:epubx/epubx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart' as xml_pkg;

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
  Future<ExtractionResult> extract({
    required String path,
    required String extension,
  }) async {
    try {
      switch (extension) {
        case 'txt':
        case 'md':
        case 'rtf':
          return ExtractionResult(text: await File(path).readAsString());

        case 'html':
        case 'htm':
          final raw = await File(path).readAsString();
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
      return const ExtractionResult(
        text: '',
        error: 'Nessun testo estraibile da questo PDF '
            '(potrebbe essere un PDF scansionato o protetto).',
      );
    }
    return ExtractionResult(text: text);
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
    final xmlString = String.fromCharCodes(docEntry.content as List<int>);
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
