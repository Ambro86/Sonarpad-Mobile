import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';
import 'audio_voice_preview_test.dart' show PreviewPlayer;

// Enforce the same resource limit as just_audio_background. Pausing deliberately
// retains ownership; only stop/dispose releases it.
class SingleNativePlayer extends PreviewPlayer {
  static SingleNativePlayer? owner;
  List<AudioSource> sources = [];
  bool failLoad = false;
  void claim() {
    if (owner != null && owner != this) {
      throw StateError(
        'just_audio_background supports only a single player instance',
      );
    }
    owner = this;
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    claim();
    if (failLoad) throw StateError('load failed');
    sources = [source];
    return super.setAudioSource(source, initialPosition: initialPosition);
  }

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> sources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    claim();
    this.sources = sources;
    return super.setAudioSource(
      sources.first,
      initialPosition: initialPosition,
    );
  }

  @override
  List<IndexedAudioSource> get sequence => const [];
  @override
  Stream<int?> get currentIndexStream => const Stream.empty();
  @override
  Future<void> play() {
    claim();
    return super.play();
  }

  @override
  Future<void> stop() async {
    await super.stop();
    if (owner == this) owner = null;
  }

  @override
  Future<void> dispose() async {
    if (owner == this) owner = null;
    await super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SingleNativePlayer media;
  late SingleNativePlayer voice;
  late AudioPlayerService mediaService;
  late AudioPlayerService voiceService;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
    SingleNativePlayer.owner = null;
    media = SingleNativePlayer();
    voice = SingleNativePlayer();
    mediaService = AudioPlayerService(player: media, isAndroid: true);
    voiceService = AudioPlayerService(player: voice, isAndroid: true);
  });
  tearDown(() async {
    await mediaService.dispose();
    await voiceService.dispose();
  });
  Future<void> loadPausedMedia() async {
    await mediaService.setUrl('https://example.com/media.mp3');
    media.currentPosition = const Duration(seconds: 42);
    await mediaService.pause();
    expect(SingleNativePlayer.owner, media);
  }

  for (final android in [true, false]) {
    test(
      'voice test releases paused player and media resumes at its position, Android=$android',
      () async {
        await voiceService.dispose();
        voice = SingleNativePlayer();
        voiceService = AudioPlayerService(player: voice, isAndroid: android);
        await loadPausedMedia();
        final preview = voiceService.playVoicePreview(File('sample.mp3'));
        await voice.started.future;
        expect(SingleNativePlayer.owner, voice);
        expect(media.currentPosition, const Duration(seconds: 42));
        expect(media.sources, hasLength(1));
        voice.complete();
        await preview;
        final resumed = mediaService.play();
        await media.started.future;
        expect(SingleNativePlayer.owner, media);
        expect(media.currentPosition, const Duration(seconds: 42));
        media.complete();
        await resumed;
      },
    );
  }
  test('Edge article/chunk playlist can replace paused media', () async {
    await loadPausedMedia();
    final reading = voiceService.playFilesSequentially([
      File('chunk1.mp3'),
      File('chunk2.mp3'),
    ], resetAfterCompletion: false);
    await voice.started.future;
    expect(voice.sources, hasLength(2));
    expect(SingleNativePlayer.owner, voice);
    voice.complete();
    await reading;
  });
  test(
    'new playback cancels an active voice preview without resurrecting it',
    () async {
      final preview = voiceService.playVoicePreview(File('sample.mp3'));
      await voice.started.future;
      await mediaService.setUrl('https://example.com/media.mp3');
      await preview;
      voice.regainFocus();
      expect(voice.playing, isFalse);
      expect(SingleNativePlayer.owner, media);
    },
  );
  test('handoff waits for an in-flight native source load', () async {
    media.sourceGate = Completer<void>();
    final loadingMedia = mediaService.setUrl('https://example.com/media.mp3');
    await media.loading.future;
    final preview = voiceService.playVoicePreview(File('sample.mp3'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(voice.loads, 0);
    media.sourceGate!.complete();
    await loadingMedia;
    await voice.started.future;
    expect(SingleNativePlayer.owner, voice);
    voice.complete();
    await preview;
  });
  test(
    'a failed voice load does not poison subsequent media playback',
    () async {
      await loadPausedMedia();
      voice.failLoad = true;
      await expectLater(
        voiceService.playVoicePreview(File('sample.mp3')),
        throwsStateError,
      );
      final resumed = mediaService.play();
      await media.started.future;
      expect(SingleNativePlayer.owner, media);
      media.complete();
      await resumed;
    },
  );
  test('closing an old screen does not release the new player', () async {
    await loadPausedMedia();
    final preview = voiceService.playVoicePreview(File('sample.mp3'));
    await voice.started.future;
    await mediaService.dispose();
    expect(SingleNativePlayer.owner, voice);
    voice.complete();
    await preview;
  });
  test(
    'streamed Edge chunks replace paused media without a second native player',
    () async {
      await loadPausedMedia();
      final reading = voiceService.playFileStreamSequentially(
        Stream.fromIterable([File('chunk1.mp3'), File('chunk2.mp3')]),
        initialBufferCount: 2,
      );
      await voice.started.future;
      expect(voice.sources, hasLength(2));
      expect(SingleNativePlayer.owner, voice);
      voice.complete();
      await reading;
    },
  );
}
