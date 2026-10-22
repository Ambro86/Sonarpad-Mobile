import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';
import 'audio_voice_preview_test.dart' show PreviewPlayer;

class BookmarkPlayer extends PreviewPlayer {
  bool failLoad = false;
  @override
  Duration get duration => const Duration(minutes: 10);
  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    // Reproduce the native loading event with the previous track's position.
    processingState = ProcessingState.loading;
    states.add(PlayerState(false, processingState));
    await Future<void>.delayed(Duration.zero);
    if (failLoad) throw StateError('load failed');
    return super.setAudioSource(source, initialPosition: initialPosition);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    currentPosition = position ?? Duration.zero;
    states.add(PlayerState(false, ProcessingState.ready));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BookmarkPlayer player;
  late AudioPlayerService service;
  final settings = AppSettingsService();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await settings.setAutoBookmarkEnabled(true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
    player = BookmarkPlayer();
    service = AudioPlayerService(player: player, isAndroid: true);
  });
  tearDown(() => service.dispose());

  for (final category in ['sonarmusic', 'sonartube']) {
    for (final saved in [null, 42]) {
      test(
        '$category switch preserves each bookmark, next saved=$saved',
        () async {
          final first = '$category:first';
          final next = '$category:next';
          await service.setUrl('https://example.org/first.mp3', mediaId: first);
          player.currentPosition = const Duration(seconds: 145);
          if (saved != null) await settings.saveMediaBookmark(next, saved);
          await service.setUrl('https://example.org/next.mp3', mediaId: next);
          expect(await settings.getMediaBookmark(first), 145);
          expect(await settings.getMediaBookmark(next), saved);
          expect(player.position, Duration(seconds: saved ?? 0));
          player.currentPosition = const Duration(seconds: 60);
          await service.saveCurrentBookmark();
          expect(await settings.getMediaBookmark(next), 60);
          await service.setUrl('https://example.org/first.mp3', mediaId: first);
          expect(player.position, const Duration(seconds: 145));
          expect(await settings.getMediaBookmark(next), 60);
        },
      );
    }
  }
  test(
    'failed load cannot save the old position under the next media ID',
    () async {
      await service.setUrl('https://example.org/first.mp3', mediaId: 'first');
      player.currentPosition = const Duration(seconds: 145);
      await settings.saveMediaBookmark('next', 42);
      player.failLoad = true;
      await expectLater(
        service.setUrl('https://example.org/next.mp3', mediaId: 'next'),
        throwsStateError,
      );
      await service.saveCurrentBookmark();
      await service.stop();
      expect(await settings.getMediaBookmark('first'), 145);
      expect(await settings.getMediaBookmark('next'), 42);
      player.failLoad = false;
      await service.setUrl('https://example.org/next.mp3', mediaId: 'next');
      expect(player.position, const Duration(seconds: 42));
    },
  );
  test('disabled bookmarks keep playback at the beginning', () async {
    await settings.setAutoBookmarkEnabled(false);
    await settings.saveMediaBookmark('next', 42);
    await service.setUrl('https://example.org/first.mp3', mediaId: 'first');
    player.currentPosition = const Duration(seconds: 145);
    await service.setUrl('https://example.org/next.mp3', mediaId: 'next');
    expect(player.position, Duration.zero);
    expect(await settings.getMediaBookmark('first'), isNull);
    expect(await settings.getMediaBookmark('next'), 42);
  });
}
