import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/global_recording_service.dart';
import 'package:sonarpad_mobile_starter/services/protected_wakelock.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late bool awake;
  late WakeLockCoordinator wakeLock;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    awake = false;
    wakeLock = WakeLockCoordinator(
      read: () async => awake,
      write: (value) async {
        awake = value;
      },
    );
  });
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));
  GlobalRecordingTarget target() => GlobalRecordingTarget(
    id: 'tv8',
    stationName: 'TV8',
    streamUrl: 'https://example.test/live.m3u8',
    includeVideo: true,
    tvChannel: TvChannel(
      name: 'TV8',
      url: 'https://example.test/live.m3u8',
      category: 'TV',
      tvgId: 'Tv8.it',
      httpUserAgent: 'test-agent',
    ),
  );
  Future<String> save(
    GlobalRecordingService service,
    DateTime start,
    DateTime end,
  ) async {
    await service.schedule(
      target: target(),
      start: start,
      end: end,
      title: 'Programme',
    );
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(GlobalRecordingService.scheduleStorageKey)!;
  }

  test(
    'pending schedule holds screen independently and cancellation clears storage',
    () async {
      final service = GlobalRecordingService.forTesting(wakeLock: wakeLock);
      final now = DateTime.now();
      await save(
        service,
        now.add(const Duration(hours: 1)),
        now.add(const Duration(hours: 2)),
      );
      await wakeLock.toggle(false);
      expect(awake, isTrue);
      expect(service.hasPendingScheduleFor('tv8'), isTrue);
      service.cancelSchedule();
      await settle();
      expect(awake, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(
          GlobalRecordingService.scheduleStorageKey,
        ),
        isNull,
      );
    },
  );
  test(
    'restart restores future schedule and all TV resolver metadata',
    () async {
      final now = DateTime.now();
      final first = GlobalRecordingService.forTesting(wakeLock: wakeLock);
      final raw = await save(
        first,
        now.add(const Duration(hours: 1)),
        now.add(const Duration(hours: 2)),
      );
      first.cancelSchedule();
      await settle();
      SharedPreferences.setMockInitialValues({
        GlobalRecordingService.scheduleStorageKey: raw,
      });
      final restored = GlobalRecordingService.forTesting(wakeLock: wakeLock);
      expect(await restored.restoreSchedule(), isNull);
      expect(restored.hasPendingScheduleFor('tv8'), isTrue);
      expect(awake, isTrue);
      final data = jsonDecode(
        (await SharedPreferences.getInstance()).getString(
          GlobalRecordingService.scheduleStorageKey,
        )!,
      );
      expect(data['tvChannel']['tvg_id'], 'Tv8.it');
      expect(data['tvChannel']['http_user_agent'], 'test-agent');
      restored.cancelSchedule();
      await settle();
    },
  );
  test(
    'ongoing programme resumes once; expired programme never starts',
    () async {
      final now = DateTime.now();
      final first = GlobalRecordingService.forTesting(wakeLock: wakeLock);
      final raw = await save(
        first,
        now.add(const Duration(hours: 1)),
        now.add(const Duration(hours: 2)),
      );
      first.cancelSchedule();
      await settle();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data['start'] = now
          .subtract(const Duration(minutes: 10))
          .toIso8601String();
      data['end'] = now.add(const Duration(hours: 1)).toIso8601String();
      SharedPreferences.setMockInitialValues({
        GlobalRecordingService.scheduleStorageKey: jsonEncode(data),
      });
      var starts = 0;
      final restored = GlobalRecordingService.forTesting(
        wakeLock: wakeLock,
        startRecording: (target, title) async {
          starts++;
          expect(target.tvChannel!.tvgId, 'Tv8.it');
          expect(title, 'Programme');
          return File('test-recording.mp4');
        },
      );
      await restored.restoreSchedule();
      await restored.restoreSchedule();
      await settle();
      expect(starts, 1);
      restored.cancelSchedule();
      await settle();
      data['end'] = now.subtract(const Duration(minutes: 1)).toIso8601String();
      SharedPreferences.setMockInitialValues({
        GlobalRecordingService.scheduleStorageKey: jsonEncode(data),
      });
      final expired = GlobalRecordingService.forTesting(
        wakeLock: wakeLock,
        startRecording: (_, _) async {
          starts++;
          return File('unexpected.mp4');
        },
      );
      expect(await expired.restoreSchedule(), 'Programme');
      await settle();
      expect(starts, 1);
      expect(awake, isFalse);
      expect(expired.hasAnySchedule, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(
          GlobalRecordingService.scheduleStorageKey,
        ),
        isNull,
      );
    },
  );
}
