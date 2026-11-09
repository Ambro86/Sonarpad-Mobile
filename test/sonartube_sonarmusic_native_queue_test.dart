import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';

import 'audio_voice_preview_test.dart' show PreviewPlayer;

class NativeQueueTestPlayer extends PreviewPlayer {
  final indexEvents = StreamController<int?>.broadcast(sync: true);
  final sources = <AudioSource>[];
  int? selectedIndex = 0;

  @override
  List<AudioSource> get audioSources => sources;

  @override
  int? get currentIndex => selectedIndex;

  @override
  Stream<int?> get currentIndexStream => indexEvents.stream;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    sources..clear()..add(source);
    selectedIndex = 0;
    return super.setAudioSource(source, initialPosition: initialPosition);
  }

  @override
  Future<void> addAudioSource(AudioSource source) async {
    sources.add(source);
  }

  void nativeAdvance() {
    selectedIndex = 1;
    currentPosition = Duration.zero;
    indexEvents.add(1);
  }

  @override
  Future<void> dispose() async {
    await indexEvents.close();
    await super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService().setAutoBookmarkEnabled(true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (_) async => null,
    );
  });

  for (final platform in ['ios', 'android']) {
    test('native SonarTube/Music successor and bookmark $platform', () async {
      final player = NativeQueueTestPlayer();
      final service = AudioPlayerService(player: player, isAndroid: platform == 'android');
      final settings = AppSettingsService();
      try {
        await service.setUrl('https://example.test/first.mp3',
          mediaId: 'sonarmusic:first', title: 'First');
        final nextIndex = await service.queueNextUrl(
          'https://example.test/second.mp3',
          mediaId: 'sonarmusic:second', title: 'Second');
        expect(nextIndex, 1);
        expect(player.audioSources.length, 2);
        expect((player.sources.last as IndexedAudioSource).tag, isA<MediaItem>());
        expect(service.currentIndex, 0);
        expect(await service.queueNextUrl('https://example.test/third.mp3',
          mediaId: 'sonarmusic:third', title: 'Third'), isNull,
          reason: 'Never queue over an already queued successor');
        player.nativeAdvance();
        expect(service.currentIndex, 1);
        player.currentPosition = const Duration(seconds: 12);
        await service.saveCurrentBookmark();
        expect(await settings.getMediaBookmark('sonarmusic:second'), 12);
        expect(await settings.getMediaBookmark('sonarmusic:first'), isNull);
      } finally {
        await service.dispose();
      }
    });
  }
}
