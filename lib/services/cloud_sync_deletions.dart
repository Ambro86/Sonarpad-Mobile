import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Written only by explicit user removal commands, never by cloud import/save.
class CloudSyncDeletions {
  static const _key = 'sonarpad_cloud_deletion_events_v1';
  static Future<void> _tail = Future.value();
  static Future<void> _exclusive(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.catchError((Object _) {});
    return result;
  }

  static Future<List<Map<String, dynamic>>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString(_key) ?? '[]') as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> record(
    String collection,
    Iterable<String> ids,
  ) => _exclusive(() async {
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final meta =
        jsonDecode(prefs.getString('sonarpad_cloud_sync_v1') ?? '{}') as Map;
    if (meta['group_id'] == null) return;
    final events = await read();
    for (final id in ids.toSet()) {
      events.add({
        'event':
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
        'group_id': meta['group_id'],
        'collection': collection,
        'id': id,
      });
    }
    if (!await prefs.setString(_key, jsonEncode(events))) {
      throw StateError('deletion_intent_save_failed');
    }
    for (final id in ids.toSet()) {
      await AppLogger.log(
        '[CloudSync] explicit_user_removal collection=$collection id_sha256=${sha256.convert(utf8.encode(id))}',
      );
    }
  });
  static Future<void> consume(List<dynamic> sent) => _exclusive(() async {
    final events = await read();
    events.removeWhere(
      (event) => sent.any((old) => old['event'] == event['event']),
    );
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, jsonEncode(events))) {
      throw StateError('deletion_intent_save_failed');
    }
  });
}
