import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/stream_diagnostics_service.dart';

void main() {
  late StreamPlaybackStability stability;
  setUp(() => stability = StreamPlaybackStability());
  bool tick(
    int time,
    int position, {
    bool playing = true,
    bool buffering = false,
    bool paused = false,
  }) => stability.observe(
    elapsed: Duration(seconds: time),
    position: Duration(seconds: position),
    playing: playing,
    buffering: buffering,
    paused: paused,
  );

  test('only sustained real playback restores a recovery attempt', () {
    for (var i = 0; i < 30; i++) {
      expect(tick(i, 14400 + i), isFalse);
    }
    expect(tick(30, 14430), isTrue);
  });
  test('a frozen live clock is not healthy playback', () {
    for (var i = 0; i <= 90; i++) {
      expect(tick(i, 14400), isFalse);
    }
  });
  test('a timestamp jump cannot replace thirty seconds of playback', () {
    expect(tick(0, 14400), isFalse);
    expect(tick(1, 15000), isFalse);
  });
  test('missing callbacks cannot count background time as stable playback', () {
    expect(tick(0, 14400), isFalse);
    expect(tick(60, 14460), isFalse);
    for (var i = 61; i < 90; i++) {
      expect(tick(i, 14400 + i), isFalse);
    }
    expect(tick(90, 14490), isTrue);
  });
  for (final interruption in ['pause', 'buffer', 'stopped', 'reset']) {
    test('$interruption requires a new stable interval', () {
      for (var i = 0; i < 25; i++) {
        expect(tick(i, 14400 + i), isFalse);
      }
      if (interruption == 'reset') {
        stability.reset();
      } else {
        expect(
          tick(
            25,
            14425,
            playing: interruption != 'stopped',
            buffering: interruption == 'buffer',
            paused: interruption == 'pause',
          ),
          isFalse,
        );
      }
      for (var i = 26; i < 56; i++) {
        expect(tick(i, 14400 + i), isFalse);
      }
      expect(tick(56, 14456), isTrue);
    });
  }
  test('a new live timeline does not inherit stability', () {
    for (var i = 0; i < 25; i++) {
      expect(tick(i, 14400 + i), isFalse);
    }
    expect(tick(25, 100), isFalse);
    for (var i = 26; i < 55; i++) {
      expect(tick(i, 75 + i), isFalse);
    }
    expect(tick(55, 130), isTrue);
  });
}
