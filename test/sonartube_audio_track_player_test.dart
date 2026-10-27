import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sonarpad_mobile_starter/models/media_audio_track.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/media_playback_speed.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_episode_player_screen.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
// The public platform interface is supplied by the video_player dependency.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class PlayerTestVideoBackend extends VideoPlayerPlatform {
  final requestedRates = <double>[];
  double speed = 1;
  bool playing = false;
  Duration position = Duration.zero;
  double volume = 1;
  bool rejectNextRate = false;
  Completer<void>? holdNextRate;
  int _rateCallsInFlight = 0;
  int maximumRateCallsInFlight = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(minutes: 10),
      size: const Size(640, 360),
    ),
  );

  @override
  Future<void> setPlaybackSpeed(int playerId, double playbackSpeed) async {
    requestedRates.add(playbackSpeed);
    _rateCallsInFlight++;
    if (_rateCallsInFlight > maximumRateCallsInFlight) {
      maximumRateCallsInFlight = _rateCallsInFlight;
    }
    final gate = holdNextRate;
    holdNextRate = null;
    try {
      if (gate != null) await gate.future;
      speed = playbackSpeed;
      if (rejectNextRate) {
        rejectNextRate = false;
        throw PlatformException(code: 'rate_unavailable');
      }
    } finally {
      _rateCallsInFlight--;
    }
  }

  @override
  Future<void> play(int playerId) async {
    playing = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing = false;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {
    this.volume = volume;
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();

  @override
  Future<void> dispose(int playerId) async {}
}

Future<void> pumpTestPlayer(
  WidgetTester tester, {
  bool fullscreen = false,
  bool audioOnly = false,
  bool remote = false,
  List<MediaAudioTrack> tracks = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = fullscreen
      ? const Size(1000, 700)
      : const Size(480, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await AppSettingsService().setDisplayVideoInPortrait(fullscreen);
  await AppSettingsService().setAutoBookmarkEnabled(false);
  // Initialize just_audio's asynchronous idle streams outside FakeAsync.
  // The speed gestures below use normal widget pumping.
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PodcastEpisodePlayerScreen(
          episode: PodcastEpisode(
            title: 'Prova velocità',
            description: '',
            audioUrl: remote
                ? 'https://example.org/video.mp4'
                : 'file:///recorded-video.mp4',
            audioTracks: tracks,
            selectedAudioTrackId: 'it',
          ),
          speedCategory: MediaPlaybackSpeedCategory.sonartube,
          isVideoSupported: !audioOnly,
          startWithVideo: !audioOnly,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
  await tester.pump();
}

Future<void> disposeTestPlayer(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const SizedBox());
    await Future<void>.delayed(Duration.zero);
  });
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

class PlayerTestAudioPlatform extends JustAudioPlatform {
  PlayerTestAudioBackend? latest;
  bool rejectLoad = false;
  bool rejectPrimary = false;
  final requestedUrls = <String>[];
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      latest = PlayerTestAudioBackend(request.id, this);
  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    unawaited(latest?.events.close());
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async => DisposeAllPlayersResponse();
}

class PlayerTestAudioBackend extends AudioPlayerPlatform {
  PlayerTestAudioBackend(super.id, this.owner);
  final PlayerTestAudioPlatform owner;
  final events = StreamController<PlaybackEventMessage>.broadcast();
  String? url;
  Duration position = Duration.zero;
  bool playing = false;
  double speed = 1;
  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;
  void notify() => events.add(
    PlaybackEventMessage(
      processingState: ProcessingStateMessage.ready,
      updatePosition: position,
      updateTime: DateTime.now(),
      bufferedPosition: const Duration(minutes: 10),
      duration: const Duration(minutes: 10),
      currentIndex: 0,
      icyMetadata: null,
      androidAudioSessionId: null,
    ),
  );
  @override
  Future<LoadResponse> load(LoadRequest request) async {
    final playlist =
        request.audioSourceMessage as ConcatenatingAudioSourceMessage;
    url = (playlist.children.first as UriAudioSourceMessage).uri;
    owner.requestedUrls.add(url!);
    if (owner.rejectLoad || (owner.rejectPrimary && url == 'https://example.org/pl')) {
      throw PlatformException(code: 'unavailable');
    }
    position = request.initialPosition ?? Duration.zero;
    notify();
    return LoadResponse(duration: const Duration(minutes: 10));
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    position = request.position ?? Duration.zero;
    notify();
    return SeekResponse();
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playing = true;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    playing = false;
    return PauseResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    speed = request.speed;
    return SetSpeedResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();
  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();
  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();
  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();
  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
  setCanUseNetworkResourcesForLiveStreamingWhilePaused(
    SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request,
  ) async => SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();
  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
    SetPreferredPeakBitRateRequest request,
  ) async => SetPreferredPeakBitRateResponse();
  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
    SetAllowsExternalPlaybackRequest request,
  ) async => SetAllowsExternalPlaybackResponse();
  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();
}

class PlayerTestNoLogFiles extends PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async =>
      throw MissingPluginException('test');
}

void main() {
  late PlayerTestVideoBackend video;
  late PlayerTestAudioPlatform audio;
  late VideoPlayerPlatform originalVideo;
  late JustAudioPlatform originalAudio;
  const tracks = [
    MediaAudioTrack(id: 'it', label: 'Italiano', url: 'https://example.org/it'),
    MediaAudioTrack(id: 'pl', label: 'Polski', url: 'https://example.org/pl',
      fallbackUrls: ['https://example.org/pl-compatible']),
  ];
  setUp(() {
    PathProviderPlatform.instance = PlayerTestNoLogFiles();
    SharedPreferences.setMockInitialValues({});
    originalVideo = VideoPlayerPlatform.instance;
    originalAudio = JustAudioPlatform.instance;
    video = PlayerTestVideoBackend();
    audio = PlayerTestAudioPlatform();
    VideoPlayerPlatform.instance = video;
    JustAudioPlatform.instance = audio;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => call.method == 'setActive' ? true : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.arthenica.com/ffmpeg_kit_event'),
          (_) async => null,
        );
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    VideoPlayerPlatform.instance = originalVideo;
    JustAudioPlatform.instance = originalAudio;
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
  });
  UniversalAccessibleList form(WidgetTester tester) => tester
      .widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
  Future<void> event(WidgetTester tester, String id) async {
    await form(tester).onEvent!(AccessibleListEvent(type: 'activate', id: id));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'track switching preserves playback and pause on both mobile layouts',
    (tester) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final paused in [false, true]) {
          for (final mode in [0, 1, 2]) {
            final rejected = mode == 1;
            audio.rejectLoad = rejected;
            audio.rejectPrimary = mode == 2;
            audio.requestedUrls.clear();
            await pumpTestPlayer(tester, tracks: tracks);
            await form(tester).onEvent!(
              const AccessibleListEvent(
                type: 'slider',
                id: 'accessible_position',
                value: 123.0,
              ),
            );
            await tester.pumpAndSettle();
            if (paused) await event(tester, 'play_pause');
            final dialog = form(tester).onEvent!(
              const AccessibleListEvent(type: 'activate', id: 'audio_track'),
            );
            await tester.pumpAndSettle();
            expect(find.text('Italiano'), findsOneWidget);
            await tester.runAsync(() async {
              await tester.tap(find.text('Polski'));
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });
            await tester.pumpAndSettle();
            var completed = false;
            unawaited(Future<void>.value(dialog).then((_) => completed = true));
            for (var i = 0; i < 150 && !completed; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(completed, isTrue, reason: 'track selection completed');
            if (!rejected) {
              expect(audio.latest?.url, mode == 2
                  ? 'https://example.org/pl-compatible' : 'https://example.org/pl');
              expect(audio.requestedUrls, mode == 2
                  ? ['https://example.org/pl', 'https://example.org/pl-compatible']
                  : ['https://example.org/pl']);
              expect(audio.latest?.position.inSeconds, 123);
              expect(audio.latest?.playing, !paused);
            }
            expect(video.position.inSeconds, 123);
            expect(video.volume, rejected ? 1 : 0);
            expect(video.playing, !paused);
            await disposeTestPlayer(tester);
          }
        }
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('single audio track has no selector', (tester) async {
    await pumpTestPlayer(tester, tracks: [tracks.first]);
    expect(
      form(tester).sections
          .expand((section) => section.rows)
          .where((row) => row.id == 'audio_track'),
      isEmpty,
    );
    await disposeTestPlayer(tester);
  });
}
