import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_text.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_bridge.dart';

void main() {
  test('Windows Edge sanitization cases', () {
    expect(EdgeTtsText.sanitize('Ciao... come va...'), 'Ciao. come va.');
    expect(
      EdgeTtsText.sanitize('ciao\u00A0\u200Bmondo\u2409!!!???'),
      'ciao mondo!?',
    );
    expect(EdgeTtsText.sanitize('a.\u200b.. b'), 'a. b');
    expect(EdgeTtsText.sanitize('andrà...": parla'), 'andrà.  parla');
    expect(EdgeTtsText.sanitize('a\u0000b\u001fc'), 'a b c');
    expect(EdgeTtsText.sanitize('a\u200cb\u200dc\u2060d\ufeffe'), 'abcde');
  });
  test(
    'Strict audiobook mapping matches Windows and preserves Unicode words',
    () {
      expect(
        EdgeTtsText.audiobook('«Ciao» l’acqua `sì`…'),
        '"Ciao" l\'acqua \'sì\'.',
      );
      expect(
        EdgeTtsText.audiobook('A—B − C 中文 Русский العربية 😀'),
        'A-B - C 中文 Русский العربية  ',
      );
      expect(EdgeTtsText.audiobook(r'a\b / c'), r'a\b / c');
    },
  );
  test('Paragraphs and words survive existing audiobook splitting', () {
    final text = EdgeTtsText.audiobook(
      'Prima😀\u200b frase.\n\n… | 😀\n\n中文 ≤ 3.',
    );
    expect(EdgeTtsBridge().splitTextForStreaming(text), [
      'Prima frase.',
      '中文 3.',
    ]);
    expect(EdgeTtsText.audiobook('| … 😀'), isEmpty);
  });
}
