import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:sonarpad_mobile_starter/services/podcast_recorder_service.dart';

Future<void> writeTone(
  String path, {
  double seconds = 1,
  double amplitude = .2,
  double frequency = 440,
}) async {
  final count = (44100 * seconds).round();
  final bytes = ByteData(44 + count * 2);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + count * 2, Endian.little);
  text(8, 'WAVEfmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, 44100, Endian.little);
  bytes.setUint32(28, 88200, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    bytes.setInt16(
      44 + i * 2,
      (math.sin(i * 2 * math.pi * frequency / 44100) * amplitude * 32767)
          .round(),
      Endian.little,
    );
  }
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
}

class FakeMicrophone implements PodcastMicrophone {
  final events = StreamController<RecordState>.broadcast(sync: true);
  bool allowed = true, failStart = false;
  int starts = 0, pauses = 0, resumes = 0, stops = 0;
  String? path;
  @override
  Stream<RecordState> get states => events.stream;
  @override
  Future<bool> permission() async => allowed;
  @override
  Future<void> start(String path) async {
    starts++;
    if (failStart) throw StateError('capture failed');
    this.path = path;
    await writeTone(path);
    events.add(RecordState.record);
  }

  @override
  Future<void> pause() async {
    pauses++;
    events.add(RecordState.pause);
  }

  @override
  Future<void> resume() async {
    resumes++;
    events.add(RecordState.record);
  }

  @override
  Future<String?> stop() async {
    stops++;
    events.add(RecordState.stop);
    return path;
  }

  @override
  Future<void> dispose() async => events.close();
}

class FakeMixer implements PodcastMixer {
  List<String>? arguments;
  bool fail = false;
  Completer<void>? waiting;
  @override
  Future<void> render(List<String> arguments) async {
    this.arguments = arguments;
    if (waiting != null) await waiting!.future;
    if (fail) throw const PodcastRecorderException('mix_failed');
    await File(arguments.last).writeAsBytes(List.filled(100, 1));
  }

  @override
  Future<void> cancel() async {
    if (waiting != null && !waiting!.isCompleted) waiting!.complete();
  }
}

class ProcessMixer implements PodcastMixer {
  @override
  Future<void> render(List<String> arguments) async {
    final result = await Process.run('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'error',
      ...arguments,
    ]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FakeMicrophone microphone;
  late FakeMixer mixer;
  late PodcastRecorderService service;
  late List<bool> awake;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sonarpad-recorder-test-');
    microphone = FakeMicrophone();
    mixer = FakeMixer();
    awake = [];
    service = PodcastRecorderService(
      microphone: microphone,
      mixer: mixer,
      directory: () async => root,
      keepAwake: (v) async {
        awake.add(v);
      },
    );
    await service.initialize();
  });
  tearDown(() async {
    await service.close();
    await root.delete(recursive: true);
  });
  test(
    'permission refusal never starts capture and releases busy state',
    () async {
      microphone.allowed = false;
      await expectLater(
        service.start(),
        throwsA(
          isA<PodcastRecorderException>().having(
            (e) => e.code,
            'code',
            'permission',
          ),
        ),
      );
      expect(microphone.starts, 0);
      expect(service.busy, false);
      expect(service.state, PodcastCaptureState.idle);
    },
  );
  test('failed native start can be retried', () async {
    microphone.failStart = true;
    await expectLater(service.start(), throwsStateError);
    expect(service.busy, false);
    microphone.failStart = false;
    await service.start();
    expect(service.state, PodcastCaptureState.recording);
  });
  test(
    'start, pause, resume and stop preserve raw audio; duplicate start ignored',
    () async {
      service.name = 'Test podcast';
      await service.start();
      await service.start();
      expect(microphone.starts, 1);
      expect(awake.last, true);
      await service.pause();
      expect(service.state, PodcastCaptureState.paused);
      expect(awake.last, false);
      final frozen = service.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.elapsed, frozen);
      await service.resume();
      expect(microphone.resumes, 1);
      await service.stop();
      expect(service.state, PodcastCaptureState.ready);
      expect(awake.last, false);
      expect(await File(microphone.path!).length(), greaterThan(44));
    },
  );
  test(
    'native interruptions pause the UI and stop its elapsed clock',
    () async {
      await service.start();
      microphone.events.add(RecordState.pause);
      expect(service.state, PodcastCaptureState.paused);
      final elapsed = service.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.elapsed, elapsed);
      microphone.events.add(RecordState.stop);
      expect(service.state, PodcastCaptureState.ready);
    },
  );
  test(
    'mix arguments keep path arguments separate and apply independent gains',
    () async {
      final args = PodcastRecorderService.mixArguments(
        voice: 'voice with spaces.wav',
        destination: 'output.m4a',
        microphone: 1.5,
        music: .2,
        background: 'music with spaces.wav',
      );
      expect(args, contains('voice with spaces.wav'));
      expect(args, contains('music with spaces.wav'));
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, contains('volume=1.500'));
      expect(graph, contains('volume=0.200'));
      expect(graph, contains('duration=first'));
      expect(graph, contains('normalize=0'));
      expect(graph, contains('alimiter='));
      expect(args, contains('-stream_loop'));
    },
  );
  test('music is copied; discarded draft cannot delete the source', () async {
    final external = await Directory.systemTemp.createTemp('podcast-original-');
    try {
      final source = File('${external.path}/song.wav');
      await writeTone(source.path);
      await service.chooseMusic(source.path);
      expect(service.musicPath, isNot(source.path));
      await service.start();
      await service.stop();
      await service.discard();
      expect(await source.exists(), true);
      expect(service.state, PodcastCaptureState.idle);
    } finally {
      await external.delete(recursive: true);
    }
  });
  test(
    'mix failures and cancellation retain the recording for retry',
    () async {
      await service.start();
      await service.stop();
      mixer.fail = true;
      await expectLater(
        service.render(),
        throwsA(isA<PodcastRecorderException>()),
      );
      expect(await File(microphone.path!).exists(), true);
      expect(service.busy, false);
      mixer.fail = false;
      mixer.waiting = Completer<void>();
      final operation = service.render();
      while (mixer.arguments == null || !service.busy) {
        await Future<void>.delayed(Duration.zero);
      }
      // Let render dispatch after its metadata write.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await service.cancelRender();
      await expectLater(
        operation,
        throwsA(
          isA<PodcastRecorderException>().having(
            (e) => e.code,
            'code',
            'cancelled',
          ),
        ),
      );
      expect(service.output, isNull);
      expect(await File(microphone.path!).exists(), true);
      mixer.waiting = null;
      expect(await service.render(), endsWith('.m4a'));
    },
  );
  test(
    'mix change invalidates preview but never changes original voice',
    () async {
      await service.start();
      await service.stop();
      final bytes = await File(microphone.path!).readAsBytes();
      await service.render();
      service.saved = true;
      await service.updateMix(microphone: .5);
      expect(service.output, isNull);
      expect(service.saved, false);
      expect(await File(microphone.path!).readAsBytes(), bytes);
    },
  );
  test('unsaved draft and settings survive reopening', () async {
    service.name = 'Recovery test';
    await service.updateMix(microphone: .8);
    await service.start();
    await service.stop();
    await service.close();
    final recovered = PodcastRecorderService(
      microphone: FakeMicrophone(),
      mixer: FakeMixer(),
      directory: () async => root,
      keepAwake: (_) async {},
    );
    await recovered.initialize();
    expect(recovered.recovered, true);
    expect(recovered.state, PodcastCaptureState.ready);
    expect(recovered.name, 'Recovery test');
    expect(recovered.microphoneVolume, .8);
    await recovered.close();
  });
  test('saved draft is cleaned on close', () async {
    await service.start();
    await service.stop();
    await service.render();
    service.saved = true;
    await service.close();
    expect(await root.list().toList(), isEmpty);
  });
  test(
    'jingles survive discard and saved close; removal and replacement persist',
    () async {
      final external = await Directory.systemTemp.createTemp('jingle-source-');
      PodcastRecorderService? reopened;
      try {
        final source = '${external.path}/opening.wav';
        await writeTone(source, seconds: .2);
        await service.chooseJingle(source, intro: true);
        await service.chooseJingle(source, intro: false);
        final intro = service.introPath!;
        await service.start();
        await service.stop();
        await service.render();
        expect(mixer.arguments, contains(intro));
        await service.chooseJingle(source, intro: true);
        expect(service.output, isNull);
        await expectLater(
          service.chooseJingle('bad.txt', intro: true),
          throwsA(isA<PodcastRecorderException>()),
        );
        expect(await File(intro).exists(), true);
        await service.discard();
        expect(await File(intro).exists(), true);
        await service.start();
        await service.stop();
        service.saved = true;
        await service.close();
        reopened = PodcastRecorderService(
          microphone: FakeMicrophone(),
          mixer: FakeMixer(),
          directory: () async => root,
          keepAwake: (_) async {},
        );
        await reopened.initialize();
        expect(reopened.state, PodcastCaptureState.idle);
        expect(reopened.introPath, intro);
        expect(reopened.outroPath, isNotNull);
        await reopened.chooseJingle(null, intro: true);
        expect(reopened.introPath, isNull);
        expect(await File(intro).exists(), false);
        expect(await File(source).exists(), true);
        expect(await File(reopened.outroPath!).exists(), true);
      } finally {
        await reopened?.close();
        await external.delete(recursive: true);
      }
    },
  );
  var hasFfmpeg = false;
  try {
    hasFfmpeg = Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } catch (_) {}
  test('real audio: gains, looping music, silence and duration', () async {
    final voice = '${root.path}/voice.wav', bed = '${root.path}/bed.wav';
    await writeTone(voice);
    await writeTone(bed, seconds: .2, frequency: 880);
    Future<List<double>> samples(
      String name,
      double mic,
      double music,
      String? background,
    ) async {
      final output = '${root.path}/$name.m4a';
      await ProcessMixer().render(
        PodcastRecorderService.mixArguments(
          voice: voice,
          destination: output,
          microphone: mic,
          music: music,
          background: background,
        ),
      );
      final probe = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'json',
        output,
      ]);
      final duration = double.parse(
        jsonDecode(probe.stdout as String)['format']['duration'] as String,
      );
      expect(duration, closeTo(1, .05));
      final decoded = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-i',
        output,
        '-f',
        'f32le',
        '-ac',
        '1',
        'pipe:1',
      ], stdoutEncoding: null);
      expect(decoded.exitCode, 0);
      final data = ByteData.sublistView(
        Uint8List.fromList(decoded.stdout as List<int>),
      );
      return [
        for (var i = 0; i < data.lengthInBytes; i += 4)
          data.getFloat32(i, Endian.little),
      ];
    }

    double rms(List<double> s) =>
        math.sqrt(s.fold<double>(0, (a, b) => a + b * b) / s.length);
    final normal = await samples('normal', 1, 0, null);
    final half = await samples('half', .5, 0, null);
    expect(rms(half) / rms(normal), closeTo(.5, .02));
    final silent = await samples('silent', 0, 0, null);
    expect(rms(silent), lessThan(.0001));
    final music = await samples('music', 0, .5, bed);
    expect(rms(music.sublist(22050)), greaterThan(.04));
    final mix = await samples('mix', 2, 1, bed);
    expect(mix.every((v) => v.isFinite && v.abs() < 1), true);
  }, skip: !hasFfmpeg ? 'Requires FFmpeg' : false);
  test(
    'real audio: optional jingles preserve order and add their full duration',
    () async {
      final voice = '${root.path}/voice.wav';
      final intro = '${root.path}/intro.wav';
      final outro = '${root.path}/outro.wav';
      await writeTone(voice, frequency: 440);
      await writeTone(intro, seconds: .3, frequency: 220);
      await writeTone(outro, seconds: .4, frequency: 880);
      for (final opening in [false, true]) {
        for (final closing in [false, true]) {
          final destination = '${root.path}/$opening-$closing.m4a';
          await ProcessMixer().render(
            PodcastRecorderService.mixArguments(
              voice: voice,
              destination: destination,
              microphone: 1,
              music: 0,
              background: outro,
              intro: opening ? intro : null,
              outro: closing ? outro : null,
            ),
          );
          final decoded = await Process.run('ffmpeg', [
            '-v',
            'error',
            '-i',
            destination,
            '-f',
            'f32le',
            '-ar',
            '44100',
            '-ac',
            '1',
            'pipe:1',
          ], stdoutEncoding: null);
          expect(decoded.exitCode, 0);
          final data = ByteData.sublistView(
            Uint8List.fromList(decoded.stdout as List<int>),
          );
          final samples = [
            for (var i = 0; i < data.lengthInBytes; i += 4)
              data.getFloat32(i, Endian.little),
          ];
          expect(
            samples.length / 44100,
            closeTo(1 + (opening ? .3 : 0) + (closing ? .4 : 0), .05),
          );
          double frequencyAt(double seconds) {
            final start = (seconds * 44100).round();
            var crossings = 0;
            for (var i = start + 1; i < start + 4410; i++) {
              if (samples[i - 1] < 0 && samples[i] >= 0) crossings++;
            }
            return crossings * 10.0;
          }

          if (opening) expect(frequencyAt(.1), closeTo(220, 12));
          expect(frequencyAt((opening ? .3 : 0) + .2), closeTo(440, 12));
          if (closing) {
            expect(frequencyAt((opening ? .3 : 0) + 1.1), closeTo(880, 12));
          }
        }
      }
    },
    skip: !hasFfmpeg ? 'Requires FFmpeg' : false,
  );
}
