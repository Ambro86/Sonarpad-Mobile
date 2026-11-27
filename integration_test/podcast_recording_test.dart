import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:media_kit/media_kit.dart';
import 'package:sonarpad_mobile_starter/services/podcast_recorder_service.dart';

// During PODCAST_BACKGROUND_READY, put the app in the background and lock
// the screen, then reopen it. Also runnable on a physical iPhone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('record and export with background music monitoring enabled', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final folder = await Directory.systemTemp.createTemp('podcast-monitor-');
    final recorder = PodcastRecorderService(directory: () async => folder);
    try {
      await recorder.initialize();
      final asset = await rootBundle.load('assets/audio/underwater_bubbles.mp3');
      final music = File('${folder.path}/source.mp3');
      await music.writeAsBytes(Uint8List.sublistView(asset));
      await recorder.chooseMusic(music.path);
      recorder.listenToMusic = true;
      await recorder.start();
      expect(recorder.state, PodcastCaptureState.recording);
      await Future<void>.delayed(const Duration(seconds: 2));
      await recorder.pause();
      expect(recorder.state, PodcastCaptureState.paused);
      await recorder.resume();
      await Future<void>.delayed(const Duration(seconds: 2));
      await recorder.stop();
      expect(recorder.state, PodcastCaptureState.ready);
      final raw = await File('${folder.path}/microphone.wav').readAsBytes();
      expect(String.fromCharCodes(raw.take(4)), 'RIFF');
      // At least three seconds of mono 44.1 kHz, 16-bit PCM.
      expect(raw.length, greaterThan(3 * 44100 * 2));
      final output = File(await recorder.render());
      expect(await output.length(), greaterThan(1024));
      final preview = ja.AudioPlayer();
      try {
        final duration = await preview.setFilePath(output.path);
        expect(duration?.inMilliseconds, greaterThan(3000));
      } finally {
        await preview.dispose();
      }
    } finally {
      await recorder.close();
      await folder.delete(recursive: true);
    }
  });

  testWidgets('native mono and stereo recording with background enabled', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final folder = await Directory.systemTemp.createTemp(
      'podcast-native-test-',
    );
    final microphone = NativePodcastMicrophone();
    final subscription = microphone.states.listen((_) {});
    try {
      expect(await microphone.permission(), isTrue);
      for (final channels in [1, 2]) {
        final path = '${folder.path}/capture-$channels.wav';
        await microphone.start(path, channels: channels, background: true);
        if (channels == 2) {
          debugPrint('PODCAST_BACKGROUND_READY');
        }
        await Future<void>.delayed(Duration(seconds: channels == 2 ? 15 : 2));
        await microphone.stop();
        final bytes = await File(path).readAsBytes();
        final data = ByteData.sublistView(bytes);
        expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
        int? actualChannels;
        int? bytesPerSecond;
        int? audioBytes;
        for (var offset = 12; offset + 8 <= bytes.length;) {
          final tag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
          final length = data.getUint32(offset + 4, Endian.little);
          if (tag == 'fmt ') {
            actualChannels = data.getUint16(offset + 10, Endian.little);
            bytesPerSecond = data.getUint32(offset + 16, Endian.little);
          } else if (tag == 'data') {
            audioBytes = length;
          }
          offset += 8 + length + (length % 2);
        }
        expect(actualChannels, channels);
        expect(audioBytes, isNotNull);
        final seconds = audioBytes! / bytesPerSecond!;
        expect(seconds, greaterThan(channels == 2 ? 12 : 1));
        debugPrint(
          'PODCAST_CAPTURE_OK channels=$actualChannels seconds=$seconds',
        );
        // Allow the Android service destruction callback before restarting.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } finally {
      await microphone.dispose();
      await subscription.cancel();
      await folder.delete(recursive: true);
    }
  });
}
