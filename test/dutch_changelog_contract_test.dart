import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/changelog_service.dart';

void main() {
  final entries = (jsonDecode(File('assets/changelog.json').readAsStringSync())
          as List<dynamic>)
      .cast<Map<String, dynamic>>();

  test('Every English release note also exists in Dutch', () {
    expect(entries.length, 9);
    expect(entries.first['version'], '0.5.3');
    expect(entries.last['version'], '0.2.0');
    var total = 0;
    for (final entry in entries) {
      final english = (entry['en'] as List<dynamic>).cast<String>();
      final dutch = (entry['nl'] as List<dynamic>).cast<String>();
      expect(dutch, hasLength(english.length), reason: '${entry['version']}');
      expect(dutch.toSet(), hasLength(dutch.length));
      for (var i = 0; i < english.length; ++i) {
        expect(dutch[i].trim(), isNotEmpty);
        expect(dutch[i], isNot(english[i]), reason: '${entry['version']}, $i');
      }
      final decoded = ChangelogEntry.fromJson(entry);
      expect(decoded.changesFor('nl'), dutch);
      total += dutch.length;
    }
    expect(total, 169);
  });

  test('Platform-specific changes use Dutch rather than English', () {
    final version = entries.singleWhere((e) => e['version'] == '0.4.0');
    final decoded = ChangelogEntry.fromJson(version);
    final base = (version['nl'] as List<dynamic>).cast<String>();
    final ios = (version['ios'] as Map<String, dynamic>);
    final android = (version['android'] as Map<String, dynamic>);
    expect((ios['nl'] as List<dynamic>), hasLength(2));
    expect((android['nl'] as List<dynamic>), hasLength(1));
    expect(decoded.changesFor('nl', platform: TargetPlatform.iOS),
        [...(ios['nl'] as List<dynamic>).cast<String>(), ...base]);
    expect(decoded.changesFor('nl', platform: TargetPlatform.android),
        [...(android['nl'] as List<dynamic>).cast<String>(), ...base]);
    expect(ios['nl'], isNot(ios['en']));
    expect(android['nl'], isNot(android['en']));
  });

  test('Restricted Italian extras are not visible in Dutch', () {
    for (final entry in entries) {
      final decoded = ChangelogEntry.fromJson(entry);
      expect(decoded.changesFor('nl', includeItalianExtras: true),
          (entry['nl'] as List<dynamic>).cast<String>());
    }
  });
}
