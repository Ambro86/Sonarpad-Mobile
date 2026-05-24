import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'document_text_extractor.dart';

enum AifaSectionType {
  aCosaServe,
  posologia,
  effettiIndesiderati,
  conservazione,
  leggiTutto,
}

class AifaPdfParser {
  static final RegExp _s1 =
      RegExp(r'(?:\n|^)\s*1\.\s+Che\s+cos', caseSensitive: false);
  static final RegExp _s3 = RegExp(
      r'(?:\n|^)\s*3\.\s+Come\s+(?:prendere|usare|assumere)',
      caseSensitive: false);
  static final RegExp _s4 =
      RegExp(r'(?:\n|^)\s*4\.\s+Possibili\s+effetti', caseSensitive: false);
  static final RegExp _s5 =
      RegExp(r'(?:\n|^)\s*5\.\s+Come\s+conservare', caseSensitive: false);
  static final RegExp _sePrendePiu = RegExp(
      r'(?:\n|^)\s*Se\s+(?:prende|usa|assume)\s+più',
      caseSensitive: false);

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
    final i1 = _s1.firstMatch(text)?.start ?? 0;
    final i3 = _s3.firstMatch(text)?.start ?? text.length;
    final i4 = _s4.firstMatch(text)?.start ?? text.length;
    final i5 = _s5.firstMatch(text)?.start ?? text.length;

    String extractedText = '';

    switch (type) {
      case AifaSectionType.aCosaServe:
        // Paragrafo 1 e 2 (da 1 a 3)
        final start = i1;
        final end = i3 < text.length ? i3 : text.length;
        extractedText = text.substring(start, end);
        if (extractedText.trim().isEmpty) {
          extractedText =
              "Impossibile trovare chiaramente i capitoli 1 e 2. Il testo potrebbe essere formattato diversamente.";
        }
        break;

      case AifaSectionType.posologia:
        // Paragrafo 3 (solo la parte su come prendere, escludendo sovradosaggio se possibile)
        final start = i3;
        final end = i4 < text.length ? i4 : text.length;
        var section3 = text.substring(start, end);

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
        final start3 = i3;
        final end3 = i4 < text.length ? i4 : text.length;
        final section3 = text.substring(start3, end3);

        String sovradosaggio = '';
        final sePrendeMatch = _sePrendePiu.firstMatch(section3);
        if (sePrendeMatch != null) {
          sovradosaggio = '${section3.substring(sePrendeMatch.start)}\n\n';
        }

        final start4 = i4;
        final end4 = i5 < text.length ? i5 : text.length;
        final section4 = text.substring(start4, end4);

        extractedText = sovradosaggio + section4;
        if (extractedText.trim().isEmpty) {
          extractedText =
              "Impossibile trovare i capitoli relativi agli effetti indesiderati e sovradosaggio.";
        }
        break;

      case AifaSectionType.conservazione:
        // Paragrafo 5 e 6
        final start = i5;
        extractedText = text.substring(start);
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
