import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/protected_wakelock.dart';
import 'package:sonarpad_mobile_starter/services/recording_health_monitor.dart';
import 'package:sonarpad_mobile_starter/services/radio_recording_service.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
// ignore: implementation_imports
import 'package:ffmpeg_kit_flutter_new/src/ffmpeg_kit_factory.dart';
// ignore: depend_on_referenced_packages
import 'package:ffmpeg_kit_flutter_platform_interface/ffmpeg_kit_flutter_platform_interface.dart';

class RecordingFixture extends RadioRecordingService {
  RecordingFixture(this.directory);
  final Directory directory;
  @override
  Future<Directory> recordingsDirectory() async => directory;
}

class NativeRecording extends FFmpegKitPlatform {
  int id = 0;
  int? code;
  late Map<String, Object?> session;
  late File file;
  bool cancelled = false;
  @override
  Future<Map<dynamic, dynamic>?> abstractSessionCreateFFmpegSession(
    List<String> args,
  ) async {
    code = null;
    cancelled = false;
    session = {
      'sessionId': ++id,
      'createTime': 0,
      'startTime': 0,
      'command': args.join(' '),
      'type': 1,
    };
    file = File(args.last);
    return session;
  }

  @override
  Future<void> ffmpegKitConfigAsyncFFmpegExecute(int? sessionId) async {
    await file.writeAsBytes([1, 2, 3]);
  }

  @override
  Future<int?> abstractSessionGetReturnCode(int? sessionId) async => code;
  @override
  Future<void> ffmpegKitCancelSession(int sessionId) async {
    cancelled = true;
  }

  void finish(int value) {
    code = value;
    FFmpegKitFactory.getFFmpegSessionCompleteCallback(
      id,
    )?.call(FFmpegKitFactory.mapToSession(session) as FFmpegSession);
  }

  @override
  Future<int?> ffmpegKitFlutterInitializerGetLogLevel() async => 16;
  @override
  Future<void> ffmpegKitConfigSetLogLevel(int level) async {}
  @override
  Future<String?> ffmpegKitConfigGetPlatform() async => 'test';
  @override
  Future<String> archDetectGetArch() async => 'test';
  @override
  Future<String?> getPackageName() async => 'ffmpeg';
  @override
  Future<List<dynamic>?> getExternalLibraries() async => [];
  @override
  Future<void> ffmpegKitConfigEnableRedirection() async {}
  @override
  Future<bool?> ffmpegKitConfigIsLTSBuild() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Recording hold survives player stop/fallback and resumes after lock reset',
    () async {
      var enabled = false;
      final changes = <bool>[];
      final lock = WakeLockCoordinator(
        read: () async => enabled,
        write: (value) async {
          enabled = value;
          changes.add(value);
        },
      );
      final recording = Object();
      await lock.toggle(true);
      await lock.acquire(recording);
      await lock.toggle(
        false,
      ); // AVPlayer -> MediaKit fallback calls audio.stop().
      expect(enabled, isTrue);
      await lock.toggle(
        false,
      ); // Disposing another player cannot release the hold.
      expect(changes, everyElement(isTrue));
      enabled = false; // The OS can reset the screen idle timer on resume.
      await lock.refresh();
      expect(enabled, isTrue);
      await lock.release(recording);
      expect(enabled, isFalse);
    },
  );
  test(
    'Overlapping holds and concurrent requests do not disable a recording',
    () async {
      var enabled = false;
      final lock = WakeLockCoordinator(
        read: () async => enabled,
        write: (v) async {
          enabled = v;
        },
      );
      final a = Object(), b = Object();
      await Future.wait([lock.acquire(a), lock.toggle(false), lock.acquire(b)]);
      await lock.release(a);
      expect(enabled, isTrue);
      await lock.toggle(true); // Playback is still active when recording ends.
      await lock.release(b);
      expect(enabled, isTrue);
      await lock.toggle(false);
      expect(enabled, isFalse);
    },
  );
  test('Stall is detected from media/file progress and clears on recovery', () {
    final now = DateTime(2026, 10, 20);
    final monitor = RecordingHealthMonitor(now);
    expect(
      monitor.update(
        now: now.add(const Duration(seconds: 30)),
        bytes: 100,
        mediaMs: 1000,
      ),
      isFalse,
    );
    expect(
      monitor.update(
        now: now.add(const Duration(seconds: 75)),
        bytes: 100,
        mediaMs: 1000,
      ),
      isFalse,
    );
    expect(
      monitor.update(
        now: now.add(const Duration(seconds: 90)),
        bytes: 100,
        mediaMs: 1000,
      ),
      isTrue,
    );
    expect(monitor.stalled, isTrue);
    expect(
      monitor.update(
        now: now.add(const Duration(hours: 3)),
        bytes: 100,
        mediaMs: 1000,
      ),
      isFalse,
    );
    expect(
      monitor.update(
        now: now.add(const Duration(hours: 3, seconds: 15)),
        bytes: 101,
        mediaMs: 1000,
      ),
      isTrue,
    );
    expect(monitor.stalled, isFalse);
  });
  final native = NativeRecording();
  FFmpegKitPlatform.instance = native;
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('recording-lifecycle-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.arthenica.com/ffmpeg_kit_event'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => root.path,
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test('Stop waits for native completion and final file bytes', () async {
    final service = RecordingFixture(root);
    await service.start(
      stationName: 'TV',
      streamUrl: 'https://example.org/live.m3u8',
    );
    var returned = false;
    final stopping = service.stop().then((f) {
      returned = true;
      return f;
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(native.cancelled, isTrue);
    expect(returned, isFalse);
    expect(service.isRecording, isTrue);
    await native.file.writeAsBytes([4, 5, 6], mode: FileMode.append);
    native.finish(255);
    final output = await stopping;
    expect(await output!.length(), 6);
    expect(service.isRecording, isFalse);
    expect(service.stoppedUnexpectedly, isFalse);
    service.dispose();
  });
  test(
    'Unexpected process exit clears recording state and notifies UI',
    () async {
      final service = RecordingFixture(root);
      final changed = Completer<void>();
      service.addListener(() {
        if (!service.isRecording && !changed.isCompleted) changed.complete();
      });
      await service.start(
        stationName: 'TV',
        streamUrl: 'https://example.org/live.m3u8',
      );
      native.finish(1);
      await changed.future;
      expect(service.isRecording, isFalse);
      expect(service.stoppedUnexpectedly, isTrue);
      expect(await service.outputFile!.exists(), isTrue);
      service.dispose();
    },
  );
}
