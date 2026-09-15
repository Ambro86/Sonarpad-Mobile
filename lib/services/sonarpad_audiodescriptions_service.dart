import 'dart:convert';

import 'package:http/http.dart' as http;

enum SonarpadAudiodescriptionsServiceError { missingCode, invalidResponse }

class SonarpadAudiodescriptionsServiceException implements Exception {
  const SonarpadAudiodescriptionsServiceException(this.error);

  final SonarpadAudiodescriptionsServiceError error;
}


class SonarpadAudiodescriptionItem {
  const SonarpadAudiodescriptionItem({
    required this.type,
    required this.title,
    required this.path,
    required this.filename,
    required this.downloadFilename,
    required this.modifiedTimestamp,
    required this.mimeType,
    required this.streamUrl,
    required this.downloadUrl,
    required this.plot,
  });

  final String type;
  final String title;
  final String path;
  final String filename;
  final String downloadFilename;
  final int modifiedTimestamp;
  final String mimeType;
  final String streamUrl;
  final String downloadUrl;
  final String plot;

  bool get isFolder => type.toLowerCase() == 'folder';

  bool get isVideo {
    if (mimeType.toLowerCase().startsWith('video/')) return true;
    final lower = filename.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm');
  }

  DateTime? get modifiedAt => modifiedTimestamp > 0
      ? DateTime.fromMillisecondsSinceEpoch(modifiedTimestamp * 1000)
      : null;

  String get dateLabel {
    final value = modifiedAt;
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  factory SonarpadAudiodescriptionItem.fromJson(Map<String, dynamic> json) {
    return SonarpadAudiodescriptionItem(
      type: (json['type'] ?? 'file').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      path: (json['path'] ?? '').toString().trim(),
      filename: (json['filename'] ?? '').toString().trim(),
      downloadFilename: (json['download_filename'] ?? json['filename'] ?? '')
          .toString()
          .trim(),
      modifiedTimestamp: int.tryParse(
            (json['modified_timestamp'] ?? '0').toString(),
          ) ??
          0,
      mimeType: (json['mime_type'] ?? '').toString().trim(),
      streamUrl: (json['stream_url'] ?? '').toString().trim(),
      downloadUrl: (json['download_url'] ?? '').toString().trim(),
      plot: (json['plot'] ?? '').toString().trim(),
    );
  }
}

class SonarpadAudiodescriptionsService {
  static const _apiUrl =
      'https://www.nicofranca.it/index.php?api=sonarpad';

  SonarpadAudiodescriptionsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<SonarpadAudiodescriptionItem>> fetchRecent(
    String sonarpadCode, {
    int limit = 50,
  }) =>
      _request(
        sonarpadCode,
        action: 'recent',
        sort: 'recent',
        limit: limit,
      );

  Future<List<SonarpadAudiodescriptionItem>> fetchAll(
    String sonarpadCode, {
    bool chronological = false,
  }) =>
      _request(
        sonarpadCode,
        action: 'all',
        sort: chronological ? 'recent' : 'alpha',
        limit: 1000,
      );

  Future<List<SonarpadAudiodescriptionItem>> fetchFolder(
    String sonarpadCode,
    String folder, {
    bool chronological = false,
  }) =>
      _request(
        sonarpadCode,
        action: folder.trim().isEmpty ? 'catalog' : 'folder',
        folder: folder.trim(),
        sort: chronological ? 'recent' : 'alpha',
        limit: 1000,
      );

  Future<List<SonarpadAudiodescriptionItem>> search(
    String sonarpadCode,
    String query,
  ) =>
      _request(
        sonarpadCode,
        action: 'search',
        query: query.trim(),
        sort: 'alpha',
        limit: 1000,
      );

  Future<List<SonarpadAudiodescriptionItem>> _request(
    String sonarpadCode, {
    required String action,
    required String sort,
    String? query,
    String? folder,
    required int limit,
  }) async {
    final code = sonarpadCode.trim();
    if (code.isEmpty) {
      throw const SonarpadAudiodescriptionsServiceException(
        SonarpadAudiodescriptionsServiceError.missingCode,
      );
    }

    final body = <String, Object?>{
      'action': action,
      'sort': sort,
      'limit': limit,
      'offset': 0,
      'show_branding': false,
      if (query != null && query.isNotEmpty) 'q': query,
      if (folder != null && folder.isNotEmpty) 'folder': folder,
    };

    final response = await _client.post(
      Uri.parse(_apiUrl),
      headers: {
        'User-Agent': 'SonarpadMobile/0.4',
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        'X-Sonarpad-Password': code,
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic>? root;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) root = decoded;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = root?['message']?.toString().trim();
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : 'Errore di rete: ${response.statusCode}',
      );
    }
    if (root == null || root['ok'] != true) {
      throw const SonarpadAudiodescriptionsServiceException(
        SonarpadAudiodescriptionsServiceError.invalidResponse,
      );
    }

    final rawItems = root['items'];
    if (rawItems is! List) return const [];

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(SonarpadAudiodescriptionItem.fromJson)
        .where(
          (item) =>
              item.title.isNotEmpty &&
              (item.isFolder ||
                  (item.streamUrl.isNotEmpty && item.downloadUrl.isNotEmpty)),
        )
        .toList(growable: false);
  }
}
