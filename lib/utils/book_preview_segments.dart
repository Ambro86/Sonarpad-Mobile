/// Keep the library's AI introduction separate from the actual book excerpt.
/// The observed server format ends the introduction with an AI disclaimer and
/// a dashed separator. Without that marker, retain the ordinary text fallback.
List<String> splitBookPreview(String text) {
  final disclaimer = RegExp(
    r'^Avvertenza:[^\r\n]*informazioni generate automaticamente tramite intelligenza artificiale[^\r\n]*(?:\r?\n|$)',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(text);
  if (disclaimer != null &&
      disclaimer.start < 8000 &&
      RegExp(
        r'^\s*\uFEFF?Target di lettura:',
        caseSensitive: false,
      ).hasMatch(text)) {
    var end = disclaimer.end;
    final separator = RegExp(
      r'^[ \t]*-{3,}[ \t]*(?:\r?\n|$)(?:[ \t]*\r?\n)*',
    ).firstMatch(text.substring(end));
    if (separator != null) end += separator.end;
    return [text.substring(0, end), ..._splitExcerpt(text.substring(end))];
  }
  return _splitExcerpt(text);
}

/// Divide the excerpt into at most three stops without losing any characters.
List<String> _splitExcerpt(String text) {
  if (text.trim().isEmpty) return const [];
  final count = text.length <= 1200 ? 1 : (text.length <= 3600 ? 2 : 3);
  if (count == 1) return [text];
  final boundaries =
      [
            RegExp(r'(?:\r?\n)[ \t]*(?:\r?\n)'),
            RegExp(r'''[.!?…]["»”')]*\s+'''),
            RegExp(r'\r?\n'),
            RegExp(r'\s+'),
          ]
          .map((pattern) => pattern.allMatches(text).map((m) => m.end).toList())
          .toList();
  final result = <String>[];
  var start = 0;
  for (var remaining = count; remaining > 1; remaining--) {
    final size = (text.length - start) / remaining;
    final target = start + size.round();
    int? split;
    for (final candidates in boundaries) {
      var distance = size * 0.35;
      for (final candidate in candidates) {
        if (candidate <= start || candidate >= text.length) continue;
        final difference = (candidate - target).abs();
        if (difference <= distance) {
          split = candidate;
          distance = difference.toDouble();
        }
      }
      if (split != null) break;
    }
    // A single unbroken word has no safe linguistic boundary. Keep it intact.
    if (split == null) break;
    result.add(text.substring(start, split));
    start = split;
  }
  result.add(text.substring(start));
  return result;
}
