import 'dart:convert';
import 'dart:io';

void main() async {
  final dir = Directory('lib/l10n');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.arb'));

  final additions = <String, Map<String, dynamic>>{
    'app_it.arb': {
      'routeReadAction': 'Leggi percorso',
      '@routeReadAction': {'description': 'Localized text for routeReadAction.'},
      'routeSaveAction': 'Salva nei documenti',
      '@routeSaveAction': {'description': 'Localized text for routeSaveAction.'},
      'routeSaveSuccess': 'Percorso salvato nei documenti',
      '@routeSaveSuccess': {'description': 'Localized text for routeSaveSuccess.'},
    },
    'app_en.arb': {
      'routeReadAction': 'Read route',
      'routeSaveAction': 'Save to documents',
      'routeSaveSuccess': 'Route saved to documents',
    },
    'app_es.arb': {
      'routeReadAction': 'Leer ruta',
      'routeSaveAction': 'Guardar en documentos',
      'routeSaveSuccess': 'Ruta guardada en documentos',
    },
    'app_fr.arb': {
      'routeReadAction': "Lire l'itinéraire",
      'routeSaveAction': 'Enregistrer dans les documents',
      'routeSaveSuccess': 'Itinéraire enregistré dans les documents',
    },
    'app_cs.arb': {
      'routeReadAction': 'Přečíst trasu',
      'routeSaveAction': 'Uložit do dokumentů',
      'routeSaveSuccess': 'Trasa uložena do dokumentů',
    },
    'app_pl.arb': {
      'routeReadAction': 'Przeczytaj trasę',
      '@routeReadAction': {'description': 'Localized text for routeReadAction.'},
      'routeSaveAction': 'Zapisz w dokumentach',
      '@routeSaveAction': {'description': 'Localized text for routeSaveAction.'},
      'routeSaveSuccess': 'Trasa zapisana w dokumentach',
      '@routeSaveSuccess': {'description': 'Localized text for routeSaveSuccess.'},
    },
    'app_pt.arb': {
      'routeReadAction': 'Ler percurso',
      'routeSaveAction': 'Guardar nos documentos',
      'routeSaveSuccess': 'Percurso guardado nos documentos',
    },
  };

  for (final file in files) {
    final basename = file.uri.pathSegments.last;
    final adds = additions[basename];
    if (adds != null) {
      final text = file.readAsStringSync();
      // Remove last '}'
      final trimmed = text.trim();
      final withoutBrace = trimmed.substring(0, trimmed.lastIndexOf('}'));
      
      final encoder = JsonEncoder.withIndent('  ');
      final newEntries = adds.entries.map((e) {
        final keyStr = '"${e.key}"';
        final valStr = encoder.convert(e.value);
        return '  $keyStr: $valStr';
      }).join(',\n');
      
      final newText = withoutBrace + ',\n' + newEntries + '\n}\n';
      file.writeAsStringSync(newText);
      print('Updated $basename');
    }
  }
}
