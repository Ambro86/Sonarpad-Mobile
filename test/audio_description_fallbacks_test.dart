import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_fallbacks.dart';

void main() {
  group('HTTP and transport classification', () {
    test('400 INVALID_ARGUMENT is permanent', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(
          statusCode: 400,
          body: 'INVALID_ARGUMENT invalid value',
        ),
        AdFailureKind.invalidArgument,
      );
    });
    test('403 is permission denied', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(statusCode: 403),
        AdFailureKind.permissionDenied,
      );
    });
    test('429 quota is quota exhausted', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(
          statusCode: 429,
          body: 'RESOURCE_EXHAUSTED quota exceeded',
        ),
        AdFailureKind.quotaExhausted,
      );
    });
    test('plain 429 stays transient', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(statusCode: 429, body: 'busy'),
        AdFailureKind.transient,
      );
    });
    test('503 high demand is distinguished', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(
          statusCode: 503,
          body: 'UNAVAILABLE currently experiencing high demand service unavailable',
        ),
        AdFailureKind.highDemand,
      );
    });
    for (final code in <int>[500, 502, 504, 599]) {
      test('$code is transient', () {
        expect(
          AudioDescriptionFallbacks.classifyHttp(statusCode: code),
          AdFailureKind.transient,
        );
      });
    }
    test('prepayment depletion overrides quota retry', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(
          statusCode: 429,
          body: 'RESOURCE_EXHAUSTED: Your prepayment credits are depleted.',
        ),
        AdFailureKind.prepaidCreditsDepleted,
      );
    });
    test('Sonarpad file verification has dedicated class', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(
          statusCode: 502,
          body: 'file_verification_failed',
        ),
        AdFailureKind.fileVerificationFailed,
      );
    });
    test('ordinary client error is permanent', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(statusCode: 404),
        AdFailureKind.permanentClient,
      );
    });
    test('success has no failure', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(statusCode: 200),
        AdFailureKind.none,
      );
    });
  });

  group('retry exception rules', () {
    for (final message in <String>[
      'HTTP 502 upstream failed',
      '503 service unavailable',
      '504 DEADLINE_EXCEEDED',
      '429 rate limit',
      'connection reset by peer',
      'connection refused',
      'network is unreachable',
      'temporary failure in name resolution',
      'failed to connect',
      'request timeout',
    ]) {
      test('retryable exception: $message', () {
        expect(AudioDescriptionFallbacks.isRetryableExceptionText(message), isTrue);
      });
    }
    test('400 INVALID_ARGUMENT is never hidden by transient wording', () {
      expect(
        AudioDescriptionFallbacks.isRetryableExceptionText(
          '400 INVALID_ARGUMENT cannot find field after timeout',
        ),
        isFalse,
      );
    });
    test('prepayment depletion is not retryable', () {
      expect(
        AudioDescriptionFallbacks.isRetryableExceptionText(
          '429 prepayment credits are depleted',
        ),
        isFalse,
      );
    });
  });

  group('Gemini blocked and malformed response fallbacks', () {
    Map<String, Object?> candidate(String text) => <String, Object?>{
          'candidates': <Object?>[
            <String, Object?>{
              'content': <String, Object?>{
                'parts': <Object?>[<String, Object?>{'text': text}],
              },
            },
          ],
        };

    test('PROHIBITED_CONTENT with no candidate text is blocked', () {
      expect(
        AudioDescriptionFallbacks.isProhibitedContent(<String, Object?>{
          'promptFeedback': <String, Object?>{'blockReason': 'PROHIBITED_CONTENT'},
        }),
        isTrue,
      );
    });
    test('PROHIBITED_CONTENT with usable text is not treated as empty block', () {
      expect(
        AudioDescriptionFallbacks.isProhibitedContent(<String, Object?>{
          'promptFeedback': <String, Object?>{'blockReason': 'PROHIBITED_CONTENT'},
          ...candidate('{"audio_descriptions":[]}'),
        }),
        isFalse,
      );
    });
    test('MALFORMED_RESPONSE with no text is detected', () {
      expect(
        AudioDescriptionFallbacks.isMalformedResponse(<String, Object?>{
          'candidates': <Object?>[
            <String, Object?>{'finishReason': 'MALFORMED_RESPONSE'},
          ],
        }),
        isTrue,
      );
    });
    test('nested candidate text is found', () {
      expect(AudioDescriptionFallbacks.hasCandidateText(candidate('ok')), isTrue);
    });
    test('blocked and malformed counters remain independent constants', () {
      expect(AudioDescriptionFallbacks.prohibitedContentMaxAttempts, 2);
      expect(AudioDescriptionFallbacks.malformedResponseMaxAttempts, 3);
    });
    test('Sonarpad file verification is bounded to three attempts', () {
      expect(AudioDescriptionFallbacks.sonarpadVerificationMaxAttempts, 3);
      expect(
        AudioDescriptionFallbacks.maxAttemptsForFailure(
          AdFailureKind.fileVerificationFailed,
        ),
        3,
      );
    });
    test('high demand prompts on third consecutive error', () {
      expect(AudioDescriptionFallbacks.shouldPromptAfterHighDemand(2), isFalse);
      expect(AudioDescriptionFallbacks.shouldPromptAfterHighDemand(3), isTrue);
      expect(AudioDescriptionFallbacks.shouldPromptAfterHighDemand(7), isTrue);
    });
  });

  group('blocked 180 second chunk to one-minute recovery', () {
    test('180 seconds becomes three independent minutes', () {
      final result = AudioDescriptionFallbacks.blockedMinuteRanges(0, 180);
      expect(result.length, 3);
      expect(result.map((e) => [e.start, e.end]).toList(), <List<double>>[
        <double>[0, 60],
        <double>[60, 120],
        <double>[120, 180],
      ]);
    });
    test('partial last minute is retained', () {
      final result = AudioDescriptionFallbacks.blockedMinuteRanges(100, 225);
      expect(result.length, 3);
      expect(result.last.start, 220);
      expect(result.last.end, 225);
    });
    test('tail below half a second is ignored', () {
      final result = AudioDescriptionFallbacks.blockedMinuteRanges(0, 120.4);
      expect(result.length, 2);
    });
    test('tail exactly half a second is usable', () {
      final result = AudioDescriptionFallbacks.blockedMinuteRanges(0, 120.5);
      expect(result.length, 3);
    });
  });

  group('safe slots and mandatory coverage', () {
    test('gap below 0.5 second is ignored', () {
      expect(
        AudioDescriptionFallbacks.splitSafeInterval(
          start: 0,
          end: 0.49,
          baseIndex: 1,
        ),
        isEmpty,
      );
    });
    test('short safe gap is optional anchor', () {
      final slots = AudioDescriptionFallbacks.splitSafeInterval(
        start: 2,
        end: 4,
        baseIndex: 7,
      );
      expect(slots.single.mandatory, isFalse);
      expect(slots.single.id, 'E0007');
    });
    test('three second gap becomes mandatory', () {
      final slot = AudioDescriptionFallbacks.splitSafeInterval(
        start: 0,
        end: 3,
        baseIndex: 1,
      ).single;
      expect(slot.mandatory, isTrue);
      expect(slot.maxWords, 6);
    });
    test('long silence is balanced into <=15 second mandatory pieces', () {
      final slots = AudioDescriptionFallbacks.splitSafeInterval(
        start: 0,
        end: 40,
        baseIndex: 2,
      );
      expect(slots.length, 3);
      expect(slots.every((e) => e.duration <= 15.0 + 1e-9), isTrue);
      expect(slots.every((e) => e.mandatory), isTrue);
      expect(slots.first.id, 'S0002P001');
    });
    test('mandatory word budget is two words per second', () {
      final slot = AudioDescriptionFallbacks.splitSafeInterval(
        start: 10,
        end: 20,
        baseIndex: 1,
      ).single;
      expect(slot.maxWords, 20);
    });
    test('minute fallback rebases selected slots to local time', () {
      final slots = <AdFallbackSlot>[
        const AdFallbackSlot(
          id: 'S1', start: 65, end: 70, mandatory: true,
          partitionIndex: 1, partitionCount: 1,
        ),
        const AdFallbackSlot(
          id: 'S2', start: 125, end: 130, mandatory: true,
          partitionIndex: 1, partitionCount: 1,
        ),
      ];
      final selected = AudioDescriptionFallbacks.slotsForMinute(
        slots,
        const AdTimeRange(60, 120),
      );
      expect(selected.length, 1);
      expect(selected.single.id, 'S1');
      expect(selected.single.start, 5);
      expect(selected.single.end, 10);
    });
    test('uncovered mandatory slot is detected by description midpoint', () {
      final slots = <AdFallbackSlot>[
        const AdFallbackSlot(
          id: 'S1', start: 0, end: 10, mandatory: true,
          partitionIndex: 1, partitionCount: 1,
        ),
        const AdFallbackSlot(
          id: 'S2', start: 10, end: 20, mandatory: true,
          partitionIndex: 1, partitionCount: 1,
        ),
      ];
      final missing = AudioDescriptionFallbacks.uncoveredMandatorySlots(
        slots,
        const <AdTimeRange>[AdTimeRange(2, 4)],
      );
      expect(missing.map((e) => e.id), <String>['S2']);
    });
  });

  group('large coverage recovery', () {
    test('90 second uncovered beginning triggers recovery', () {
      final gaps = AudioDescriptionFallbacks.findLargeCoverageGaps(
        chunkStart: 0,
        chunkEnd: 180,
        descriptions: const <AdTimeRange>[AdTimeRange(100, 110)],
      );
      expect(gaps.first.start, 0);
      expect(gaps.first.end, 100);
    });
    test('89.9 second gap does not trigger recovery', () {
      final gaps = AudioDescriptionFallbacks.findLargeCoverageGaps(
        chunkStart: 0,
        chunkEnd: 100,
        descriptions: const <AdTimeRange>[AdTimeRange(89.9, 100)],
      );
      expect(gaps, isEmpty);
    });
    test('large tail triggers recovery', () {
      final gaps = AudioDescriptionFallbacks.findLargeCoverageGaps(
        chunkStart: 0,
        chunkEnd: 180,
        descriptions: const <AdTimeRange>[AdTimeRange(0, 80)],
      );
      expect(gaps.single, isA<AdTimeRange>());
      expect(gaps.single.start, 80);
      expect(gaps.single.end, 180);
    });
    test('covered chunk has no recovery gaps', () {
      final gaps = AudioDescriptionFallbacks.findLargeCoverageGaps(
        chunkStart: 0,
        chunkEnd: 180,
        descriptions: const <AdTimeRange>[AdTimeRange(0, 180)],
      );
      expect(gaps, isEmpty);
    });
  });

  group('timestamp parsing and contextual repair', () {
    test('numeric seconds', () =>
        expect(AudioDescriptionFallbacks.parseTimeSeconds(12.5), 12.5));
    test('decimal string seconds', () =>
        expect(AudioDescriptionFallbacks.parseTimeSeconds('12.25'), 12.25));
    test('MM:SS milliseconds', () =>
        expect(AudioDescriptionFallbacks.parseTimeSeconds('02:13.500'), 133.5));
    test('comma decimal', () =>
        expect(AudioDescriptionFallbacks.parseTimeSeconds('01:02,250'), 62.25));
    test('HH:MM:SS is unambiguous', () =>
        expect(AudioDescriptionFallbacks.parseTimeSeconds('01:02:03.5'), 3723.5));
    test('Gemini MM:SS:ms colon typo with three digits is exact', () {
      expect(
        AudioDescriptionFallbacks.parseTimeSeconds('01:13:473'),
        closeTo(73.473, 0.000001),
      );
      expect(
        AudioDescriptionFallbacks.parseTimeSeconds('02:17:160'),
        closeTo(137.160, 0.000001),
      );
    });
    test('HH:MM:SS:ms remains supported', () {
      expect(
        AudioDescriptionFallbacks.parseTimeSeconds('01:02:03:500'),
        closeTo(3723.5, 0.000001),
      );
    });
    test('two digit colon fraction is repaired only inside local window', () {
      expect(
        AudioDescriptionFallbacks.parseTimeSecondsInWindow(
          '02:02:18',
          windowStart: 0,
          windowEnd: 182.110,
        ),
        closeTo(122.18, 0.000001),
      );
      expect(
        AudioDescriptionFallbacks.parseTimeSecondsInWindow(
          '02:54:53',
          windowStart: 0,
          windowEnd: 182.110,
        ),
        closeTo(174.53, 0.000001),
      );
    });
    test('valid hour timestamp wins over contextual fraction repair', () {
      expect(
        AudioDescriptionFallbacks.parseTimeSecondsInWindow(
          '01:02:03',
          windowStart: 3600,
          windowEnd: 3900,
        ),
        3723,
      );
    });
    test('out of local window typo is left for range audit', () {
      expect(
        AudioDescriptionFallbacks.parseTimeSecondsInWindow(
          '09:30:20',
          windowStart: 0,
          windowEnd: 182.110,
        ),
        34220,
      );
    });
    test('negative numeric time rejected', () =>
        expect(AudioDescriptionFallbacks.parseTimeSeconds(-1), isNull));
    test('invalid second 60 rejected', () =>
        expect(AudioDescriptionFallbacks.parseTimeSeconds('02:60'), isNull));
    test('contextual colon fraction is rebased once into original timeline', () {
      const slot = AdFallbackSlot(
        id: 'S1', start: 304.0, end: 322.0, mandatory: true,
        partitionIndex: 1, partitionCount: 1,
      );
      final result = AudioDescriptionFallbacks.normalizeTimes(
        startValue: '02:02:18',
        endValue: '02:19:52',
        evidenceValue: '02:10:00',
        chunkStart: 182.44,
        chunkEnd: 364.55,
        slot: slot,
      );
      expect(result, isNotNull);
      expect(result!.start, closeTo(304.62, 0.000001));
      expect(result.end, closeTo(321.96, 0.000001));
    });
    test('relative chunk timestamps are offset once', () {
      const slot = AdFallbackSlot(
        id: 'S', start: 425, end: 430, mandatory: true,
        partitionIndex: 1, partitionCount: 1,
      );
      final result = AudioDescriptionFallbacks.normalizeTimes(
        startValue: 5,
        endValue: 7,
        evidenceValue: 6,
        chunkStart: 420,
        chunkEnd: 600,
        slot: slot,
      );
      expect(result, isNotNull);
      expect(result!.start, 425);
      expect(result.end, 427);
      expect(result.evidence, 426);
    });
    test('absolute chunk timestamps are not double shifted', () {
      const slot = AdFallbackSlot(
        id: 'S', start: 425, end: 430, mandatory: true,
        partitionIndex: 1, partitionCount: 1,
      );
      final result = AudioDescriptionFallbacks.normalizeTimes(
        startValue: 425,
        endValue: 427,
        evidenceValue: 426,
        chunkStart: 420,
        chunkEnd: 600,
        slot: slot,
      );
      expect(result!.start, 425);
      expect(result.end, 427);
    });
    test('small boundary drift is clamped', () {
      const slot = AdFallbackSlot(
        id: 'S', start: 100, end: 105, mandatory: true,
        partitionIndex: 1, partitionCount: 1,
      );
      final result = AudioDescriptionFallbacks.normalizeTimes(
        startValue: 99.5,
        endValue: 105.5,
        chunkStart: 100,
        chunkEnd: 110,
        slot: slot,
      );
      expect(result!.start, 100);
      expect(result.end, 105);
    });
    test('large out-of-window timestamp is rejected', () {
      const slot = AdFallbackSlot(
        id: 'S', start: 100, end: 105, mandatory: true,
        partitionIndex: 1, partitionCount: 1,
      );
      expect(
        AudioDescriptionFallbacks.normalizeTimes(
          startValue: 900,
          endValue: 905,
          chunkStart: 100,
          chunkEnd: 200,
          slot: slot,
        ),
        isNull,
      );
    });
    test('evidence is clamped inside accepted narration range', () {
      const slot = AdFallbackSlot(
        id: 'S', start: 10, end: 20, mandatory: true,
        partitionIndex: 1, partitionCount: 1,
      );
      final result = AudioDescriptionFallbacks.normalizeTimes(
        startValue: 12,
        endValue: 15,
        evidenceValue: 99,
        chunkStart: 0,
        chunkEnd: 30,
        slot: slot,
      );
      expect(result!.evidence, 15);
    });
  });

  group('exact TTS scheduling', () {
    final slots = <AdFallbackSlot>[
      const AdFallbackSlot(
        id: 'S1', start: 10, end: 15, mandatory: true,
        partitionIndex: 1, partitionCount: 1,
      ),
      const AdFallbackSlot(
        id: 'S2', start: 18, end: 24, mandatory: true,
        partitionIndex: 1, partitionCount: 1,
      ),
    ];
    test('preferred fitting slot wins', () {
      final slot = AudioDescriptionFallbacks.chooseNearbySlot(
        slots: slots,
        occupied: <String>{},
        preferredSlotId: 'S1',
        visualTime: 12,
        requiredDuration: 2,
      );
      expect(slot!.id, 'S1');
    });
    test('nearby safe slot can recover after exact TTS duration', () {
      final slot = AudioDescriptionFallbacks.chooseNearbySlot(
        slots: slots,
        occupied: <String>{'S1'},
        preferredSlotId: 'S1',
        visualTime: 16,
        requiredDuration: 3,
      );
      expect(slot!.id, 'S2');
    });
    test('movement beyond five seconds is rejected', () {
      final slot = AudioDescriptionFallbacks.chooseNearbySlot(
        slots: slots,
        occupied: <String>{'S1'},
        preferredSlotId: 'S1',
        visualTime: 1,
        requiredDuration: 2,
      );
      expect(slot, isNull);
    });
    test('occupied slots cannot be reused', () {
      expect(
        AudioDescriptionFallbacks.chooseNearbySlot(
          slots: slots,
          occupied: <String>{'S1', 'S2'},
          preferredSlotId: 'S1',
          visualTime: 12,
          requiredDuration: 1,
        ),
        isNull,
      );
    });
    test('slot shorter than exact synthesized duration is rejected', () {
      expect(
        AudioDescriptionFallbacks.chooseNearbySlot(
          slots: slots,
          occupied: <String>{},
          preferredSlotId: 'S1',
          visualTime: 12,
          requiredDuration: 10,
        ),
        isNull,
      );
    });
  });

  group('JSON salvage and one-shot repair decision', () {
    const valid = '{"character_glossary":[],"audio_descriptions":[]}';
    test('markdown fences are stripped', () {
      expect(AudioDescriptionFallbacks.stripJsonFences('```json\n$valid\n```'), valid);
    });
    test('leading prose object can be extracted', () {
      expect(AudioDescriptionFallbacks.extractJsonObject('hello $valid bye'), valid);
    });
    test('valid object parses normally', () {
      final result = AudioDescriptionFallbacks.parseOrSalvageUnifiedJson(valid);
      expect(result.parseOk, isTrue);
      expect(result.salvaged, isFalse);
    });
    test('list root does not crash and requests repair', () {
      final result = AudioDescriptionFallbacks.parseOrSalvageUnifiedJson('[]');
      expect(result.data, isNull);
      expect(result.parseOk, isFalse);
    });
    test('complete objects are salvaged from truncated response', () {
      const broken = '{"character_glossary":[],"audio_descriptions":['
          '{"slot_id":"S1","description_text":"uno"},'
          '{"slot_id":"S2","description_text":"due"';
      final result = AudioDescriptionFallbacks.parseOrSalvageUnifiedJson(broken);
      expect(result.salvaged, isTrue);
      expect((result.data!['audio_descriptions'] as List).length, 1);
    });
    test('salvaged JSON still triggers one repair attempt', () {
      expect(
        AudioDescriptionFallbacks.shouldAttemptJsonRepair(
          parseOk: false,
          salvaged: true,
          parsedDescriptionCount: 1,
          rawText: 'broken',
        ),
        isTrue,
      );
    });
    test('MAX_TOKENS triggers repair', () {
      expect(
        AudioDescriptionFallbacks.shouldAttemptJsonRepair(
          parseOk: true,
          salvaged: false,
          parsedDescriptionCount: 2,
          rawText: valid,
          finishReason: 'MAX_TOKENS',
        ),
        isTrue,
      );
    });
    test('valid nonempty response does not trigger repair', () {
      expect(
        AudioDescriptionFallbacks.shouldAttemptJsonRepair(
          parseOk: true,
          salvaged: false,
          parsedDescriptionCount: 2,
          rawText: valid,
        ),
        isFalse,
      );
    });
    test('broken repair fragment is capped to 40000 characters', () {
      final result = AudioDescriptionFallbacks.brokenJsonForRepair(List.filled(45000, 'x').join());
      expect(result.length, 40000);
    });
  });

  group('language detection and correction selection', () {
    test('locale variants match by base language', () {
      expect(AudioDescriptionFallbacks.languagesMatch('pt-BR', 'pt'), isTrue);
      expect(AudioDescriptionFallbacks.languagesMatch('zh-CN', 'zh-TW'), isTrue);
    });
    test('legacy language aliases normalize', () {
      expect(AudioDescriptionFallbacks.normalizeLanguageCode('iw-IL'), 'he');
      expect(AudioDescriptionFallbacks.normalizeLanguageCode('in-ID'), 'id');
    });
    test('short text is not sent for detection', () {
      expect(AudioDescriptionFallbacks.sampleHasEnoughLetters('A car.'), isFalse);
    });
    test('short but meaningful English description is detectable', () {
      expect(
        AudioDescriptionFallbacks.sampleHasEnoughLetters('Dwarves observe joyously'),
        isTrue,
      );
    });
    test('Google list response language and confidence parse', () {
      final payload = <Object?>[
        'traduzione',
        <Object?>[],
        null,
        null,
        <Object?>[
          <Object?>['en'],
          null,
          <Object?>[0.98],
          <Object?>['en'],
        ],
        'en',
      ];
      final result = AudioDescriptionFallbacks.parseGoogleLanguageDetection(payload);
      expect(result!.language, 'en');
      expect(result.confidence, 0.98);
    });
  });

  group('persistent character catalog continuity', () {
    Map<String, Object?> c(String id, String name, String description) =>
        <String, Object?>{'id': id, 'name': name, 'description': description};

    test('authoritative saved ID survives shortened Gemini alias', () {
      final result = AudioDescriptionFallbacks.mergeCharacterCatalog(
        <Map<String, Object?>>[
          c('anna_robinson', 'Anna Robinson', 'Madre di Flo. Capelli castani.'),
        ],
        <Map<String, Object?>>[
          c('anna', 'Anna Robinson', 'Indossa un abito azzurro.'),
        ],
      );
      expect(result.single['id'], 'anna_robinson');
      expect(result.single['description'], contains('abito azzurro'));
    });
    test('ambiguous first-name-only does not merge', () {
      final result = AudioDescriptionFallbacks.mergeCharacterCatalog(
        <Map<String, Object?>>[
          c('john_a', 'John Smith', 'Alto.'),
          c('john_b', 'John Brown', 'Basso.'),
        ],
        <Map<String, Object?>>[c('john', 'John', 'Indossa un cappello.')],
      );
      expect(result.length, 3);
    });
    test('exact ID merges even if name varies', () {
      final result = AudioDescriptionFallbacks.mergeCharacterCatalog(
        <Map<String, Object?>>[c('hero', 'Roberto Canali', 'Capelli scuri.')],
        <Map<String, Object?>>[c('hero', 'Roberto', 'Indossa una giacca.')],
      );
      expect(result.length, 1);
      expect(result.single['name'], 'Roberto Canali');
    });
    test('exact full name merges', () {
      final result = AudioDescriptionFallbacks.mergeCharacterCatalog(
        <Map<String, Object?>>[c('a', 'Luca Canali', 'Bambino.')],
        <Map<String, Object?>>[c('b', 'Luca Canali', 'Capelli scuri.')],
      );
      expect(result.length, 1);
    });
    test('two stable name tokens can identify one catalog entry', () {
      final result = AudioDescriptionFallbacks.mergeCharacterCatalog(
        <Map<String, Object?>>[c('r', 'Roberto Canali', 'Adulto.')],
        <Map<String, Object?>>[c('x', 'Canali Roberto', 'Camicia bianca.')],
      );
      expect(result.length, 1);
      expect(result.single['id'], 'r');
    });
    test('duplicate description sentence is not repeated', () {
      final result = AudioDescriptionFallbacks.mergeCharacterCatalog(
        <Map<String, Object?>>[c('a', 'Anna Rossi', 'Ha capelli scuri.')],
        <Map<String, Object?>>[c('a', 'Anna Rossi', 'Ha capelli scuri.')],
      );
      expect(result.single['description'], 'Ha capelli scuri.');
    });
    test('new visual information is appended instead of truncating established bio', () {
      final old = List.filled(8, 'Descrizione fisica stabile molto dettagliata. ').join();
      final result = AudioDescriptionFallbacks.mergeCharacterCatalog(
        <Map<String, Object?>>[c('a', 'Anna Rossi', old)],
        <Map<String, Object?>>[c('a', 'Anna Rossi', 'Indossa un abito azzurro.')],
      );
      expect((result.single['description'] as String).length, greaterThan(old.length));
      expect(result.single['description'], contains('abito azzurro'));
    });
    test('catalog is bounded to 96 characters', () {
      final incoming = List<Map<String, Object?>>.generate(
        120,
        (i) => c('id$i', 'Personaggio $i', 'Descrizione $i'),
      );
      expect(
        AudioDescriptionFallbacks.mergeCharacterCatalog(const [], incoming).length,
        96,
      );
    });
  });

  group('TTS fallback rules', () {
    test('negative infinity volume means silent output', () {
      expect(
        AudioDescriptionFallbacks.ttsLogHasAudibleSignal('max_volume: -inf dB'),
        isFalse,
      );
    });
    test('extremely low volume is treated as silent', () {
      expect(
        AudioDescriptionFallbacks.ttsLogHasAudibleSignal('max_volume: -90.0 dB'),
        isFalse,
      );
    });
    test('normal signal is audible', () {
      expect(
        AudioDescriptionFallbacks.ttsLogHasAudibleSignal('max_volume: -12.2 dB'),
        isTrue,
      );
    });
    test('unknown volumedetect output is not falsely rejected', () {
      expect(AudioDescriptionFallbacks.ttsLogHasAudibleSignal('no max value'), isTrue);
    });
    test('voice-not-installed is permanent', () {
      expect(
        AudioDescriptionFallbacks.isPermanentTtsError('Voice is not installed'),
        isTrue,
      );
    });
    test('temporary network TTS failure is not permanent', () {
      expect(
        AudioDescriptionFallbacks.isPermanentTtsError('connection reset'),
        isFalse,
      );
    });
  });

  group('Gemini media compatibility sequence', () {
    test('normal media failure moves to compact', () {
      expect(
        AudioDescriptionFallbacks.nextMediaStage(
          current: AdMediaFallbackStage.normal,
          failure: AdFailureKind.invalidArgument,
        ),
        AdMediaFallbackStage.compact,
      );
    });
    test('compact media failure moves to compatibility', () {
      expect(
        AudioDescriptionFallbacks.nextMediaStage(
          current: AdMediaFallbackStage.compact,
          failure: AdFailureKind.fileProcessingFailed,
        ),
        AdMediaFallbackStage.compatibility,
      );
    });
    test('compatibility is last media fallback', () {
      expect(
        AudioDescriptionFallbacks.nextMediaStage(
          current: AdMediaFallbackStage.compatibility,
          failure: AdFailureKind.fileProcessingFailed,
        ),
        AdMediaFallbackStage.none,
      );
    });
    test('credentials do not trigger media re-encode', () {
      expect(
        AudioDescriptionFallbacks.nextMediaStage(
          current: AdMediaFallbackStage.normal,
          failure: AdFailureKind.permissionDenied,
        ),
        AdMediaFallbackStage.none,
      );
    });
    test('quota does not trigger media re-encode', () {
      expect(
        AudioDescriptionFallbacks.nextMediaStage(
          current: AdMediaFallbackStage.normal,
          failure: AdFailureKind.quotaExhausted,
        ),
        AdMediaFallbackStage.none,
      );
    });
    test('generic processing failure is reuploaded once', () {
      expect(AudioDescriptionFallbacks.maxFileProcessingReuploads(), 1);
    });
    test('Gemini code 13 gets three reuploads', () {
      expect(
        AudioDescriptionFallbacks.maxFileProcessingReuploads(providerCode: '13'),
        3,
      );
      expect(
        AudioDescriptionFallbacks.maxFileProcessingReuploads(
          providerCode: 'provider code 13',
        ),
        3,
      );
    });
    test('inline preferred at 48 MiB boundary', () {
      expect(
        AudioDescriptionFallbacks.shouldUseInlineVideo(48 * 1024 * 1024),
        isTrue,
      );
      expect(
        AudioDescriptionFallbacks.shouldUseInlineVideo(48 * 1024 * 1024 + 1),
        isFalse,
      );
    });
    test('Files-to-inline fallback remains available to 50 MiB', () {
      expect(
        AudioDescriptionFallbacks.canFallbackToInlineVideo(50 * 1024 * 1024),
        isTrue,
      );
    });
    test('MIME is chosen from prepared container', () {
      expect(AudioDescriptionFallbacks.mimeTypeForPath('x.mkv'), 'video/x-matroska');
      expect(AudioDescriptionFallbacks.mimeTypeForPath('x.mp4'), 'video/mp4');
    });
  });

  group('checkpoint and recovery safety', () {
    test('matching duration and chunk layout resumes', () {
      expect(
        AudioDescriptionFallbacks.checkpointCompatible(
          savedDurationSec: 5400,
          currentDurationSec: 5400.3,
          savedChunkCount: 30,
          currentChunkCount: 30,
        ),
        isTrue,
      );
    });
    test('changed chunk layout invalidates checkpoint without crashing', () {
      expect(
        AudioDescriptionFallbacks.checkpointCompatible(
          savedDurationSec: 5400,
          currentDurationSec: 5400,
          savedChunkCount: 30,
          currentChunkCount: 31,
        ),
        isFalse,
      );
    });
    test('large duration change invalidates checkpoint', () {
      expect(
        AudioDescriptionFallbacks.checkpointCompatible(
          savedDurationSec: 100,
          currentDurationSec: 103,
          savedChunkCount: 1,
          currentChunkCount: 1,
        ),
        isFalse,
      );
    });
    test('recovery result is accepted only inside requested range', () {
      expect(
        AudioDescriptionFallbacks.descriptionBelongsToRanges(
          const AdTimeRange(10, 12),
          const <AdTimeRange>[AdTimeRange(9, 15)],
        ),
        isTrue,
      );
      expect(
        AudioDescriptionFallbacks.descriptionBelongsToRanges(
          const AdTimeRange(30, 32),
          const <AdTimeRange>[AdTimeRange(9, 15)],
        ),
        isFalse,
      );
    });
  });

  group('Windows parity fallbacks added for mobile', () {
    test('Gemini model prefix is normalized', () {
      expect(
        AudioDescriptionFallbacks.normalizeGeminiModelId('models/gemini-3.5-flash'),
        'gemini-3.5-flash',
      );
    });

    test('legacy Gemini 3.1 Pro id migrates to preview id', () {
      expect(
        AudioDescriptionFallbacks.normalizeGeminiModelId('gemini-3.1-pro'),
        'gemini-3.1-pro-preview',
      );
    });

    test('model metadata must explicitly support generateContent', () {
      expect(
        AudioDescriptionFallbacks.modelSupportsGenerateContent(<String, Object?>{
          'supportedGenerationMethods': <String>['generateContent', 'countTokens'],
        }),
        isTrue,
      );
      expect(
        AudioDescriptionFallbacks.modelSupportsGenerateContent(<String, Object?>{
          'supportedGenerationMethods': <String>['bidiGenerateContent'],
        }),
        isFalse,
      );
    });

    test('generic non-credential INVALID_ARGUMENT activates Windows media fallback', () {
      expect(
        AudioDescriptionFallbacks.isMediaCompatibilityInvalidArgument(
          'HTTP 400 INVALID_ARGUMENT: Request contains an invalid argument',
        ),
        isTrue,
      );
    });

    test('media INVALID_ARGUMENT activates compatibility for decode errors', () {
      expect(
        AudioDescriptionFallbacks.isMediaCompatibilityInvalidArgument(
          'HTTP 400 INVALID_ARGUMENT: video codec/container could not be decoded',
        ),
        isTrue,
      );
    });

    for (final message in <String>[
      'HTTP 400 INVALID_ARGUMENT: API key is invalid',
      'HTTP 400 invalid argument: credential authentication failed',
      'HTTP 400 INVALID_ARGUMENT: permission denied',
      'HTTP 400 INVALID_ARGUMENT: billing account disabled',
      'HTTP 400 INVALID_ARGUMENT: quota/prepayment credits are depleted',
    ]) {
      test('credential/billing error never activates media fallback: $message', () {
        expect(
          AudioDescriptionFallbacks.isMediaCompatibilityInvalidArgument(message),
          isFalse,
        );
      });
    }

    test('MKV absolute-end duration is converted to local media span', () {
      expect(
        AudioDescriptionFallbacks.normalizeSourceDuration(
          path: 'movie.mkv',
          measuredDurationSec: 6200,
          formatStartSec: 200,
        ),
        6000,
      );
    });

    test('WebM absolute-end duration uses same Matroska fallback', () {
      expect(
        AudioDescriptionFallbacks.normalizeSourceDuration(
          path: 'movie.webm',
          measuredDurationSec: 4000,
          formatStartSec: 250,
        ),
        3750,
      );
    });

    test('MP4 duration is never shifted by container start time', () {
      expect(
        AudioDescriptionFallbacks.normalizeSourceDuration(
          path: 'movie.mp4',
          measuredDurationSec: 6200,
          formatStartSec: 200,
        ),
        6200,
      );
    });

    test('small MKV start offset is left untouched', () {
      expect(
        AudioDescriptionFallbacks.normalizeSourceDuration(
          path: 'movie.mkv',
          measuredDurationSec: 6002,
          formatStartSec: 2,
        ),
        6002,
      );
    });

    test('blocked minute accepts full-video timestamps without double offset', () {
      final result = AudioDescriptionFallbacks.normalizeBlockedMinuteTimes(
        startValue: 245.0,
        endValue: 248.0,
        evidenceValue: 246.0,
        minuteStart: 240.0,
        minuteEnd: 300.0,
        parentChunkStart: 180.0,
        slot: const AdFallbackSlot(
          id: 'S', start: 240, end: 250, mandatory: true,
          partitionIndex: 1, partitionCount: 1,
        ),
      );
      expect(result, isNotNull);
      expect(result!.start, 245.0);
      expect(result.end, 248.0);
    });

    test('blocked minute accepts parent-chunk local timestamps', () {
      final result = AudioDescriptionFallbacks.normalizeBlockedMinuteTimes(
        startValue: 65.0,
        endValue: 68.0,
        evidenceValue: 66.0,
        minuteStart: 240.0,
        minuteEnd: 300.0,
        parentChunkStart: 180.0,
        slot: const AdFallbackSlot(
          id: 'S', start: 240, end: 250, mandatory: true,
          partitionIndex: 1, partitionCount: 1,
        ),
      );
      expect(result, isNotNull);
      expect(result!.start, 245.0);
      expect(result.end, 248.0);
    });

    test('blocked minute accepts one-minute local timestamps', () {
      final result = AudioDescriptionFallbacks.normalizeBlockedMinuteTimes(
        startValue: 5.0,
        endValue: 8.0,
        evidenceValue: 6.0,
        minuteStart: 240.0,
        minuteEnd: 300.0,
        parentChunkStart: 180.0,
        slot: const AdFallbackSlot(
          id: 'S', start: 240, end: 250, mandatory: true,
          partitionIndex: 1, partitionCount: 1,
        ),
      );
      expect(result, isNotNull);
      expect(result!.start, 245.0);
      expect(result.end, 248.0);
    });

    test('blocked minute contextual colon fraction stays on local minute timeline', () {
      final result = AudioDescriptionFallbacks.normalizeBlockedMinuteTimes(
        startValue: '00:05:25',
        endValue: '00:08:50',
        evidenceValue: '00:06:50',
        minuteStart: 240.0,
        minuteEnd: 300.0,
        parentChunkStart: 180.0,
        slot: const AdFallbackSlot(
          id: 'S', start: 240, end: 250, mandatory: true,
          partitionIndex: 1, partitionCount: 1,
        ),
      );
      expect(result, isNotNull);
      expect(result!.start, closeTo(245.25, 0.000001));
      expect(result.end, closeTo(248.50, 0.000001));
      expect(result.evidence, closeTo(246.50, 0.000001));
    });

    test('dialogue overlap starts at visual time', () {
      expect(
        AudioDescriptionFallbacks.dialogueOverlapStart(
          visualStartSec: 12,
          requiredDurationSec: 2,
          mediaDurationSec: 100,
          cursorSec: 0,
        ),
        12,
      );
    });

    test('dialogue overlap moves forward to avoid narration overlap', () {
      expect(
        AudioDescriptionFallbacks.dialogueOverlapStart(
          visualStartSec: 12,
          requiredDurationSec: 2,
          mediaDurationSec: 100,
          cursorSec: 14.5,
        ),
        14.5,
      );
    });

    test('dialogue overlap rejects movement beyond five seconds', () {
      expect(
        AudioDescriptionFallbacks.dialogueOverlapStart(
          visualStartSec: 12,
          requiredDurationSec: 2,
          mediaDurationSec: 100,
          cursorSec: 17.01,
        ),
        isNull,
      );
    });

    test('dialogue overlap respects media end', () {
      expect(
        AudioDescriptionFallbacks.dialogueOverlapStart(
          visualStartSec: 99,
          requiredDurationSec: 4,
          mediaDurationSec: 100,
          cursorSec: 0,
        ),
        96,
      );
    });

    test('Edge cleanup keeps a tail shorter than 60 ms after 30 ms reserve', () {
      expect(
        AudioDescriptionFallbacks.edgeTrailingTrimEnd(
          durationSec: 2,
          silenceStartSec: 1.92,
          silenceEndSec: 2,
        ),
        isNull,
      );
    });

    test('Edge cleanup trims a long final silence and keeps 30 ms', () {
      expect(
        AudioDescriptionFallbacks.edgeTrailingTrimEnd(
          durationSec: 2,
          silenceStartSec: 1.7,
          silenceEndSec: 2,
        ),
        closeTo(1.73, 0.000001),
      );
    });

    test('Edge cleanup does not turn all-silent cue into valid audio', () {
      expect(
        AudioDescriptionFallbacks.edgeTrailingTrimEnd(
          durationSec: 2,
          silenceStartSec: 0,
          silenceEndSec: 2,
        ),
        isNull,
      );
    });

    test('Edge cleanup ignores silence that is not at the tail', () {
      expect(
        AudioDescriptionFallbacks.edgeTrailingTrimEnd(
          durationSec: 2,
          silenceStartSec: 1.2,
          silenceEndSec: 1.5,
        ),
        isNull,
      );
    });

    test('extended pause anchor needs an immediate following scene', () {
      expect(
        AudioDescriptionFallbacks.extendedAnchorHasFollowingScene(
          anchorEndSec: 99.60,
          mediaDurationSec: 100,
        ),
        isFalse,
      );
      expect(
        AudioDescriptionFallbacks.extendedAnchorHasFollowingScene(
          anchorEndSec: 95,
          mediaDurationSec: 100,
        ),
        isTrue,
      );
    });

    test('voice dictionary underscores are made pronounceable', () {
      expect(
        AudioDescriptionFallbacks.normalizePronunciationText('Jon_Snow entra'),
        'Jon Snow entra',
      );
    });

    test('Brief/overlap escalation is allowed only for pure no-safe-space exclusions', () {
      expect(
        AudioDescriptionFallbacks.shouldEscalateNoSafeSpace(
          <String?>['no_safe_space_after_exact_tts', 'no_safe_space_after_exact_tts'],
        ),
        isTrue,
      );
      expect(
        AudioDescriptionFallbacks.shouldEscalateNoSafeSpace(
          <String?>['no_safe_space_after_exact_tts', 'tts_error'],
        ),
        isFalse,
      );
      expect(
        AudioDescriptionFallbacks.shouldEscalateNoSafeSpace(<String?>[]),
        isFalse,
      );
    });

    test('corrupted repeated biography is not appended to saved catalog', () {
      final result = AudioDescriptionFallbacks.mergeCharacterCatalog(
        <Map<String, Object?>>[
          <String, Object?>{
            'id': 'anna_robinson',
            'name': 'Anna Robinson',
            'description': 'Madre di Flo. Descrizione fisica stabile.',
          },
        ],
        <Map<String, Object?>>[
          <String, Object?>{
            'id': 'anna_robinson',
            'name': 'Anna Robinson',
            'description':
                'indossa abito azzurro con colletto alto e capelli raccolti '
                'indossa abito azzurro con colletto alto e capelli raccolti',
          },
        ],
      );
      expect(result.single['description'], contains('Descrizione fisica stabile'));
      expect(
        (result.single['description'] as String)
            .split('indossa abito azzurro')
            .length,
        lessThanOrEqualTo(2),
      );
    });
  });

}
