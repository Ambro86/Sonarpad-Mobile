import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/pyannote_mobile_service.dart';

void main() {
  test('candidate selection uses both quantiles and duration', () {
    final counts = Uint8List(80);
    final confidence = Float64List(80);
    for (var i = 2; i <= 27; i++) {
      counts[i] = 1;
      confidence[i] = 0.67;
    }
    for (var i = 35; i <= 62; i++) {
      counts[i] = 1;
      confidence[i] = 0.985;
    }
    final result = detectPyannoteNonverbalCandidates(
      frameCounts: counts, confidence: confidence, durationSec: 4,
    );
    expect(result.length, 1);
    expect(result.first.id, startsWith('NV-'));
    expect(result.first.p50, closeTo(0.67, 0.001));
    expect(result.first.p90, closeTo(0.67, 0.001));
  });

  test('candidates are protected unless Gemini approves their exact ID', () {
    final c = PyannoteNonverbalCandidate(
      id: 'NV-0000001400', start: 1.4, end: 1.8,
      p50: 0.67, p90: 0.72,
    );
    const original = <PyannoteInterval>[PyannoteInterval(1, 3)];
    final rejected = protectedIntervalsAfterVerifiedNonverbal(
      original: original, candidates: <PyannoteNonverbalCandidate>[c],
      approvedIds: <String>{'SPOOFED-ID'}, durationSec: 5,
    );
    // Protection is defined by interval boundaries, not list identity.
    expect(
      rejected.map((interval) => (interval.start, interval.end)),
      original.map((interval) => (interval.start, interval.end)),
    );
    final allowed = protectedIntervalsAfterVerifiedNonverbal(
      original: original, candidates: <PyannoteNonverbalCandidate>[c],
      approvedIds: <String>{c.id}, durationSec: 5,
    );
    expect(allowed.length, 2);
    expect(allowed.first.start, 1);
    expect(allowed.first.end, closeTo(1.45, 0.000001));
    expect(allowed.last.start, closeTo(1.75, 0.000001));
    expect(allowed.last.end, 3);
  });
}
