import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sonarpad_mobile_starter/services/internet_archive_service.dart';

class _MetadataClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonEncode({
      'files': [
        {
          'name': 'Folder/Show #1 + finale?.mp3',
          'format': 'VBR MP3',
          'title': 'Show 1',
        },
        {
          'name': 'Folder/Show #1 + finale?.mp3',
          'format': 'VBR MP3',
          'title': 'Duplicate',
        },
      ],
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

InternetArchiveItem _item({List<InternetArchiveTrack> tracks = const []}) =>
    InternetArchiveItem(
      identifier: 'collection id',
      title: 'Collection',
      creator: 'Creator',
      description: 'Description',
      source: InternetArchiveSource.oldTimeRadio,
      tracks: tracks,
    );

void main() {
  test('download URL encodes every path segment and preserves nesting', () {
    final url = buildInternetArchiveDownloadUrl(
      'collection id',
      'Folder/Show #1 + finale?.mp3',
    );
    final uri = Uri.parse(url);

    expect(uri.scheme, 'https');
    expect(uri.host, 'archive.org');
    expect(uri.pathSegments, [
      'download',
      'collection id',
      'Folder',
      'Show #1 + finale?.mp3',
    ]);
    expect(url, isNot(contains(' ')));
    expect(url, contains('%23'));
    expect(url, contains('%3F'));
  });

  test('metadata parsing removes duplicate audio URLs', () async {
    final service = InternetArchiveService(client: _MetadataClient());
    final result = await service.fetchItem(_item());

    expect(result.tracks, hasLength(1));
    expect(result.tracks.single.title, 'Show 1');
  });

  test('library metadata omits the potentially huge track list', () {
    final saved = _item(
      tracks: const [
        InternetArchiveTrack(
          title: 'Track',
          fileName: 'track.mp3',
          audioUrl: 'https://example.com/track.mp3',
          format: 'MP3',
          length: '1:00',
        ),
      ],
    ).metadataOnly();

    expect(saved.tracks, isEmpty);
    expect(
      internetArchiveItemFromLibraryPath(saved.encodeForLibrary()).tracks,
      isEmpty,
    );
  });
}
