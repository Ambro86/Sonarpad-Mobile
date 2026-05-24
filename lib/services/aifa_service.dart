import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
