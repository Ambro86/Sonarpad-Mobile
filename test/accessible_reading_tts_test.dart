import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sonarpad_mobile_starter/services/accessible_reading_tts.dart';
import 'package:sonarpad_mobile_starter/services/audio_player_service.dart';
import 'package:sonarpad_mobile_starter/utils/app_logger.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _Audio extends Fake implements AudioPlayerService {
  final playing = StreamController<bool>.broadcast(sync: true);
  final completed = StreamController<void>.broadcast(sync: true);
  final started = Completer<void>();
  final ended = Completer<void>();
  int loads = 0;
  @override
  Stream<bool> get playingStream => playing.stream;
  @override
  Stream<void> get completionStream => completed.stream;
  @override
  Future<void> playFilesSequentially(
    List<File> files, {
    void Function(int, File)? onChunkStarted,
    AudioSessionType sessionType = AudioSessionType.speech,
    String title = 'Sonarpad',
    bool resetAfterCompletion = true,
  }) async {
    expect(await files.single.length(), greaterThan(44));
    loads++;
    playing.add(true);
    if (!started.isCompleted) started.complete();
    await ended.future;
  }

  @override
  Future<void> pause() async => playing.add(false);
  @override
  Future<void> play() async => playing.add(true);
  @override
  Future<void> stop() async {
    playing.add(false);
    if (!ended.isCompleted) ended.complete();
  }

  void finish() {
    completed.add(null);
    playing.add(false);
    if (!ended.isCompleted) ended.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  late Directory root;
  late PathProviderPlatform originalPaths;
  late _Audio audio;
  late AccessibleReadingTts tts;
  late List<String> calls;
  Completer<void>? synthesisGate;
  var failSynthesis = false;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('reading-tts-test-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    audio = _Audio();
    calls = [];
    synthesisGate = null;
    failSynthesis = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'synthesizeToFile') {
            await synthesisGate?.future;
            if (failSynthesis) return 0;
            final args = call.arguments as Map;
            await File(
              args['fileName'] as String,
            ).writeAsBytes(List.filled(100, 0));
          }
          return 1;
        });
    tts = AccessibleReadingTts(audio: audio, isAndroid: true);
    await tts.awaitSpeakCompletion(true);
  });

  tearDown(() async {
    await tts.stop();
    await audio.playing.close();
    await audio.completed.close();
    await AppLogger.log('Reading test finished');
    PathProviderPlatform.instance = originalPaths;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test(
    'media pause and resume retain the utterance and do not synthesize again',
    () async {
      var finished = false;
      var pauses = 0;
      var resumes = 0;
      tts.setPauseHandler(() => pauses++);
      tts.setContinueHandler(() => resumes++);
      final reading = tts.speak('One sentence.').then((_) => finished = true);
      await audio.started.future;
      await audio
          .pause(); // Same player state change as a media-session command.
      expect(pauses, 1);
      expect(finished, isFalse);
      await audio.play();
      expect(resumes, 1);
      expect(audio.loads, 1);
      audio.finish();
      await reading;
      expect(finished, isTrue);
      expect(pauses, 1); // EOF is not a user pause.
      expect(calls.where((c) => c == 'synthesizeToFile'), hasLength(1));
      expect(calls, isNot(contains('speak')));
      expect(root.listSync().whereType<Directory>(), isEmpty);
    },
  );

  test('screen pause and empty-text resume control the media player', () async {
    final reading = tts.speak('Reading.');
    await audio.started.future;
    await tts.pause();
    await tts.speak('');
    expect(calls, isNot(contains('pause')));
    expect(calls, isNot(contains('speak')));
    audio.finish();
    await reading;
  });

  test(
    'stop while paused completes the pending read and removes temporary audio',
    () async {
      final reading = tts.speak('Reading.');
      await audio.started.future;
      await audio.pause();
      await tts.stop();
      await reading;
      expect(root.listSync().whereType<Directory>(), isEmpty);
    },
  );

  test('pausing during synthesis waits for resume before playing', () async {
    synthesisGate = Completer<void>();
    final reading = tts.speak('Reading.');
    while (!calls.contains('synthesizeToFile')) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await tts.pause();
    synthesisGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(audio.loads, 0);
    await tts.speak('');
    await audio.started.future;
    audio.finish();
    await reading;
  });

  test('failed synthesis is reported without starting audio', () async {
    failSynthesis = true;
    await expectLater(tts.speak('Reading.'), throwsStateError);
    expect(audio.loads, 0);
    expect(root.listSync().whereType<Directory>(), isEmpty);
  });

  test(
    'native synthesis completion does not report playback completion',
    () async {
      var completed = 0;
      tts.setCompletionHandler(() => completed++);
      final reading = tts.speak('Reading.');
      await audio.started.future;
      await tts.platformCallHandler(const MethodCall('synth.onComplete', true));
      expect(completed, 0);
      audio.finish();
      await reading;
      expect(completed, 1);
    },
  );

  test('iOS delegates speech pause resume and stop unchanged', () async {
    tts = AccessibleReadingTts(audio: audio, isAndroid: false);
    await tts.awaitSpeakCompletion(true);
    await tts.speak('Reading.');
    await tts.pause();
    await tts.speak('');
    await tts.stop();
    expect(calls.where((c) => c == 'speak'), hasLength(2));
    expect(calls, contains('pause'));
    expect(calls, isNot(contains('synthesizeToFile')));
    expect(audio.loads, 0);
  });
}
