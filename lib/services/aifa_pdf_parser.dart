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

    // 2. Trova gli indici dei capitoli principali
    final i1 = _chapterStart(_s1, text) ?? _chapterStartByNumber(text, 1);
    final i2 = _chapterStart(_s2, text) ?? _chapterStartByNumber(text, 2);
    final i3 = _chapterStart(_s3, text) ?? _chapterStartByNumber(text, 3);
    final i4 = _chapterStart(_s4, text) ?? _chapterStartByNumber(text, 4);
    final i5 = _chapterStart(_s5, text) ?? _chapterStartByNumber(text, 5);

    String extractedText = '';

    switch (type) {
      case AifaSectionType.aCosaServe:
        // Paragrafo 1 (da 1 a 2)
        extractedText = _textBetween(text, start: i1, end: i2);
        if (extractedText.trim().isEmpty) {
          extractedText =
              "Impossibile trovare chiaramente i capitoli 1 e 2. Il testo potrebbe essere formattato diversamente.";
        }
        break;

      case AifaSectionType.cosaDeveSapere:
        // Paragrafo 2 (da 2 a 3)
        extractedText = _textBetween(text, start: i2, end: i3);
        if (extractedText.trim().isEmpty) {
          extractedText = "Impossibile trovare il capitolo 2.";
        }
        break;

      case AifaSectionType.posologia:
        // Paragrafo 3 (solo la parte su come prendere, escludendo sovradosaggio se possibile)
        var section3 = _textBetween(text, start: i3, end: i4);

        // Cerchiamo di escludere "Se prende più"
        final sePrendeMatch = _sePrendePiu.firstMatch(section3);
        if (sePrendeMatch != null) {
          section3 = section3.substring(0, sePrendeMatch.start);
        }
        extractedText = section3;
        if (extractedText.trim().isEmpty) {
          extractedText =
              "Impossibile trovare il capitolo 3 relativo alla posologia.";
        }
        break;

      case AifaSectionType.effettiIndesiderati:
        // Paragrafo 4 + eventuale parte finale del paragrafo 3
        final section3 = _textBetween(text, start: i3, end: i4);

        String sovradosaggio = '';
        final sePrendeMatch = _sePrendePiu.firstMatch(section3);
        if (sePrendeMatch != null) {
          sovradosaggio = '${section3.substring(sePrendeMatch.start)}\n\n';
        }

        final section4 = _textBetween(text, start: i4, end: i5);

        extractedText = sovradosaggio + section4;
        if (extractedText.trim().isEmpty) {
          extractedText =
              "Impossibile trovare i capitoli relativi agli effetti indesiderati e sovradosaggio.";
        }
        break;

      case AifaSectionType.conservazione:
        // Paragrafo 5 e 6
        extractedText = _textBetween(text, start: i5, end: null);
        if (extractedText.trim().isEmpty) {
          extractedText = "Impossibile trovare i capitoli 5 e 6.";
        }
        break;

      case AifaSectionType.leggiTutto:
        break; // Gestito all'inizio
    }

    // 3. Salva in un file .txt temporaneo
    final dir = await getTemporaryDirectory();
    final safeName = farmacoName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final typeName = type.toString().split('.').last;
    final file = File('${dir.path}/${safeName}_$typeName.txt');
    await file.writeAsString(extractedText);

    return file.path;
  }
}
