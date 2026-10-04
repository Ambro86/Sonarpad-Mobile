import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/models/media_playback_speed.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/services/media_playback_rate_transaction.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('speed control defaults to on and each category initially uses 1x', () async {
    final settings = AppSettingsService();
    expect(await settings.isMediaSpeedControlEnabled(), isTrue);
    for (final category in MediaPlaybackSpeedCategory.values) {
      expect(await settings.loadMediaPlaybackSpeed(category), 1.0);
    }
    await settings.setMediaSpeedControlEnabled(false);
    expect(await AppSettingsService().isMediaSpeedControlEnabled(), isFalse);
    await settings.setMediaSpeedControlEnabled(true);
    expect(await AppSettingsService().isMediaSpeedControlEnabled(), isTrue);
  });

  test('category preferences stay independent and survive disabling the control', () async {
    final settings = AppSettingsService();
    await settings.saveMediaPlaybackSpeed(MediaPlaybackSpeedCategory.podcasts, 1.5);
    await settings.saveMediaPlaybackSpeed(MediaPlaybackSpeedCategory.sonartube, 1.25);
    await settings.setMediaSpeedControlEnabled(false);
    expect(await settings.loadMediaPlaybackSpeed(MediaPlaybackSpeedCategory.media), 1.0);
    expect(await settings.loadMediaPlaybackSpeed(MediaPlaybackSpeedCategory.audiobooks), 1.0);
    expect(await settings.loadMediaPlaybackSpeed(MediaPlaybackSpeedCategory.podcasts), 1.5);
    expect(await settings.loadMediaPlaybackSpeed(MediaPlaybackSpeedCategory.sonartube), 1.25);
    await settings.setMediaSpeedControlEnabled(true);
    expect(await settings.loadMediaPlaybackSpeed(MediaPlaybackSpeedCategory.podcasts), 1.5);
  });

  test('only the seven finite supported speeds are accepted', () {
    expect(mediaPlaybackSpeeds, [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]);
    for (final value in mediaPlaybackSpeeds) {
      expect(normalizeMediaPlaybackSpeed(value), value);
    }
    for (final value in [null, 0.0, -1.0, 3.0, 1.1, double.nan, double.infinity]) {
      expect(normalizeMediaPlaybackSpeed(value), 1.0);
    }
  });

  test('malformed stored values safely return normal speed', () async {
    SharedPreferences.setMockInitialValues({
      'sonarpad_media_playback_speed_podcasts': 'invalid',
      'sonarpad_media_playback_speed_media': 99.0,
    });
    final settings = AppSettingsService();
    expect(await settings.loadMediaPlaybackSpeed(MediaPlaybackSpeedCategory.podcasts), 1.0);
    expect(await settings.loadMediaPlaybackSpeed(MediaPlaybackSpeedCategory.media), 1.0);
  });

  test('both engines receive the same speed before resuming', () async {
    var audio = 1.0;
    var video = 1.0;
    var resumed = false;
    await applyMediaPlaybackRate(
      rate: 1.5,
      targets: [
        MediaPlaybackRateTarget(previousRate: video, setRate: (value) async { video = value; }),
        MediaPlaybackRateTarget(previousRate: audio, setRate: (value) async { audio = value; }),
      ],
      afterApply: () async {
        expect(video, 1.5);
        expect(audio, 1.5);
        resumed = true;
      },
    );
    expect(resumed, isTrue);
  });

  test('a plugin throwing after mutation restores both engines', () async {
    var audio = 1.25;
    var video = 1.25;
    var resumed = false;
    await expectLater(
      applyMediaPlaybackRate(
        rate: 2.0,
        targets: [
          MediaPlaybackRateTarget(previousRate: video, setRate: (value) async { video = value; }),
          MediaPlaybackRateTarget(previousRate: audio, setRate: (value) async {
            audio = value;
            if (value == 2.0) {
              throw StateError('unsupported_rate');
            }
          }),
        ],
        afterApply: () async { resumed = true; },
      ),
      throwsA(isA<MediaPlaybackRateException>().having((e) => e.rollbackFailed, 'rollbackFailed', isFalse)),
    );
    expect(audio, 1.25);
    expect(video, 1.25);
    expect(resumed, isFalse);
  });

  test('a deferred video error on play is also rolled back', () async {
    var rate = 1.0;
    var pausedBeforeRollback = false;
    await expectLater(
      applyMediaPlaybackRate(
        rate: 0.5,
        targets: [MediaPlaybackRateTarget(previousRate: 1.0, setRate: (value) async { rate = value; })],
        afterApply: () async { throw StateError('rejected_on_play'); },
        beforeRollback: () async { pausedBeforeRollback = true; },
      ),
      throwsA(isA<MediaPlaybackRateException>().having((e) => e.rollbackFailed, 'rollbackFailed', isFalse)),
    );
    expect(rate, 1.0);
    expect(pausedBeforeRollback, isTrue);
  });

  test('failed rollback is reported and remaining engines are still restored', () async {
    var audio = 1.0;
    await expectLater(
      applyMediaPlaybackRate(
        rate: 2.0,
        targets: [
          MediaPlaybackRateTarget(previousRate: 1.0, setRate: (value) async { audio = value; }),
          MediaPlaybackRateTarget(previousRate: 1.0, setRate: (value) async { throw StateError('backend_failure'); }),
        ],
      ),
      throwsA(isA<MediaPlaybackRateException>().having((e) => e.rollbackFailed, 'rollbackFailed', isTrue)),
    );
    expect(audio, 1.0);
  });

  test('invalid rates never reach a playback engine', () async {
    var calls = 0;
    await expectLater(
      applyMediaPlaybackRate(
        rate: double.nan,
        targets: [MediaPlaybackRateTarget(previousRate: 1.0, setRate: (_) async { calls++; })],
      ),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test('live metadata is explicit and not inferred from episode duration', () {
    const recording = PodcastEpisode(title: 'recording', description: '', audioUrl: 'file:///sample.mp3');
    const live = PodcastEpisode(title: 'live', description: '', audioUrl: 'https://example.test/live.m3u8', isLive: true);
    expect(recording.isLive, isFalse);
    expect(live.isLive, isTrue);
  });

  test('server live metadata and unknown YouTube HLS prevent speed controls', () async {
    for (final sample in [
      ({'stream': 'https://example.test/live.m3u8'}, true),
      ({'stream': 'https://example.test/sample.mp4', 'is_live': true}, true),
      ({'stream': 'https://example.test/recording.m3u8', 'is_live': false}, false),
      ({'stream': 'https://example.test/sample.mp4'}, false),
    ]) {
      final service = SonarTubeService(
        enableDirectNavigation: false,
        client: MockClient((_) async => http.Response(jsonEncode({'ok': true, ...sample.$1}), 200)),
      );
      final media = await service.resolveUrl('https://www.youtube.com/watch?v=abc12345678', fallbackTitle: 'sample');
      expect(media.isLive, sample.$2);
    }
  });
}
