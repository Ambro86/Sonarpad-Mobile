import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'document_text_extractor.dart';

enum AifaSectionType {
  aCosaServe,
  cosaDeveSapere,
  posologia,
  effettiIndesiderati,
  conservazione,
  leggiTutto,
}

class AifaPdfParser {
  // Regex per intercettare i titoli dei capitoli AIFA standard.
  // Usiamo espressioni regolari robuste per ignorare spaziature strane e case-sensitivity.
  static final _chapterHeading =
      RegExp(r'(?:\n|^)\s*([1-6])\s*[\.\)]\s*([^\n\r]+)');
  static final _s1 = RegExp(
      r'(?:\n|^)\s*1\s*[\.\)]\s*(?:Che\s+cos|Cos.?è|A\s+cosa\s+serve|Che\s+cosa\s+serve)',
      caseSensitive: false);
  static final _s2 = RegExp(
      r'(?:\n|^)\s*2\s*[\.\)]\s*(?:Cosa\s+deve|Prima\s+di\s+(?:prendere|usare|assumere))',
      caseSensitive: false);
  static final _s3 = RegExp(
      r'(?:\n|^)\s*3\s*[\.\)]\s*Come\s+(?:prendere|usare|assumere)',
      caseSensitive: false);
  static final _s4 = RegExp(
      r'(?:\n|^)\s*4\s*[\.\)]\s*(?:Possibili\s+effetti|Effetti\s+indesiderati)',
      caseSensitive: false);
  static final _s5 = RegExp(r'(?:\n|^)\s*5\s*[\.\)]\s*Come\s+conservare',
      caseSensitive: false);
  static final _sePrendePiu = RegExp(
      r'(?:\n|^)\s*Se\s+(?:prende|usa|assume)\s+più',
      caseSensitive: false);

  static int? _chapterStart(RegExp pattern, String text) {
    int? start;
    for (final match in pattern.allMatches(text)) {
      start = match.start;
    }
    return start;
  }

  static List<int> _chapterStarts(RegExp pattern, String text) {
    return pattern.allMatches(text).map((match) => match.start).toList();
  }

  static int? _chapterStartByNumber(String text, int number) {
    int? start;
    for (final match in _chapterHeading.allMatches(text)) {
      final parsedNumber = int.tryParse(match.group(1) ?? '');
      if (parsedNumber != number) continue;

      final title = _normalizeHeading(match.group(2) ?? '');
      if (!_looksLikeChapterTitle(number, title)) continue;
      start = match.start;
    }
    return start;
  }

  static List<int> _chapterStartsByNumber(String text, int number) {
    final starts = <int>[];
    for (final match in _chapterHeading.allMatches(text)) {
      final parsedNumber = int.tryParse(match.group(1) ?? '');
      if (parsedNumber != number) continue;

      final title = _normalizeHeading(match.group(2) ?? '');
      if (!_looksLikeChapterTitle(number, title)) continue;
      starts.add(match.start);
    }
    return starts;
  }

  static String _normalizeHeading(String text) {
    final buffer = StringBuffer();
    var previousWasSpace = false;
    for (final codeUnit in text.toLowerCase().codeUnits) {
      final isSpace = codeUnit == 9 ||
          codeUnit == 10 ||
          codeUnit == 11 ||
          codeUnit == 12 ||
          codeUnit == 13 ||
          codeUnit == 32;
      if (isSpace) {
        if (!previousWasSpace && buffer.isNotEmpty) {
          buffer.write(' ');
        }
        previousWasSpace = true;
      } else {
        buffer.writeCharCode(codeUnit);
        previousWasSpace = false;
      }
    }
    return buffer.toString().trim();
  }

  static bool _looksLikeChapterTitle(int number, String title) {
    switch (number) {
      case 1:
        return title.startsWith('che cos') ||
            title.startsWith('cosè') ||
            title.startsWith('cos’è') ||
            title.contains('a cosa serve') ||
            title.startsWith('che cosa serve');
      case 2:
        return title.startsWith('cosa deve') ||
            title.startsWith('prima di prendere') ||
            title.startsWith('prima di usare') ||
            title.startsWith('prima di assumere');
      case 3:
        return title.startsWith('come prendere') ||
            title.startsWith('come usare') ||
            title.startsWith('come assumere');
      case 4:
        return title.startsWith('possibili effetti') ||
            title.startsWith('effetti indesiderati');
      case 5:
        return title.startsWith('come conservare');
      default:
        return false;
    }
  }

  static String _textBetween(
    String text, {
    required int? start,
    required int? end,
  }) {
    if (start == null) return '';
    final safeEnd = end == null || end <= start ? text.length : end;
    return text.substring(start, safeEnd);
  }

  static List<int> _mergeStarts(List<int> primary, List<int> fallback) {
    final starts = {...primary, ...fallback}.toList()..sort();
    return starts;
  }

  static _ChapterPositions _lastChapterPositions(String text) {
    return _ChapterPositions(
      i1: _chapterStart(_s1, text) ?? _chapterStartByNumber(text, 1),
      i2: _chapterStart(_s2, text) ?? _chapterStartByNumber(text, 2),
      i3: _chapterStart(_s3, text) ?? _chapterStartByNumber(text, 3),
      i4: _chapterStart(_s4, text) ?? _chapterStartByNumber(text, 4),
      i5: _chapterStart(_s5, text) ?? _chapterStartByNumber(text, 5),
    );
  }

  static _ChapterPositions _chapterPositionsFor(
    String text,
    String farmacoName,
  ) {
    final fallback = _lastChapterPositions(text);
    final i3Starts = _mergeStarts(
      _chapterStarts(_s3, text),
      _chapterStartsByNumber(text, 3),
    );
    if (i3Starts.length <= 1) return fallback;

    final i1Starts = _mergeStarts(
      _chapterStarts(_s1, text),
      _chapterStartsByNumber(text, 1),
    );
    final i2Starts = _mergeStarts(
      _chapterStarts(_s2, text),
      _chapterStartsByNumber(text, 2),
    );
    final i4Starts = _mergeStarts(
      _chapterStarts(_s4, text),
      _chapterStartsByNumber(text, 4),
    );
    final i5Starts = _mergeStarts(
      _chapterStarts(_s5, text),
      _chapterStartsByNumber(text, 5),
    );

    final tokens = _selectionTokens(farmacoName);
    if (tokens.isEmpty) return fallback;

    _ChapterPositions? best;
    var bestScore = 0;
    for (final i3 in i3Starts) {
      final i4 = _firstAfter(i4Starts, i3);
      if (i4 == null || i4 - i3 < 80) continue;

      final i2 = _lastBefore(i2Starts, i3);
      final i1 = i2 == null
          ? _lastBefore(i1Starts, i3)
          : _lastBefore(i1Starts, i2);
      final i5 = _firstAfter(i5Starts, i4);
      final blockStart = i1 ?? i2 ?? i3;
      final blockEnd = i5 ?? _firstAfter(i1Starts, i3) ?? text.length;
      final score = _selectionScore(
        text,
        blockStart: blockStart,
        blockEnd: blockEnd,
        tokens: tokens,
      );

      if (score > bestScore) {
        bestScore = score;
        best = _ChapterPositions(i1: i1, i2: i2, i3: i3, i4: i4, i5: i5);
      }
    }

    return bestScore == 0 || best == null ? fallback : best;
  }

  static int? _lastBefore(List<int> starts, int position) {
    int? previous;
    for (final start in starts) {
      if (start >= position) break;
      previous = start;
    }
    return previous;
  }

  static int? _firstAfter(List<int> starts, int position) {
    for (final start in starts) {
      if (start > position) return start;
    }
    return null;
  }

  static List<String> _selectionTokens(String farmacoName) {
    final normalized = _normalizeSearchText(farmacoName);
    final tokens = normalized
        .split(' ')
        .where((token) =>
            token.length >= 4 && !_commonSelectionTokens.contains(token))
        .toSet()
        .toList();
    return tokens;
  }

  static int _selectionScore(
    String text, {
    required int blockStart,
    required int blockEnd,
    required List<String> tokens,
  }) {
    final safeStart = blockStart < 500 ? 0 : blockStart - 500;
    final safeEnd = blockEnd > text.length ? text.length : blockEnd;
    final context = _normalizeSearchText(text.substring(safeStart, safeEnd));
    var score = 0;
    for (final token in tokens) {
      if (context.contains(token)) score++;
    }
    return score;
  }

  static String _normalizeSearchText(String text) {
    final buffer = StringBuffer();
    var previousWasSpace = false;
    for (final codeUnit in text.toLowerCase().codeUnits) {
      final isAlphaNumeric = codeUnit >= 48 && codeUnit <= 57 ||
          codeUnit >= 97 && codeUnit <= 122 ||
          codeUnit >= 224 && codeUnit <= 255;
      if (isAlphaNumeric) {
        buffer.writeCharCode(codeUnit);
        previousWasSpace = false;
      } else if (!previousWasSpace && buffer.isNotEmpty) {
        buffer.write(' ');
        previousWasSpace = true;
      }
    }
    return buffer.toString().trim();
  }

  static String _extractSectionText(
    String text,
    AifaSectionType type,
    String farmacoName,
  ) {
    final positions = _chapterPositionsFor(text, farmacoName);
    final i1 = positions.i1;
    final i2 = positions.i2;
    final i3 = positions.i3;
    final i4 = positions.i4;
    final i5 = positions.i5;

    switch (type) {
      case AifaSectionType.aCosaServe:
        final extractedText = _textBetween(text, start: i1, end: i2);
        if (extractedText.trim().isEmpty) {
          return "Impossibile trovare chiaramente i capitoli 1 e 2. Il testo potrebbe essere formattato diversamente.";
        }
        return extractedText;

      case AifaSectionType.cosaDeveSapere:
        final extractedText = _textBetween(text, start: i2, end: i3);
        if (extractedText.trim().isEmpty) {
          return "Impossibile trovare il capitolo 2.";
        }
        return extractedText;

      case AifaSectionType.posologia:
        var section3 = _textBetween(text, start: i3, end: i4);
        final sePrendeMatch = _sePrendePiu.firstMatch(section3);
        if (sePrendeMatch != null) {
          section3 = section3.substring(0, sePrendeMatch.start);
        }
        if (section3.trim().isEmpty) {
          return "Impossibile trovare il capitolo 3 relativo alla posologia.";
        }
        return section3;

      case AifaSectionType.effettiIndesiderati:
        final section3 = _textBetween(text, start: i3, end: i4);

        String sovradosaggio = '';
        final sePrendeMatch = _sePrendePiu.firstMatch(section3);
        if (sePrendeMatch != null) {
          sovradosaggio = '${section3.substring(sePrendeMatch.start)}\n\n';
        }

        final section4 = _textBetween(text, start: i4, end: i5);
        final extractedText = sovradosaggio + section4;
        if (extractedText.trim().isEmpty) {
          return "Impossibile trovare i capitoli relativi agli effetti indesiderati e sovradosaggio.";
        }
        return extractedText;

      case AifaSectionType.conservazione:
        final extractedText = _textBetween(text, start: i5, end: null);
        if (extractedText.trim().isEmpty) {
          return "Impossibile trovare i capitoli 5 e 6.";
        }
        return extractedText;

      case AifaSectionType.leggiTutto:
        return text;
    }
  }

  @visibleForTesting
  static String extractSectionTextForTest(
    String text,
    AifaSectionType type,
    String farmacoName,
  ) {
    return _extractSectionText(text, type, farmacoName);
  }

  /// Estrae il testo completo dal PDF e lo suddivide in base alla sezione richiesta.
  /// Salva il frammento in un file .txt e restituisce il percorso.
  static Future<String> extractSectionAndSave(
      String pdfPath, AifaSectionType type, String farmacoName) async {
    // Se la scelta è "leggi tutto", non facciamo alcun parsing, passiamo direttamente il PDF
    if (type == AifaSectionType.leggiTutto) {
      return pdfPath;
    }

    // 1. Estrae l'intero testo dal PDF
    final extractor = DocumentTextExtractor();
    final result = await extractor.extract(path: pdfPath, extension: 'pdf');
    final text = result.text;

    if (text.trim().isEmpty) {
      throw Exception(
          "Il PDF non contiene testo estraibile (potrebbe essere una scansione). Scegli 'Leggi tutto il bugiardino' per aprirlo come documento.");
    }

    final extractedText = _extractSectionText(text, type, farmacoName);

    // 3. Salva in un file .txt temporaneo
    final dir = await getTemporaryDirectory();
    final safeName = farmacoName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final typeName = type.toString().split('.').last;
    final file = File('${dir.path}/${safeName}_$typeName.txt');
    await file.writeAsString(extractedText);

    return file.path;
  }
}

class _ChapterPositions {
  final int? i1;
  final int? i2;
  final int? i3;
  final int? i4;
  final int? i5;

  const _ChapterPositions({
    required this.i1,
    required this.i2,
    required this.i3,
    required this.i4,
    required this.i5,
  });
}

const _commonSelectionTokens = <String>{
  'acido',
  'aic',
  'bromuro',
  'compressa',
  'farmaco',
  'medicinale',
};
