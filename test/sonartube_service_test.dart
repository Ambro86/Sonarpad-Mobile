import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  test(
    'search uses direct InnerTube and preserves mixed result behavior',
    () async {
      var innerTubeRequests = 0;
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        clientToken: 'test-route-client-token',
        client: MockClient((request) async {
          expect(request.url.host, 'www.youtube.com');
          expect(request.method, 'POST');
          expect(request.url.path, '/youtubei/v1/search');
          innerTubeRequests++;
          final body = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          final params = body['params']?.toString();

          if (params == 'EgIQAQ==') {
            return http.Response(
              jsonEncode({
                'contents': {
                  'itemSectionRenderer': {
                    'contents': [
                      {
                        'videoRenderer': {
                          'videoId': 'exactvid001',
                          'title': {
                            'runs': [
                              {'text': 'Elisa risultato esatto'},
                            ],
                          },
                          'shortBylineText': {
                            'runs': [
                              {
                                'text': 'Elisa',
                                'navigationEndpoint': {
                                  'browseEndpoint': {
                                    'browseId':
                                        'UCabcdefghijklmnopqrstuv',
                                  },
                                },
                              },
                            ],
                          },
                          'lengthText': {'simpleText': '4:12'},
                          'viewCountText': {'simpleText': '100 visualizzazioni'},
                        },
                      },
                    ],
                  },
                },
              }),
              200,
            );
          }
          if (params == 'EgIQAg==') {
            return http.Response(
              jsonEncode({
                'contents': {
                  'channelRenderer': {
                    'channelId': 'UCabcdefghijklmnopqrstuv',
                    'title': {'simpleText': 'Elisa'},
                    'thumbnail': {
                      'thumbnails': [
                        {'url': 'https://img.test/elisa.jpg'},
                      ],
                    },
                  },
                },
              }),
              200,
            );
          }
          if (params == 'EgIQAw==') {
            return http.Response(
              jsonEncode({
                'contents': {
                  'playlistRenderer': {
                    'playlistId': 'PLelisa123',
                    'title': {'simpleText': 'Elisa playlist'},
                  },
                },
              }),
              200,
            );
          }

          expect(body['query'], 'elisa');
          return http.Response(
            jsonEncode({
              'estimatedResults': '1000',
              'contents': {
                'sectionListRenderer': {
                  'contents': [
                    {
                      'itemSectionRenderer': {
                        'contents': [
                          {
                            'videoRenderer': {
                              'videoId': 'general0001',
                              'title': {
                                'runs': [
                                  {'text': 'Elisa video generale'},
                                ],
                              },
                              'viewCountText': {'simpleText': '200 visualizzazioni'},
                              'shortBylineText': {
                                'runs': [
                                  {
                                    'text': 'Elisa',
                                    'navigationEndpoint': {
                                      'browseEndpoint': {
                                        'browseId':
                                            'UCabcdefghijklmnopqrstuv',
                                      },
                                    },
                                  },
                                ],
                              },
                            },
                          },
                        ],
                      },
                    },
                    {
                      'continuationItemRenderer': {
                        'continuationEndpoint': {
                          'continuationCommand': {'token': 'next-page'},
                        },
                      },
                    },
                  ],
                },
              },
            }),
            200,
          );
        }),
      );

      final page = await service.search('elisa');

      expect(innerTubeRequests, 4);
      expect(page.items.map((item) => item.title), [
        'Elisa risultato esatto',
        'Elisa video generale',
        'Elisa',
        'Elisa playlist',
      ]);
      expect(page.items.map((item) => item.kind), [
        SonarTubeItemKind.video,
        SonarTubeItemKind.video,
        SonarTubeItemKind.channel,
        SonarTubeItemKind.playlist,
      ]);
      expect(page.items.first.channelId, 'UCabcdefghijklmnopqrstuv');
      expect(page.nextToken, 'next-page');
      expect(page.hasMore, isTrue);
    },
  );

  test('search falls back to the resolver after direct InnerTube fails', () async {
    var directAttempts = 0;
    var fallbackRequests = 0;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      clientToken: 'test-route-client-token',
      client: MockClient((request) async {
        if (request.url.host == 'www.youtube.com') {
          directAttempts++;
          return http.Response('temporary InnerTube failure', 503);
        }
        fallbackRequests++;
        expect(
          request.headers['X-Sonarpad-Route-Token'],
          'test-route-client-token',
        );
        expect(request.url.queryParameters['q'], 'retry');
        expect(request.url.queryParameters['type'], 'all');
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 1,
            'items': [
              {
                'kind': 'video',
                'id': 'abcdefghijk',
                'title': 'Risultato dal fallback',
                'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                'views': '10 visualizzazioni',
              },
            ],
          }),
          200,
        );
      }),
    );

    final page = await service.search('retry');

    expect(directAttempts, 2);
    expect(fallbackRequests, 1);
    expect(page.items.single.title, 'Risultato dal fallback');
  });

  test('search continuation uses the direct token without supplemental queries', () async {
    var requests = 0;
    late Map<String, dynamic> requestedBody;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requests++;
        expect(request.url.host, 'www.youtube.com');
        expect(request.url.path, '/youtubei/v1/search');
        requestedBody = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        return http.Response(
          jsonEncode({
            'contents': {
              'videoRenderer': {
                'videoId': 'nextvideo01',
                'title': {'simpleText': 'Elisa pagina due'},
                'viewCountText': {'simpleText': '300 visualizzazioni'},
              },
            },
            'continuationItemRenderer': {
              'continuationEndpoint': {
                'continuationCommand': {'token': 'next-page-3'},
              },
            },
          }),
          200,
        );
      }),
    );

    final page = await service.search(
      'elisa',
      token: 'next-page-2',
      page: 2,
    );

    expect(requests, 1);
    expect(requestedBody['continuation'], 'next-page-2');
    expect(requestedBody.containsKey('query'), isFalse);
    expect(requestedBody.containsKey('params'), isFalse);
    expect(page.page, 2);
    expect(page.items.single.title, 'Elisa pagina due');
    expect(page.nextToken, 'next-page-3');
  });

  test('browse falls back to the resolver when direct navigation is unusable', () async {
    var directAttempts = 0;
    var fallbackRequests = 0;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      clientToken: 'test-route-client-token',
      client: MockClient((request) async {
        if (request.url.host == 'www.youtube.com') {
          directAttempts++;
          // HTTP 200 ma nessun renderer video: viene trattato come navigazione
          // diretta non utilizzabile e deve scattare il resolver server.
          return http.Response(jsonEncode({'contents': {}}), 200);
        }
        fallbackRequests++;
        expect(request.url.queryParameters['browse'], 'PLfallback123');
        expect(request.url.queryParameters['kind'], 'playlist');
        expect(
          request.headers['X-Sonarpad-Route-Token'],
          'test-route-client-token',
        );
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 1,
            'items': [
              {
                'kind': 'video',
                'id': 'abcdefghijk',
                'title': 'Video dal resolver',
                'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                'views': '20 visualizzazioni',
              },
            ],
          }),
          200,
        );
      }),
    );
    const playlist = SonarTubeItem(
      kind: SonarTubeItemKind.playlist,
      id: 'PLfallback123',
      title: 'Playlist fallback',
      url: 'https://www.youtube.com/playlist?list=PLfallback123',
    );

    final page = await service.browse(playlist);

    expect(directAttempts, 2);
    expect(fallbackRequests, 1);
    expect(page.items.single.title, 'Video dal resolver');
  });

  test('channel browse uses the direct Videos tab', () async {
    late Map<String, dynamic> requestedBody;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        expect(request.url.host, 'www.youtube.com');
        expect(request.url.path, '/youtubei/v1/browse');
        requestedBody = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        return http.Response(
          jsonEncode({
            'contents': {
              'playlistVideoRenderer': {
                'videoId': 'abcdefghijk',
                'title': {'simpleText': 'Video del canale'},
                'viewCountText': {'simpleText': '10 visualizzazioni'},
              },
            },
            'continuationItemRenderer': {
              'continuationEndpoint': {
                'continuationCommand': {'token': 'channel-next'},
              },
            },
          }),
          200,
        );
      }),
    );
    const channel = SonarTubeItem(
      kind: SonarTubeItemKind.channel,
      id: 'UCabcdefghijklmnopqrstuv',
      title: 'Canale accessibile',
      url:
          'https://www.youtube.com/channel/UCabcdefghijklmnopqrstuv',
    );

    final page = await service.browse(channel);

    expect(requestedBody['browseId'], 'UCabcdefghijklmnopqrstuv');
    expect(requestedBody['params'], 'EgZ2aWRlb3PyBgQKAjoA');
    expect(page.items.single.title, 'Video del canale');
    expect(page.nextToken, 'channel-next');
  });

  test(
    'channel browse uses the real Videos tab instead of the capped uploads playlist',
    () async {
      late Map<String, dynamic> requestedBody;
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        client: MockClient((request) async {
          requestedBody = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode({
              'contents': {
                'richGridRenderer': {
                  'contents': [
                    {
                      'richItemRenderer': {
                        'content': {
                          'videoRenderer': {
                            'videoId': 'abcdefghijk',
                            'title': {'simpleText': 'Video recente'},
                            'viewCountText': {'simpleText': '20 visualizzazioni'},
                          },
                        },
                      },
                    },
                    {
                      'continuationItemRenderer': {
                        'continuationEndpoint': {
                          'continuationCommand': {'token': 'older-videos'},
                        },
                      },
                    },
                  ],
                },
              },
            }),
            200,
          );
        }),
      );
      const channel = SonarTubeItem(
        kind: SonarTubeItemKind.channel,
        id: 'UCabcdefghijklmnopqrstuv',
        title: 'Canale molto lungo',
        url: 'https://www.youtube.com/@canale',
      );

      final page = await service.browse(channel);

      expect(requestedBody['browseId'], channel.id);
      expect(requestedBody['params'], 'EgZ2aWRlb3PyBgQKAjoA');
      expect(page.items.single.title, 'Video recente');
      expect(page.nextToken, 'older-videos');
      expect(page.hasMore, isTrue);
    },
  );

  test(
    'channel Videos tab restores channel, age and views from compact lockup metadata',
    () async {
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'contents': {
                  'richGridRenderer': {
                    'contents': [
                      {
                        'richItemRenderer': {
                          'content': {
                            'lockupViewModel': {
                              'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
                              'contentId': 'abcdefghijk',
                              'metadata': {
                                'lockupMetadataViewModel': {
                                  'title': {
                                    'content':
                                        "Generale Vannacci: l'aborto non e un diritto",
                                  },
                                  'metadata': {
                                    'contentMetadataViewModel': {
                                      'metadataRows': [
                                        {
                                          'metadataParts': [
                                            {
                                              'text': {
                                                'content': '207 visualizzazioni',
                                              },
                                            },
                                            {
                                              'text': {
                                                'content': '55 minuti fa',
                                              },
                                            },
                                          ],
                                        },
                                      ],
                                    },
                                  },
                                },
                              },
                              'contentImage': {
                                'thumbnailViewModel': {
                                  'image': {
                                    'sources': [
                                      {'url': 'https://img.test/video.jpg'},
                                    ],
                                  },
                                  'overlays': [
                                    {
                                      'thumbnailBottomOverlayViewModel': {
                                        'badges': [
                                          {
                                            'thumbnailBadgeViewModel': {
                                              'text': '1:48',
                                            },
                                          },
                                        ],
                                      },
                                    },
                                  ],
                                },
                              },
                            },
                          },
                        },
                      },
                      {
                        'continuationItemRenderer': {
                          'continuationEndpoint': {
                            'continuationCommand': {'token': 'next-page'},
                          },
                        },
                      },
                    ],
                  },
                },
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      const channel = SonarTubeItem(
        kind: SonarTubeItemKind.channel,
        id: 'UCLfQVw8Opp0ZcOHbcbY_4CQ',
        title: 'Diego Fusaro',
        url: 'https://www.youtube.com/@DiegoFusaro',
      );

      final page = await service.browse(channel);
      final video = page.items.single;

      expect(video.channel, 'Diego Fusaro');
      expect(video.channelId, channel.id);
      expect(video.duration, '1:48');
      expect(video.published, '55 minuti fa');
      expect(video.views, '207 visualizzazioni');
      expect(page.hasMore, isTrue);
    },
  );

  test(
    'channel browse hides video placeholders without view metadata',
    () async {
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'contents': {
                'richGridRenderer': {
                  'contents': [
                    {
                      'richItemRenderer': {
                        'content': {
                          'videoRenderer': {
                            'videoId': 'playable001',
                            'title': {'simpleText': 'Video apribile'},
                            'viewCountText': {
                              'simpleText': '123 visualizzazioni',
                            },
                          },
                        },
                      },
                    },
                    {
                      'richItemRenderer': {
                        'content': {
                          'videoRenderer': {
                            'videoId': 'blocked0001',
                            'title': {'simpleText': 'Placeholder non apribile'},
                          },
                        },
                      },
                    },
                  ],
                },
              },
            }),
            200,
          );
        }),
      );
      const channel = SonarTubeItem(
        kind: SonarTubeItemKind.channel,
        id: 'UCabcdefghijklmnopqrstuv',
        title: 'Canale',
        url: 'https://www.youtube.com/channel/UCabcdefghijklmnopqrstuv',
      );

      final page = await service.browse(channel);

      expect(page.items, hasLength(1));
      expect(page.items.single.id, 'playable001');
      expect(page.items.single.views, '123 visualizzazioni');
    },
  );

  test(
    'channel browse keeps pagination when YouTube uses reloadContinuationData',
    () async {
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'continuationContents': {
                  'playlistVideoListContinuation': {
                    'contents': [
                      {
                        'playlistVideoRenderer': {
                          'videoId': 'oldvideo001',
                          'title': {'simpleText': 'Video più vecchio'},
                          'viewCountText': {'simpleText': '30 visualizzazioni'},
                        },
                      },
                    ],
                    'continuations': [
                      {
                        'reloadContinuationData': {
                          'continuation': 'older-channel-page',
                        },
                      },
                    ],
                  },
                },
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      const channel = SonarTubeItem(
        kind: SonarTubeItemKind.channel,
        id: 'UCabcdefghijklmnopqrstuv',
        title: 'Canale lungo',
        url: 'https://www.youtube.com/channel/UCabcdefghijklmnopqrstuv',
      );

      final page = await service.browse(
        channel,
        token: 'current-channel-page',
        page: 8,
      );

      expect(page.items.single.title, 'Video più vecchio');
      expect(page.nextToken, 'older-channel-page');
      expect(page.hasMore, isTrue);
    },
  );

  test(
    'channel browse accepts continuation nested in command executor',
    () async {
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'onResponseReceivedActions': [
                {
                  'appendContinuationItemsAction': {
                    'continuationItems': [
                      {
                        'playlistVideoRenderer': {
                          'videoId': 'oldvideo002',
                          'title': {'simpleText': 'Altro video vecchio'},
                          'viewCountText': {'simpleText': '40 visualizzazioni'},
                        },
                      },
                      {
                        'continuationItemRenderer': {
                          'button': {
                            'buttonRenderer': {
                              'command': {
                                'commandExecutorCommand': {
                                  'commands': [
                                    {
                                      'continuationCommand': {
                                        'token': 'nested-channel-page',
                                      },
                                    },
                                  ],
                                },
                              },
                            },
                          },
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      const channel = SonarTubeItem(
        kind: SonarTubeItemKind.channel,
        id: 'UCabcdefghijklmnopqrstuv',
        title: 'Canale lungo',
        url: 'https://www.youtube.com/channel/UCabcdefghijklmnopqrstuv',
      );

      final page = await service.browse(
        channel,
        token: 'current-channel-page',
        page: 9,
      );

      expect(page.items.single.title, 'Altro video vecchio');
      expect(page.nextToken, 'nested-channel-page');
      expect(page.hasMore, isTrue);
    },
  );

  test('browse continuation is sent directly without needing the browse id', () async {
    late Map<String, dynamic> requestedBody;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requestedBody = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        return http.Response(
          jsonEncode({
            'contents': {
              'playlistVideoRenderer': {
                'videoId': 'abcdefghijk',
                'title': {'simpleText': 'Pagina successiva'},
                'viewCountText': {'simpleText': '50 visualizzazioni'},
              },
            },
          }),
          200,
        );
      }),
    );
    const playlist = SonarTubeItem(
      kind: SonarTubeItemKind.playlist,
      id: 'PL123',
      title: 'Playlist',
      url: 'https://www.youtube.com/playlist?list=PL123',
    );

    final page = await service.browse(
      playlist,
      token: 'continuation-token',
      page: 2,
    );

    expect(requestedBody['continuation'], 'continuation-token');
    expect(requestedBody.containsKey('browseId'), isFalse);
    expect(page.page, 2);
    expect(page.items.single.title, 'Pagina successiva');
  });

  test(
    'resolve keeps separate video and audio streams for the player',
    () async {
      final service = SonarTubeService(
        endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
        client: MockClient((request) async {
          expect(request.url.queryParameters['format'], 'json');
          return http.Response(
            jsonEncode({
              'ok': true,
              'title': 'Video risolto',
              'channel': 'Canale',
              'stream': 'https://media.test/video.mp4',
              'stream_video': 'https://media.test/video.mp4',
              'stream_audio': 'https://media.test/audio.m4a',
            }),
            200,
          );
        }),
      );
      const video = SonarTubeItem(
        kind: SonarTubeItemKind.video,
        id: 'abcdefghijk',
        title: 'Video',
        url: 'https://www.youtube.com/watch?v=abcdefghijk',
      );

      final media = await service.resolve(video);

      expect(media.videoUrl, 'https://media.test/video.mp4');
      expect(media.audioUrl, 'https://media.test/audio.m4a');
      expect(media.title, 'Video risolto');
    },
  );
  test('browse sends the seed video directly for a generated YouTube Mix', () async {
    late Uri requestedUri;
    late Map<String, dynamic> requestedBody;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requestedUri = request.url;
        requestedBody = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        return http.Response(
          jsonEncode({
            'contents': {
              'playlistPanelVideoRenderer': {
                'videoId': 'abcdefghijk',
                'title': {'simpleText': 'Mix seed'},
                'viewCountText': {'simpleText': '60 visualizzazioni'},
              },
            },
          }),
          200,
        );
      }),
    );
    const mix = SonarTubeItem(
      kind: SonarTubeItemKind.playlist,
      id: 'RDabcdefghijk',
      title: 'Mix',
      url: 'https://www.youtube.com/watch?v=abcdefghijk&list=RDabcdefghijk',
    );

    await service.browse(mix);

    expect(requestedUri.host, 'www.youtube.com');
    expect(requestedUri.path, '/youtubei/v1/next');
    expect(requestedBody['playlistId'], 'RDabcdefghijk');
    expect(requestedBody['videoId'], 'abcdefghijk');
  });

  test('resolveUrl accepts a direct YouTube trailer URL', () async {
    late Uri requestedUri;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'ok': true,
            'stream': 'https://media.test/trailer.mp4',
          }),
          200,
        );
      }),
    );

    final media = await service.resolveUrl(
      'https://www.youtube.com/watch?v=trailer12345',
      fallbackTitle: 'Titolo film',
    );

    expect(
      requestedUri.queryParameters['url'],
      'https://www.youtube.com/watch?v=trailer12345',
    );
    expect(media.audioUrl, 'https://media.test/trailer.mp4');
    expect(media.title, 'Titolo film');
  });


  test('comments use the dedicated resolver mode and parse pagination', () async {
    late Uri requestedUri;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 2,
            'next_token': 'comments-next',
            'items': [
              {
                'id': 'comment-1',
                'text': 'Commento di prova',
                'author': 'Autore',
                'published': '1 giorno fa',
              },
            ],
          }),
          200,
        );
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    final page = await service.comments(video, token: 'token-1', page: 2);

    expect(requestedUri.queryParameters['comments'], '1');
    expect(requestedUri.queryParameters['token'], 'token-1');
    expect(page.items.single.text, 'Commento di prova');
    expect(page.hasMore, isTrue);
  });

  test('channel action resolves missing channel metadata directly from YouTube', () async {
    var fallbackCalled = false;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        if (request.url.host != 'www.youtube.com') {
          fallbackCalled = true;
          return http.Response('{}', 500);
        }
        expect(request.url.path, '/youtubei/v1/player');
        final body = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        expect(body['videoId'], 'abcdefghijk');
        return http.Response(
          jsonEncode({
            'videoDetails': {
              'author': 'Canale diretto',
              'channelId': 'UCabcdefghijklmnopqrstuv',
            },
          }),
          200,
        );
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    final channel = await service.channelForVideo(video);

    expect(fallbackCalled, isFalse);
    expect(channel.id, 'UCabcdefghijklmnopqrstuv');
    expect(channel.title, 'Canale diretto');
  });

  test('channel action uses stored channel id without a request', () async {
    var requested = false;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requested = true;
        return http.Response('{}', 500);
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
      channel: 'Canale',
      channelId: 'UCabcdefghijklmnopqrstuv',
    );

    final channel = await service.channelForVideo(video);

    expect(requested, isFalse);
    expect(channel.kind, SonarTubeItemKind.channel);
    expect(channel.id, 'UCabcdefghijklmnopqrstuv');
  });

  test('transcribe uses resolver transcript mode and requested app language', () async {
    late Uri requestedUri;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'ok': true,
            'title': 'Video trascritto',
            'lang': 'it',
            'auto_generated': true,
            'transcript': 'Testo completo della trascrizione.',
            'lines': [
              {'start': 0, 'text': 'Testo completo'},
              {'start': 2, 'text': 'della trascrizione.'},
            ],
          }),
          200,
        );
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    final transcript = await service.transcribe(video);

    expect(requestedUri.queryParameters['transcribe'], '1');
    expect(requestedUri.queryParameters['format'], 'json');
    expect(requestedUri.queryParameters['lang'], 'auto');
    expect(requestedUri.queryParameters['timestamps'], '1');
    expect(transcript.text, 'Testo completo della trascrizione.');
    expect(transcript.autoGenerated, isTrue);
    expect(transcript.language, 'it');
    expect(transcript.paragraphs, ['Testo completo della trascrizione.']);
  });

  test('transcribe retries once after a temporary resolver failure', () async {
    var requests = 0;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        requests++;
        if (requests == 1) return http.Response('temporarily unavailable', 503);
        return http.Response(
          jsonEncode({
            'ok': true,
            'transcript': 'Trascrizione recuperata al secondo tentativo.',
          }),
          200,
        );
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    final transcript = await service.transcribe(video);

    expect(requests, 2);
    expect(transcript.text, 'Trascrizione recuperata al secondo tentativo.');
    expect(transcript.paragraphs, isNotEmpty);
  });

  test('transcribe groups caption segments into flickable paragraphs', () async {
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        final lines = List.generate(8, (index) => {
          'start': index * 2,
          'text': 'Segmento ${index + 1} ${List.filled(18, 'testo').join(' ')}',
        });
        return http.Response(
          jsonEncode({
            'ok': true,
            'transcript': 'fallback',
            'lines': lines,
          }),
          200,
        );
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    final transcript = await service.transcribe(video);

    expect(transcript.paragraphs.length, greaterThan(1));
    expect(transcript.text, contains('Segmento 1'));
    expect(transcript.text, contains('Segmento 8'));
  });

  test('transcribe maps missing captions to transcript unavailable', () async {
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': false, 'error': 'no_captions'}),
          200,
        );
      }),
    );
    const video = SonarTubeItem(
      kind: SonarTubeItemKind.video,
      id: 'abcdefghijk',
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=abcdefghijk',
    );

    await expectLater(
      service.transcribe(video),
      throwsA(isA<SonarTubeTranscriptUnavailableException>()),
    );
  });


  test('direct search parses modern lockup and mix renderers without server fallback', () async {
    var serverFallbackCalled = false;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        if (request.url.host != 'www.youtube.com') {
          serverFallbackCalled = true;
          return http.Response('{}', 500);
        }
        final body = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        if (body['params'] != null) {
          return http.Response(jsonEncode({'contents': {}}), 200);
        }
        return http.Response(
          jsonEncode({
            'contents': {
              'sectionListRenderer': {
                'contents': [
                  {
                    'lockupViewModel': {
                      'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
                      'contentId': 'lockupvid01',
                      'metadata': {
                        'lockupMetadataViewModel': {
                          'title': {'content': 'Video layout moderno'},
                          'metadata': {
                            'contentMetadataViewModel': {
                              'metadataRows': [
                                {
                                  'metadataParts': [
                                    {
                                      'text': {'content': 'Canale moderno'},
                                    },
                                  ],
                                },
                                {
                                  'metadataParts': [
                                    {
                                      'text': {'content': '12.345 visualizzazioni'},
                                    },
                                    {
                                      'text': {'content': '2 giorni fa'},
                                    },
                                  ],
                                },
                              ],
                            },
                          },
                        },
                      },
                      'contentImage': {
                        'thumbnailViewModel': {
                          'image': {
                            'sources': [
                              {'url': 'https://img.test/modern.jpg'},
                            ],
                          },
                          'overlays': [
                            {
                              'thumbnailBottomOverlayViewModel': {
                                'badges': [
                                  {
                                    'thumbnailBadgeViewModel': {'text': '3:21'},
                                  },
                                ],
                              },
                            },
                          ],
                        },
                      },
                    },
                  },
                  {
                    'radioRenderer': {
                      'playlistId': 'RDlockupvid01',
                      'title': {'simpleText': 'Mix moderno'},
                      'navigationEndpoint': {
                        'watchEndpoint': {
                          'playlistId': 'RDlockupvid01',
                          'videoId': 'lockupvid01',
                        },
                      },
                    },
                  },
                  {
                    'continuationItemRenderer': {
                      'continuationEndpoint': {
                        'continuationCommand': {'token': 'modern-next'},
                      },
                    },
                  },
                ],
              },
            },
          }),
          200,
        );
      }),
    );

    final page = await service.search('layout moderno');

    expect(serverFallbackCalled, isFalse);
    expect(page.items.where((item) => item.id == 'lockupvid01').single.kind,
        SonarTubeItemKind.video);
    expect(
      page.items.where((item) => item.id == 'RDlockupvid01').single.kind,
      SonarTubeItemKind.playlist,
    );
    expect(page.nextToken, 'modern-next');
  });

  test('search continuation fallback preserves token and page for the PHP resolver', () async {
    var directAttempts = 0;
    var fallbackRequests = 0;
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      clientToken: 'test-route-client-token',
      client: MockClient((request) async {
        if (request.url.host == 'www.youtube.com') {
          directAttempts++;
          return http.Response('temporary InnerTube failure', 503);
        }
        fallbackRequests++;
        expect(request.url.queryParameters['q'], 'elisa');
        expect(request.url.queryParameters['token'], 'direct-next-token');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['type'], 'all');
        expect(
          request.headers['X-Sonarpad-Route-Token'],
          'test-route-client-token',
        );
        return http.Response(
          jsonEncode({
            'ok': true,
            'page': 2,
            'next_token': 'server-next-token',
            'items': [
              {
                'kind': 'video',
                'id': 'servervid01',
                'title': 'Pagina due dal fallback',
                'url': 'https://www.youtube.com/watch?v=servervid01',
                'views': '70 visualizzazioni',
              },
            ],
          }),
          200,
        );
      }),
    );

    final page = await service.search(
      'elisa',
      token: 'direct-next-token',
      page: 2,
    );

    expect(directAttempts, 2);
    expect(fallbackRequests, 1);
    expect(page.page, 2);
    expect(page.nextToken, 'server-next-token');
    expect(page.items.single.title, 'Pagina due dal fallback');
  });

  test('search hides video results without view metadata but keeps collections', () async {
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        if (body['params'] != null) {
          return http.Response(jsonEncode({'contents': {}}), 200);
        }
        return http.Response(
          jsonEncode({
            'contents': {
              'sectionListRenderer': {
                'contents': [
                  {
                    'itemSectionRenderer': {
                      'contents': [
                        {
                          'videoRenderer': {
                            'videoId': 'playable001',
                            'title': {'simpleText': 'Video valido'},
                            'viewCountText': {'simpleText': '42 visualizzazioni'},
                          },
                        },
                        {
                          'videoRenderer': {
                            'videoId': 'blocked0001',
                            'title': {'simpleText': 'Video non apribile'},
                          },
                        },
                        {
                          'playlistRenderer': {
                            'playlistId': 'PLkeep123',
                            'title': {'simpleText': 'Playlist valida'},
                          },
                        },
                      ],
                    },
                  },
                ],
              },
            },
          }),
          200,
        );
      }),
    );

    final page = await service.search('prova');

    expect(page.items.any((item) => item.id == 'playable001'), isTrue);
    expect(page.items.any((item) => item.id == 'blocked0001'), isFalse);
    expect(page.items.any((item) => item.id == 'PLkeep123'), isTrue);
  });

  test('playlist browse hides video entries without view metadata', () async {
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'contents': {
              'playlistVideoListRenderer': {
                'contents': [
                  {
                    'playlistVideoRenderer': {
                      'videoId': 'playable001',
                      'title': {'simpleText': 'Video valido'},
                      'viewCountText': {'simpleText': '42 visualizzazioni'},
                    },
                  },
                  {
                    'playlistVideoRenderer': {
                      'videoId': 'blocked0001',
                      'title': {'simpleText': 'Video non apribile'},
                    },
                  },
                ],
              },
            },
          }),
          200,
        );
      }),
    );
    const playlist = SonarTubeItem(
      kind: SonarTubeItemKind.playlist,
      id: 'PLfilter123',
      title: 'Playlist',
      url: 'https://www.youtube.com/playlist?list=PLfilter123',
    );

    final page = await service.browse(playlist);

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'playable001');
  });

}
