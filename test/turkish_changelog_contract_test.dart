import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '0.5.1 announces Turkish exactly once in every release-note language',
    () {
      final entries =
          jsonDecode(File('assets/changelog.json').readAsStringSync())
              as List<dynamic>;
      final release = entries.cast<Map<String, dynamic>>().singleWhere(
        (entry) => entry['version'] == '0.5.1',
      );
      const languageNames = <String, String>{
        'it': 'turc',
        'en': 'Turkish',
        'fr': 'turc',
        'es': 'turco',
        'pt': 'turco',
        'pt_BR': 'turco',
        'pl': 'tureck',
        'cs': 'tureč',
        'de': 'Türk',
        'zh_CN': '土耳其',
        'uk': 'турець',
        'ro': 'turc',
        'tr': 'Türk',
      };
      const completedTranslations = <String, String>{
        'it': 'completa',
        'en': 'complete',
        'fr': 'complète',
        'es': 'completa',
        'pt': 'completa',
        'pt_BR': 'completa',
        'pl': 'pełnym',
        'cs': 'úplným',
        'de': 'vollständigen',
        'zh_CN': '完成',
        'uk': 'повним',
        'ro': 'completă',
        'tr': 'tam',
      };
      final italianNotes = (release['it'] as List<dynamic>).cast<String>();
      expect(italianNotes, isNotEmpty);
      for (final entry in languageNames.entries) {
        final notes = (release[entry.key] as List<dynamic>).cast<String>();
        expect(notes.length, italianNotes.length, reason: entry.key);
        final turkishNotes = notes
            .where(
              (note) => note.toLowerCase().contains(entry.value.toLowerCase()),
            )
            .toList();
        expect(turkishNotes, hasLength(1), reason: entry.key);
        expect(
          turkishNotes.single,
          contains(completedTranslations[entry.key]!),
          reason: entry.key,
        );
        expect(notes.toSet(), hasLength(notes.length), reason: entry.key);
        expect(
          notes.every((note) => note.trim().isNotEmpty),
          isTrue,
          reason: entry.key,
        );
        expect(
          notes.where((note) => note.contains('**')),
          isEmpty,
          reason: entry.key,
        );
      }
    },
  );
}
