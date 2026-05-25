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
  static final _s1 =
      RegExp(r'(?:\n|^)\s*1\.\s+Che\s+cos', caseSensitive: false);
  static final _s2 =
      RegExp(r'(?:\n|^)\s*2\.\s+Cosa\s+deve', caseSensitive: false);
  static final _s3 = RegExp(
      r'(?:\n|^)\s*3\.\s+Come\s+(?:prendere|usare|assumere)',
      caseSensitive: false);
  static final _s4 =
      RegExp(r'(?:\n|^)\s*4\.\s+Possibili\s+effetti', caseSensitive: false);
  static final _s5 =
      RegExp(r'(?:\n|^)\s*5\.\s+Come\s+conservare', caseSensitive: false);
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
    final i1 = _chapterStart(_s1, text);
    final i2 = _chapterStart(_s2, text);
    final i3 = _chapterStart(_s3, text);
    final i4 = _chapterStart(_s4, text);
    final i5 = _chapterStart(_s5, text);

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
