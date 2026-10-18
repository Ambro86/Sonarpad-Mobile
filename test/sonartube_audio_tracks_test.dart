import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/models/media_audio_track.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

Map<String, Object?> audio(
  String id, {
  String codec = 'mp4',
  int rate = 128000,
  bool cipher = false,
}) => {
  'itag': 140,
  'mimeType': 'audio/$codec',
  'bitrate': rate,
  if (!cipher) 'url': 'https://example.org/$id/$codec/$rate',
  if (cipher) 'signatureCipher': 'unresolved',
  'audioTrack': {
    'id': id,
    'displayName': id == 'it.3' ? 'Italiano' : 'Polski',
    'audioIsDefault': id == 'it.3',
  },
};

Map<String, Object?> player(List<Map<String, Object?>> tracks) => {
  'playabilityStatus': {'status': 'OK'},
  'videoDetails': {'videoId': 'RE3_PGwDwhw', 'title': 'Multilingual'},
  'streamingData': {
    'formats': [
      {
        'itag': 18,
        'mimeType': 'video/mp4',
        'width': 640,
        'height': 360,
        'audioQuality': 'AUDIO_QUALITY_MEDIUM',
        'url': 'https://example.org/video',
      },
    ],
    'adaptiveFormats': tracks,
  },
};

void main() {
  test('deduplicates codecs, prefers AAC and excludes unplayable tracks', () {
    final tracks = MediaAudioTrack.fromYouTube({
      'adaptiveFormats': [
        audio('it.3', codec: 'webm', rate: 200000),
        audio('it.3'),
        audio('it.3', rate: 64000),
        audio('pl.3'),
        audio('fr.3', cipher: true),
      ],
    });
    expect(tracks.map((track) => track.id), ['it.3', 'pl.3']);
    expect(tracks.first.url, 'https://example.org/it.3/mp4/128000');
    expect(tracks.first.isDefault, isTrue);
  });

  test(
    'single track keeps original stream and makes no extra request',
    () async {
      var requests = 0;
      final service = SonarTubeService(
        client: MockClient((request) async {
          requests++;
          return http.Response(jsonEncode(player([audio('it.3')])), 200);
        }),
      );
      final media = await service.resolveUrl(
        'RE3_PGwDwhw',
        fallbackTitle: 'Video',
      );
      expect(requests, 1);
      expect(media.audioUrl, 'https://example.org/video');
      expect(media.videoUrl, isNull);
      expect(media.audioTracks, hasLength(1));
    },
  );

  test('encrypted alternate tracks trigger compatible profile only', () async {
    final versions = <String>[];
    final service = SonarTubeService(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final version = body['context']['client']['clientVersion'] as String;
        versions.add(version);
        expect(request.headers['X-YouTube-Client-Version'], version);
        return http.Response(
          jsonEncode(
            player([
              audio('it.3', cipher: versions.length == 1),
              audio('pl.3', cipher: versions.length == 1),
            ]),
          ),
          200,
        );
      }),
    );
    final media = await service.resolveUrl(
      'RE3_PGwDwhw',
      fallbackTitle: 'Video',
    );
    expect(versions, ['21.29.366', '20.10.38']);
    expect(media.audioTracks, hasLength(2));
    expect(media.selectedAudioTrackId, 'it.3');
    expect(media.audioUrl, 'https://example.org/video');
  });

  test(
    'alternate profile failure does not break existing video playback',
    () async {
      var count = 0;
      final service = SonarTubeService(
        client: MockClient((request) async {
          if (++count > 1) return http.Response('unavailable', 503);
          return http.Response(
            jsonEncode(
              player([
                audio('it.3', cipher: true),
                audio('pl.3', cipher: true),
              ]),
            ),
            200,
          );
        }),
      );
      final media = await service.resolveUrl(
        'RE3_PGwDwhw',
        fallbackTitle: 'Video',
      );
      expect(media.audioUrl, 'https://example.org/video');
      expect(media.audioTracks, isEmpty);
    },
  );

  test(
    'PHP metadata is optional and duplicate/unsafe tracks are excluded',
    () async {
      for (final withTracks in [false, true]) {
        final service = SonarTubeService(
          enableDirectNavigation: false,
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'ok': true,
                'stream': 'https://example.org/video',
                if (withTracks)
                  'audio_tracks': [
                    {
                      'id': 'it.3',
                      'label': 'Italiano',
                      'url': 'https://example.org/it',
                    },
                    {'id': 'it.3', 'url': 'https://example.org/duplicate'},
                    {
                      'id': 'pl.3',
                      'label': 'Polski',
                      'url': 'https://example.org/pl',
                    },
                    {'id': 'bad', 'url': 'file:///private'},
                  ],
                'selected_audio_track_id': 'it.3',
              }),
              200,
            ),
          ),
        );
        final media = await service.resolveUrl(
          'RE3_PGwDwhw',
          fallbackTitle: 'Video',
        );
        expect(media.audioTracks, hasLength(withTracks ? 2 : 0));
      }
    },
  );

  test('changing track keeps video, stable identity and chapter metadata', () {
    final tracks = MediaAudioTrack.fromYouTube({
      'adaptiveFormats': [audio('it.3'), audio('pl.3')],
    });
    final original = PodcastEpisode(
      id: 'sonartube:RE3_PGwDwhw',
      title: 'Video',
      description: 'Description',
      audioUrl: 'https://example.org/video',
      chaptersUrl: 'https://example.org/chapters',
      audioTracks: tracks,
    );
    final polish = original.withAudioTrack('pl.3');
    final italian = polish.withAudioTrack('it.3');
    expect(polish.videoUrl, original.audioUrl);
    expect(italian.videoUrl, original.audioUrl);
    expect(polish.audioUrl, tracks.last.url);
    expect(italian.audioUrl, tracks.first.url);
    expect(polish.id, original.id);
    expect(polish.chaptersUrl, original.chaptersUrl);
    expect(polish.selectedAudioTrackId, 'pl.3');
    expect(identical(original.withAudioTrack('missing'), original), isTrue);
  });

  test(
    'live Dart uses the local PHP resolver and its alternate tracks',
    () async {
      final phpPath = Platform.environment['SONARPAD_YOUTUBE_PHP']!;
      final source = File(phpPath).readAsStringSync();
      final token = RegExp(
        r"const SONARPAD_YOUTUBE_CLIENT_TOKEN = '([^']+)'",
      ).firstMatch(source)!.group(1)!;
      final directory = Directory.systemTemp.createTempSync(
        'sonarpad-audio-php-',
      );
      final router = File('${directory.path}/router.php')
        ..writeAsStringSync("<?php require getenv('SONARPAD_YOUTUBE_PHP');");
      final server = await Process.start('php', [
        '-S',
        '127.0.0.1:18949',
        router.path,
      ], workingDirectory: directory.path);
      final output = server.stdout.drain<void>();
      final errors = server.stderr.drain<void>();
      try {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final service = SonarTubeService(
          enableDirectNavigation: false,
          clientToken: token,
          endpoint: Uri.parse('http://127.0.0.1:18949/'),
        );
        final media = await service.resolveUrl(
          'RE3_PGwDwhw',
          fallbackTitle: 'Video',
        );
        expect(media.audioTracks.length, greaterThan(1));
        for (final id in ['it.3', 'es.3', 'pl.3']) {
          final track = media.audioTracks.singleWhere(
            (track) => track.id == id,
          );
          final response = await http
              .get(Uri.parse(track.url), headers: {'Range': 'bytes=0-1023'})
              .timeout(const Duration(seconds: 20));
          expect(response.statusCode, 206);
          expect(response.bodyBytes.length, 1024);
        }
      } finally {
        server.kill();
        await server.exitCode;
        await Future.wait([output, errors]);
        // Only the known temporary router is removed.
        router.deleteSync();
        directory.deleteSync();
      }
    },
    skip: Platform.environment['SONARPAD_YOUTUBE_PHP'] == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'live direct Dart resolver exposes playable alternate languages',
    () async {
      final service = SonarTubeService(
        endpoint: Uri.parse('http://127.0.0.1:9'),
      );
      final media = await service.resolveUrl(
        'RE3_PGwDwhw',
        fallbackTitle: 'Video',
      );
      expect(media.audioTracks.length, greaterThan(1));
      for (final id in ['it.3', 'es.3', 'pl.3']) {
        final track = media.audioTracks.singleWhere((track) => track.id == id);
        final response = await http
            .get(Uri.parse(track.url), headers: {'Range': 'bytes=0-1023'})
            .timeout(const Duration(seconds: 20));
        expect(response.statusCode, 206);
        expect(response.bodyBytes.length, 1024);
      }
      // Store only the track names, never temporary signed URLs.
      if (Platform.environment['SONARPAD_AUDIO_TRACK_REPORT']
          case final String path) {
        File(path).writeAsStringSync(
          jsonEncode(
            media.audioTracks
                .map((track) => {'id': track.id, 'label': track.label})
                .toList(),
          ),
        );
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_SONARTUBE_AUDIO'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
