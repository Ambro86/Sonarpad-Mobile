import 'dart:io';

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
  static final _chapterNumber = RegExp(r'(?:\n|^)\s*([1-6])\s*[\.\)]');
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
    for (final match in _chapterNumber.allMatches(text)) {
      if (!_numberMatchLooksLikeChapter(text, match, number)) continue;
      start = match.start;
    }
    return start;
  }

  static List<int> _chapterStartsByNumber(String text, int number) {
    final starts = <int>[];
    for (final match in _chapterNumber.allMatches(text)) {
      if (!_numberMatchLooksLikeChapter(text, match, number)) continue;
      starts.add(match.start);
    }
    return starts;
  }

  static bool _numberMatchLooksLikeChapter(
    String text,
    RegExpMatch match,
    int number,
  ) {
    final parsedNumber = int.tryParse(match.group(1) ?? '');
    if (parsedNumber != number) return false;

    final end = match.end + 220 > text.length ? text.length : match.end + 220;
    final title = _normalizeHeading(text.substring(match.end, end));
    final compactTitle = _compactHeading(title);
    return _looksLikeChapterTitle(number, title) ||
        _looksLikeCompactChapterTitle(number, compactTitle);
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

  static String _compactHeading(String text) {
    final buffer = StringBuffer();
    for (final codeUnit in text.toLowerCase().codeUnits) {
      final isAlpha = codeUnit >= 97 && codeUnit <= 122 ||
          codeUnit >= 224 && codeUnit <= 255;
      if (isAlpha) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static bool _looksLikeCompactChapterTitle(int number, String title) {
    switch (number) {
      case 1:
        return title.startsWith('checos') ||
            title.startsWith('cosè') ||
            title.startsWith('cosè') ||
            title.startsWith('acosaserve') ||
            title.startsWith('checosa');
      case 2:
        return title.startsWith('cosadeve') ||
            title.startsWith('primadiprendere') ||
            title.startsWith('primadiusare') ||
            title.startsWith('primadiassumere');
      case 3:
        return title.startsWith('comeprendere') ||
            title.startsWith('comeusare') ||
            title.startsWith('comeassumere');
      case 4:
        return title.startsWith('possibilieffetti') ||
            title.startsWith('effettiindesiderati');
      case 5:
        return title.startsWith('comeconservare');
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
    final formTokens = tokens
        .where((token) => _formSelectionTokens.contains(token))
        .toList();
    final scoringTokens = formTokens.isEmpty ? tokens : formTokens;
    final excludedFormTokens =
        formTokens.isEmpty ? const <String>[] : _excludedFormTokens(formTokens);

    _ChapterPositions? best;
    var bestScore = -1000000;
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
        tokens: scoringTokens,
        excludedTokens: excludedFormTokens,
      );

      if (score > bestScore) {
        bestScore = score;
        best = _ChapterPositions(i1: i1, i2: i2, i3: i3, i4: i4, i5: i5);
      }
    }

    if (best == null) return fallback;
    if (formTokens.isNotEmpty) return best;
    return bestScore <= 0 ? fallback : best;
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
    final tokens = <String>{
      ...normalized
        .split(' ')
        .where((token) =>
            token.length >= 4 && !_commonSelectionTokens.contains(token)),
    };

    if (tokens.contains('compressa') || tokens.contains('compresse')) {
      tokens.addAll(['compressa', 'compresse']);
    }
    if (tokens.contains('rivestita') || tokens.contains('rivestite')) {
      tokens.addAll(['rivestita', 'rivestite']);
    }
    if (tokens.contains('supposta') || tokens.contains('supposte')) {
      tokens.addAll(['supposta', 'supposte']);
    }
    if (tokens.contains('iniettabile') || tokens.contains('iniettabili')) {
      tokens.addAll(['iniettabile', 'iniettabili']);
    }

    return tokens.toList();
  }

  static int _selectionScore(
    String text, {
    required int blockStart,
    required int blockEnd,
    required List<String> tokens,
    required List<String> excludedTokens,
  }) {
    final safeStart = blockStart < 1500 ? 0 : blockStart - 1500;
    final safeEnd = blockEnd > text.length ? text.length : blockEnd;
    final context = _normalizeSearchText(text.substring(safeStart, safeEnd));
    var score = 0;
    for (final token in tokens) {
      if (!context.contains(token)) continue;
      score += _selectionTokenWeight(token);
    }
    for (final token in excludedTokens) {
      if (!context.contains(token)) continue;
      score -= _selectionTokenWeight(token) * 3;
    }
    return score;
  }

  static int _selectionTokenWeight(String token) {
    return _formSelectionTokens.contains(token) ? 4 : 1;
  }

  static List<String> _excludedFormTokens(List<String> selectedTokens) {
    final selectedIsInjectable =
        selectedTokens.any(_injectableSelectionTokens.contains);
    if (selectedIsInjectable) {
      return _nonInjectableSelectionTokens.toList();
    }
    if (selectedTokens.any(_nonInjectableSelectionTokens.contains)) {
      return _injectableSelectionTokens.toList();
    }
    return const <String>[];
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

  static String _filterPosologiaForSelectedForm(
    String section3,
    String farmacoName,
  ) {
    final selectedGroup = _selectedPosologiaFormGroup(farmacoName);
    if (selectedGroup == null) return section3;

    final headings = _posologiaFormHeadings(section3);
    if (headings.length < 2) return section3;

    final selectedIndex = headings.indexWhere(
      (heading) => heading.group == selectedGroup,
    );
    if (selectedIndex < 0) return section3;

    final selected = headings[selectedIndex];
    final nextStart = selectedIndex + 1 < headings.length
        ? headings[selectedIndex + 1].start
        : section3.length;
    final prefix = section3.substring(0, headings.first.start).trim();
    final selectedText = section3.substring(selected.start, nextStart).trim();

    if (selectedText.isEmpty) return section3;
    if (prefix.isEmpty) return selectedText;
    return '$prefix\n\n$selectedText';
  }

  static String? _selectedPosologiaFormGroup(String farmacoName) {
    final tokens = _selectionTokens(farmacoName);
    if (tokens.any(_suppositorySelectionTokens.contains)) {
      return _suppositoryFormGroup;
    }
    if (tokens.any(_tabletSelectionTokens.contains)) {
      return _tabletFormGroup;
    }
    return null;
  }

  static List<_PosologiaFormHeading> _posologiaFormHeadings(String text) {
    final headings = <_PosologiaFormHeading>[];
    var lineStart = 0;

    for (var i = 0; i <= text.length; i++) {
      if (i < text.length && text.codeUnitAt(i) != 10) continue;

      final rawLine = text.substring(lineStart, i);
      final group = _posologiaFormHeadingGroup(rawLine);
      if (group != null) {
        headings.add(_PosologiaFormHeading(start: lineStart, group: group));
      }

      lineStart = i + 1;
    }

    return headings;
  }

  static String? _posologiaFormHeadingGroup(String line) {
    final normalized = _normalizeSearchText(line);
    if (_tabletPosologiaHeadings.contains(normalized)) {
      return _tabletFormGroup;
    }
    if (_suppositoryPosologiaHeadings.contains(normalized)) {
      return _suppositoryFormGroup;
    }
    return null;
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
        return _filterPosologiaForSelectedForm(section3, farmacoName);

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

class _PosologiaFormHeading {
  final int start;
  final String group;

  const _PosologiaFormHeading({
    required this.start,
    required this.group,
  });
}

const _commonSelectionTokens = <String>{
  'acido',
  'aic',
  'bromuro',
  'farmaco',
  'medicinale',
};

const _formSelectionTokens = <String>{
  'compressa',
  'compresse',
  'iniettabile',
  'iniettabili',
  'rivestita',
  'rivestite',
  'supposta',
  'supposte',
};

const _injectableSelectionTokens = <String>{
  'iniettabile',
  'iniettabili',
};

const _nonInjectableSelectionTokens = <String>{
  'compressa',
  'compresse',
  'rivestita',
  'rivestite',
  'supposta',
  'supposte',
};

const _tabletFormGroup = 'tablet';
const _suppositoryFormGroup = 'suppository';

const _tabletSelectionTokens = <String>{
  'compressa',
  'compresse',
  'rivestita',
  'rivestite',
};

const _suppositorySelectionTokens = <String>{
  'supposta',
  'supposte',
};

const _tabletPosologiaHeadings = <String>{
  'compressa',
  'compressa rivestita',
  'compresse',
  'compresse rivestite',
};

const _suppositoryPosologiaHeadings = <String>{
  'supposta',
  'supposte',
};
