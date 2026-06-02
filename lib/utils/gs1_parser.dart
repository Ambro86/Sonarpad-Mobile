import '../utils/app_logger.dart';

class Gs1ParsedData {
  final String? gtin;
  final String? aic;
  final String? batch;
  final String? expiry;
  final String? serial;

  Gs1ParsedData({this.gtin, this.aic, this.batch, this.expiry, this.serial});

  bool get hasValidAic =>
      aic != null &&
      aic!.length == 9 &&
      aic!.startsWith('0') &&
      RegExp(r'^\d+$').hasMatch(aic!);

  @override
  String toString() {
    return 'Gs1ParsedData(GTIN: $gtin, AIC: $aic, SCAD: $expiry, LOTTO: $batch, SERIAL: $serial)';
  }
}

class Gs1Parser {
  /// Analizza una stringa Barcode (GS1 DataMatrix, EAN, ecc.) in modo rigoroso
  static Gs1ParsedData parse(String rawValue) {
    AppLogger.log('GS1Parser: decodifica stringa -> "$rawValue"');

    String data = rawValue.trim();

    // Rimuoviamo eventuali prefissi simbologia DataMatrix ]d2 o ]d1
    if (data.startsWith(']d2') || data.startsWith(']d1')) {
      data = data.substring(3);
    }

    // Normalizziamo il separatore FNC1 (ASCII 29) e <GS> in un separatore standard interno |
    data = data.replaceAll(String.fromCharCode(29), '|');
    data = data.replaceAll('<GS>', '|');

    String? gtin;
    String? aic;
    String? batch;
    String? expiry;
    String? serial;

    // Se è formattato con parentesi (es. lettori hardware), facciamo fallback rapido
    if (data.contains('(01)') || data.contains('(716)')) {
      aic = RegExp(r'\(716\)(\d{9})').firstMatch(data)?.group(1);
      gtin = RegExp(r'\(01\)(\d{14})').firstMatch(data)?.group(1);
      expiry = RegExp(r'\(17\)(\d{6})').firstMatch(data)?.group(1);
      batch = RegExp(r'\(10\)([^|()]+)').firstMatch(data)?.group(1);
      serial = RegExp(r'\(21\)([^|()]+)').firstMatch(data)?.group(1);
    } else {
      // Loop rigoroso
      int i = 0;
      while (i < data.length) {
        if (data[i] == '|') {
          i++;
          continue;
        }

        if (data.startsWith('01', i)) {
          i += 2;
          if (i + 14 <= data.length) {
            final candidate = data.substring(i, i + 14);
            if (candidate.contains('|')) {
              int end = data.indexOf('|', i);
              if (end == -1) break;
              i = end;
            } else {
              gtin = candidate;
              i += 14;
            }
          } else {
            break; // errore formato
          }
        } else if (data.startsWith('17', i)) {
          i += 2;
          if (i + 6 <= data.length) {
            final candidate = data.substring(i, i + 6);
            if (candidate.contains('|')) {
              int end = data.indexOf('|', i);
              if (end == -1) break;
              i = end;
            } else {
              expiry = candidate;
              i += 6;
            }
          } else {
            break; // errore formato
          }
        } else if (data.startsWith('716', i)) {
          i += 3;
          int end = data.indexOf('|', i);
          if (end == -1) end = data.length;

          final candidate = data.substring(i, end);
          if (RegExp(r'^0\d{8}$').hasMatch(candidate)) {
            aic = candidate;
          }
          i = end;
        } else if (data.startsWith('10', i)) {
          i += 2;
          int end = data.indexOf('|', i);
          if (end == -1) end = data.length;
          batch = data.substring(i, end);
          i = end;
        } else if (data.startsWith('21', i)) {
          i += 2;
          int end = data.indexOf('|', i);
          if (end == -1) end = data.length;
          serial = data.substring(i, end);
          i = end;
        } else {
          // AI sconosciuto, saltiamo fino al prossimo FNC1/separatore
          int end = data.indexOf('|', i);
          if (end == -1) {
            break; // Non possiamo sapere quanto è lungo
          }
          i = end;
        }
      }
    }

    // Se è un EAN-13 o EAN-8 puro senza indicatori GS1
    if (gtin == null &&
        aic == null &&
        (data.length == 13 || data.length == 8) &&
        RegExp(r'^\d+$').hasMatch(data)) {
      gtin = data;
    }

    // Se è un Pharmacode italiano (Code 39), tipicamente A + 9 cifre (o solo 9 cifre)
    if (gtin == null && aic == null) {
      if (data.length == 10 &&
          data.startsWith('A') &&
          RegExp(r'^A\d{9}$').hasMatch(data)) {
        aic = data.substring(1);
      } else if (data.length == 9 && RegExp(r'^\d{9}$').hasMatch(data)) {
        aic = data;
      }
    }

    // NESSUNA estrazione automatica dell'AIC dal GTIN.
    // L'AIC esiste solo se esplicitamente dichiarato con AI 716.

    return Gs1ParsedData(
        gtin: gtin, aic: aic, batch: batch, expiry: expiry, serial: serial);
  }
}
