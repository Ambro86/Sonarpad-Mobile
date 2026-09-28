import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/services/home_customization_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/utils/home_item_catalog.dart';

void main() {
  test('Romanian localization is complete apart from intentional shared labels', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    final ro = jsonDecode(File('lib/l10n/app_ro.arb').readAsStringSync())
        as Map<String, dynamic>;

    final enKeys = en.keys.where((key) => !key.startsWith('@')).toSet();
    final roKeys = ro.keys.where((key) => !key.startsWith('@')).toSet();
    expect(ro['@@locale'], 'ro');
    expect(roKeys, enKeys);

    const intentionalShared = <String>{
      'appTitle',
      'sonarTubeTitle',
      'convertMediaFormat',
      'importFromWikipedia',
      'documentTypeLabel',
      'ok',
      'textFormat',
      'pdfFormat',
      'docxFormat',
      'epubFormat',
      'internetArchiveTitle',
      'calendar',
      'radio',
      'selectionActionCount',
      'radioLanguageHi',
      'radioCountryOptionAt',
      'radioCountryOptionAr',
      'radioCountryOptionCa',
      'radioCountryOptionAu',
      'radioGenreOptionSport',
      'radioGenreOptionPop',
      'radioGenreOptionRock',
      'radioGenreOptionJazz',
      'radioGenreOptionBlues',
      'radioGenreOptionCountry',
      'radioGenreOptionReggae',
      'radioGenreOptionMetal',
      'radioGenreOptionFolk',
      'radioGenreOptionLocal',
      'radioGenreOptionAmbient',
      'radioCommunityLanguageHindi',
      'routeDistanceMeters',
      'routeDistanceKilometers',
      'routeDurationMinutes',
      'routeGoogleMapsAction',
      'weatherTemperatureCelsius',
      'weatherTemperatureFahrenheit',
      'mediaCutterPartEffectSuperRobot',
      'mediaCutterPartEffectLoFi',
      'mediaCutterPartEffectExterminator',
      'radioScheduleLabeledValue',
      'chinaCountryName',
      'cinemaTrailerTitle',
      'audioDescriptionDetailNormal',
      'audioDescriptionProjectEditorDescriptionOption',
      'audioDescriptionLanguageCountry',
      'homeTv',
      'homeRaiPlay',
      'homeLa7Play',
      'homeRaiPlaySound',
    };

    final identical = <String>{
      for (final key in enKeys)
        if (en[key] is String && ro[key] == en[key]) key,
    };
    expect(identical, intentionalShared);

    expect(ro['sonarTubeLive'], 'În direct');
    expect(ro['folderTypeLabel'], 'Dosar');
    expect(ro['newDocumentDefaultName'], 'Document_nou');
    expect(ro['pyannoteFailure'], 'Testul pyannote a eșuat.');
    expect(ro['audiobookMp3Format'], 'Carte audio MP3 (.mp3)');
  });

  test('Romanian SonarTube direct search sends ro and RO to InnerTube', () async {
    var requests = 0;
    final service = SonarTubeService(
      client: MockClient((request) async {
        expect(request.url.host, 'www.youtube.com');
        expect(request.headers['Accept-Language'], 'ro');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final context = body['context'] as Map<String, dynamic>;
        final client = context['client'] as Map<String, dynamic>;
        expect(client['hl'], 'ro');
        expect(client['gl'], 'RO');
        requests++;
        return http.Response(
          jsonEncode({
            'contents': {
              'itemSectionRenderer': {
                'contents': [
                  {
                    'videoRenderer': {
                      'videoId': 'abcdefghijk',
                      'title': {
                        'runs': [
                          {'text': 'Rezultat românesc'},
                        ],
                      },
                      'viewCountText': {'simpleText': '100 de vizionări'},
                    },
                  },
                ],
              },
            },
          }),
          200,
        );
      }),
    )..setLocaleName('ro');

    final page = await service.search('muzică românească');
    expect(requests, 4);
    expect(page.items, isNotEmpty);
  });

  test('Romanian SonarTube server fallback sends hl=ro and gl=RO', () async {
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      enableDirectNavigation: false,
      client: MockClient((request) async {
        expect(request.url.queryParameters['hl'], 'ro');
        expect(request.url.queryParameters['gl'], 'RO');
        return http.Response(
          jsonEncode({'ok': true, 'page': 1, 'items': []}),
          200,
        );
      }),
    )..setLocaleName('ro');

    await service.search('știri România');
  });

  test('Romanian SonarTube metadata requests keep locale too', () async {
    final service = SonarTubeService(
      endpoint: Uri.parse('https://example.test/youtube_resolve.php'),
      client: MockClient((request) async {
        expect(request.url.queryParameters['hl'], 'ro');
        expect(request.url.queryParameters['gl'], 'RO');
        expect(request.url.queryParameters['metadata'], '1');
        return http.Response(
          jsonEncode({'ok': true, 'description': 'Descriere în română'}),
          200,
        );
      }),
    )..setLocaleName('ro');

    final description = await service.videoDescription(
      const SonarTubeItem(
        kind: SonarTubeItemKind.video,
        id: 'abcdefghijk',
        title: 'Video',
        url: 'https://www.youtube.com/watch?v=abcdefghijk',
      ),
    );
    expect(description, 'Descriere în română');
  });

  test('Romanian remains wired into TTS fallback, countries and news reader', () {
    expect(
      AppSettingsService.ttsLanguages.any((language) => language.code == 'ro'),
      isTrue,
    );
    expect(
      AppSettingsService.voicesForLanguage('ro')
          .map((voice) => voice.voice)
          .toSet(),
      containsAll(<String>{'ro-RO-AlinaNeural', 'ro-RO-EmilNeural'}),
    );

    final countryHelper =
        File('lib/utils/country_name_helper.dart').readAsStringSync();
    expect(countryHelper, contains("normalized.startsWith('ro')"));

    final newsReader =
        File('lib/screens/news_webview_screen.dart').readAsStringSync();
    expect(newsReader, contains("case 'ro':"));
    expect(
      newsReader,
      contains('Acest articol este disponibil doar abonaților.'),
    );
  });

  test(
    'Romanian service wiring is present and Italian-only services stay guarded',
    () {
      final sonarTube =
          File('lib/services/sonartube_service.dart').readAsStringSync();
      expect(
        sonarTube,
        contains("normalized == 'ro' || normalized.startsWith('ro_')"),
      );
      expect(sonarTube, contains("_youtubeLanguage = 'ro';"));
      expect(sonarTube, contains("_youtubeRegion = 'RO';"));

      final php = File('server/youtube_resolve.php').readAsStringSync();
      expect(php, contains('yt_accept_language_header'));
      expect(php, contains("'hl' => yt_request_language()"));
      expect(php, contains("'gl' => yt_request_region()"));

      final nonItalianIds = availableHomeItemIds(
        isItalian: false,
        isTvCodeValid: true,
        isRaiPlayValid: true,
        isRaiPlaySoundCodeValid: true,
      );
      expect(nonItalianIds, isNot(contains(HomeItemIds.raiPlay)));
      expect(nonItalianIds, isNot(contains(HomeItemIds.raiPlaySound)));
      expect(
        nonItalianIds,
        isNot(contains(HomeItemIds.sonarpadAudioDescriptions)),
      );
      expect(nonItalianIds, contains(HomeItemIds.sonarTube));
      expect(nonItalianIds, contains(HomeItemIds.radio));
      expect(nonItalianIds, contains(HomeItemIds.podcasts));
    },
  );

  test('Romanian calendar remains complete', () {
    final data = jsonDecode(File('assets/calendar/ro.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(data['locale'], 'ro');
    expect(data['saints'], hasLength(365));
    expect(data['quotes'], hasLength(128));
  });
}
