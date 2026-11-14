/// Edge text rules shared with Windows tts_engine.rs.
class EdgeTtsText {
  static final _invisible = RegExp('[\u200B\u200C\u200D\u2060\uFEFF]');
  static final _spaces = RegExp(
    '[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\u2420\u2423\u2409]',
  );
  static final _newlines = RegExp('[\u240A\u240D\u2424]');
  static final _alphanumeric = RegExp(r'[\p{L}\p{N}]', unicode: true);

  static String _normalizeSpaces(String text) => text
      .replaceAll(_invisible, '')
      .replaceAll(_spaces, ' ')
      .replaceAll(_newlines, '\n');

  static bool isUsable(String text) => _alphanumeric.hasMatch(text);

  static String sanitize(String text) {
    final out = <String>[];
    var dots = 0;
    var bangs = 0;
    var questions = 0;
    void flush() {
      for (final run in [(dots, '.'), (bangs, '!'), (questions, '?')]) {
        if (run.$1 > 0) {
          while (out.isNotEmpty && out.last.trim().isEmpty) {
            out.removeLast();
          }
          out.add(run.$2 * (run.$1 >= 3 ? 1 : run.$1));
        }
      }
      dots = bangs = questions = 0;
    }

    for (final rune in _normalizeSpaces(text).runes) {
      if (rune == 46) {
        dots++;
        continue;
      }
      if (rune == 33) {
        bangs++;
        continue;
      }
      if (rune == 63) {
        questions++;
        continue;
      }
      flush();
      out.add(
        (rune <= 8 || (rune >= 11 && rune <= 12) || (rune >= 14 && rune <= 31))
            ? ' '
            : String.fromCharCode(rune),
      );
    }
    flush();
    return out
        .join()
        .replaceAll('.":', '. ')
        .replaceAll(".':", '. ')
        .replaceAll('.”:', '. ')
        .replaceAll('.’:', '. ');
  }

  /// Apply Windows' Strict profile before Edge punctuation sanitization.
  /// Paragraphs remain separate so punctuation-only paragraphs can be skipped.
  static String audiobook(String text) {
    final strict = StringBuffer();
    const punctuation = r""".,;:!?"'-()[]{}/\@#%&+=*_<>|~""";
    for (final rune in _normalizeSpaces(text).runes) {
      var ch = String.fromCharCode(rune);
      if ('“”„‟«»〝〞'.contains(ch)) ch = '"';
      if ('‘’‚‛‹›`´'.contains(ch)) ch = "'";
      if ('–—―−'.contains(ch)) ch = '-';
      if (ch == '…') {
        strict.write('...');
        continue;
      }
      strict.write(
        isUsable(ch) || ch.trim().isEmpty || punctuation.contains(ch)
            ? ch
            : ' ',
      );
    }
    return strict
        .toString()
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split(RegExp(r'\n{2,}'))
        .map(sanitize)
        .where(isUsable)
        .join('\n\n');
  }
}
