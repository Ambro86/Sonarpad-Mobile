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
    if (value is List) {
      for (final item in value) {
        _tryPushResult(item, results);
        _collectResultsFromJson(item, results);
      }
    } else if (value is Map<String, dynamic>) {
      _tryPushResult(value, results);
      for (final child in value.values) {
        _collectResultsFromJson(child, results);
      }
    }
  }

  void _tryPushResult(dynamic value, List<AifaDrugResult> results) {
    if (value is! Map<String, dynamic>) return;

    final codiceSis =
        _getStringAny(value, ['CodiceSis', 'codiceSis', 'codice_sis']);
    final aic6 = _getStringAny(value, ['aic6', 'Aic6', 'AIC6']);
    final name = _getStringAny(value, [
      'denominazione',
      'nome',
      'descrizione',
      'farmaco',
      'denominazioneFarmaco',
      'nomeFarmaco',
    ]);

    if (codiceSis != null && aic6 != null) {
      final drugName = name ?? 'Farmaco AIC $aic6';

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

  String? _getStringAny(Map<String, dynamic> obj, List<String> keys) {
    for (final key in keys) {
      final val = obj[key];
      if (val != null) {
        if (val is String && val.trim().isNotEmpty) return val.trim();
        if (val is num) return val.toString();
      }
    }
    return null;
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
