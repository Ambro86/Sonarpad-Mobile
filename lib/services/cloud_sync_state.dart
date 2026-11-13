import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../utils/app_logger.dart';

typedef CloudState = Map<String, List<Map<String, dynamic>>>;

CloudState parseCloudState(Object? value) {
  if (value is! Map) throw const FormatException('Invalid cloud state');
  final result = <String, List<Map<String, dynamic>>>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! List) {
      throw const FormatException('Invalid cloud collection');
    }
    final ids = <String>{};
    result[entry.key as String] = (entry.value as List).map((raw) {
      if (raw is! Map ||
          raw['id'] is! String ||
          raw['data'] is! Map ||
          !ids.add(raw['id'] as String)) {
        throw const FormatException('Invalid cloud item');
      }
      return <String, dynamic>{
        'id': raw['id'],
        'data': Map<String, dynamic>.from(raw['data'] as Map),
      };
    }).toList();
  }
  return result;
}

/// Reapply edits made locally while an HTTP request was running.
CloudState mergeCloudState(
  CloudState remote,
  CloudState baseline,
  CloudState local,
) {
  final result = parseCloudState(jsonDecode(jsonEncode(remote)));
  for (final entry in local.entries) {
    final before = {
      for (final item in baseline[entry.key] ?? <Map<String, dynamic>>[])
        item['id'] as String: item,
    };
    final after = {for (final item in entry.value) item['id'] as String: item};
    final current = {
      for (final item in result[entry.key] ?? <Map<String, dynamic>>[])
        item['id'] as String: item,
    };
    for (final id in before.keys) {
      if (!after.containsKey(id)) current.remove(id);
    }
    for (final item in after.entries) {
      final id = item.key;
      final data = item.value['data'] as Map<String, dynamic>;
      if (entry.key == 'podcast_bookmarks') {
        final currentRow = current[id];
        if (currentRow != null) {
          if (jsonEncode(before[id]?['data']) != jsonEncode(data) &&
              (data['updated_at'] as int) > (currentRow['data']['updated_at'] as int)) {
            current[id] = {'id': id, 'data': {...data}};
          }
        } else if (!before.containsKey(id)) {
          current[id] = {'id': id, 'data': {...data}};
        }
        continue;
      }
      if (before.containsKey(id)) {
        if (!current.containsKey(id)) continue;
        final old = before[id]!['data'] as Map<String, dynamic>;
        final next = current[id]!['data'] as Map<String, dynamic>;
        for (final field in data.entries) {
          if (!old.containsKey(field.key) ||
              jsonEncode(old[field.key]) != jsonEncode(field.value)) {
            next[field.key] = field.value;
          }
        }
        for (final field in old.keys) {
          if (!data.containsKey(field)) next.remove(field);
        }
      } else {
        current[id] = {
          'id': id,
          'data': {...?current[id]?['data'] as Map<String, dynamic>?, ...data},
        };
      }
    }
    if (jsonEncode(before.keys.toList()) != jsonEncode(after.keys.toList())) {
      final ordered = <String, Map<String, dynamic>>{};
      for (final id in after.keys) {
        final item = current.remove(id);
        if (item != null) ordered[id] = item;
      }
      result[entry.key] = [...ordered.values, ...current.values];
    } else {
      result[entry.key] = current.values.toList();
    }
  }
  return result;
}

String cloudYoutubeUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null) return input.trim();
  if (uri.host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return 'https://www.youtube.com/watch?v=${uri.pathSegments.first}';
  }
  if (!{'youtube.com', 'www.youtube.com', 'm.youtube.com'}.contains(uri.host)) {
    return input.trim();
  }
  final segments = uri.pathSegments;
  if (segments.length >= 2 &&
      {'shorts', 'live', 'embed'}.contains(segments.first)) {
    return 'https://www.youtube.com/watch?v=${segments[1]}';
  }
  final video = uri.queryParameters['v'];
  if (video != null && video.isNotEmpty) {
    return 'https://www.youtube.com/watch?v=$video';
  }
  final playlist = uri.queryParameters['list'];
  if (playlist != null && playlist.isNotEmpty) {
    return 'https://www.youtube.com/playlist?list=$playlist';
  }
  if (segments.isNotEmpty && segments.first.startsWith('@')) {
    return 'https://www.youtube.com/${segments.first}';
  }
  if (segments.length >= 2 && segments.first == 'channel') {
    return 'https://www.youtube.com/channel/${segments[1]}';
  }
  return 'https://www.youtube.com${uri.path.replaceFirst(RegExp(r'/$'), '')}';
}

CloudState removedCloudItems(CloudState before, CloudState after) => {
  for (final entry in after.entries)
    entry.key: (before[entry.key] ?? [])
        .where((row) => !entry.value.any((item) => item['id'] == row['id']))
        .toList(),
}..removeWhere((key, rows) => rows.isEmpty);

Future<void> logCloudReductions(
  CloudState before,
  CloudState after,
  String stage,
) async {
  final previous = {
    for (final row in before['preferences'] ?? <Map<String, dynamic>>[])
      row['id']: row,
  };
  for (final row in after['preferences'] ?? <Map<String, dynamic>>[]) {
    final old = previous[row['id']];
    if (old == null || jsonEncode(old['data']) == jsonEncode(row['data'])) {
      continue;
    }
    final id = row['id'] as String;
    if (!RegExp(r'^[a-z][a-z0-9_.]{1,79}$').hasMatch(id)) continue;
    // Never include preference values or credentials in diagnostics.
    await AppLogger.log(
      '[CloudSync] preference_changed stage=$stage preference_id=$id',
    );
  }
  for (final entry in removedCloudItems(before, after).entries) {
    await AppLogger.log(
      '[CloudSync] reduction stage=$stage collection=${entry.key} '
      'before=${before[entry.key]!.length} after=${after[entry.key]!.length} removed=${entry.value.length}',
    );
    for (final row in entry.value) {
      await AppLogger.log(
        '[CloudSync] removed_item stage=$stage collection=${entry.key} '
        'id_sha256=${sha256.convert(utf8.encode(row['id'] as String))}',
      );
    }
  }
}
