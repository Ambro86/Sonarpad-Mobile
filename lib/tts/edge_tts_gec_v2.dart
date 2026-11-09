// Sec-MS-GEC v2 for mobile Edge TTS (CS64 + salted SHA-256).
// Dart adaptation of the MIT-licensed implementation from
// https://github.com/hs-CN/msedge-tts/blob/master/src/tts/drm.rs
// Attribution and complete license: THIRD_PARTY_EDGE_GEC_V2_LICENSE.txt
// Validated against actual Edge 157 CDP signatures. No browser cookies,
// captured signatures, or user credentials are stored or reused.
import 'dart:convert';

class EdgeTtsGecV2 {
  EdgeTtsGecV2._();

  static const int _mask = 0xFFFFFFFF;
  static const int _winEpoch = 11644473600;
  static const int _adjustment = 0xC9DC06A7;
  static const int _sigma0Adjustment = 0x059C0B80;
  static const int _sigma1Adjustment = 0x000B92C0;
  static const int _csFactor = 0x82893933;
  static const int _csAdjustment0 = 0xF2F90B1A;
  static const int _csAdjustment1 = 0x0B1A0000;

  static const List<int> _initial = [
    0x6A09E667,
    0xBB67AE85,
    0x3C6EF372,
    0xA54FF53A,
    0x510E527F,
    0x9B05688C,
    0x1F83D9AB,
    0x5BE0CD19,
  ];

  static const List<int> _state = [
    0xFD9FBEA2,
    0x91243CE7,
    0xBE499094,
    0xCD2E1E0A,
    0x6C006F49,
    0x04BD35AB,
    0xFEB0A7E4,
    0x03EFFBD2,
  ];

  static const List<int> _schedule = [
    0xEB24BF9E,
    0x1558691F,
    0xA0C09EE2,
    0x0CFA32BA,
    0xA622EE8C,
    0xD1DD9491,
    0xC0DD25A0,
    0xF9E70AB6,
    0xF0C31573,
    0x7058CE4E,
    0x7188E606,
    0x00E5AB33,
    0xD258B060,
    0x72766564,
  ];

  static const List<int> _roundConstants = [
    0x428A2F98,
    0x71374491,
    0xB5C0FBCF,
    0xE9B5DBA5,
    0x3956C25B,
    0x59F111F1,
    0x923F82A4,
    0xAB1C5ED5,
    0xD807AA98,
    0x12835B01,
    0x243185BE,
    0x550C7DC3,
    0x72BE5D74,
    0x80DEB1FE,
    0x9BDC06A7,
    0xC19BF174,
    0xE49B69C1,
    0xEFBE4786,
    0x0FC19DC6,
    0x240CA1CC,
    0x2DE92C6F,
    0x4A7484AA,
    0x5CB0A9DC,
    0x76F988DA,
    0x983E5152,
    0xA831C66D,
    0xB00327C8,
    0xBF597FC7,
    0xC6E00BF3,
    0xD5A79147,
    0x06CA6351,
    0x14292967,
    0x27B70A85,
    0x2E1B2138,
    0x4D2C6DFC,
    0x53380D13,
    0x650A7354,
    0x766A0ABB,
    0x81C2C92E,
    0x92722C85,
    0xA2BFE8A1,
    0xA81A664B,
    0xC24B8B70,
    0xC76C51A3,
    0xD192E819,
    0xD6990624,
    0xF40E3585,
    0x106AA070,
    0x19A4C116,
    0x1E376C08,
    0x2748774C,
    0x34B0BCB5,
    0x391C0CB3,
    0x4ED8AA4A,
    0x5B9CCA4F,
    0x682E6FF3,
    0x748F82EE,
    0x78A5636F,
    0x84C87814,
    0x8CC70208,
    0x90BEFFFA,
    0xA4506CEB,
    0xBEF9A3F7,
    0xC67178F2,
  ];

  static const List<List<int>> _csCoefficients = [
    [0xE82E91B1, 0xB32700D0],
    [0x44DE24C6, 0x88DFF51D],
    [0x3BEB65BC, 0x29514038],
    [0xC89C5933, 0xB328CBDF],
    [0x8D1EC211, 0xD405B4D5],
    [0x314EF5D5, 0x26E55F3C],
    [0xE92491B1, 0x607801C6],
    [0xF0A5B9D5, 0x82B2C1FB],
    [0x06064CF3, 0xFA51A3DA],
    [0xDA79FA60, 0x207CC464],
    [0xBED20560, 0x3C3C74F3],
    [0x89F9C9F8, 0xD2D14B61],
    [0x35FA38C6, 0xBB04A2C1],
    [0xCB49E3C6, 0xC5626167],
  ];

  static int _u32(int value) => value & _mask;
  static int _rol16(int value) => _u32((value << 16) | (value >> 16));
  static int _sigma0(int value) => _u32(
    (value >> 7) ^ (value << 25) ^ (value >> 18) ^ (value << 14) ^ (value >> 3),
  );
  static int _sigma1(int value) => _u32(
    (value >> 17) ^
        (value << 15) ^
        (value >> 19) ^
        (value << 13) ^
        (value >> 10),
  );
  static int _ch(int x, int y, int z) => z ^ (x & (y ^ z));
  static int _maj(int x, int y, int z) => (x & y) | (z & (x | y));
  static int _bigSigmaE(int x) => _u32(_ror(x, 6) ^ _ror(x, 11) ^ _ror(x, 25));
  static int _bigSigmaA(int x) => _u32(_ror(x, 2) ^ _ror(x, 13) ^ _ror(x, 22));
  static int _ror(int x, int bits) => _u32((x >> bits) | (x << (32 - bits)));

  static List<int> _leWordsEven(List<int> data) {
    final padded = List<int>.of(data);
    while (padded.length % 4 != 0) {
      padded.add(0);
    }
    final words = <int>[];
    for (var i = 0; i < padded.length; i += 4) {
      words.add(
        padded[i] |
            (padded[i + 1] << 8) |
            (padded[i + 2] << 16) |
            (padded[i + 3] << 24),
      );
    }
    if (words.length.isOdd) {
      words.add(0);
    }
    return words;
  }

  static List<int> _rounds(List<int> state, List<int> words, int firstRound) {
    var a = state[0], b = state[1], c = state[2], d = state[3];
    var e = state[4], f = state[5], g = state[6], h = state[7];
    for (var i = firstRound; i < 64; i++) {
      final constant = firstRound == 14 && i == 14
          ? _adjustment
          : _roundConstants[i];
      final t1 = _u32(h + _bigSigmaE(e) + _ch(e, f, g) + constant + words[i]);
      final t2 = _u32(_bigSigmaA(a) + _maj(a, b, c));
      h = g;
      g = f;
      f = e;
      e = _u32(d + t1);
      d = c;
      c = b;
      b = a;
      a = _u32(t1 + t2);
    }
    return [a, b, c, d, e, f, g, h];
  }

  static void _expand(List<int> words, int firstWord) {
    for (var index = firstWord; index < 64; index++) {
      words.add(
        _u32(
          _sigma1(words[index - 2]) +
              words[index - 7] +
              _sigma0(words[index - 15]) +
              words[index - 16],
        ),
      );
    }
  }

  static List<int> _shaInit(List<int> data) {
    final words = List<int>.filled(16, 0, growable: true);
    words[14] = (data[0] << 16) | (data[1] << 8) | data[2];
    words[15] = _u32(
      (data[3] << 24) | (data[4] << 16) | (data[5] << 8) | data[6],
    );
    for (var index = 16; index < 30; index++) {
      var value = _schedule[index - 16];
      if (index - 2 >= 14) {
        final s = _sigma1(words[index - 2]);
        value = _u32(value + (index == 16 ? s ^ _sigma1Adjustment : s));
      }
      if (index - 7 >= 14) {
        value = _u32(value + words[index - 7]);
      }
      if (index - 15 >= 14) {
        final s = _sigma0(words[index - 15]);
        value = _u32(value + (index == 29 ? s ^ _sigma0Adjustment : s));
      }
      words.add(value);
    }
    words.add(
      _u32(
        _sigma1(words[28]) +
            words[23] +
            _sigma0(words[15]) +
            words[14] +
            _adjustment -
            _roundConstants[14],
      ),
    );
    _expand(words, 31);
    final result = _rounds(_state, words, 14);
    return List<int>.generate(8, (i) => _u32(_initial[i] + result[i]));
  }

  static List<int> _shaDigest(List<int> data) {
    if (data.length < 7) {
      throw ArgumentError('Invalid v2 token data');
    }
    final length = 57 + data.length;
    final padded = List<int>.of(data.skip(7))..add(0x80);
    final zeros = (55 - length) % 64;
    padded.addAll(List<int>.filled(zeros, 0));
    final bitCount = length * 8;
    for (var i = 7; i >= 0; i--) {
      padded.add((bitCount >> (i * 8)) & 0xFF);
    }
    final state = _shaInit(data.sublist(0, 7));
    for (var offset = 0; offset < padded.length; offset += 64) {
      final words = <int>[];
      for (var i = offset; i < offset + 64; i += 4) {
        words.add(
          _u32(
            (padded[i] << 24) |
                (padded[i + 1] << 16) |
                (padded[i + 2] << 8) |
                padded[i + 3],
          ),
        );
      }
      _expand(words, 16);
      final working = _rounds(state, words, 0);
      for (var i = 0; i < 8; i++) {
        state[i] = _u32(state[i] + working[i]);
      }
    }
    final digest = <int>[];
    for (final word in state) {
      for (var shift = 24; shift >= 0; shift -= 8) {
        digest.add((word >> shift) & 0xFF);
      }
    }
    return digest;
  }

  static List<int> _cs64(List<int> data, List<int> digest) {
    final keyA =
        _u32(
          digest[0] | (digest[1] << 8) | (digest[2] << 16) | (digest[3] << 24),
        ) |
        1;
    final keyB =
        _u32(
          digest[4] | (digest[5] << 8) | (digest[6] << 16) | (digest[7] << 24),
        ) |
        1;
    final factors = [_u32(keyA * _csFactor), _u32(keyB * _csFactor)];
    final terms = <int>[];
    final offsets = <int>[];
    for (var i = 0; i < _csCoefficients.length; i++) {
      terms.add(_u32(_csCoefficients[i][0] * factors[i % 2]));
      offsets.add(_csCoefficients[i][1]);
    }
    final input = [0, ...data];
    final words = _leWordsEven(input);
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      var term = _u32(word * (index.isEven ? keyA : keyB));
      var offset = _u32(
        _rol16(word) * (index.isEven ? 0xEF0569FB : 0xC31713DB),
      );
      if (index == 0) {
        term = _u32(term + _u32(_csAdjustment0 * factors[0]));
        offset = _u32(offset + _csAdjustment1);
      }
      terms.add(term);
      offsets.add(offset);
    }
    var swapAcc = 0, swapLast = 0, state = 0, acc = 0;
    for (var index = 0; index < terms.length; index += 2) {
      final x = terms[index], y = terms[index + 1];
      var t = _rol16(_u32(offsets[index] + x));
      var q = _u32(t * 0x76F50F34);
      swapAcc = _u32(swapAcc + _u32(_rol16(q) * 0xC3EFEA97) + q);
      t = _rol16(_u32(offsets[index + 1] + y));
      q = _u32(t * 0x1881CE3C);
      swapLast = _u32(_u32(_rol16(q) * 0x35BD1EC9) + q);
      swapAcc = _u32(swapAcc + swapLast);
      state = _u32(state * keyA + x);
      state = _u32(_rol16(state) * 0xCF98B111);
      state = _u32(_rol16(state) * 0x87085B9F);
      state = _u32(_rol16(state) * 0x12CEB96D);
      state = _u32(_rol16(state) * 0x257E1D83);
      acc = _u32(acc + state);
      t = _u32(state * keyB + y);
      t = _u32(_rol16(t) * 0xA27416F5);
      t = _u32(_rol16(t) * 0xD38396FF);
      state = _u32(_rol16(_u32(_rol16(t) * 0x7C932B89)) * 0xBFA49F69);
      acc = _u32(acc + state);
    }
    return [_u32(swapLast ^ state), _u32(swapAcc ^ acc)];
  }

  static String _hex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();

  /// Build the 81-character v2 signature from a fixed 100 ns timestamp.
  /// Exported for deterministic validation against Edge capture vectors.
  static String generateForTicks(int ticks, {required String clientToken}) {
    final data = utf8.encode('$ticks$clientToken');
    final digest = _shaDigest(data);
    final words = _cs64(data, digest);
    final littleEndian = <int>[];
    for (final word in words) {
      for (var i = 0; i < 4; i++) {
        littleEndian.add((word >> (8 * i)) & 0xFF);
      }
    }
    return '${_hex(littleEndian)}-${_hex(digest)}';
  }

  /// Generate for the current clock, rounded down to a five-minute window.
  static String generate({required String clientToken, DateTime? now}) {
    final unixSeconds =
        (now ?? DateTime.now().toUtc()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final windowsSeconds = unixSeconds + _winEpoch;
    final rounded = windowsSeconds - (windowsSeconds % 300);
    return generateForTicks(rounded * 10000000, clientToken: clientToken);
  }
}
