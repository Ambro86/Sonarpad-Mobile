import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:string_similarity/string_similarity.dart';
import 'aifa_cache_manager.dart';
import 'app_cache_service.dart';

enum DrugMatchLevel { confirmed, strong, possible, unknown }

class DrugMatch {
  final AifaDrugResult? drug;
  final DrugMatchLevel level;

  DrugMatch(this.drug, this.level);
}

class AifaConfezione {
  final String name;
  final String codiceSis;
  final String aic6;

  const AifaConfezione({
    required this.name,
    required this.codiceSis,
    required this.aic6,
  });
}

class AifaDrugResult {
  final String denominazione;
  final String principiAttivi;
  final String aic9;
  final List<AifaConfezione> confezioni;

  AifaDrugResult({
    required this.denominazione,
    required this.principiAttivi,
    required this.aic9,
    required this.confezioni,
  });
}

class AifaService {
  static const String _baseUrl =
      "https://api.aifa.gov.it/aifa-bdf-eif-be/1.0.0";
  static const String _drugRegistryCsvUrl =
      'https://drive.aifa.gov.it/farmaci/confezioni_fornitura.csv';
  static Future<List<String>>? _drugRegistryNamesFuture;

  /// Restituisce le denominazioni dei medicinali autorizzati AIFA che
  /// iniziano con la lettera richiesta.
  ///
  /// L'anagrafica ufficiale viene pubblicata quotidianamente da AIFA come CSV.
  /// La conserviamo nella cache rigenerabile dell'app per evitare di scaricare
  /// circa 160 mila confezioni a ogni apertura della schermata A-Z.
  Future<List<String>> browseDrugNamesByLetter(String rawLetter) async {
    final letter = _normalizeCatalogLetter(rawLetter);
    if (letter == null) return const [];

    try {
      final names = await (_drugRegistryNamesFuture ??= _loadDrugRegistryNames());
      return names
          .where((name) => _normalizeCatalogLetter(name) == letter)
          .toList(growable: false);
    } catch (_) {
      // Un errore temporaneo non deve avvelenare la cache in memoria: il
      // pulsante Riprova deve poter effettuare davvero un nuovo tentativo.
      _drugRegistryNamesFuture = null;
      rethrow;
    }
  }

  Future<List<String>> _loadDrugRegistryNames() async {
    final cacheDir = await AppCacheService.directory(AppCacheService.aifaFolder);
    final cacheFile = File('${cacheDir.path}/anagrafica_farmaci_aifa.csv');
    final now = DateTime.now();

    List<int>? bytes;
    if (await cacheFile.exists()) {
      try {
        final modified = await cacheFile.lastModified();
        if (now.difference(modified) < const Duration(hours: 24)) {
          bytes = await cacheFile.readAsBytes();
        }
      } catch (_) {}
    }

    if (bytes == null) {
      try {
        final response = await http.get(
          Uri.parse(_drugRegistryCsvUrl),
          headers: const {'User-Agent': 'SonarpadMobile/1.0'},
        );
        if (response.statusCode != 200) {
          throw const _AifaRegistryException();
        }
        bytes = response.bodyBytes;
        if (bytes.isEmpty) {
          throw const _AifaRegistryException();
        }
        try {
          await cacheFile.writeAsBytes(bytes, flush: true);
        } catch (_) {
          // La cache e' soltanto un'ottimizzazione: il catalogo deve
          // funzionare anche se il file non puo' essere scritto.
        }
      } catch (_) {
        // Se AIFA e' momentaneamente irraggiungibile, una copia precedente e'
        // comunque molto piu' utile di una schermata vuota.
        if (await cacheFile.exists()) {
          bytes = await cacheFile.readAsBytes();
        } else {
          rethrow;
        }
      }
    }

    final csv = _decodeRegistryCsv(bytes);
    final names = AifaDrugRegistryCsvParser.parseNames(csv);
    if (names.isEmpty) {
      throw const _AifaRegistryException();
    }
    return List.unmodifiable(names);
  }

  String _decodeRegistryCsv(List<int> bytes) {
    var decoded = utf8.decode(bytes, allowMalformed: true);
    // Alcuni export storici AIFA non erano UTF-8. Se la decodifica produce
    // molti caratteri sostitutivi, prova latin1 prima di indicizzare i nomi.
    final replacementCount = '�'.allMatches(decoded).length;
    if (replacementCount > 20) {
      decoded = latin1.decode(bytes, allowInvalid: true);
    }
    return decoded;
  }

  String? _normalizeCatalogLetter(String raw) {
    const folded = <String, String>{
      'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
      'Ç': 'C',
      'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
      'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
      'Ñ': 'N',
      'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
      'Ý': 'Y',
    };
    for (final rune in raw.trim().runes) {
      final upper = String.fromCharCode(rune).toUpperCase();
      final value = folded[upper] ?? upper;
      if (value.length != 1) continue;
      final code = value.codeUnitAt(0);
      if (code >= 0x41 && code <= 0x5A) return value;
    }
    return null;
  }

  /// Cerca i farmaci nell'API AIFA.
  Future<List<AifaDrugResult>> searchDrugs(String query) async {
    final encodedQuery = Uri.encodeComponent(query.trim());
    final url =
        '$_baseUrl/formadosaggio/ricerca?query=$encodedQuery&spellingCorrection=true&page=0';

    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'SonarpadMobile/1.0'},
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Errore nella ricerca farmaci AIFA (codice ${response.statusCode})');
    }

    final json = jsonDecode(response.body);
    final results = <AifaDrugResult>[];
    _collectResultsFromJson(json, results);

    return results;
  }

  Future<DrugMatch> searchByAic(String aic,
      {void Function()? onNetworkFallback}) async {
    final cached = await AifaCacheManager().getDrugByAic(aic);
    if (cached != null) {
      return DrugMatch(cached, DrugMatchLevel.confirmed);
    }

    if (onNetworkFallback != null) {
      onNetworkFallback();
    }

    try {
      final results = await searchDrugs(aic);
      if (results.isNotEmpty) {
        final drug = results.first;
        await AifaCacheManager().insertOrUpdateDrug(drug);
        return DrugMatch(drug, DrugMatchLevel.confirmed);
      }
    } catch (e) {
      // Offline o errore API
    }
    return DrugMatch(null, DrugMatchLevel.unknown);
  }

  Future<DrugMatch> searchByGtin(String gtin) async {
    // Senza una tabella di mapping GTIN -> AIC validata,
    // un GTIN isolato non può garantire il farmaco in modo "Strong".
    return DrugMatch(null, DrugMatchLevel.unknown);
  }

  Future<DrugMatch> searchByOcrFuzzy(String ocrText) async {
    final ocrNorm = ocrText.trim().toLowerCase();
    if (ocrNorm.length < 3) return DrugMatch(null, DrugMatchLevel.unknown);

    List<AifaDrugResult> results = [];

    final cached = await AifaCacheManager()
        .searchDrugsByNormalizedName(ocrNorm.toUpperCase());
    if (cached.isNotEmpty) {
      results = cached;
    } else {
      try {
        results = await searchDrugs(ocrText);
        for (var drug in results) {
          await AifaCacheManager().insertOrUpdateDrug(drug);
        }
      } catch (e) {
        // Offline o errore API
      }
    }

    if (results.isEmpty) return DrugMatch(null, DrugMatchLevel.unknown);

    results.sort((a, b) {
      final scoreA = a.denominazione.toLowerCase().similarityTo(ocrNorm);
      final scoreB = b.denominazione.toLowerCase().similarityTo(ocrNorm);
      return scoreB.compareTo(scoreA);
    });

    final bestResult = results[0];
    final bestName = bestResult.denominazione.toLowerCase();
    final bestScore = bestName.similarityTo(ocrNorm);

    double secondScore = 0.0;
    if (results.length > 1) {
      secondScore =
          results[1].denominazione.toLowerCase().similarityTo(ocrNorm);
    }

    bool isValid = false;

    if (ocrNorm.length <= 4) {
      // Massima rigidità per nomi corti come OKI
      if (bestName == ocrNorm) isValid = true;
    } else {
      if (bestScore >= 0.92) {
        isValid = true;
      } else if (bestScore >= 0.86) {
        // Regole speciali se sotto 0.92 ma sopra 0.86
        if (ocrNorm.length >= 6 &&
            ocrNorm[0] == bestName[0] &&
            (bestScore - secondScore) >= 0.08) {
          isValid = true;
        }
      }
    }

    if (isValid) {
      return DrugMatch(bestResult, DrugMatchLevel.possible);
    }
    return DrugMatch(null, DrugMatchLevel.unknown);
  }

  void _collectResultsFromJson(dynamic value, List<AifaDrugResult> results) {
    if (value is Map<String, dynamic>) {
      final content =
          (value['content'] as List?) ?? (value['data']?['content'] as List?);
      if (content != null) {
        for (final item in content) {
          if (item is! Map<String, dynamic>) continue;

          final med = item['medicinale'] ?? <String, dynamic>{};
          final den =
              med['denominazioneMedicinale']?.toString() ?? 'Sconosciuto';
          final desc = item['descrizioneFormaDosaggio']?.toString() ?? '';

          final principiList = item['principiAttiviIt'] as List? ?? [];
          final principi = principiList.join(' + ');

          String aic9 = '';
          if (item['confezioni'] is List &&
              (item['confezioni'] as List).isNotEmpty) {
            aic9 = (item['confezioni'] as List)[0]['aic']?.toString() ?? '';
          }

          // Nome della singola confezione
          // Es: "Aspirina 400 mg compresse effervescenti - acido acetilsalicilico"
          final confName = '$den $desc - $principi'.trim();

          // Gestisce importazioni parallele che hanno un codiceSIS diverso per il PDF
          final isP = item['tipoAutorizzazione'] == 'P';
          final codiceSis = isP
              ? item['sisImportazioneParallela']?.toString()
              : med['codiceSis']?.toString();
          final aic6 = isP
              ? item['aic6ImportazioneParallela']?.toString()
              : med['aic6']?.toString();

          if (codiceSis != null && aic6 != null) {
            final confezione = AifaConfezione(
              name: confName.isEmpty ? 'Farmaco AIC $aic6' : confName,
              codiceSis: codiceSis,
              aic6: aic6,
            );

            // Raggruppa per denominazione e principi attivi
            final existingGroup = results
                .where((r) =>
                    r.denominazione.toLowerCase() == den.toLowerCase() &&
                    r.principiAttivi.toLowerCase() == principi.toLowerCase())
                .toList();

            if (existingGroup.isNotEmpty) {
              // Evita duplicati esatti nella lista delle confezioni
              final group = existingGroup.first;
              if (!group.confezioni.any((c) =>
                  c.codiceSis == codiceSis &&
                  c.aic6 == aic6 &&
                  c.name == confezione.name)) {
                group.confezioni.add(confezione);
              }
            } else {
              results.add(AifaDrugResult(
                denominazione: den,
                principiAttivi: principi,
                aic9: aic9,
                confezioni: [confezione],
              ));
            }
          }
        }
      }
    }
  }

  /// Scarica il PDF del Foglio Illustrativo e lo salva in cache.
  Future<File> downloadFoglioIllustrativo(AifaConfezione drug) async {
    final url =
        '$_baseUrl/organizzazione/${drug.codiceSis}/farmaci/${drug.aic6}/stampati?ts=FI';

    // Predispone la directory di cache
    final cacheDir = await AppCacheService.directory(
      AppCacheService.aifaFolder,
    );

    // Nome file sicuro per il file system
    final safeName = drug.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(
        '${cacheDir.path}/FI_${drug.codiceSis}_${drug.aic6}_$safeName.pdf');

    // Se esiste già in cache, restituiscilo direttamente
    if (await file.exists()) {
      return file;
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'SonarpadMobile/1.0'},
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Impossibile scaricare il bugiardino (HTTP ${response.statusCode})');
    }

    await file.writeAsBytes(response.bodyBytes);
    return file;
  }
}

/// Parser piccolo e senza dipendenze aggiuntive per l'Anagrafica Farmaci AIFA.
/// Gestisce separatori `;`, `,` o tab, campi quotati e doppi apici escapati.
class AifaDrugRegistryCsvParser {
  static List<String> parseNames(String csv) {
    if (csv.trim().isEmpty) return const [];
    final delimiter = _detectDelimiter(csv);
    final names = <String>{};
    List<String>? header;
    int? nameIndex;

    for (final row in _records(csv, delimiter)) {
      if (row.isEmpty) continue;
      if (header == null) {
        header = row;
        nameIndex = _findNameColumn(header);
        if (nameIndex == null) {
          throw const _AifaRegistryException();
        }
        continue;
      }
      final index = nameIndex;
      if (index == null || index >= row.length) continue;
      final name = _clean(row[index]);
      if (name.length >= 2) names.add(name);
    }

    final result = names.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  static String _detectDelimiter(String csv) {
    final end = _firstRecordEnd(csv);
    final first = csv.substring(0, end);
    final candidates = <String, int>{';': 0, ',': 0, '\t': 0};
    var quoted = false;
    for (var i = 0; i < first.length; i++) {
      final ch = first[i];
      if (ch == '"') {
        if (quoted && i + 1 < first.length && first[i + 1] == '"') {
          i++;
          continue;
        }
        quoted = !quoted;
        continue;
      }
      if (!quoted && candidates.containsKey(ch)) {
        candidates[ch] = candidates[ch]! + 1;
      }
    }
    return candidates.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static int _firstRecordEnd(String csv) {
    var quoted = false;
    for (var i = 0; i < csv.length; i++) {
      final ch = csv[i];
      if (ch == '"') {
        if (quoted && i + 1 < csv.length && csv[i + 1] == '"') {
          i++;
          continue;
        }
        quoted = !quoted;
      } else if (!quoted && (ch == '\n' || ch == '\r')) {
        return i;
      }
    }
    return csv.length;
  }

  static Iterable<List<String>> _records(String csv, String delimiter) sync* {
    final row = <String>[];
    var field = StringBuffer();
    var quoted = false;

    void finishField() {
      row.add(field.toString());
      field = StringBuffer();
    }

    for (var i = 0; i < csv.length; i++) {
      final ch = csv[i];
      if (ch == '"') {
        if (quoted && i + 1 < csv.length && csv[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
        continue;
      }
      if (!quoted && ch == delimiter) {
        finishField();
        continue;
      }
      if (!quoted && (ch == '\n' || ch == '\r')) {
        finishField();
        if (row.any((value) => value.trim().isNotEmpty)) {
          yield List<String>.of(row);
        }
        row.clear();
        if (ch == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') i++;
        continue;
      }
      field.write(ch);
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      finishField();
      if (row.any((value) => value.trim().isNotEmpty)) {
        yield List<String>.of(row);
      }
    }
  }

  static int? _findNameColumn(List<String> header) {
    final normalized = header.map(_normalizeHeader).toList(growable: false);
    const exactPriority = <String>[
      'denominazionemedicinale',
      'denominazionefarmaco',
      'denominazione',
      'nomemedicinale',
      'nomefarmaco',
    ];
    for (final wanted in exactPriority) {
      final index = normalized.indexOf(wanted);
      if (index >= 0) return index;
    }
    for (var i = 0; i < normalized.length; i++) {
      final value = normalized[i];
      if ((value.contains('denominazione') || value.contains('nome')) &&
          (value.contains('medicinal') || value.contains('farmac')) &&
          !value.contains('titolare') &&
          !value.contains('principio')) {
        return i;
      }
    }
    return null;
  }

  static String _normalizeHeader(String raw) => raw
      .replaceFirst('\ufeff', '')
      .toLowerCase()
      .replaceAll('à', 'a')
      .replaceAll('è', 'e')
      .replaceAll('é', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ù', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _clean(String raw) => raw
      .replaceFirst('\ufeff', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _AifaRegistryException implements Exception {
  const _AifaRegistryException();
}
