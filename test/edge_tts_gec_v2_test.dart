import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_gec_v2.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_protocol.dart';

void main() {
  test('Sec-MS-GEC v2 matches independent historical Rust vectors', () {
    // Historical deterministic test vectors, not captured browser credentials.
    const vectors = <(int, String)>[
      (
        132223104000000000,
        'D10F23DC48295BD2-E6E2AA64410971AA6513AD619500D20FA1A1B839D141A5CCF28D5D738D0019B4',
      ),
      (
        133485408000000000,
        '9586E5FBB4BD2CFF-DE636BA8369C7431ED826BDEEB00ECA1CC52826A6BB736DCB150A2AF37DFC498',
      ),
      (
        134116128000000000,
        '9DCBE9F8FA4AB77D-CA04286C2DDD2253475C966035FB821DD5ACEB920A3AE69E3F976EE02FD92C37',
      ),
    ];
    for (final (ticks, expected) in vectors) {
      final actual = EdgeTtsGecV2.generateForTicks(
        ticks,
        clientToken: EdgeTtsProtocol.clientToken,
      );
      expect(actual, expected);
      expect(actual.length, 81);
      expect(actual[16], '-');
      expect(RegExp(r'^[A-F0-9]{16}-[A-F0-9]{64}$').hasMatch(actual), isTrue);
    }
  });

  test('Sec-MS-GEC v2 rounds the clock to five minutes', () {
    final start = DateTime.utc(2026, 1, 1, 0, 1, 4);
    final later = start.add(const Duration(minutes: 2));
    final following = start.add(const Duration(minutes: 6));
    final first = EdgeTtsGecV2.generate(
      clientToken: EdgeTtsProtocol.clientToken,
      now: start,
    );
    expect(
      EdgeTtsGecV2.generate(
        clientToken: EdgeTtsProtocol.clientToken,
        now: later,
      ),
      first,
    );
    expect(
      EdgeTtsGecV2.generate(
        clientToken: EdgeTtsProtocol.clientToken,
        now: following,
      ),
      isNot(first),
    );
  });
}
