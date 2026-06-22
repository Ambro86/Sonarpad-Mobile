import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VoiceDictionaryEntry {
  final String original;
  final String replacement;
  final bool matchCase;

  const VoiceDictionaryEntry({
    required this.original,
    required this.replacement,
    required this.matchCase,
  });

  factory VoiceDictionaryEntry.fromJson(Map<String, dynamic> json) {
    return VoiceDictionaryEntry(
      original: json['original']?.toString() ?? '',
      replacement: json['replacement']?.toString() ?? '',
      matchCase: json['matchCase'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'original': original,
        'replacement': replacement,
        'matchCase': matchCase,
      };
}

class VoiceDictionaryService {
  static const _entriesKey = 'sonarpad_voice_dictionary_entries';

  Future<List<VoiceDictionaryEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) return <VoiceDictionaryEntry>[];

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return <VoiceDictionaryEntry>[];
    }
    if (decoded is! List) return <VoiceDictionaryEntry>[];

    return decoded
        .whereType<Map>()
        .map((item) => VoiceDictionaryEntry.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((entry) => entry.original.trim().isNotEmpty)
        .toList();
  }

  Future<void> addEntry(VoiceDictionaryEntry entry) async {
    final normalized = VoiceDictionaryEntry(
      original: entry.original.trim(),
      replacement: entry.replacement.trim(),
      matchCase: entry.matchCase,
    );
    if (normalized.original.isEmpty) return;

    final entries = List<VoiceDictionaryEntry>.of(await loadEntries());
    entries.removeWhere(
      (item) =>
          item.original == normalized.original &&
          item.matchCase == normalized.matchCase,
    );
    entries.add(normalized);
    await saveEntries(entries);
  }

  Future<void> removeAt(int index) async {
    final entries = List<VoiceDictionaryEntry>.of(await loadEntries());
    if (index < 0 || index >= entries.length) return;
    entries.removeAt(index);
    await saveEntries(entries);
  }

  Future<void> saveEntries(List<VoiceDictionaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    await prefs.setString(_entriesKey, encoded);
  }

  String applyToText(String text, List<VoiceDictionaryEntry> entries) {
    var output = text;
    for (final entry in entries) {
      if (entry.original.isEmpty) continue;
      output = entry.matchCase
          ? output.replaceAll(entry.original, entry.replacement)
          : _replaceCaseInsensitive(output, entry.original, entry.replacement);
    }
    return output;
  }

  String _replaceCaseInsensitive(
    String text,
    String original,
    String replacement,
  ) {
    final output = StringBuffer();
    var cursor = 0;
    while (cursor < text.length) {
      final matchLength = _matchLengthCaseInsensitive(text, cursor, original);
      if (matchLength != null) {
        output.write(replacement);
        cursor += matchLength;
        continue;
      }

      final rune = text.substring(cursor).runes.first;
      output.write(String.fromCharCode(rune));
      cursor += String.fromCharCode(rune).length;
    }
    return output.toString();
  }

  int? _matchLengthCaseInsensitive(String text, int start, String original) {
    var consumed = 0;
    final sourceIterator = text.substring(start).runes.iterator;
    for (final originalRune in original.runes) {
      if (!sourceIterator.moveNext()) return null;
      final sourceChar = String.fromCharCode(sourceIterator.current);
      final originalChar = String.fromCharCode(originalRune);
      if (sourceChar.toLowerCase() != originalChar.toLowerCase()) {
        return null;
      }
      consumed += sourceChar.length;
    }
    return consumed;
  }
}
