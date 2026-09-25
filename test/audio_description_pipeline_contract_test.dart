import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File('lib/services/ai_audiodescription_service.dart')
      .readAsStringSync();
  final fallbacks = File('lib/services/audio_description_fallbacks.dart')
      .readAsStringSync();
  final screen = File('lib/screens/create_ai_audiodescription_screen.dart')
      .readAsStringSync();
  final pyannote = File('lib/services/pyannote_mobile_service.dart')
      .readAsStringSync();

  group('production pipeline is wired to Windows-derived fallbacks', () {
    test('shared fallback layer is imported by production service', () {
      expect(service, contains("import 'audio_description_fallbacks.dart';"));
    });
    test('HTTP failures use shared classifier', () {
      expect(service, contains('AudioDescriptionFallbacks.classifyHttp'));
    });
    test('temporary HTTP/network errors retry through cancelable loop', () {
      expect(service, contains('_cancelableDelay'));
      expect(service, contains('AdFailureKind.transient'));
    });
    test('Sonarpad file verification is bounded', () {
      expect(service, contains('boundFileVerificationFailures: true'));
      expect(service, contains('sonarpadVerificationMaxAttempts'));
    });
    test('high demand is surfaced to accessible UI after retry threshold', () {
      expect(service, contains('shouldPromptAfterHighDemand'));
      expect(screen, contains('onHighDemand: _askHighDemandFallback'));
    });
    test('personal Gemini quota can switch model and persists new model', () {
      expect(service, contains('AiAudioDescriptionQuotaAction.switchModel'));
      expect(service, contains('saveGeminiModel'));
      expect(screen, contains('onQuota:'));
    });
    test('prepaid credit depletion is classified before generic quota', () {
      expect(fallbacks, contains("prepayment credits are depleted"));
    });
    test('PROHIBITED_CONTENT has bounded same-request retry', () {
      expect(service, contains('prohibitedAttempts'));
      expect(service, contains('AdFailureKind.prohibitedContent'));
    });
    test('blocked chunks activate 60-second fallback', () {
      expect(service, contains('_blockedChunkMinuteFallback'));
      expect(service, contains('blockedMinuteRanges'));
    });
    test('blocked-minute parser accepts minute, parent-chunk and full-video timelines', () {
      expect(service, contains('blockedParentChunkStart: chunkStart'));
      expect(service, contains('normalizeBlockedMinuteTimes'));
    });
    test('blocked minute that remains prohibited is skipped only locally', () {
      expect(service, contains('still prohibited; preserving original audio'));
    });
    test('MALFORMED_RESPONSE has independent bounded retry', () {
      expect(service, contains('malformedCount'));
      expect(service, contains('malformedResponseMaxAttempts'));
    });
    test('small personal Gemini clips prefer inline', () {
      expect(service, contains('shouldUseInlineVideo'));
      expect(service, contains("'inlineData'"));
    });
    test('inline failure can fall back to Files API', () {
      expect(service, contains('falling back to Files API'));
    });
    test('Files processing can fall back to inline', () {
      expect(service, contains('Files API processing failed'));
    });
    test('Files permission denial can fall back to inline', () {
      expect(service, contains('Files API generation permission denied'));
    });
    test('Gemini processing failures are reuploaded with code-13 budget', () {
      expect(service, contains('_uploadGeminiFileWithProcessingFallback'));
      expect(service, contains('maxFileProcessingReuploads'));
    });
    test('media compatibility sequence is normal compact compatibility', () {
      expect(service, contains('AdMediaFallbackStage.normal'));
      expect(service, contains('AdMediaFallbackStage.compact'));
      expect(service, contains('AdMediaFallbackStage.compatibility'));
      expect(service, contains('nextMediaStage'));
    });
    test('non-media StateError cannot activate media compatibility ladder', () {
      final processStart = service.indexOf('Future<_ChunkProcessResult> _processChunkWithFallbacks');
      final processEnd = service.indexOf('bool _isMediaCompatibilityFailure', processStart);
      final processBody = service.substring(processStart, processEnd);
      expect(processBody, isNot(contains('on StateError catch')));
      expect(service, contains("AdFailureKind.fileProcessingFailed"));
    });
    test('bad audio mux retries prepared video without audio', () {
      expect(service, contains('retrying video-only'));
    });
    test('AVI/MKV timestamp repair intent is present in FFmpeg prep', () {
      expect(service, contains('+genpts+discardcorrupt'));
      expect(service, contains('make_zero'));
    });
    test('JSON parser salvages truncated objects', () {
      expect(service, contains('parseOrSalvageUnifiedJson'));
    });
    test('invalid or MAX_TOKENS JSON gets one repair request', () {
      expect(service, contains('_parseWithOptionalJsonRepair'));
      expect(service, contains('brokenJsonForRepair'));
      expect(fallbacks, contains('jsonRepairMaxAttempts = 1'));
    });
    test('mandatory coverage recovery is capped to three passes', () {
      expect(service, contains('for (var pass = 1; pass <= 3; pass++)'));
    });
    test('large uncovered gaps get a separate best-effort recovery', () {
      expect(service, contains('findLargeCoverageGaps'));
      expect(service, contains('COVERAGE RECOVERY'));
    });
    test('language is checked per generated description', () {
      expect(service, contains('Future<bool> wrongLanguage(String text)'));
      expect(service, contains('_detectLanguage('));
      expect(service, contains('wrongLanguage(item.text)'));
    });
    test('wrong-language glossary descriptions are also corrected', () {
      expect(service, contains('wrongGlossary'));
      expect(service, contains('translate ONLY'));
    });
    test('language correction never changes catalog id/name', () {
      expect(service, contains("updatedGlossary[index]['description'] = description"));
    });
    test('catalog merge uses authoritative continuity helper', () {
      expect(service, contains('mergeCharacterCatalog'));
    });
    test('checkpoint is saved only after completed chunk', () {
      final process = service.indexOf('_processChunkWithFallbacks(');
      final checkpoint = service.indexOf('_saveCheckpoint(', process);
      expect(checkpoint, greaterThan(process));
    });
    test('checkpoint survives failure but is deleted on full success', () {
      expect(service, contains('_loadCheckpoint'));
      expect(service, contains('_deleteCheckpoint(sourcePath)'));
    });
    test('checkpoint layout mismatch uses shared compatibility rule', () {
      expect(service, contains('checkpointCompatible'));
    });
    test('source without audio gets silent canonical analysis track', () {
      expect(service, contains('anullsrc=r=16000:cl=mono'));
    });
    test('exact TTS duration is measured before placement', () {
      final synth = service.indexOf('_synthesizeTtsWithFallback');
      final duration = service.indexOf('_audioDuration(target.path)', synth);
      final choose = service.indexOf('chooseNearbySlot', duration);
      expect(duration, greaterThan(synth));
      expect(choose, greaterThan(duration));
    });
    test('TTS may shift at most five seconds', () {
      expect(fallbacks, contains('maxPlacementShiftSeconds = 5.0'));
      expect(service, contains('chooseNearbySlot'));
    });
    test('mandatory descriptions are scheduled before optional', () {
      expect(service, contains('return a.mandatory ? -1 : 1'));
    });
    test('extended pauses use short speech-free anchors', () {
      expect(service, contains('slot.duration >= 1.0 && slot.duration < 3.0'));
    });
    test('empty or silent TTS output is retried', () {
      expect(service, contains('TTS_EMPTY_OUTPUT'));
      expect(service, contains('TTS_SILENT_OUTPUT'));
      expect(service, contains('volumedetect'));
    });
    test('permanent missing-voice errors are not retried or converted into AI fallback', () {
      expect(service, contains('isPermanentTtsError'));
      expect(service, contains('rethrow;'));
    });
    test('TTS/placement failures cannot masquerade as no-safe-space Brief fallback', () {
      expect(service, contains('shouldEscalateNoSafeSpace'));
      expect(service, contains("AUDIO_DESCRIPTION_TTS_OR_PLACEMENT_FAILED"));
      expect(fallbacks, contains("reason == 'no_safe_space_after_exact_tts'"));
    });
    test('invalid TTS duration is retried inside TTS fallback', () {
      final synth = service.indexOf('Future<void> _synthesizeTtsWithFallback');
      final placement = service.indexOf('Future<List<_Placement>> _synthesizeAndPlace');
      expect(service.substring(synth), contains("TTS_DURATION_INVALID"));
      expect(synth, greaterThan(placement));
    });
    test('dialogue overlap fallback is never automatic', () {
      expect(service, contains('if (inserted.isEmpty && mayOfferOverlap && onOverlapConsent != null)'));
      expect(screen, contains('onOverlapConsent: _askOverlapFallback'));
    });
    test('Brief retry is offered before dialogue overlap', () {
      final brief = service.indexOf('onBriefRetry');
      final overlap = service.indexOf('mayOfferOverlap && onOverlapConsent');
      expect(brief, greaterThanOrEqualTo(0));
      expect(overlap, greaterThan(brief));
      expect(screen, contains('onBriefRetry: _askBriefRetryFallback'));
    });
    test('declining Brief retry cannot silently escalate to overlap', () {
      expect(service, contains('dialogue-overlap fallback will not be offered'));
      expect(service, contains('mayOfferOverlap = false'));
    });
    test('initial Brief mode skips redundant Brief regeneration', () {
      expect(service, contains("settings.verbosity == 'short' && safeSpaceExhausted"));
      expect(service, contains("settings.verbosity != 'short'"));
    });
    test('final overlap scheduler uses visual timing and five-second bound', () {
      expect(service, contains('AudioDescriptionFallbacks.dialogueOverlapStart'));
      expect(service, contains('visualStartSec: item.requestedStart'));
      expect(fallbacks, contains('maxPlacementShiftSeconds = 5.0'));
    });
    test('final overlap bypasses safe-slot scheduler after explicit consent', () {
      final overlapBranch = service.indexOf('if (allowDialogueOverlap) {');
      final safeScheduler = service.indexOf('chooseNearbySlot', overlapBranch);
      expect(overlapBranch, greaterThanOrEqualTo(0));
      expect(safeScheduler, greaterThan(overlapBranch));
      expect(service.substring(overlapBranch, safeScheduler), contains('continue;'));
    });
    test('media INVALID_ARGUMENT excludes credentials and billing failures', () {
      expect(service, contains('isMediaCompatibilityInvalidArgument'));
      expect(fallbacks, contains("'api key'"));
      expect(fallbacks, contains("'billing'"));
      expect(fallbacks, contains("'quota'"));
    });
    test('Matroska and WebM source duration fallback is wired into probe', () {
      expect(service, contains('info.getStartTime()'));
      expect(service, contains('normalizeSourceDuration'));
    });
    test('Gemini model ids are normalized and validated before generation', () {
      expect(service, contains('_validateGeminiModel'));
      expect(service, contains('modelSupportsGenerateContent'));
      expect(fallbacks, contains("'gemini-3.1-pro-preview'"));
    });
    test('quota replacement model is normalized and verified', () {
      expect(service, contains('replacement = AudioDescriptionFallbacks.normalizeGeminiModelId'));
      expect(service, contains('model: replacement'));
    });
    test('Edge trailing silence is trimmed before signal and duration checks', () {
      final trim = service.indexOf('_trimEdgeTrailingSilenceBestEffort(target.path)');
      final signal = service.indexOf('_ttsFileHasAudibleSignal(target.path)', trim);
      expect(trim, greaterThanOrEqualTo(0));
      expect(signal, greaterThan(trim));
      expect(service, contains('silencedetect=noise='));
    });
    test('Edge cleanup is best effort and keeps the original on failure', () {
      expect(service, contains('Edge trailing-silence cleanup skipped'));
    });
    test('extended pause is rejected at the movie tail without following scene', () {
      expect(service, contains('extendedAnchorHasFollowingScene'));
    });
    test('voice dictionary underscores are normalized before TTS', () {
      expect(service, contains('normalizePronunciationText'));
    });
    test('resume choice is accessible from production UI', () {
      expect(screen, contains('onResumeCheckpoint: _askResumeCheckpoint'));
    });
    test('Sonarpad expired session is reactivated only through explicit token fallback', () {
      expect(service, contains('SONARPAD_AI_SESSION_EXPIRED'));
      expect(service, contains('allowSessionReactivation: false'));
      expect(service, contains('clearSonarpadToken'));
    });
    test('Sonarpad uploads are deleted after use', () {
      expect(service, contains(r"Uri.parse('$_sonarpadAiBase/upload/delete')"));
    });
    test('all mobile locales contain every new fallback prompt', () {
      final arbs = Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .toList();
      expect(arbs, isNotEmpty);
      for (final file in arbs) {
        final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final key in <String>[
          'audioDescriptionStageBriefRetry',
          'audioDescriptionBriefRetryTitle',
          'audioDescriptionBriefRetryMessage',
          'audioDescriptionRetryBrief',
        ]) {
          expect(data[key]?.toString().trim(), isNotEmpty, reason: '${file.path}: $key');
        }
      }
    });
    test('pyannote benchmark action is not exposed in Sonarpad audiodescriptions UI', () {
      final page = File('lib/screens/sonarpad_audiodescriptions_screen.dart')
          .readAsStringSync();
      expect(page, isNot(contains('pyannote')));
      expect(page, isNot(contains('benchmark')));
    });
    test('safe final MP3 still uses ducking and 192 kbps', () {
      expect(service, contains("'-b:a', '192k'"));
      expect(service, contains('_duckVolume'));
    });
  });

  group('pyannote production configuration remains exact/safe', () {
    test('production uses 10 second window', () {
      expect(pyannote, contains('windowSec = 10.0'));
    });
    test('production step remains one second, not experimental step two', () {
      expect(pyannote, contains('stepSec = 1.0'));
    });
    test('production batch remains 32', () {
      expect(pyannote, contains('batchSize = 32'));
    });
    test('production padding remains 0.25 second', () {
      expect(pyannote, contains('defaultPaddingSec = 0.25'));
    });

    test('generation keeps the screen awake and restores wakelock state', () {
      expect(service, contains('WakelockPlus.enable()'));
      expect(service, contains('wakelock restored enabled='));
      expect(screen, contains('WidgetsBindingObserver'));
      expect(screen, contains('_ensureGenerationWakelock'));
    });
    test('generation exposes a determinate accessible progress bar', () {
      expect(screen, contains('LinearProgressIndicator('));
      expect(screen, contains('semanticsValue:'));
      expect(screen, contains("id: 'progress'"));
      expect(screen, contains('if (progress.value > _progress)'));
    });
    test('Pyannote heavy PCM preparation stays off the UI isolate', () {
      final reader = File('lib/services/pyannote_pcm_reader.dart').readAsStringSync();
      expect(pyannote, contains('await readPyannotePcmBatch('));
      expect(pyannote, isNot(contains('Isolate.run')));
      expect(reader, contains('Isolate.run('));
      expect(pyannote, contains('session.runAsync('));
    });
  });
}
