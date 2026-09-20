// ignore_for_file: avoid_print, file_names

import 'dart:convert';

import 'package:http/http.dart' as http;

// Test autonomo per il nuovo menu di ordinamento del tab Video di YouTube.
//
// Esecuzione dalla radice del progetto:
//   dart run "sonartube popular and oldest.dart"
//
// Si puo' anche indicare un altro channel id:
//   dart run "sonartube popular and oldest.dart" UCxxxxxxxxxxxxxxxxxxxxxx

enum ChannelSort { newest, popular, oldest }

const _defaultChannelId = 'UCLfQVw8Opp0ZcOHbcbY_4CQ';
const _apiKey = 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vfUWA8808';
const _clientVersion = '2.20260722.01.00';
const _newestVideosParams = 'EgZ2aWRlb3PyBgQKAjoA';

final _browseUri = Uri.parse(
  'https://www.youtube.com/youtubei/v1/browse'
  '?prettyPrint=false&key=$_apiKey',
);

Map<String, dynamic> _context() => <String, dynamic>{
  'client': <String, dynamic>{
    'hl': 'it',
    'gl': 'IT',
    'clientName': 'WEB',
    'clientVersion': _clientVersion,
    'platform': 'DESKTOP',
  },
};

Future<Map<String, dynamic>> _post(
  http.Client client,
  Map<String, dynamic> payload,
) async {
  final response = await client.post(
    _browseUri,
    headers: const <String, String>{
      'Content-Type': 'application/json',
      'X-YouTube-Client-Name': '1',
      'X-YouTube-Client-Version': _clientVersion,
    },
    body: jsonEncode(payload),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = utf8.decode(response.bodyBytes);
    throw StateError(
      'InnerTube HTTP ${response.statusCode}: '
      '${errorBody.length <= 300 ? errorBody : errorBody.substring(0, 300)}',
    );
  }
  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! Map) throw const FormatException('JSON InnerTube non valido');
  return Map<String, dynamic>.from(decoded);
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<dynamic> _list(dynamic value) => value is List ? value : const [];

String? _text(dynamic value) {
  if (value is String) return value.trim().isEmpty ? null : value.trim();
  final map = _map(value);
  if (map == null) return null;
  final content = map['content'];
  if (content is String && content.trim().isNotEmpty) return content.trim();
  final simpleText = map['simpleText'];
  if (simpleText is String && simpleText.trim().isNotEmpty) {
    return simpleText.trim();
  }
  final runs = _list(map['runs']);
  final joined = runs
      .map(_map)
      .whereType<Map<String, dynamic>>()
      .map((run) => run['text'])
      .whereType<String>()
      .join()
      .trim();
  return joined.isEmpty ? null : joined;
}

void _walk(dynamic node, void Function(Map<String, dynamic>) visitor) {
  if (node is Map) {
    final map = Map<String, dynamic>.from(node);
    visitor(map);
    for (final child in map.values) {
      _walk(child, visitor);
    }
  } else if (node is List) {
    for (final child in node) {
      _walk(child, visitor);
    }
  }
}

String? _continuationToken(dynamic node) {
  String? result;
  _walk(node, (map) {
    if (result != null) return;
    final command = _map(map['continuationCommand']);
    final token = command?['token'];
    if (token is String && token.isNotEmpty) result = token;
  });
  return result;
}

/// Legge i due formati WEB attuali (agosto 2026):
/// - chipBarViewModel -> chipViewModel, con i tre chip visibili direttamente;
/// - chipBarViewModel -> showSheetCommand -> listViewModel -> listItemViewModel,
///   usato quando l'ordinamento e' presentato come menu a tendina.
///
/// Le etichette sono localizzate, quindi l'associazione non dipende dalle
/// parole italiane: YouTube presenta le tre voci nell'ordine newest, popular,
/// oldest. Ogni voce oggi esegue un continuationCommand.
Map<ChannelSort, String> _modernSortContinuations(dynamic root) {
  var result = <ChannelSort, String>{};
  _walk(root, (map) {
    if (result.length == ChannelSort.values.length) return;

    // Variante con i tre pulsanti Più recenti / Popolari / Meno recenti
    // direttamente nella barra. E' quella restituita, per esempio, da
    // https://www.youtube.com/@Loffina/videos.
    final chipBar = _map(map['chipBarViewModel']);
    if (chipBar != null) {
      final chips = _list(chipBar['chips'])
          .map(_map)
          .whereType<Map<String, dynamic>>()
          .map((wrapper) => _map(wrapper['chipViewModel']))
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      if (chips.length >= ChannelSort.values.length &&
          chips.first['selected'] == true) {
        final candidate = <ChannelSort, String>{};
        for (var index = 0; index < ChannelSort.values.length; index++) {
          final token = _continuationToken(chips[index]);
          if (token != null) candidate[ChannelSort.values[index]] = token;
        }
        if (candidate.length == ChannelSort.values.length) {
          result = candidate;
          return;
        }
      }
    }

    // Variante a menu a tendina, presente quando la barra contiene anche
    // altri filtri (per esempio "Per soli abbonati").
    final listView = _map(map['listViewModel']);
    if (listView == null) return;

    final items = _list(listView['listItems'])
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .map((wrapper) => _map(wrapper['listItemViewModel']))
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (items.length < ChannelSort.values.length ||
        items.first['isSelected'] != true) {
      return;
    }

    final candidate = <ChannelSort, String>{};
    for (var index = 0; index < ChannelSort.values.length; index++) {
      final token = _continuationToken(items[index]);
      if (token != null) candidate[ChannelSort.values[index]] = token;
    }
    if (candidate.length == ChannelSort.values.length) result = candidate;
  });
  return result;
}

/// Compatibilita' con il formato precedente, che esponeva browseEndpoint.params
/// nei chipCloudChipRenderer. Non viene usato dalla risposta WEB attuale.
Map<ChannelSort, String> _legacySortParams(dynamic root) {
  var result = <ChannelSort, String>{};
  _walk(root, (map) {
    if (result.length == ChannelSort.values.length) return;
    final cloud = _map(map['chipCloudRenderer']);
    if (cloud == null) return;
    final chips = _list(cloud['chips'])
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .map((wrapper) => _map(wrapper['chipCloudChipRenderer']))
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (chips.length < 3 || chips.first['isSelected'] != true) return;

    final candidate = <ChannelSort, String>{};
    for (var index = 0; index < ChannelSort.values.length; index++) {
      final endpoint = _map(chips[index]['navigationEndpoint']);
      final browse = _map(endpoint?['browseEndpoint']);
      final params = browse?['params'];
      if (params is String && params.isNotEmpty) {
        candidate[ChannelSort.values[index]] = params;
      }
    }
    if (candidate.length == ChannelSort.values.length) result = candidate;
  });
  return result;
}

List<({String id, String title, String? details})> _videos(dynamic root) {
  final videos = <({String id, String title, String? details})>[];
  final seen = <String>{};
  _walk(root, (map) {
    final lockup = _map(map['lockupViewModel']);
    if (lockup != null &&
        lockup['contentType'] == 'LOCKUP_CONTENT_TYPE_VIDEO') {
      final id = lockup['contentId'];
      final metadata = _map(
        _map(lockup['metadata'])?['lockupMetadataViewModel'],
      );
      final title = _text(metadata?['title']);
      if (id is String && title != null && seen.add(id)) {
        videos.add((id: id, title: title, details: _metadataDetails(metadata)));
      }
      return;
    }

    final renderer =
        _map(map['videoRenderer']) ??
        _map(map['gridVideoRenderer']) ??
        _map(map['richItemRenderer']);
    final actual = _map(renderer?['content'])?['videoRenderer'] ?? renderer;
    final video = _map(actual);
    final id = video?['videoId'];
    final title = _text(video?['title']);
    if (id is String && title != null && seen.add(id)) {
      final details = <String?>[
        _text(video?['viewCountText']),
        _text(video?['publishedTimeText']),
      ].whereType<String>().join(' - ');
      videos.add((
        id: id,
        title: title,
        details: details.isEmpty ? null : details,
      ));
    }
  });
  return videos;
}

String? _metadataDetails(Map<String, dynamic>? metadata) {
  final content = _map(
    _map(metadata?['metadata'])?['contentMetadataViewModel'],
  );
  final parts = <String>[];
  _walk(content, (map) {
    final value = _text(map['text']);
    if (value != null && !parts.contains(value)) parts.add(value);
  });
  return parts.isEmpty ? null : parts.join(' - ');
}

Future<Map<String, dynamic>> _loadSort(
  http.Client client, {
  required String channelId,
  required ChannelSort sort,
  required Map<ChannelSort, String> continuations,
  required Map<ChannelSort, String> legacyParams,
}) {
  final continuation = continuations[sort];
  if (continuation != null) {
    return _post(client, <String, dynamic>{
      'context': _context(),
      'continuation': continuation,
    });
  }
  final params = legacyParams[sort];
  if (params != null) {
    return _post(client, <String, dynamic>{
      'context': _context(),
      'browseId': channelId,
      'params': params,
    });
  }
  throw StateError('YouTube non ha esposto il comando per ${sort.name}');
}

Future<void> main(List<String> arguments) async {
  final channelId = arguments.isEmpty ? _defaultChannelId : arguments.first;
  if (!RegExp(r'^UC[A-Za-z0-9_-]{20,}$').hasMatch(channelId)) {
    throw ArgumentError.value(channelId, 'channelId', 'ID canale non valido');
  }

  final client = http.Client();
  try {
    print('Canale: $channelId');
    print('Scopro il menu di ordinamento dal tab Video...');
    final initial = await _post(client, <String, dynamic>{
      'context': _context(),
      'browseId': channelId,
      'params': _newestVideosParams,
    });

    final continuations = _modernSortContinuations(initial);
    final legacyParams = _legacySortParams(initial);
    final mode = continuations.isNotEmpty
        ? 'continuation moderno'
        : 'params legacy';
    print('Formato trovato: $mode');

    for (final sort in const [ChannelSort.popular, ChannelSort.oldest]) {
      final response = await _loadSort(
        client,
        channelId: channelId,
        sort: sort,
        continuations: continuations,
        legacyParams: legacyParams,
      );
      final videos = _videos(response);
      print('\n=== ${sort.name.toUpperCase()} (${videos.length} video) ===');
      for (final video in videos.take(8)) {
        final suffix = video.details == null ? '' : ' | ${video.details}';
        print('${video.id} | ${video.title}$suffix');
      }
      if (videos.isEmpty) {
        throw StateError('La risposta ${sort.name} non contiene video');
      }
    }

    print('\nTEST RIUSCITO: popular e oldest rispondono entrambi.');
  } finally {
    client.close();
  }
}
