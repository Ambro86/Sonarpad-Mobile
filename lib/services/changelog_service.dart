import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings_service.dart';
import 'raiplay_service.dart';
import 'raiplay_sound_service.dart';
import 'tv_service.dart';

class ChangelogEntry {
  final String version;
  final String date;
  final Map<String, List<String>> changesByLanguage;
  final List<String> italianExtraChanges;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changesByLanguage,
    this.italianExtraChanges = const [],
  });

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) {
    final changesByLanguage = <String, List<String>>{};
    for (final language in const ['it', 'en', 'fr', 'es', 'pt', 'pt_BR', 'pl', 'cs', 'de', 'zh_CN']) {
      final rawChanges = json[language];
      if (rawChanges is List) {
        changesByLanguage[language] =
            rawChanges.map((item) => item.toString()).toList();
      }
    }

    final rawItalianExtraChanges = json['it_extra'];
    final italianExtraChanges = rawItalianExtraChanges is List
        ? rawItalianExtraChanges.map((item) => item.toString()).toList()
        : const <String>[];

    return ChangelogEntry(
      version: json['version']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      changesByLanguage: changesByLanguage,
      italianExtraChanges: italianExtraChanges,
    );
  }

  List<String> changesFor(
    String languageCode, {
    bool includeItalianExtras = false,
  }) {
    final baseChanges = changesByLanguage[languageCode] ??
        changesByLanguage['en'] ??
        changesByLanguage['it'] ??
        const <String>[];
    if (languageCode != 'it' ||
        !includeItalianExtras ||
        italianExtraChanges.isEmpty) {
      return baseChanges;
    }
    return [...baseChanges, ...italianExtraChanges];
  }
}

class ChangelogService {
  static const _assetPath = 'assets/changelog.json';
  static const _lastSeenVersionKey = 'sonarpad_last_seen_changelog_version';

  Future<bool> hasSonarpadExtraAccess() async {
    final code = (await AppSettingsService().getTvSecretCode()).trim();
    if (code.isEmpty) return false;
    return TvService().isSecretCodeValid(code) ||
        RaiPlayService().isSecretCodeValid(code) ||
        RaiPlaySoundService().isSecretCodeValid(code);
  }

  Future<List<String>> visibleChangesFor(
    ChangelogEntry entry,
    String languageCode,
  ) async {
    final includeItalianExtras = languageCode == 'it' &&
        await hasSonarpadExtraAccess();
    return entry.changesFor(
      languageCode,
      includeItalianExtras: includeItalianExtras,
    );
  }

  Future<List<ChangelogEntry>> loadEntries() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ChangelogEntry.fromJson)
        .where((entry) => entry.version.isNotEmpty)
        .toList();
  }

  Future<ChangelogEntry?> loadCurrentEntry() async {
    final info = await PackageInfo.fromPlatform();
    final entries = await loadEntries();
    for (final entry in entries) {
      if (entry.version == info.version) return entry;
    }
    return entries.isEmpty ? null : entries.first;
  }

  Future<ChangelogEntry?> loadCurrentEntryIfUnseen() async {
    final info = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion = prefs.getString(_lastSeenVersionKey);
    if (lastSeenVersion == info.version) return null;
    final entries = await loadEntries();
    for (final entry in entries) {
      if (entry.version == info.version) return entry;
    }
    return null;
  }

  Future<void> markSeen(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenVersionKey, version);
  }
}
