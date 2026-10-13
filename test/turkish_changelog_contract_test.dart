import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0.5.1 announces Turkish exactly once in every release-note language', () {
    final entries = jsonDecode(File('assets/changelog.json').readAsStringSync())
        as List<dynamic>;
    final release = entries.cast<Map<String, dynamic>>()
        .singleWhere((entry) => entry['version'] == '0.5.1');
    const announcements = <String, String>{
      'it': 'Aggiunta la lingua turca.',
      'en': 'Added Turkish language support.',
      'fr': 'Ajout de la prise en charge du turc.',
      'es': 'Añadido soporte para el idioma turco.',
      'pt': 'Adicionado suporte para a língua turca.',
      'pt_BR': 'Adicionado suporte ao idioma turco.',
      'pl': 'Dodano obsługę języka tureckiego.',
      'cs': 'Přidána podpora turečtiny.',
      'de': 'Unterstützung für Türkisch hinzugefügt.',
      'zh_CN': '新增土耳其语支持。',
      'uk': 'Додано підтримку турецької мови.',
      'ro': 'Adăugat suport pentru limba turcă.',
      'tr': 'Türkçe dil desteği eklendi.',
    };
    final italianNotes = (release['it'] as List<dynamic>).cast<String>();
    expect(italianNotes.length, greaterThanOrEqualTo(25));
    for (final entry in announcements.entries) {
      final notes = (release[entry.key] as List<dynamic>).cast<String>();
      expect(notes.length, italianNotes.length, reason: entry.key);
      expect(notes.where((note) => note == entry.value), hasLength(1),
          reason: entry.key);
      expect(notes.every((note) => note.trim().isNotEmpty), isTrue,
          reason: entry.key);
      expect(notes.where((note) => note.contains('**')), isEmpty,
          reason: entry.key);
    }
  });
}
