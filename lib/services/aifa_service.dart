import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AifaDrugResult {
  final String name;
  final String codiceSis;
  final String aic6;

  const AifaDrugResult({
    required this.name,
    required this.codiceSis,
    required this.aic6,
  });
}

class AifaService {
  static const String _baseUrl =
      "https://api.aifa.gov.it/aifa-bdf-eif-be/1.0.0";

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

  void _collectResultsFromJson(dynamic value, List<AifaDrugResult> results) {
    if (value is Map<String, dynamic> && value['content'] is List) {
      final content = value['content'] as List;
      for (final item in content) {
        if (item is! Map<String, dynamic>) continue;

        // Controlla se c'è il foglio illustrativo, altrimenti 404
        final flagFI = item['flagFI'];
        if (flagFI != 1 && flagFI != '1') {
          continue;
        }

        final med = item['medicinale'] ?? <String, dynamic>{};
        final den = med['denominazioneMedicinale']?.toString() ?? 'Sconosciuto';
        final desc = item['descrizioneFormaDosaggio']?.toString() ?? '';
        final name = '$den $desc'.trim();

        // Gestisce importazioni parallele che hanno un codiceSIS diverso per il PDF
        final isP = item['tipoAutorizzazione'] == 'P';
        final codiceSis = isP
            ? item['sisImportazioneParallela']?.toString()
            : med['codiceSis']?.toString();
        final aic6 = isP
            ? item['aic6ImportazioneParallela']?.toString()
            : med['aic6']?.toString();

        if (codiceSis != null && aic6 != null) {
          final drugName = name.isEmpty ? 'Farmaco AIC $aic6' : name;

          // Evita duplicati
          final exists =
              results.any((r) => r.codiceSis == codiceSis && r.aic6 == aic6);
          if (!exists) {
            results.add(AifaDrugResult(
              name: drugName,
              codiceSis: codiceSis,
              aic6: aic6,
            ));
          }
        }
      }
    }
  }

  /// Scarica il PDF del Foglio Illustrativo e lo salva in cache.
  Future<File> downloadFoglioIllustrativo(AifaDrugResult drug) async {
    final url =
        '$_baseUrl/organizzazione/${drug.codiceSis}/farmaci/${drug.aic6}/stampati?ts=FI';

    // Predispone la directory di cache
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/aifa_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

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
