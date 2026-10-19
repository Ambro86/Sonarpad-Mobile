import 'dart:convert';
import 'dart:io';

import '../utils/document_unicode_normalizer.dart';

enum TextDocumentExportFormat { markdown, html }

/// Exports the document's current text, including edits, as UTF-8.
class TextDocumentExportService {
  Future<File> write({
    required String path,
    required String text,
    required TextDocumentExportFormat format,
    required String title,
    String language = 'und',
  }) async {
    final normalized = normalizeDocumentUnicode(
      text,
    ).replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\u0000', '');
    final content = switch (format) {
      // Keep existing Markdown markup and paragraph boundaries intact.
      TextDocumentExportFormat.markdown => normalized,
      TextDocumentExportFormat.html => _html(normalized, title, language),
    };
    return File(path).writeAsString(content, encoding: utf8, flush: true);
  }

  String _html(String text, String title, String language) {
    const escape = HtmlEscape(HtmlEscapeMode.element);
    final locale = language.replaceAll('_', '-');
    final safeLanguage =
        RegExp(r'^[a-zA-Z]{2,8}(-[a-zA-Z0-9]{1,8})*$').hasMatch(locale)
        ? locale
        : 'und';
    final paragraphs = text
        .split(RegExp(r'\n[ \t]*\n'))
        .map(
          (paragraph) =>
              '<p>${escape.convert(paragraph).replaceAll('\n', '<br>\n')}</p>',
        )
        .join('\n');
    return '<!DOCTYPE html>\n'
        '<html lang="$safeLanguage">\n<head>\n'
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '<title>${escape.convert(normalizeDocumentUnicode(title))}</title>\n'
        '<style>body{font-family:system-ui,sans-serif;line-height:1.6;'
        'max-width:70ch;margin:2rem auto;padding:0 1rem;overflow-wrap:anywhere;}'
        'p{white-space:pre-wrap;}</style>\n</head>\n'
        '<body>\n<main>\n$paragraphs\n</main>\n</body>\n</html>\n';
  }
}
