import 'dart:convert';
import 'dart:math' as math;

/// Processing fallbacks shared by the mobile audio-description pipeline.
///
/// This file deliberately contains only deterministic logic so every recovery
/// path can be unit-tested without FFmpeg, Gemini, ONNX Runtime or a device.
class AudioDescriptionFallbacks {
  AudioDescriptionFallbacks._();

  static const int transientRetryDelaySeconds = 5;
  static const int malformedResponseMaxAttempts = 3;
  static const int prohibitedContentMaxAttempts = 2;
  static const int sonarpadVerificationMaxAttempts = 3;
  static const int genericFileProcessingReuploads = 1;
  static const int code13FileProcessingReuploads = 3;
  static const int overloadPromptAfterConsecutiveErrors = 3;
  static const int jsonRepairMaxAttempts = 1;
  static const double blockedMinuteSeconds = 60.0;
  static const double blockedMinuteMinTailSeconds = 0.5;
  static const double largeCoverageGapSeconds = 90.0;
  static const double maxPlacementShiftSeconds = 5.0;
  static const double maxMandatorySlotSeconds = 15.0;
  static const double minSafeSlotSeconds = 0.5;
  static const double minMandatorySlotSeconds = 3.0;
  static const int inlineVideoMaxBytes = 48 * 1024 * 1024;
  static const int inlineFallbackMaxBytes = 50 * 1024 * 1024;
  static const int preferredPreparedChunkBytes = 40 * 1024 * 1024;
  static const int compatibilityPreparedChunkBytes = 15 * 1024 * 1024;
  static const double edgeTrailingKeepSeconds = 0.030;
  static const double edgeTrailingMinRemoveSeconds = 0.060;

  /// Mirrors the Windows model-id compatibility layer.
  static String normalizeGeminiModelId(String value) {
    var model = value.trim();
    if (model.startsWith('models/')) model = model.substring('models/'.length);
    if (model == 'gemini-3.1-pro') return 'gemini-3.1-pro-preview';
    return model;
  }

  static bool modelSupportsGenerateContent(Object? payload) {
    if (payload is! Map) return false;
    final methods = payload['supportedGenerationMethods'];
    if (methods is! List) return false;
    return methods.map((e) => '$e').contains('generateContent');
  }

  /// INVALID_ARGUMENT should trigger media re-encoding only when it really
  /// looks like a media/container failure. Credentials, billing and quota
  /// failures must never be hidden by the compatibility transcoder.
  static bool isMediaCompatibilityInvalidArgument(String message) {
    final lower = message.toLowerCase();
    final invalid = lower.contains('invalid_argument') ||
        lower.contains('invalid argument') ||
        lower.contains('invalid value');
    if (!invalid) return false;
    const nonMedia = <String>[
      'api key', 'api_key', 'credential', 'authentication', 'unauthenticated',
      'permission denied', 'permission_denied', 'unauthorized', 'billing',
      'quota', 'prepayment', 'credits are depleted',
    ];
    if (nonMedia.any(lower.contains)) return false;
    // Match Windows: once this is a real HTTP-400-style INVALID_ARGUMENT and
    // credentials/entitlement causes have been excluded, allow the media
    // compatibility ladder even when Gemini returned only the generic
    // "Request contains an invalid argument" wording.
    return true;
  }

  /// Matroska/WebM sometimes report duration as an absolute end timestamp.
  /// For a large non-zero container start clock, use the local media span.
  static double normalizeSourceDuration({
    required String path,
    required double measuredDurationSec,
    required double formatStartSec,
    double chunkSeconds = 180.0,
  }) {
    if (!measuredDurationSec.isFinite || measuredDurationSec <= 0) {
      return measuredDurationSec;
    }
    final lower = path.toLowerCase();
    final matroska = lower.endsWith('.mkv') || lower.endsWith('.webm');
    if (!matroska ||
        !formatStartSec.isFinite ||
        formatStartSec <= chunkSeconds ||
        measuredDurationSec <= formatStartSec) {
      return measuredDurationSec;
    }
    final local = measuredDurationSec - formatStartSec;
    return local > 0.001 ? local : measuredDurationSec;
  }

  /// Scheduler used by the explicit final overlap fallback. It starts at the
  /// visual timestamp, moves forward only to avoid narration-on-narration,
  /// and rejects a shift beyond the same five-second Windows safety bound.
  static double? dialogueOverlapStart({
    required double visualStartSec,
    required double requiredDurationSec,
    required double mediaDurationSec,
    required double cursorSec,
    double maxShiftSec = maxPlacementShiftSeconds,
  }) {
    if (requiredDurationSec <= 0 ||
        mediaDurationSec <= 0 ||
        requiredDurationSec > mediaDurationSec) {
      return null;
    }
    final visual = visualStartSec.clamp(0.0, mediaDurationSec).toDouble();
    final latest = math.max(0.0, mediaDurationSec - requiredDurationSec);
    final start = math.max(math.min(visual, latest), cursorSec);
    if (start > latest + 1e-9 || (start - visual).abs() > maxShiftSec + 1e-9) {
      return null;
    }
    return start;
  }

  /// Pure counterpart of the Edge trailing-silence cleanup. Returns the
  /// desired trim end or null when the tail must be preserved.
  static double? edgeTrailingTrimEnd({
    required double durationSec,
    required double silenceStartSec,
    required double silenceEndSec,
    double keepSeconds = edgeTrailingKeepSeconds,
    double minRemoveSeconds = edgeTrailingMinRemoveSeconds,
  }) {
    if (durationSec <= 0 || silenceStartSec < 0 || silenceEndSec <= silenceStartSec) {
      return null;
    }
    if ((durationSec - silenceEndSec).abs() > 0.030) return null;
    // A completely silent cue is handled by the empty/silent-output retry; do
    // not turn it into a tiny apparently-valid cue here.
    if (silenceStartSec <= 0.001) return null;
    final trimEnd = math.min(durationSec, silenceStartSec + keepSeconds);
    if (durationSec - trimEnd < minRemoveSeconds) return null;
    return trimEnd;
  }

  static bool extendedAnchorHasFollowingScene({
    required double anchorEndSec,
    required double mediaDurationSec,
    double epsilonSec = 0.500,
  }) => anchorEndSec < mediaDurationSec - epsilonSec;

  static String normalizePronunciationText(String value) =>
      value.replaceAll('_', ' ');

  /// Brief regeneration and the final dialogue-overlap fallback are allowed
  /// only when the previous TTS pass succeeded and every exclusion is purely
  /// a lack-of-safe-space decision. Provider/TTS failures must never be
  /// disguised as a request to regenerate or narrate over dialogue.
  static bool shouldEscalateNoSafeSpace(Iterable<String?> reasons) {
    final list = reasons.toList(growable: false);
    return list.isNotEmpty &&
        list.every((reason) => reason == 'no_safe_space_after_exact_tts');
  }

  static AdFailureKind classifyHttp({
    required int statusCode,
    String body = '',
  }) {
    final text = body.toLowerCase();
    if (text.contains('prepayment credits are depleted')) {
      return AdFailureKind.prepaidCreditsDepleted;
    }
    if (text.contains('file_verification_failed')) {
      return AdFailureKind.fileVerificationFailed;
    }
    if (statusCode == 400) {
      return AdFailureKind.invalidArgument;
    }
    if (statusCode == 403) {
      return AdFailureKind.permissionDenied;
    }
    if (statusCode == 429 &&
        (text.contains('quota') ||
            text.contains('rate limit') ||
            text.contains('resource_exhausted') ||
            text.contains('resource exhausted'))) {
      return AdFailureKind.quotaExhausted;
    }
    if (statusCode == 503 &&
        (text.contains('high demand') || text.contains('spikes in demand')) &&
        (text.contains('unavailable') || text.contains('service unavailable'))) {
      return AdFailureKind.highDemand;
    }
    if (statusCode >= 500 && statusCode <= 599) {
      return AdFailureKind.transient;
    }
    if (statusCode == 429) {
      return AdFailureKind.transient;
    }
    if (statusCode >= 400 && statusCode <= 499) {
      return AdFailureKind.permanentClient;
    }
    return AdFailureKind.none;
  }

  static bool isRetryableExceptionText(String message) {
    final text = message.toLowerCase();
    if (text.contains('400') &&
        (text.contains('invalid_argument') ||
            text.contains('invalid argument') ||
            text.contains('invalid value') ||
            text.contains('unknown name') ||
            text.contains('cannot find field'))) {
      return false;
    }
    if (text.contains('prepayment credits are depleted')) return false;
    if (RegExp(r'(?:^|\D)5\d{2}(?:\D|$)').hasMatch(text)) return true;
    const tokens = <String>[
      '429',
      'resource exhausted',
      'rate limit',
      'quota',
      '503',
      'service unavailable',
      'overloaded',
      'unavailable',
      '504',
      'deadline exceeded',
      'deadline_exceeded',
      'timed out',
      'timeout',
      'time out',
      'connection reset',
      'connection aborted',
      'connection refused',
      'connection error',
      'connect error',
      'broken pipe',
      'network is unreachable',
      'temporary failure',
      'temporarily unavailable',
      'remote end closed',
      'server disconnected',
      'failed to establish',
      'failed to connect',
      'name resolution',
      'getaddrinfo',
      'nodename nor servname',
    ];
    return tokens.any(text.contains);
  }

  static bool isProhibitedContent(Object? decoded) {
    final reason = _findStringByKey(decoded, const <String>{
      'blockReason',
      'block_reason',
    });
    if (reason == null || !reason.toUpperCase().contains('PROHIBITED_CONTENT')) {
      return false;
    }
    return !hasCandidateText(decoded);
  }

  static bool isMalformedResponse(Object? decoded) {
    final finish = _findStringByKey(decoded, const <String>{
      'finishReason',
      'finish_reason',
    });
    if (finish == null || !finish.toUpperCase().contains('MALFORMED_RESPONSE')) {
      return false;
    }
    return !hasCandidateText(decoded);
  }

  static bool hasCandidateText(Object? decoded) {
    if (decoded is Map) {
      final candidates = decoded['candidates'];
      if (candidates is List) {
        for (final candidate in candidates) {
          if (candidate is! Map) continue;
          final content = candidate['content'];
          if (content is! Map) continue;
          final parts = content['parts'];
          if (parts is! List) continue;
          for (final part in parts) {
            if (part is Map && '${part['text'] ?? ''}'.trim().isNotEmpty) {
              return true;
            }
          }
        }
      }
      for (final value in decoded.values) {
        if (hasCandidateText(value)) return true;
      }
    } else if (decoded is List) {
      for (final value in decoded) {
        if (hasCandidateText(value)) return true;
      }
    }
    return false;
  }

  static String? _findStringByKey(Object? value, Set<String> keys) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (keys.contains('${entry.key}') && entry.value != null) {
          final text = '${entry.value}'.trim();
          if (text.isNotEmpty) return text;
        }
      }
      for (final child in value.values) {
        final found = _findStringByKey(child, keys);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findStringByKey(child, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  static List<AdTimeRange> blockedMinuteRanges(double start, double end) {
    final result = <AdTimeRange>[];
    var cursor = start;
    while (cursor < end) {
      final next = math.min(cursor + blockedMinuteSeconds, end);
      if (next - cursor < blockedMinuteMinTailSeconds) break;
      result.add(AdTimeRange(cursor, next));
      cursor = next;
    }
    return result;
  }

  static List<AdFallbackSlot> splitSafeInterval({
    required double start,
    required double end,
    required int baseIndex,
    String suffix = '',
  }) {
    final duration = end - start;
    if (duration < minSafeSlotSeconds) return const <AdFallbackSlot>[];
    if (duration < minMandatorySlotSeconds) {
      return <AdFallbackSlot>[
        AdFallbackSlot(
          id: 'E${baseIndex.toString().padLeft(4, '0')}$suffix',
          start: start,
          end: end,
          mandatory: false,
          partitionIndex: 1,
          partitionCount: 1,
        ),
      ];
    }
    final parts = math.max(1, (duration / maxMandatorySlotSeconds).ceil());
    final partDuration = duration / parts;
    return List<AdFallbackSlot>.generate(parts, (index) {
      final partStart = start + partDuration * index;
      final partEnd = index == parts - 1 ? end : start + partDuration * (index + 1);
      final marker = parts > 1 ? 'P${(index + 1).toString().padLeft(3, '0')}' : '';
      return AdFallbackSlot(
        id: 'S${baseIndex.toString().padLeft(4, '0')}$marker$suffix',
        start: partStart,
        end: partEnd,
        mandatory: true,
        partitionIndex: index + 1,
        partitionCount: parts,
      );
    });
  }

  static List<AdFallbackSlot> slotsForMinute(
    List<AdFallbackSlot> slots,
    AdTimeRange minute,
  ) {
    final result = <AdFallbackSlot>[];
    for (final slot in slots) {
      final midpoint = (slot.start + slot.end) / 2.0;
      if (midpoint < minute.start || midpoint >= minute.end) continue;
      final start = math.max(slot.start, minute.start);
      final end = math.min(slot.end, minute.end);
      if (end <= start) continue;
      result.add(slot.copyWith(
        start: start - minute.start,
        end: end - minute.start,
      ));
    }
    return result;
  }

  static List<AdFallbackSlot> uncoveredMandatorySlots(
    List<AdFallbackSlot> slots,
    Iterable<AdTimeRange> descriptions,
  ) {
    final ranges = descriptions.toList(growable: false);
    return slots.where((slot) {
      if (!slot.mandatory) return false;
      return !ranges.any((range) {
        final midpoint = (range.start + range.end) / 2.0;
        return midpoint >= slot.start && midpoint <= slot.end;
      });
    }).toList();
  }

  static List<AdTimeRange> findLargeCoverageGaps({
    required double chunkStart,
    required double chunkEnd,
    required Iterable<AdTimeRange> descriptions,
    double minimumGapSeconds = largeCoverageGapSeconds,
  }) {
    final sorted = descriptions
        .where((item) => item.end > chunkStart && item.start < chunkEnd)
        .map((item) => AdTimeRange(
              math.max(chunkStart, item.start),
              math.min(chunkEnd, item.end),
            ))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final gaps = <AdTimeRange>[];
    var cursor = chunkStart;
    for (final range in sorted) {
      if (range.start - cursor >= minimumGapSeconds) {
        gaps.add(AdTimeRange(cursor, range.start));
      }
      cursor = math.max(cursor, range.end);
    }
    if (chunkEnd - cursor >= minimumGapSeconds) {
      gaps.add(AdTimeRange(cursor, chunkEnd));
    }
    return gaps;
  }

  static double? parseTimeSeconds(Object? value) {
    if (value is num) {
      final result = value.toDouble();
      return result.isFinite && result >= 0 ? result : null;
    }
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) return null;
    final direct = double.tryParse(raw.replaceAll(',', '.'));
    if (direct != null && direct.isFinite && direct >= 0) return direct;

    final text = raw.replaceAll(',', '.');
    final parts = text.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final seconds = double.tryParse(parts[1]);
      if (minutes == null || seconds == null || seconds < 0 || seconds >= 60) {
        return null;
      }
      return minutes * 60.0 + seconds;
    }
    if (parts.length == 3) {
      final first = int.tryParse(parts[0]);
      final second = int.tryParse(parts[1]);
      if (first == null || second == null || second < 0 || second >= 60) {
        return null;
      }
      final third = parts[2];
      // Windows observed Gemini using MM:SS:ms. Exactly three final digits
      // are mechanically unambiguous and therefore normalized globally.
      if (RegExp(r'^\d{3}$').hasMatch(third)) {
        final millis = int.tryParse(third);
        if (millis == null) return null;
        return first * 60.0 + second + millis / 1000.0;
      }
      // Otherwise preserve standard HH:MM:SS[.ms]. A one/two-digit third
      // group remains an hour timestamp globally; local recovery may
      // reinterpret it only when its chunk window makes that safe.
      final seconds = double.tryParse(third);
      if (seconds == null || seconds < 0 || seconds >= 60) return null;
      return first * 3600.0 + second * 60.0 + seconds;
    }
    if (parts.length == 4) {
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      final seconds = int.tryParse(parts[2]);
      final millisText = parts[3];
      if (hours == null || minutes == null || seconds == null ||
          minutes < 0 || minutes >= 60 || seconds < 0 || seconds >= 60 ||
          !RegExp(r'^\d{3}$').hasMatch(millisText)) {
        return null;
      }
      final millis = int.tryParse(millisText)!;
      return hours * 3600.0 + minutes * 60.0 + seconds + millis / 1000.0;
    }
    return null;
  }

  /// Windows-compatible contextual repair for Gemini's ambiguous
  /// `MM:SS:fraction` typo. The ordinary parser wins whenever its result is
  /// already inside [windowStart, windowEnd]. Only an out-of-window standard
  /// interpretation may be reinterpreted, and only when the repaired value is
  /// inside the authoritative local window.
  static double? parseTimeSecondsInWindow(
    Object? value, {
    required double windowStart,
    required double windowEnd,
    double toleranceSeconds = 2.0,
  }) {
    final parsed = parseTimeSeconds(value);
    if (parsed == null) return null;
    if (parsed >= windowStart - toleranceSeconds &&
        parsed <= windowEnd + toleranceSeconds) {
      return parsed;
    }
    final raw = '${value ?? ''}'.trim();
    final match = RegExp(r'^(\d+):([0-5]\d):(\d{1,2})$').firstMatch(raw);
    if (match == null) return parsed;
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final fractionText = match.group(3)!;
    final repaired = minutes * 60.0 +
        seconds +
        int.parse(fractionText) / math.pow(10, fractionText.length).toDouble();
    if (repaired < windowStart - toleranceSeconds ||
        repaired > windowEnd + toleranceSeconds) {
      return parsed;
    }
    return repaired;
  }

  static AdNormalizedTimes? normalizeTimes({
    required Object? startValue,
    required Object? endValue,
    Object? evidenceValue,
    required double chunkStart,
    required double chunkEnd,
    required AdFallbackSlot slot,
    double boundaryToleranceSeconds = 2.0,
  }) {
    final chunkDuration = chunkEnd - chunkStart;

    double? normalizeOne(Object? value, double fallback) {
      final ordinary = parseTimeSeconds(value);
      if (ordinary == null) return fallback;
      // A genuine absolute timestamp inside this original-movie chunk always
      // wins. This protects valid HH:MM:SS on long films.
      if (ordinary >= chunkStart - boundaryToleranceSeconds &&
          ordinary <= chunkEnd + boundaryToleranceSeconds) {
        return ordinary;
      }
      // For extracted/recovery clips, allow a local timeline. This call also
      // performs the Windows-only contextual MM:SS:fraction repair.
      final local = parseTimeSecondsInWindow(
        value,
        windowStart: 0.0,
        windowEnd: chunkDuration,
        toleranceSeconds: boundaryToleranceSeconds,
      );
      if (local != null &&
          local >= -boundaryToleranceSeconds &&
          local <= chunkDuration + boundaryToleranceSeconds) {
        return local + chunkStart;
      }
      return ordinary;
    }

    var start = normalizeOne(startValue, slot.start) ?? slot.start;
    var end = normalizeOne(endValue, slot.end) ?? slot.end;
    var evidence = normalizeOne(evidenceValue, (start + end) / 2.0) ??
        ((start + end) / 2.0);

    if (start < chunkStart - boundaryToleranceSeconds ||
        end > chunkEnd + boundaryToleranceSeconds ||
        end <= start) {
      return null;
    }
    start = start.clamp(chunkStart, chunkEnd).toDouble();
    end = end.clamp(chunkStart, chunkEnd).toDouble();
    start = math.max(start, slot.start);
    end = math.min(end, slot.end);
    if (end <= start) return null;
    evidence = evidence.clamp(start, end).toDouble();
    return AdNormalizedTimes(start: start, end: end, evidence: evidence);
  }

  /// Minute fallback timestamp normalizer. Gemini can report timestamps on
  /// the extracted minute timeline, on the prepared parent-chunk timeline, or
  /// already on the full movie timeline. Resolve those origins without ever
  /// adding the same offset twice.
  static AdNormalizedTimes? normalizeBlockedMinuteTimes({
    required Object? startValue,
    required Object? endValue,
    Object? evidenceValue,
    required double minuteStart,
    required double minuteEnd,
    required double parentChunkStart,
    required AdFallbackSlot slot,
    double toleranceSeconds = 2.0,
  }) {
    final minuteDuration = minuteEnd - minuteStart;
    final parentLocalStart = minuteStart - parentChunkStart;
    final parentLocalEnd = minuteEnd - parentChunkStart;

    double? parseForWindow(Object? value, double start, double end) =>
        parseTimeSecondsInWindow(
          value,
          windowStart: start,
          windowEnd: end,
          toleranceSeconds: toleranceSeconds,
        );

    final rawStart = parseTimeSeconds(startValue);
    final rawEnd = parseTimeSeconds(endValue);
    if (rawStart == null || rawEnd == null) return null;

    bool fits(double a, double b, double lo, double hi) =>
        a >= lo - toleranceSeconds &&
        b <= hi + toleranceSeconds &&
        b > a;

    late final String mode;
    late final double offset;
    // Full-video timestamps have highest authority.
    if (fits(rawStart, rawEnd, minuteStart, minuteEnd)) {
      mode = 'absolute';
      offset = 0.0;
    } else {
      final parentStart = parseForWindow(startValue, parentLocalStart, parentLocalEnd);
      final parentEnd = parseForWindow(endValue, parentLocalStart, parentLocalEnd);
      if (parentStart != null &&
          parentEnd != null &&
          fits(parentStart, parentEnd, parentLocalStart, parentLocalEnd)) {
        mode = 'parent';
        offset = parentChunkStart;
      } else {
        final localStart = parseForWindow(startValue, 0.0, minuteDuration);
        final localEnd = parseForWindow(endValue, 0.0, minuteDuration);
        if (localStart == null ||
            localEnd == null ||
            !fits(localStart, localEnd, 0.0, minuteDuration)) {
          return null;
        }
        mode = 'minute';
        offset = minuteStart;
      }
    }

    double convert(Object? value, double fallback) {
      final parsed = switch (mode) {
        'absolute' => parseForWindow(value, minuteStart, minuteEnd),
        'parent' => parseForWindow(value, parentLocalStart, parentLocalEnd),
        _ => parseForWindow(value, 0.0, minuteDuration),
      };
      return (parsed ?? fallback) + offset;
    }

    var start = convert(startValue, slot.start - offset);
    var end = convert(endValue, slot.end - offset);
    var evidence = evidenceValue == null
        ? (start + end) / 2.0
        : convert(evidenceValue, ((start + end) / 2.0) - offset);
    if (!fits(start, end, minuteStart, minuteEnd)) return null;
    start = math.max(start, slot.start).clamp(minuteStart, minuteEnd).toDouble();
    end = math.min(end, slot.end).clamp(minuteStart, minuteEnd).toDouble();
    if (end <= start) return null;
    evidence = evidence.clamp(start, end).toDouble();
    return AdNormalizedTimes(start: start, end: end, evidence: evidence);
  }

  static AdFallbackSlot? chooseNearbySlot({
    required List<AdFallbackSlot> slots,
    required Set<String> occupied,
    required String preferredSlotId,
    required double visualTime,
    required double requiredDuration,
    double maxShiftSeconds = maxPlacementShiftSeconds,
  }) {
    final candidates = <({double distance, int preferred, AdFallbackSlot slot})>[];
    for (final slot in slots) {
      if (occupied.contains(slot.id)) continue;
      if (slot.end - slot.start + 1e-6 < requiredDuration) continue;
      final latestStart = slot.end - requiredDuration;
      final proposed = visualTime.clamp(slot.start, latestStart).toDouble();
      final distance = (proposed - visualTime).abs();
      if (distance > maxShiftSeconds) continue;
      candidates.add((
        distance: distance,
        preferred: slot.id == preferredSlotId ? 0 : 1,
        slot: slot,
      ));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final preferred = a.preferred.compareTo(b.preferred);
      if (preferred != 0) return preferred;
      return a.distance.compareTo(b.distance);
    });
    return candidates.first.slot;
  }

  static String stripJsonFences(String value) {
    var text = value.trim();
    text = text.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'\s*```$'), '');
    return text.trim();
  }

  static String? extractJsonObject(String value) {
    final text = stripJsonFences(value);
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  static AdJsonRecoveryResult parseOrSalvageUnifiedJson(String raw) {
    final clean = stripJsonFences(raw);
    final candidates = <String>[clean];
    final extracted = extractJsonObject(clean);
    if (extracted != null && extracted != clean) candidates.add(extracted);
    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map) {
          return AdJsonRecoveryResult(
            data: Map<String, Object?>.from(decoded),
            parseOk: true,
            salvaged: false,
          );
        }
      } catch (_) {}
    }

    final descriptions = _salvageObjectsFromArray(clean, 'audio_descriptions');
    final glossary = _salvageObjectsFromArray(clean, 'character_glossary');
    if (descriptions.isEmpty && glossary.isEmpty) {
      return const AdJsonRecoveryResult(data: null, parseOk: false, salvaged: false);
    }
    return AdJsonRecoveryResult(
      data: <String, Object?>{
        'character_glossary': glossary,
        'audio_descriptions': descriptions,
      },
      parseOk: false,
      salvaged: true,
    );
  }

  static List<Map<String, Object?>> _salvageObjectsFromArray(
    String text,
    String key,
  ) {
    final keyIndex = text.indexOf('"$key"');
    if (keyIndex < 0) return const <Map<String, Object?>>[];
    final arrayStart = text.indexOf('[', keyIndex);
    if (arrayStart < 0) return const <Map<String, Object?>>[];
    final result = <Map<String, Object?>>[];
    var depth = 0;
    var objectStart = -1;
    var inString = false;
    var escaped = false;
    for (var i = arrayStart + 1; i < text.length; i++) {
      final char = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
        continue;
      }
      if (char == '{') {
        if (depth == 0) objectStart = i;
        depth++;
      } else if (char == '}') {
        if (depth > 0) depth--;
        if (depth == 0 && objectStart >= 0) {
          final fragment = text.substring(objectStart, i + 1);
          try {
            final decoded = jsonDecode(fragment);
            if (decoded is Map) {
              result.add(Map<String, Object?>.from(decoded));
            }
          } catch (_) {}
          objectStart = -1;
        }
      } else if (char == ']' && depth == 0) {
        break;
      }
    }
    return result;
  }

  static String normalizeLanguageCode(String code) {
    var value = code.trim().toLowerCase().replaceAll('_', '-');
    value = value.split('-').first;
    return switch (value) {
      'iw' => 'he',
      'in' => 'id',
      'jw' => 'jv',
      _ => value,
    };
  }

  static bool languagesMatch(String detected, String expected) {
    final a = normalizeLanguageCode(detected);
    final b = normalizeLanguageCode(expected);
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  static AdLanguageDetection? parseGoogleLanguageDetection(Object? payload) {
    if (payload is List) {
      String language = '';
      double? confidence;
      if (payload.length > 5 && payload[5] != null) {
        language = normalizeLanguageCode('${payload[5]}');
      }
      if (payload.length > 4 && payload[4] is List) {
        final metadata = payload[4] as List;
        if (metadata.length > 2 && metadata[2] is List && (metadata[2] as List).isNotEmpty) {
          final value = (metadata[2] as List).first;
          if (value is num) confidence = value.toDouble();
        }
        if (language.isEmpty && metadata.isNotEmpty && metadata[0] is List && (metadata[0] as List).isNotEmpty) {
          language = normalizeLanguageCode('${(metadata[0] as List).first}');
        }
      }
      return language.isEmpty ? null : AdLanguageDetection(language, confidence);
    }
    if (payload is Map) {
      var language = normalizeLanguageCode('${payload['src'] ?? ''}');
      if (language.isEmpty) {
        final ld = payload['ld_result'];
        if (ld is Map && ld['srclangs'] is List && (ld['srclangs'] as List).isNotEmpty) {
          language = normalizeLanguageCode('${(ld['srclangs'] as List).first}');
        }
      }
      double? confidence;
      if (payload['confidence'] is num) confidence = (payload['confidence'] as num).toDouble();
      return language.isEmpty ? null : AdLanguageDetection(language, confidence);
    }
    return null;
  }

  static bool sampleHasEnoughLetters(String text, {int minLetters = 8}) {
    var count = 0;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (_isLikelyLetter(char)) count++;
      if (count >= minLetters) return true;
    }
    return false;
  }

  static List<Map<String, Object?>> mergeCharacterCatalog(
    List<Map<String, Object?>> established,
    List<Map<String, Object?>> incoming, {
    int maxCharacters = 96,
  }) {
    final merged = <Map<String, Object?>>[];

    Map<String, Object?>? normalize(Map<String, Object?> raw) {
      final id = '${raw['id'] ?? ''}'.trim();
      final name = '${raw['name'] ?? ''}'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final description = '${raw['description'] ?? ''}'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (name.isEmpty || description.isEmpty) return null;
      return <String, Object?>{
        'id': id,
        'name': name,
        'description': description,
      };
    }

    for (final raw in established) {
      final candidate = normalize(raw);
      if (candidate == null) continue;
      final index = _findCharacterMatch(merged, candidate);
      if (index >= 0) {
        final current = merged[index];
        merged[index] = <String, Object?>{
          'id': '${current['id'] ?? ''}'.trim().isEmpty &&
                  '${candidate['id'] ?? ''}'.trim().isNotEmpty
              ? '${candidate['id'] ?? ''}'.trim()
              : '${current['id'] ?? ''}'.trim(),
          'name': '${current['name'] ?? ''}'.trim(),
          'description': _mergeDescriptionSentences(
            '${current['description'] ?? ''}',
            '${candidate['description'] ?? ''}',
          ),
        };
      } else if (merged.length < maxCharacters) {
        merged.add(candidate);
      }
    }

    final authoritativeCount = merged.length;
    for (final raw in incoming) {
      final candidate = normalize(raw);
      if (candidate == null) continue;
      final index = _findCharacterMatch(merged, candidate);
      if (index >= 0) {
        final current = merged[index];
        final mayFillId = index >= authoritativeCount &&
            '${current['id'] ?? ''}'.trim().isEmpty &&
            '${candidate['id'] ?? ''}'.trim().isNotEmpty;
        merged[index] = <String, Object?>{
          'id': mayFillId
              ? '${candidate['id'] ?? ''}'.trim()
              : '${current['id'] ?? ''}'.trim(),
          'name': '${current['name'] ?? ''}'.trim(),
          'description': _mergeDescriptionSentences(
            '${current['description'] ?? ''}',
            '${candidate['description'] ?? ''}',
          ),
        };
      } else if (merged.length < maxCharacters) {
        merged.add(candidate);
      }
    }
    return merged.take(maxCharacters).toList(growable: false);
  }

  static int _findCharacterMatch(
    List<Map<String, Object?>> established,
    Map<String, Object?> incoming,
  ) {
    final incomingId = '${incoming['id'] ?? ''}'.trim();
    final incomingName = '${incoming['name'] ?? ''}'.trim();
    if (incomingId.isNotEmpty) {
      final matches = <int>[];
      for (var i = 0; i < established.length; i++) {
        if ('${established[i]['id'] ?? ''}'.trim().toLowerCase() ==
            incomingId.toLowerCase()) {
          matches.add(i);
        }
      }
      if (matches.length == 1) return matches.single;
    }

    if (incomingName.isNotEmpty) {
      final matches = <int>[];
      for (var i = 0; i < established.length; i++) {
        if ('${established[i]['name'] ?? ''}'.trim().toLowerCase() ==
            incomingName.toLowerCase()) {
          matches.add(i);
        }
      }
      if (matches.length == 1) return matches.single;
    }

    final candidateId = incomingId.toLowerCase();
    final tokens = _catalogNameTokens(incomingName);
    if (candidateId.isEmpty || tokens.length != 1 || tokens.single.length < 3) {
      return -1;
    }
    final token = tokens.single;
    final prefix = '${candidateId}_';
    final aliasMatches = <int>[];
    for (var i = 0; i < established.length; i++) {
      final id = '${established[i]['id'] ?? ''}'.trim().toLowerCase();
      final nameTokens = _catalogNameTokens('${established[i]['name'] ?? ''}');
      if (id.startsWith(prefix) && nameTokens.contains(token)) {
        aliasMatches.add(i);
      }
    }
    return aliasMatches.length == 1 ? aliasMatches.single : -1;
  }

  static bool _isLikelyLetter(String char) {
    if (char.isEmpty) return false;
    final code = char.runes.first;
    if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
      return true;
    }
    // Latin extended, Greek, Cyrillic, Hebrew, Arabic, Devanagari, CJK, Hangul.
    return (code >= 0x00C0 && code <= 0x02AF) ||
        (code >= 0x0370 && code <= 0x052F) ||
        (code >= 0x0590 && code <= 0x08FF) ||
        (code >= 0x0900 && code <= 0x097F) ||
        (code >= 0x3040 && code <= 0x30FF) ||
        (code >= 0x3400 && code <= 0x9FFF) ||
        (code >= 0xAC00 && code <= 0xD7AF);
  }

  static bool _isLikelyLetterOrDigit(String char) {
    if (_isLikelyLetter(char)) return true;
    if (char.isEmpty) return false;
    final code = char.runes.first;
    return code >= 48 && code <= 57;
  }

  static List<String> _catalogNameTokens(String value) {
    return value
        .split(RegExp(r'\s+'))
        .map((token) {
          final out = StringBuffer();
          for (final rune in token.runes) {
            final char = String.fromCharCode(rune);
            if (_isLikelyLetterOrDigit(char)) out.write(char.toLowerCase());
          }
          return out.toString();
        })
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _descriptionTokens(String value) {
    final seen = <String>{};
    final result = <String>[];
    final current = StringBuffer();

    void flush() {
      final token = current.toString().toLowerCase();
      current.clear();
      if (token.isEmpty || !seen.add(token)) return;
      result.add(token);
    }

    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      if (_isLikelyLetterOrDigit(char)) {
        current.write(char);
      } else {
        flush();
      }
    }
    flush();
    return result;
  }

  static double _descriptionCoverage(String candidate, String established) {
    final candidateTokens = _descriptionTokens(candidate);
    if (candidateTokens.isEmpty) return 1.0;
    final establishedTokens = _descriptionTokens(established).toSet();
    if (establishedTokens.isEmpty) return 0.0;
    final shared =
        candidateTokens.where(establishedTokens.contains).length;
    return shared / candidateTokens.length;
  }

  static String _mergeDescriptionSentences(String oldValue, String newValue) {
    var merged = _cleanDescription(oldValue);
    final observed = _cleanDescription(newValue);
    if (merged.isEmpty) return observed;
    if (observed.isEmpty) return merged;

    for (final rawSentence in _sentences(observed)) {
      final sentence = _collapseRepeatedWordSequence(rawSentence);
      if (_descriptionTokens(sentence).length <= 2) continue;
      // Windows parity: the established catalog is authoritative. If most of
      // an observed sentence is already represented, treat it as a
      // paraphrase/corruption rather than new character information.
      if (_descriptionCoverage(sentence, merged) >= 0.65) continue;
      final separator = RegExp(r'[.!?]$').hasMatch(merged) ? ' ' : '. ';
      final candidate = '$merged$separator${sentence.trim()}';
      if (candidate.runes.length > 2000) break;
      merged = candidate;
    }
    return merged;
  }

  static String _collapseRepeatedWordSequence(String value) {
    final cleaned = _cleanDescription(value);
    if (cleaned.isEmpty) return cleaned;
    final words = cleaned.split(' ');
    if (words.length < 8) return cleaned;

    String normalizeWord(String word) {
      final out = StringBuffer();
      for (final rune in word.runes) {
        final char = String.fromCharCode(rune);
        if (_isLikelyLetterOrDigit(char)) out.write(char.toLowerCase());
      }
      return out.toString();
    }

    final normalized = words.map(normalizeWord).toList(growable: false);
    // Gemini occasionally repeats the same visual fact twice back-to-back
    // without punctuation. Collapse exact repeated halves before the
    // authoritative catalog merge so a corrupted duplicate cannot become
    // persistent biography text.
    for (var block = words.length ~/ 2; block >= 4; block--) {
      if (words.length % block != 0) continue;
      final repeats = words.length ~/ block;
      if (repeats < 2) continue;
      var same = true;
      for (var repeat = 1; repeat < repeats && same; repeat++) {
        for (var i = 0; i < block; i++) {
          if (normalized[i] != normalized[(repeat * block) + i]) {
            same = false;
            break;
          }
        }
      }
      if (same) return words.take(block).join(' ').trim();
    }
    return cleaned;
  }

  static String _cleanDescription(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<String> _sentences(String value) {
    final matches = RegExp(r'[^.!?]+[.!?]?', unicode: true).allMatches(value);
    return matches
        .map((m) => m.group(0)!.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList(growable: false);
  }

  static bool ttsLogHasAudibleSignal(String logs) {
    final lower = logs.toLowerCase();
    if (lower.contains('max_volume: -inf')) return false;
    final match = RegExp(r'max_volume:\s*(-?\d+(?:\.\d+)?)\s*dB', caseSensitive: false)
        .firstMatch(logs);
    if (match == null) return true;
    final db = double.tryParse(match.group(1) ?? '');
    if (db == null) return true;
    return db > -70.0;
  }

  static int maxAttemptsForFailure(AdFailureKind failure) {
    return switch (failure) {
      AdFailureKind.malformedResponse => malformedResponseMaxAttempts,
      AdFailureKind.prohibitedContent => prohibitedContentMaxAttempts,
      AdFailureKind.fileVerificationFailed => sonarpadVerificationMaxAttempts,
      _ => 0,
    };
  }

  static int maxFileProcessingReuploads({String? providerCode}) {
    final code = (providerCode ?? '').trim().toLowerCase();
    return code == '13' || code.contains('code 13')
        ? code13FileProcessingReuploads
        : genericFileProcessingReuploads;
  }

  static bool shouldPromptAfterHighDemand(int consecutiveFailures) =>
      consecutiveFailures >= overloadPromptAfterConsecutiveErrors;

  static bool shouldAttemptJsonRepair({
    required bool parseOk,
    required bool salvaged,
    required int parsedDescriptionCount,
    required String rawText,
    String finishReason = '',
  }) {
    if (finishReason.toUpperCase().contains('MAX_TOKENS')) return true;
    if (!parseOk) return true;
    if (salvaged) return true;
    if (rawText.trim().isNotEmpty && parsedDescriptionCount == 0) return true;
    return false;
  }

  static String brokenJsonForRepair(String raw, {int maxChars = 40000}) {
    final value = stripJsonFences(raw);
    if (value.length <= maxChars) return value;
    return value.substring(0, maxChars);
  }

  static bool shouldUseInlineVideo(int bytes) => bytes <= inlineVideoMaxBytes;

  static bool canFallbackToInlineVideo(int bytes) => bytes <= inlineFallbackMaxBytes;

  static bool isPermanentTtsError(String message) {
    final text = message.toLowerCase();
    const permanent = <String>[
      'voice not found',
      'voice is not installed',
      'language is not available',
      'unsupported voice',
      'invalid voice',
      'not supported on this device',
    ];
    return permanent.any(text.contains);
  }

  static bool checkpointCompatible({
    required double savedDurationSec,
    required double currentDurationSec,
    required int savedChunkCount,
    required int currentChunkCount,
    double durationToleranceSec = 1.0,
  }) {
    return (savedDurationSec - currentDurationSec).abs() <= durationToleranceSec &&
        savedChunkCount == currentChunkCount;
  }

  static bool descriptionBelongsToRanges(
    AdTimeRange description,
    Iterable<AdTimeRange> ranges,
  ) {
    final midpoint = (description.start + description.end) / 2.0;
    return ranges.any((range) => midpoint >= range.start && midpoint <= range.end);
  }

  static String mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    return 'video/mp4';
  }

  static AdMediaFallbackStage nextMediaStage({
    required AdMediaFallbackStage current,
    required AdFailureKind failure,
  }) {
    final mediaFailure = failure == AdFailureKind.invalidArgument ||
        failure == AdFailureKind.fileProcessingFailed ||
        failure == AdFailureKind.fileVerificationFailed;
    if (!mediaFailure) return AdMediaFallbackStage.none;
    return switch (current) {
      AdMediaFallbackStage.normal => AdMediaFallbackStage.compact,
      AdMediaFallbackStage.compact => AdMediaFallbackStage.compatibility,
      AdMediaFallbackStage.compatibility || AdMediaFallbackStage.none =>
        AdMediaFallbackStage.none,
    };
  }
}

enum AdFailureKind {
  none,
  transient,
  invalidArgument,
  permissionDenied,
  quotaExhausted,
  highDemand,
  prepaidCreditsDepleted,
  fileVerificationFailed,
  fileProcessingFailed,
  permanentClient,
  prohibitedContent,
  malformedResponse,
}

enum AdMediaFallbackStage { normal, compact, compatibility, none }

class AdTimeRange {
  const AdTimeRange(this.start, this.end);
  final double start;
  final double end;
  double get duration => end - start;
}

class AdFallbackSlot extends AdTimeRange {
  const AdFallbackSlot({
    required this.id,
    required double start,
    required double end,
    required this.mandatory,
    required this.partitionIndex,
    required this.partitionCount,
  }) : super(start, end);
  final String id;
  final bool mandatory;
  final int partitionIndex;
  final int partitionCount;

  int get maxWords => math.max(1, (duration * 2.0).floor());

  AdFallbackSlot copyWith({double? start, double? end}) => AdFallbackSlot(
        id: id,
        start: start ?? this.start,
        end: end ?? this.end,
        mandatory: mandatory,
        partitionIndex: partitionIndex,
        partitionCount: partitionCount,
      );
}

class AdNormalizedTimes {
  const AdNormalizedTimes({
    required this.start,
    required this.end,
    required this.evidence,
  });
  final double start;
  final double end;
  final double evidence;
}

class AdJsonRecoveryResult {
  const AdJsonRecoveryResult({
    required this.data,
    required this.parseOk,
    required this.salvaged,
  });
  final Map<String, Object?>? data;
  final bool parseOk;
  final bool salvaged;
}

class AdLanguageDetection {
  const AdLanguageDetection(this.language, this.confidence);
  final String language;
  final double? confidence;
}
