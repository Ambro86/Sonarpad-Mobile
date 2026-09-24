import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_plus/onnxruntime_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utils/app_logger.dart';
import 'pyannote_mobile_service.dart';

class PyannoteBenchmarkConfig {
  const PyannoteBenchmarkConfig({
    required this.id,
    required this.provider,
    required this.batchSize,
    required this.intraOpThreads,
    required this.graphOptimization,
    required this.stepSec,
    this.paddingSec = PyannoteMobileService.defaultPaddingSec,
    this.coreMLFlags,
  });

  final String id;
  final String provider;
  final int batchSize;
  final int intraOpThreads;
  final GraphOptimizationLevel graphOptimization;
  final double stepSec;
  final double paddingSec;
  final CoreMLFlags? coreMLFlags;

  bool get usesCoreML => coreMLFlags != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'provider': provider,
    'batch_size': batchSize,
    'intra_op_threads': intraOpThreads,
    'graph_optimization': graphOptimization.name,
    'step_seconds': stepSec,
    'padding_seconds': paddingSec,
    'coreml_flags': coreMLFlags?.name,
  };
}

class PyannoteBenchmarkOutcome {
  const PyannoteBenchmarkOutcome({
    required this.config,
    required this.success,
    required this.sessionCreateMs,
    required this.inferenceMs,
    required this.totalMs,
    this.frameCounts,
    this.frameSha256,
    this.chunkCount,
    this.frameCount,
    this.protectedIntervals,
    this.protectedSeconds,
    this.error,
    this.differingFrames,
    this.firstDifferingFrame,
    this.maxSpeakerCountDelta,
    this.protectedSecondsDelta,
    this.protectedIntervalIoU,
    this.exactFrameMatch,
    this.speedupVsBaseline,
    this.rawIntervals,
    this.lostActiveFrames,
    this.addedActiveFrames,
    this.changedActiveSpeakerCountFrames,
    this.lostActiveSeconds,
    this.addedActiveSeconds,
    this.fullyMissedSpeechIntervals,
    this.fullyMissedSpeechSeconds,
    this.partialMissedSpeechIntervals,
    this.protectedLostSeconds,
    this.protectedAddedSeconds,
    this.maxContiguousLostMs,
    this.boundaryLostFrames250ms,
    this.interiorLostFrames250ms,
    this.boundaryOnlyCandidate,
    this.diffRuns,
  });

  final PyannoteBenchmarkConfig config;
  final bool success;
  final int sessionCreateMs;
  final int inferenceMs;
  final int totalMs;
  final Uint8List? frameCounts;
  final String? frameSha256;
  final int? chunkCount;
  final int? frameCount;
  final List<PyannoteInterval>? protectedIntervals;
  final double? protectedSeconds;
  final String? error;
  final int? differingFrames;
  final int? firstDifferingFrame;
  final int? maxSpeakerCountDelta;
  final double? protectedSecondsDelta;
  final double? protectedIntervalIoU;
  final bool? exactFrameMatch;
  final double? speedupVsBaseline;
  final List<PyannoteInterval>? rawIntervals;
  final int? lostActiveFrames;
  final int? addedActiveFrames;
  final int? changedActiveSpeakerCountFrames;
  final double? lostActiveSeconds;
  final double? addedActiveSeconds;
  final int? fullyMissedSpeechIntervals;
  final double? fullyMissedSpeechSeconds;
  final int? partialMissedSpeechIntervals;
  final double? protectedLostSeconds;
  final double? protectedAddedSeconds;
  final double? maxContiguousLostMs;
  final int? boundaryLostFrames250ms;
  final int? interiorLostFrames250ms;
  final bool? boundaryOnlyCandidate;
  final List<Map<String, Object?>>? diffRuns;

  Map<String, Object?> toJson() => <String, Object?>{
    'config': config.toJson(),
    'success': success,
    'session_create_ms': sessionCreateMs,
    'inference_ms': inferenceMs,
    'total_ms': totalMs,
    'frame_sha256': frameSha256,
    'chunk_count': chunkCount,
    'frame_count': frameCount,
    'protected_seconds': protectedSeconds,
    'error': error,
    'comparison_to_baseline': <String, Object?>{
      'exact_frame_match': exactFrameMatch,
      'differing_frames': differingFrames,
      'first_differing_frame': firstDifferingFrame,
      'first_differing_second': firstDifferingFrame == null
          ? null
          : firstDifferingFrame! * PyannoteMobileService.frameStepSec,
      'max_speaker_count_delta': maxSpeakerCountDelta,
      'protected_seconds_delta': protectedSecondsDelta,
      'protected_interval_time_iou': protectedIntervalIoU,
      'speedup_vs_baseline': speedupVsBaseline,
      'lost_active_frames': lostActiveFrames,
      'added_active_frames': addedActiveFrames,
      'changed_active_speaker_count_frames': changedActiveSpeakerCountFrames,
      'lost_active_seconds': lostActiveSeconds,
      'added_active_seconds': addedActiveSeconds,
      'fully_missed_speech_intervals': fullyMissedSpeechIntervals,
      'fully_missed_speech_seconds': fullyMissedSpeechSeconds,
      'partial_missed_speech_intervals': partialMissedSpeechIntervals,
      'protected_lost_seconds': protectedLostSeconds,
      'protected_added_seconds': protectedAddedSeconds,
      'max_contiguous_lost_ms': maxContiguousLostMs,
      'boundary_lost_frames_250ms': boundaryLostFrames250ms,
      'interior_lost_frames_250ms': interiorLostFrames250ms,
      'boundary_only_candidate': boundaryOnlyCandidate,
      'diff_runs': diffRuns,
    },
  };
}

class PyannoteBenchmarkReport {
  const PyannoteBenchmarkReport({
    required this.canonicalWavPath,
    required this.reportJsonPath,
    required this.outcomes,
  });

  final String canonicalWavPath;
  final String reportJsonPath;
  final List<PyannoteBenchmarkOutcome> outcomes;
}

class PyannoteCandidateValidationReport {
  const PyannoteCandidateValidationReport({
    required this.reportJsonPath,
    required this.clipCount,
    required this.passed,
    required this.speedup,
    required this.protectedLostSeconds,
    required this.fullyMissedSpeechIntervals,
    required this.interiorLostFrames250ms,
  });

  final String reportJsonPath;
  final int clipCount;
  final bool passed;
  final double speedup;
  final double protectedLostSeconds;
  final int fullyMissedSpeechIntervals;
  final int interiorLostFrames250ms;
}

class PyannoteBenchmarkService {
  const PyannoteBenchmarkService();

  static const double benchmarkSeconds = 600.0;
  static const int expectedFramesPerChunk = 589;
  static const List<int> _powersetSpeakerCounts = <int>[0, 1, 1, 1, 2, 2, 2];

  static List<PyannoteBenchmarkConfig> _configs() => <PyannoteBenchmarkConfig>[
    const PyannoteBenchmarkConfig(
      id: 'baseline_cpu_b32_t4_all_step1',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b32_t1_all_step1',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 1,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b32_t2_all_step1',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 2,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b32_t6_all_step1',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 6,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b16_t4_all_step1',
      provider: 'CPUExecutionProvider',
      batchSize: 16,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b64_t4_all_step1',
      provider: 'CPUExecutionProvider',
      batchSize: 64,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b96_t6_all_step1_aggressive',
      provider: 'CPUExecutionProvider',
      batchSize: 96,
      intraOpThreads: 6,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b32_t4_basic_step1',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableBasic,
      stepSec: 1.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b32_t4_extended_step1',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableExtended,
      stepSec: 1.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'coreml_default_b32_t4_all_step1',
      provider: 'CoreMLExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
      coreMLFlags: CoreMLFlags.useNone,
    ),
    const PyannoteBenchmarkConfig(
      id: 'coreml_subgraph_b32_t4_all_step1',
      provider: 'CoreMLExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
      coreMLFlags: CoreMLFlags.enableOnSubgraph,
    ),
    const PyannoteBenchmarkConfig(
      id: 'coreml_ane_b32_t4_all_step1',
      provider: 'CoreMLExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.0,
      coreMLFlags: CoreMLFlags.onlyEnableDeviceWithANE,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b64_t6_all_step1_5_aggressive',
      provider: 'CPUExecutionProvider',
      batchSize: 64,
      intraOpThreads: 6,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.5,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b64_t6_all_step2_aggressive',
      provider: 'CPUExecutionProvider',
      batchSize: 64,
      intraOpThreads: 6,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 2.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'cpu_b64_t6_all_step2_5_aggressive',
      provider: 'CPUExecutionProvider',
      batchSize: 64,
      intraOpThreads: 6,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 2.5,
    ),
    const PyannoteBenchmarkConfig(
      id: 'precision_cpu_b32_t4_all_step1_25',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.25,
    ),
    const PyannoteBenchmarkConfig(
      id: 'precision_cpu_b32_t4_all_step1_5',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.5,
    ),
    const PyannoteBenchmarkConfig(
      id: 'precision_cpu_b32_t4_all_step1_75',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 1.75,
    ),
    const PyannoteBenchmarkConfig(
      id: 'precision_cpu_b32_t4_all_step2_0',
      provider: 'CPUExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 2.0,
    ),
    const PyannoteBenchmarkConfig(
      id: 'coreml_subgraph_b32_t4_all_step2_aggressive',
      provider: 'CoreMLExecutionProvider',
      batchSize: 32,
      intraOpThreads: 4,
      graphOptimization: GraphOptimizationLevel.ortEnableAll,
      stepSec: 2.0,
      coreMLFlags: CoreMLFlags.enableOnSubgraph,
    ),
  ];

  Future<PyannoteBenchmarkReport> run({
    required String sourcePath,
    void Function(double progress)? onProgress,
  }) async {
    final started = DateTime.now();
    bool? wakelockWasEnabled;
    try {
      try {
        wakelockWasEnabled = await WakelockPlus.enabled;
        await AppLogger.log(
          'PYANNOTE[BENCH][WAKELOCK] before enabled=$wakelockWasEnabled; enabling for benchmark',
        );
        await WakelockPlus.enable();
        await AppLogger.log(
          'PYANNOTE[BENCH][WAKELOCK] enabled=${await WakelockPlus.enabled}',
        );
      } catch (error, stackTrace) {
        await AppLogger.log(
          'PYANNOTE[BENCH][WAKELOCK] enable FAILED type=${error.runtimeType} error=$error\n$stackTrace',
        );
      }

      final source = File(sourcePath);
      final sourceExists = await source.exists();
      final sourceBytes = sourceExists ? await source.length() : -1;
      await AppLogger.log(
        'PYANNOTE[BENCH] start source="$sourcePath" exists=$sourceExists '
        'bytes=$sourceBytes limitSeconds=$benchmarkSeconds platform=${Platform.operatingSystem} '
        'osVersion="${Platform.operatingSystemVersion}" processors=${Platform.numberOfProcessors}',
      );
      if (!sourceExists) {
        throw StateError('PYANNOTE_BENCH_SOURCE_MISSING');
      }

      final documents = await getApplicationDocumentsDirectory();
      final outputDir = Directory(
        p.join(documents.path, 'pyannote_benchmarks'),
      );
      await outputDir.create(recursive: true);
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '-',
      );
      final sourceBase = p
          .basenameWithoutExtension(sourcePath)
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final wavPath = p.join(
        outputDir.path,
        '${sourceBase}_$stamp.benchmark10m.wav',
      );
      final jsonPath = p.join(
        outputDir.path,
        '${sourceBase}_$stamp.benchmark.json',
      );

      onProgress?.call(0.0);
      await _createCanonicalTenMinuteWav(sourcePath, wavPath);
      onProgress?.call(0.02);

      final modelData = await rootBundle.load(PyannoteMobileService.modelAsset);
      final modelBytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );
      final modelHash = sha256.convert(modelBytes).toString();
      await AppLogger.log(
        'PYANNOTE[BENCH][MODEL] bytes=${modelBytes.length} sha256=$modelHash '
        'expected=${PyannoteMobileService.expectedModelSha256}',
      );
      if (modelHash != PyannoteMobileService.expectedModelSha256) {
        throw StateError('PYANNOTE_BENCH_MODEL_SHA256_MISMATCH');
      }

      try {
        // Accessing ptr initializes the singleton environment if another pyannote
        // test has not already initialized it.
        OrtEnv.instance.ptr;
        await AppLogger.log(
          'PYANNOTE[BENCH][ORT] environment ready version=${OrtEnv.version} '
          'availableProviders=${OrtEnv.instance.availableProviders().map((e) => e.value).toList()}',
        );
      } catch (error, stackTrace) {
        await AppLogger.log(
          'PYANNOTE[BENCH][ORT] environment FAILED type=${error.runtimeType} '
          'error=$error\n$stackTrace',
        );
        rethrow;
      }

      final configs = _configs();
      final outcomes = <PyannoteBenchmarkOutcome>[];
      PyannoteBenchmarkOutcome? baseline;

      for (var index = 0; index < configs.length; index++) {
        final config = configs[index];
        await AppLogger.log(
          'PYANNOTE[BENCH][CONFIG] ${index + 1}/${configs.length} START '
          '${jsonEncode(config.toJson())}',
        );
        PyannoteBenchmarkOutcome outcome;
        try {
          outcome = await _runConfig(
            wavPath: wavPath,
            modelBytes: modelBytes,
            config: config,
            onProgress: (inner) {
              final overall =
                  0.02 +
                  ((index + inner.clamp(0.0, 1.0)) / configs.length) * 0.96;
              onProgress?.call(overall.clamp(0.0, 0.98));
            },
          );
        } catch (error, stackTrace) {
          await AppLogger.log(
            'PYANNOTE[BENCH][CONFIG] ${config.id} FAILED '
            'type=${error.runtimeType} error=$error\n$stackTrace',
          );
          outcome = PyannoteBenchmarkOutcome(
            config: config,
            success: false,
            sessionCreateMs: 0,
            inferenceMs: 0,
            totalMs: 0,
            error: '$error',
          );
        }

        if (index == 0 && outcome.success) {
          baseline = outcome;
          outcome = _withComparison(outcome, outcome);
        } else if (outcome.success && baseline != null) {
          outcome = _withComparison(outcome, baseline);
        }
        outcomes.add(outcome);
        await _logOutcome(outcome, baseline);
      }

      final successful = outcomes.where((e) => e.success).toList()
        ..sort((a, b) => a.totalMs.compareTo(b.totalMs));
      await AppLogger.log('PYANNOTE[BENCH][SUMMARY] ===== FINAL RANKING =====');
      for (var i = 0; i < successful.length; i++) {
        final item = successful[i];
        await AppLogger.log(
          'PYANNOTE[BENCH][SUMMARY] rank=${i + 1} id=${item.config.id} '
          'provider=${item.config.provider} batch=${item.config.batchSize} '
          'threads=${item.config.intraOpThreads} step=${item.config.stepSec} '
          'graph=${item.config.graphOptimization.name} totalMs=${item.totalMs} '
          'inferenceMs=${item.inferenceMs} speedup=${item.speedupVsBaseline?.toStringAsFixed(3)} '
          'exact=${item.exactFrameMatch} differingFrames=${item.differingFrames} '
          'iou=${item.protectedIntervalIoU?.toStringAsFixed(9)} '
          'protectedDelta=${item.protectedSecondsDelta?.toStringAsFixed(6)} '
          'lostFrames=${item.lostActiveFrames} addedFrames=${item.addedActiveFrames} '
          'fullyMissed=${item.fullyMissedSpeechIntervals} '
          'protectedLost=${item.protectedLostSeconds?.toStringAsFixed(6)} '
          'boundaryOnly=${item.boundaryOnlyCandidate}',
        );
      }

      final payload = <String, Object?>{
        'schema': 'sonarpad_pyannote_benchmark_v1',
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
        'source_file': p.basename(sourcePath),
        'canonical_wav_file': p.basename(wavPath),
        'benchmark_seconds': benchmarkSeconds,
        'model_sha256': modelHash,
        'onnxruntime_version': OrtEnv.version,
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'processors': Platform.numberOfProcessors,
        'total_benchmark_elapsed_ms': DateTime.now()
            .difference(started)
            .inMilliseconds,
        'results': outcomes.map((e) => e.toJson()).toList(),
      };
      await File(jsonPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
      await AppLogger.log(
        'PYANNOTE[BENCH] report written path="$jsonPath" bytes=${await File(jsonPath).length()} '
        'totalElapsedMs=${DateTime.now().difference(started).inMilliseconds}',
      );
      onProgress?.call(1.0);
      return PyannoteBenchmarkReport(
        canonicalWavPath: wavPath,
        reportJsonPath: jsonPath,
        outcomes: outcomes,
      );
    } finally {
      if (wakelockWasEnabled != null) {
        try {
          if (wakelockWasEnabled) {
            await WakelockPlus.enable();
          } else {
            await WakelockPlus.disable();
          }
          await AppLogger.log(
            'PYANNOTE[BENCH][WAKELOCK] restored enabled=${await WakelockPlus.enabled} previous=$wakelockWasEnabled',
          );
        } catch (error, stackTrace) {
          await AppLogger.log(
            'PYANNOTE[BENCH][WAKELOCK] restore FAILED type=${error.runtimeType} error=$error\n$stackTrace',
          );
        }
      }
    }
  }

  Future<PyannoteBenchmarkReport> runXnnpackBenchmark({
    required String sourcePath,
    void Function(double progress)? onProgress,
  }) async {
    final started = DateTime.now();
    bool? wakelockWasEnabled;
    try {
      try {
        wakelockWasEnabled = await WakelockPlus.enabled;
        await AppLogger.log(
          'PYANNOTE[XNNPACK][WAKELOCK] before enabled=$wakelockWasEnabled; enabling',
        );
        await WakelockPlus.enable();
        await AppLogger.log(
          'PYANNOTE[XNNPACK][WAKELOCK] enabled=${await WakelockPlus.enabled}',
        );
      } catch (error, stackTrace) {
        await AppLogger.log(
          'PYANNOTE[XNNPACK][WAKELOCK] enable FAILED '
          'type=${error.runtimeType} error=$error\n$stackTrace',
        );
      }

      final source = File(sourcePath);
      final sourceExists = await source.exists();
      final sourceBytes = sourceExists ? await source.length() : -1;
      await AppLogger.log(
        'PYANNOTE[XNNPACK] start source="$sourcePath" exists=$sourceExists '
        'bytes=$sourceBytes limitSeconds=$benchmarkSeconds '
        'platform=${Platform.operatingSystem} '
        'osVersion="${Platform.operatingSystemVersion}" '
        'processors=${Platform.numberOfProcessors}',
      );
      if (!sourceExists) {
        throw StateError('PYANNOTE_XNNPACK_SOURCE_MISSING');
      }

      final documents = await getApplicationDocumentsDirectory();
      final outputDir = Directory(
        p.join(documents.path, 'pyannote_benchmarks'),
      );
      await outputDir.create(recursive: true);
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '-',
      );
      final sourceBase = p
          .basenameWithoutExtension(sourcePath)
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final wavPath = p.join(
        outputDir.path,
        '${sourceBase}_$stamp.xnnpack10m.wav',
      );
      final jsonPath = p.join(
        outputDir.path,
        '${sourceBase}_$stamp.xnnpack.json',
      );

      onProgress?.call(0.0);
      await _createCanonicalTenMinuteWav(sourcePath, wavPath);
      onProgress?.call(0.05);

      final modelData = await rootBundle.load(PyannoteMobileService.modelAsset);
      final modelBytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );
      final modelHash = sha256.convert(modelBytes).toString();
      if (modelHash != PyannoteMobileService.expectedModelSha256) {
        throw StateError('PYANNOTE_XNNPACK_MODEL_SHA256_MISMATCH');
      }

      OrtEnv.instance.ptr;
      final providers = OrtEnv.instance.availableProviders();
      final xnnpackAvailable = providers.contains(OrtProvider.xnnpack);
      await AppLogger.log(
        'PYANNOTE[XNNPACK][ORT] version=${OrtEnv.version} '
        'availableProviders=${providers.map((e) => e.value).toList()} '
        'xnnpackAvailable=$xnnpackAvailable',
      );
      if (!xnnpackAvailable) {
        throw StateError('PYANNOTE_XNNPACK_PROVIDER_UNAVAILABLE');
      }

      final configs = <PyannoteBenchmarkConfig>[
        const PyannoteBenchmarkConfig(
          id: 'xnn_ref_cpu_b32_t4_step1',
          provider: 'CPUExecutionProvider',
          batchSize: 32,
          intraOpThreads: 4,
          graphOptimization: GraphOptimizationLevel.ortEnableAll,
          stepSec: 1.0,
          paddingSec: 0.25,
        ),
        const PyannoteBenchmarkConfig(
          id: 'xnnpack_b32_t2_step1',
          provider: 'XnnpackExecutionProvider',
          batchSize: 32,
          intraOpThreads: 2,
          graphOptimization: GraphOptimizationLevel.ortEnableAll,
          stepSec: 1.0,
          paddingSec: 0.25,
        ),
        const PyannoteBenchmarkConfig(
          id: 'xnnpack_b32_t4_step1',
          provider: 'XnnpackExecutionProvider',
          batchSize: 32,
          intraOpThreads: 4,
          graphOptimization: GraphOptimizationLevel.ortEnableAll,
          stepSec: 1.0,
          paddingSec: 0.25,
        ),
        const PyannoteBenchmarkConfig(
          id: 'xnnpack_b32_t6_step1',
          provider: 'XnnpackExecutionProvider',
          batchSize: 32,
          intraOpThreads: 6,
          graphOptimization: GraphOptimizationLevel.ortEnableAll,
          stepSec: 1.0,
          paddingSec: 0.25,
        ),
      ];

      final outcomes = <PyannoteBenchmarkOutcome>[];
      PyannoteBenchmarkOutcome? baseline;

      for (var index = 0; index < configs.length; index++) {
        final config = configs[index];
        await AppLogger.log(
          'PYANNOTE[XNNPACK][CONFIG] ${index + 1}/${configs.length} START '
          '${jsonEncode(config.toJson())}',
        );
        PyannoteBenchmarkOutcome outcome;
        try {
          outcome = await _runConfig(
            wavPath: wavPath,
            modelBytes: modelBytes,
            config: config,
            onProgress: (inner) {
              final overall =
                  0.05 +
                  ((index + inner.clamp(0.0, 1.0)) / configs.length) * 0.90;
              onProgress?.call(overall.clamp(0.0, 0.95));
            },
          );
        } catch (error, stackTrace) {
          await AppLogger.log(
            'PYANNOTE[XNNPACK][CONFIG] ${config.id} FAILED '
            'type=${error.runtimeType} error=$error\n$stackTrace',
          );
          outcome = PyannoteBenchmarkOutcome(
            config: config,
            success: false,
            sessionCreateMs: 0,
            inferenceMs: 0,
            totalMs: 0,
            error: '$error',
          );
        }

        if (index == 0 && outcome.success) {
          baseline = outcome;
          outcome = _withComparison(outcome, outcome);
        } else if (outcome.success && baseline != null) {
          outcome = _withComparison(outcome, baseline);
        }
        outcomes.add(outcome);

        await AppLogger.log(
          'PYANNOTE[XNNPACK][RESULT] id=${config.id} '
          'success=${outcome.success} provider=${config.provider} '
          'threads=${config.intraOpThreads} '
          'sessionCreateMs=${outcome.sessionCreateMs} '
          'inferenceMs=${outcome.inferenceMs} totalMs=${outcome.totalMs} '
          'frameSha256=${outcome.frameSha256} '
          'exact=${outcome.exactFrameMatch} '
          'differingFrames=${outcome.differingFrames} '
          'protectedLost=${outcome.protectedLostSeconds?.toStringAsFixed(6)} '
          'speedup=${outcome.speedupVsBaseline?.toStringAsFixed(3)} '
          'error=${outcome.error}',
        );
      }

      final exactXnnpack =
          outcomes
              .where(
                (item) =>
                    item.success &&
                    item.config.provider == OrtProvider.xnnpack.value &&
                    item.exactFrameMatch == true &&
                    (item.differingFrames ?? -1) == 0 &&
                    (item.protectedLostSeconds ?? double.infinity) <= 0.000001,
              )
              .toList()
            ..sort((a, b) => a.inferenceMs.compareTo(b.inferenceMs));

      final best = exactXnnpack.isEmpty ? null : exactXnnpack.first;
      await AppLogger.log(
        'PYANNOTE[XNNPACK][FINAL] '
        'baselineInferenceMs=${baseline?.inferenceMs} '
        'baselineHash=${baseline?.frameSha256} '
        'exactCandidates=${exactXnnpack.length} '
        'best=${best?.config.id} '
        'bestInferenceMs=${best?.inferenceMs} '
        'bestHash=${best?.frameSha256} '
        'bestSpeedup=${best?.speedupVsBaseline?.toStringAsFixed(3)} '
        'allExact=${exactXnnpack.length == 3}',
      );

      final payload = <String, Object?>{
        'schema': 'sonarpad_pyannote_xnnpack_benchmark_v1',
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
        'source_file': p.basename(sourcePath),
        'canonical_wav_file': p.basename(wavPath),
        'benchmark_seconds': benchmarkSeconds,
        'model_sha256': modelHash,
        'onnxruntime_version': OrtEnv.version,
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'processors': Platform.numberOfProcessors,
        'xnnpack_available': xnnpackAvailable,
        'total_elapsed_ms': DateTime.now().difference(started).inMilliseconds,
        'best_exact_xnnpack': best?.config.id,
        'results': outcomes.map((e) => e.toJson()).toList(),
      };
      await File(jsonPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
      await AppLogger.log(
        'PYANNOTE[XNNPACK] report written path="$jsonPath" '
        'bytes=${await File(jsonPath).length()}',
      );
      onProgress?.call(1.0);
      return PyannoteBenchmarkReport(
        canonicalWavPath: wavPath,
        reportJsonPath: jsonPath,
        outcomes: outcomes,
      );
    } finally {
      if (wakelockWasEnabled != null) {
        try {
          if (wakelockWasEnabled) {
            await WakelockPlus.enable();
          } else {
            await WakelockPlus.disable();
          }
          await AppLogger.log(
            'PYANNOTE[XNNPACK][WAKELOCK] restored '
            'enabled=${await WakelockPlus.enabled} '
            'previous=$wakelockWasEnabled',
          );
        } catch (error, stackTrace) {
          await AppLogger.log(
            'PYANNOTE[XNNPACK][WAKELOCK] restore FAILED '
            'type=${error.runtimeType} error=$error\n$stackTrace',
          );
        }
      }
    }
  }

  Future<PyannoteCandidateValidationReport> runCandidateValidation({
    required String sourcePath,
    void Function(double progress)? onProgress,
  }) async {
    final started = DateTime.now();
    bool? wakelockWasEnabled;
    try {
      try {
        wakelockWasEnabled = await WakelockPlus.enabled;
        await AppLogger.log(
          'PYANNOTE[VALIDATE][WAKELOCK] before enabled=$wakelockWasEnabled; enabling',
        );
        await WakelockPlus.enable();
        await AppLogger.log(
          'PYANNOTE[VALIDATE][WAKELOCK] enabled=${await WakelockPlus.enabled}',
        );
      } catch (error, stackTrace) {
        await AppLogger.log(
          'PYANNOTE[VALIDATE][WAKELOCK] enable FAILED type=${error.runtimeType} error=$error\n$stackTrace',
        );
      }

      final source = File(sourcePath);
      if (!await source.exists()) {
        throw StateError('PYANNOTE_VALIDATE_SOURCE_MISSING');
      }

      final probe = await FFprobeKit.getMediaInformation(sourcePath);
      final info = probe.getMediaInformation();
      final durationSec = double.tryParse(info?.getDuration() ?? '') ?? 0.0;
      if (durationSec <= 0.0) {
        await AppLogger.log(
          'PYANNOTE[VALIDATE][PROBE] invalid duration value=${info?.getDuration()}',
        );
        throw StateError('PYANNOTE_VALIDATE_DURATION_UNKNOWN');
      }

      final starts = _distributedClipStarts(durationSec);
      await AppLogger.log(
        'PYANNOTE[VALIDATE] start source="$sourcePath" duration=${durationSec.toStringAsFixed(3)} '
        'clips=${starts.length} starts=${starts.map((e) => e.toStringAsFixed(3)).toList()} '
        'baseline=step1.0/pad0.25 candidate=step2.0/pad0.35',
      );

      final documents = await getApplicationDocumentsDirectory();
      final outputDir = Directory(
        p.join(documents.path, 'pyannote_benchmarks'),
      );
      await outputDir.create(recursive: true);
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '-',
      );
      final sourceBase = p
          .basenameWithoutExtension(sourcePath)
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final reportPath = p.join(
        outputDir.path,
        '${sourceBase}_$stamp.step2_pad035_validation.json',
      );

      final modelData = await rootBundle.load(PyannoteMobileService.modelAsset);
      final modelBytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );
      final modelHash = sha256.convert(modelBytes).toString();
      if (modelHash != PyannoteMobileService.expectedModelSha256) {
        throw StateError('PYANNOTE_VALIDATE_MODEL_SHA256_MISMATCH');
      }
      OrtEnv.instance.ptr;

      const baselineConfig = PyannoteBenchmarkConfig(
        id: 'validation_baseline_step1_pad025',
        provider: 'CPUExecutionProvider',
        batchSize: 32,
        intraOpThreads: 4,
        graphOptimization: GraphOptimizationLevel.ortEnableAll,
        stepSec: 1.0,
        paddingSec: 0.25,
      );
      const candidateConfig = PyannoteBenchmarkConfig(
        id: 'validation_candidate_step2_pad035',
        provider: 'CPUExecutionProvider',
        batchSize: 32,
        intraOpThreads: 4,
        graphOptimization: GraphOptimizationLevel.ortEnableAll,
        stepSec: 2.0,
        paddingSec: 0.35,
      );

      var baselineInferenceMs = 0;
      var candidateInferenceMs = 0;
      var totalProtectedLostSeconds = 0.0;
      var totalProtectedAddedSeconds = 0.0;
      var totalFullyMissed = 0;
      var totalInteriorLost = 0;
      var totalLostFrames = 0;
      var totalAddedFrames = 0;
      var maxContiguousLostMs = 0.0;
      final clipResults = <Map<String, Object?>>[];
      final totalRuns = starts.length * 2;
      var completedRuns = 0;

      for (var clipIndex = 0; clipIndex < starts.length; clipIndex++) {
        final startSec = starts[clipIndex];
        final remaining = math.max(0.0, durationSec - startSec);
        final clipDuration = math.min(benchmarkSeconds, remaining).toDouble();
        final wavPath = p.join(
          outputDir.path,
          '${sourceBase}_$stamp.clip${clipIndex + 1}_${startSec.toStringAsFixed(0)}s.wav',
        );
        await AppLogger.log(
          'PYANNOTE[VALIDATE][CLIP] ${clipIndex + 1}/${starts.length} '
          'extract start=${startSec.toStringAsFixed(3)} duration=${clipDuration.toStringAsFixed(3)}',
        );
        await _createCanonicalClipWav(
          sourcePath: sourcePath,
          wavPath: wavPath,
          startSec: startSec,
          durationSec: clipDuration,
        );

        try {
          final baselineRaw = await _runConfig(
            wavPath: wavPath,
            modelBytes: modelBytes,
            config: baselineConfig,
            onProgress: (inner) {
              final overall =
                  (completedRuns + inner.clamp(0.0, 1.0)) / totalRuns;
              onProgress?.call(overall.clamp(0.0, 0.999));
            },
          );
          completedRuns++;
          final baseline = _withComparison(baselineRaw, baselineRaw);
          baselineInferenceMs += baseline.inferenceMs;

          final candidateRaw = await _runConfig(
            wavPath: wavPath,
            modelBytes: modelBytes,
            config: candidateConfig,
            onProgress: (inner) {
              final overall =
                  (completedRuns + inner.clamp(0.0, 1.0)) / totalRuns;
              onProgress?.call(overall.clamp(0.0, 0.999));
            },
          );
          completedRuns++;
          final candidate = _withComparison(candidateRaw, baseline);
          candidateInferenceMs += candidate.inferenceMs;
          totalProtectedLostSeconds += candidate.protectedLostSeconds ?? 0.0;
          totalProtectedAddedSeconds += candidate.protectedAddedSeconds ?? 0.0;
          totalFullyMissed += candidate.fullyMissedSpeechIntervals ?? 0;
          totalInteriorLost += candidate.interiorLostFrames250ms ?? 0;
          totalLostFrames += candidate.lostActiveFrames ?? 0;
          totalAddedFrames += candidate.addedActiveFrames ?? 0;
          maxContiguousLostMs = math
              .max(maxContiguousLostMs, candidate.maxContiguousLostMs ?? 0.0)
              .toDouble();

          final clipSpeedup = candidate.inferenceMs > 0
              ? baseline.inferenceMs / candidate.inferenceMs
              : 0.0;
          final clipPass =
              (candidate.protectedLostSeconds ?? double.infinity) <= 0.001 &&
              (candidate.fullyMissedSpeechIntervals ?? 1) == 0 &&
              (candidate.interiorLostFrames250ms ?? 1) == 0;
          await AppLogger.log(
            'PYANNOTE[VALIDATE][CLIP_RESULT] clip=${clipIndex + 1} '
            'start=${startSec.toStringAsFixed(3)} baselineMs=${baseline.inferenceMs} '
            'candidateMs=${candidate.inferenceMs} speedup=${clipSpeedup.toStringAsFixed(3)} '
            'protectedLost=${candidate.protectedLostSeconds?.toStringAsFixed(6)} '
            'protectedAdded=${candidate.protectedAddedSeconds?.toStringAsFixed(6)} '
            'fullyMissed=${candidate.fullyMissedSpeechIntervals} '
            'interiorLost=${candidate.interiorLostFrames250ms} '
            'lostFrames=${candidate.lostActiveFrames} addedFrames=${candidate.addedActiveFrames} '
            'maxContiguousLostMs=${candidate.maxContiguousLostMs?.toStringAsFixed(3)} '
            'pass=$clipPass',
          );

          clipResults.add(<String, Object?>{
            'clip_index': clipIndex + 1,
            'start_seconds': startSec,
            'duration_seconds': clipDuration,
            'pass': clipPass,
            'baseline': baseline.toJson(),
            'candidate': candidate.toJson(),
          });
        } finally {
          try {
            final wav = File(wavPath);
            if (await wav.exists()) await wav.delete();
            await AppLogger.log(
              'PYANNOTE[VALIDATE][CLEANUP] deleted clip wav="$wavPath"',
            );
          } catch (error) {
            await AppLogger.log(
              'PYANNOTE[VALIDATE][CLEANUP] failed wav="$wavPath" error=$error',
            );
          }
        }
      }

      final speedup = candidateInferenceMs > 0
          ? baselineInferenceMs / candidateInferenceMs
          : 0.0;
      final passed =
          totalProtectedLostSeconds <= 0.001 &&
          totalFullyMissed == 0 &&
          totalInteriorLost == 0;
      await AppLogger.log(
        'PYANNOTE[VALIDATE][FINAL] passed=$passed clips=${starts.length} '
        'baselineInferenceMs=$baselineInferenceMs candidateInferenceMs=$candidateInferenceMs '
        'speedup=${speedup.toStringAsFixed(3)} protectedLostSeconds=${totalProtectedLostSeconds.toStringAsFixed(6)} '
        'protectedAddedSeconds=${totalProtectedAddedSeconds.toStringAsFixed(6)} '
        'fullyMissedSpeechIntervals=$totalFullyMissed interiorLostFrames250ms=$totalInteriorLost '
        'lostActiveFrames=$totalLostFrames addedActiveFrames=$totalAddedFrames '
        'maxContiguousLostMs=${maxContiguousLostMs.toStringAsFixed(3)}',
      );

      final payload = <String, Object?>{
        'schema': 'sonarpad_pyannote_candidate_validation_v1',
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
        'source_file': p.basename(sourcePath),
        'source_duration_seconds': durationSec,
        'clip_starts_seconds': starts,
        'clip_seconds': benchmarkSeconds,
        'model_sha256': modelHash,
        'onnxruntime_version': OrtEnv.version,
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'baseline_config': baselineConfig.toJson(),
        'candidate_config': candidateConfig.toJson(),
        'summary': <String, Object?>{
          'passed': passed,
          'clip_count': starts.length,
          'baseline_inference_ms': baselineInferenceMs,
          'candidate_inference_ms': candidateInferenceMs,
          'speedup': speedup,
          'protected_lost_seconds': totalProtectedLostSeconds,
          'protected_added_seconds': totalProtectedAddedSeconds,
          'fully_missed_speech_intervals': totalFullyMissed,
          'interior_lost_frames_250ms': totalInteriorLost,
          'lost_active_frames': totalLostFrames,
          'added_active_frames': totalAddedFrames,
          'max_contiguous_lost_ms': maxContiguousLostMs,
          'elapsed_ms': DateTime.now().difference(started).inMilliseconds,
        },
        'clips': clipResults,
      };
      await File(reportPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
      await AppLogger.log(
        'PYANNOTE[VALIDATE] report written path="$reportPath" bytes=${await File(reportPath).length()}',
      );
      onProgress?.call(1.0);
      return PyannoteCandidateValidationReport(
        reportJsonPath: reportPath,
        clipCount: starts.length,
        passed: passed,
        speedup: speedup,
        protectedLostSeconds: totalProtectedLostSeconds,
        fullyMissedSpeechIntervals: totalFullyMissed,
        interiorLostFrames250ms: totalInteriorLost,
      );
    } finally {
      if (wakelockWasEnabled != null) {
        try {
          if (wakelockWasEnabled) {
            await WakelockPlus.enable();
          } else {
            await WakelockPlus.disable();
          }
          await AppLogger.log(
            'PYANNOTE[VALIDATE][WAKELOCK] restored enabled=${await WakelockPlus.enabled} previous=$wakelockWasEnabled',
          );
        } catch (error, stackTrace) {
          await AppLogger.log(
            'PYANNOTE[VALIDATE][WAKELOCK] restore FAILED type=${error.runtimeType} error=$error\n$stackTrace',
          );
        }
      }
    }
  }

  static List<double> _distributedClipStarts(double durationSec) {
    if (durationSec <= benchmarkSeconds + 1.0) return <double>[0.0];
    final lastStart = math.max(0.0, durationSec - benchmarkSeconds).toDouble();
    final candidates = <double>[
      0.0,
      lastStart * 0.25,
      lastStart * 0.50,
      lastStart * 0.75,
      lastStart,
    ];
    final starts = <double>[];
    for (final value in candidates) {
      final rounded = (value * 1000.0).round() / 1000.0;
      if (starts.every((existing) => (existing - rounded).abs() >= 1.0)) {
        starts.add(rounded);
      }
    }
    return starts;
  }

  Future<void> _createCanonicalClipWav({
    required String sourcePath,
    required String wavPath,
    required double startSec,
    required double durationSec,
  }) async {
    final started = DateTime.now();
    final args = <String>[
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-ss',
      startSec.toStringAsFixed(3),
      '-i',
      sourcePath,
      '-t',
      durationSec.toStringAsFixed(3),
      '-vn',
      '-map_metadata',
      '-1',
      '-ac',
      '1',
      '-ar',
      '${PyannoteMobileService.sampleRate}',
      '-c:a',
      'pcm_s16le',
      '-f',
      'wav',
      wavPath,
    ];
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    final success = ReturnCode.isSuccess(returnCode);
    await AppLogger.log(
      'PYANNOTE[VALIDATE][FFMPEG] start=${startSec.toStringAsFixed(3)} '
      'duration=${durationSec.toStringAsFixed(3)} success=$success returnCode=$returnCode '
      'elapsedMs=${DateTime.now().difference(started).inMilliseconds}',
    );
    if (!success) {
      final logs = (await session.getAllLogsAsString() ?? '').trim();
      if (logs.isNotEmpty) {
        await AppLogger.log('PYANNOTE[VALIDATE][FFMPEG] logs=$logs');
      }
      throw StateError('PYANNOTE_VALIDATE_FFMPEG_FAILED');
    }
    final file = File(wavPath);
    if (!await file.exists() || await file.length() <= 44) {
      throw StateError('PYANNOTE_VALIDATE_WAV_EMPTY');
    }
  }

  Future<void> _createCanonicalTenMinuteWav(
    String sourcePath,
    String wavPath,
  ) async {
    final started = DateTime.now();
    final args = <String>[
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      sourcePath,
      '-t',
      benchmarkSeconds.toStringAsFixed(3),
      '-vn',
      '-map_metadata',
      '-1',
      '-ac',
      '1',
      '-ar',
      '${PyannoteMobileService.sampleRate}',
      '-c:a',
      'pcm_s16le',
      '-f',
      'wav',
      wavPath,
    ];
    await AppLogger.log(
      'PYANNOTE[BENCH][FFMPEG] start target="$wavPath" limit=$benchmarkSeconds',
    );
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    final success = ReturnCode.isSuccess(returnCode);
    final logs = (await session.getAllLogsAsString() ?? '').trim();
    await AppLogger.log(
      'PYANNOTE[BENCH][FFMPEG] finished success=$success returnCode=$returnCode '
      'elapsedMs=${DateTime.now().difference(started).inMilliseconds}',
    );
    if (!success) {
      if (logs.isNotEmpty) {
        await AppLogger.log('PYANNOTE[BENCH][FFMPEG] logs=$logs');
      }
      throw StateError('PYANNOTE_BENCH_FFMPEG_FAILED');
    }
    final file = File(wavPath);
    if (!await file.exists() || await file.length() <= 44) {
      throw StateError('PYANNOTE_BENCH_WAV_EMPTY');
    }
    await AppLogger.log(
      'PYANNOTE[BENCH][FFMPEG] wav ready bytes=${await file.length()}',
    );
  }

  Future<PyannoteBenchmarkOutcome> _runConfig({
    required String wavPath,
    required Uint8List modelBytes,
    required PyannoteBenchmarkConfig config,
    required void Function(double progress) onProgress,
  }) async {
    final totalStarted = DateTime.now();
    final options = OrtSessionOptions();
    OrtSession? session;
    var sessionCreateMs = 0;
    try {
      options.setIntraOpNumThreads(config.intraOpThreads);
      options.setInterOpNumThreads(1);
      options.setSessionGraphOptimizationLevel(config.graphOptimization);
      if (config.coreMLFlags != null) {
        await AppLogger.log(
          'PYANNOTE[BENCH][COREML] append provider id=${config.id} '
          'flags=${config.coreMLFlags!.name}',
        );
        final appended = options.appendCoreMLProvider(config.coreMLFlags!);
        await AppLogger.log(
          'PYANNOTE[BENCH][COREML] append result id=${config.id} appended=$appended',
        );
      } else if (config.provider == OrtProvider.xnnpack.value) {
        await AppLogger.log(
          'PYANNOTE[BENCH][XNNPACK] append provider id=${config.id} '
          'xnnpackThreads=${config.intraOpThreads}',
        );
        final appended = options.appendXnnpackProvider();
        await AppLogger.log(
          'PYANNOTE[BENCH][XNNPACK] append result id=${config.id} appended=$appended',
        );
        if (!appended) {
          throw StateError('PYANNOTE_XNNPACK_APPEND_FAILED');
        }
        options.setIntraOpNumThreads(1);
        await AppLogger.log(
          'PYANNOTE[BENCH][XNNPACK] id=${config.id} '
          'xnnpackThreads=${config.intraOpThreads} ortIntraOpThreads=1',
        );
      }

      final sessionStarted = DateTime.now();
      session = OrtSession.fromBuffer(modelBytes, options);
      sessionCreateMs = DateTime.now()
          .difference(sessionStarted)
          .inMilliseconds;
      await AppLogger.log(
        'PYANNOTE[BENCH][SESSION] id=${config.id} createdMs=$sessionCreateMs '
        'inputs=${session.inputNames} outputs=${session.outputNames}',
      );
      if (session.inputNames.isEmpty || session.outputNames.isEmpty) {
        throw StateError('PYANNOTE_BENCH_MODEL_IO_INVALID');
      }

      final inferenceStarted = DateTime.now();
      final analysis = await _analyzeWithSession(
        wavPath: wavPath,
        session: session,
        config: config,
        onProgress: onProgress,
      );
      final inferenceMs = DateTime.now()
          .difference(inferenceStarted)
          .inMilliseconds;
      final totalMs = DateTime.now().difference(totalStarted).inMilliseconds;
      return PyannoteBenchmarkOutcome(
        config: config,
        success: true,
        sessionCreateMs: sessionCreateMs,
        inferenceMs: inferenceMs,
        totalMs: totalMs,
        frameCounts: analysis.frameCounts,
        frameSha256: sha256.convert(analysis.frameCounts).toString(),
        chunkCount: analysis.chunkCount,
        frameCount: analysis.frameCounts.length,
        protectedIntervals: analysis.protectedIntervals,
        protectedSeconds: analysis.protectedSeconds,
        rawIntervals: analysis.rawIntervals,
      );
    } finally {
      session?.release();
      options.release();
    }
  }

  Future<_BenchmarkAnalysis> _analyzeWithSession({
    required String wavPath,
    required OrtSession session,
    required PyannoteBenchmarkConfig config,
    required void Function(double progress) onProgress,
  }) async {
    final wav = await _Pcm16Wave.open(wavPath);
    try {
      if (wav.channels != 1 ||
          wav.bitsPerSample != 16 ||
          wav.audioFormat != 1) {
        throw StateError('PYANNOTE_BENCH_WAV_FORMAT_INVALID');
      }
      if (wav.sampleRate != PyannoteMobileService.sampleRate) {
        throw StateError('PYANNOTE_BENCH_WAV_SAMPLE_RATE_INVALID');
      }
      final starts = _segmentationChunkStarts(
        wav.sampleCount,
        wav.sampleRate,
        config.stepSec,
      );
      final chunkCount = starts.length;
      final aggregateFrameCount = _aggregateFrameCount(
        chunkCount,
        config.stepSec,
      );
      final summed = Float64List(aggregateFrameCount);
      final contributors = Uint16List(aggregateFrameCount);
      final windowSamples = (PyannoteMobileService.windowSec * wav.sampleRate)
          .round();
      final inputName = session.inputNames.first;
      final totalBatches =
          (chunkCount + config.batchSize - 1) ~/ config.batchSize;
      var processedChunks = 0;
      var batchNumber = 0;

      await AppLogger.log(
        'PYANNOTE[BENCH][RUN] id=${config.id} wavSeconds=${wav.durationSec.toStringAsFixed(6)} '
        'chunks=$chunkCount frames=$aggregateFrameCount batches=$totalBatches '
        'batch=${config.batchSize} threads=${config.intraOpThreads} step=${config.stepSec} padding=${config.paddingSec}',
      );

      for (
        var batchStart = 0;
        batchStart < chunkCount;
        batchStart += config.batchSize
      ) {
        batchNumber++;
        final batchStarted = DateTime.now();
        final currentBatchSize = math.min(
          config.batchSize,
          chunkCount - batchStart,
        );
        final batch = Float32List(currentBatchSize * windowSamples);
        for (var row = 0; row < currentBatchSize; row++) {
          await wav.readNormalizedInto(
            startSample: starts[batchStart + row],
            maxSamples: windowSamples,
            target: batch,
            targetOffset: row * windowSamples,
          );
        }

        final input = OrtValueTensor.createTensorWithDataList(batch, <int>[
          currentBatchSize,
          1,
          windowSamples,
        ]);
        final runOptions = OrtRunOptions();
        List<OrtValue?>? outputs;
        try {
          outputs = await session.runAsync(runOptions, <String, OrtValue>{
            inputName: input,
          });
          if (outputs == null || outputs.isEmpty || outputs.first == null) {
            throw StateError('PYANNOTE_BENCH_RUNTIME_NO_OUTPUT');
          }
          _accumulateBatch(
            outputs.first!.value,
            batchStart,
            currentBatchSize,
            config.stepSec,
            summed,
            contributors,
          );
        } finally {
          input.release();
          runOptions.release();
          outputs?.forEach((value) => value?.release());
        }

        processedChunks += currentBatchSize;
        final progress = chunkCount == 0 ? 1.0 : processedChunks / chunkCount;
        await AppLogger.log(
          'PYANNOTE[BENCH][BATCH] id=${config.id} $batchNumber/$totalBatches '
          'processed=$processedChunks/$chunkCount progress=${(progress * 100).toStringAsFixed(2)}% '
          'elapsedMs=${DateTime.now().difference(batchStarted).inMilliseconds}',
        );
        onProgress(progress);
      }

      final frameCounts = Uint8List(aggregateFrameCount);
      for (var i = 0; i < aggregateFrameCount; i++) {
        final divisor = contributors[i];
        final average = divisor == 0 ? 0.0 : summed[i] / divisor;
        frameCounts[i] = _roundHalfToEven(average).clamp(0, 255).toInt();
      }
      final rawIntervals = _countsToIntervals(frameCounts);
      final protectedIntervals = _mergeIntervals(
        rawIntervals,
        paddingSec: config.paddingSec,
        durationSec: wav.durationSec,
      );
      final protectedSeconds = protectedIntervals.fold<double>(
        0.0,
        (sum, interval) => sum + interval.end - interval.start,
      );
      return _BenchmarkAnalysis(
        chunkCount: chunkCount,
        frameCounts: frameCounts,
        rawIntervals: rawIntervals,
        protectedIntervals: protectedIntervals,
        protectedSeconds: protectedSeconds,
      );
    } finally {
      await wav.close();
    }
  }

  static PyannoteBenchmarkOutcome _withComparison(
    PyannoteBenchmarkOutcome current,
    PyannoteBenchmarkOutcome baseline,
  ) {
    final left = baseline.frameCounts!;
    final right = current.frameCounts!;
    final maxLen = math.max(left.length, right.length);
    var differing = 0;
    int? first;
    var maxDelta = 0;
    var lostActiveFrames = 0;
    var addedActiveFrames = 0;
    var changedActiveSpeakerCountFrames = 0;
    var boundaryLostFrames250ms = 0;
    var interiorLostFrames250ms = 0;
    const boundaryThresholdSec = 0.250;

    String? activeKind;
    var runStart = 0;
    var runEnd = 0;
    var runMaxDelta = 0;
    final diffRuns = <Map<String, Object?>>[];

    void flushRun() {
      final kind = activeKind;
      if (kind == null) return;
      final startSec = runStart * PyannoteMobileService.frameStepSec;
      final unclampedEnd =
          runEnd * PyannoteMobileService.frameStepSec +
          PyannoteMobileService.frameDurationSec;
      final endSec = math.min(benchmarkSeconds, unclampedEnd);
      final durationMs = math.max(0.0, endSec - startSec) * 1000.0;
      bool? nearBoundary;
      if (kind == 'lost') {
        nearBoundary = true;
        for (var frame = runStart; frame <= runEnd; frame++) {
          final center =
              frame * PyannoteMobileService.frameStepSec +
              PyannoteMobileService.frameDurationSec / 2.0;
          if (!_isNearAnyBoundary(
            center,
            baseline.rawIntervals ?? const <PyannoteInterval>[],
            boundaryThresholdSec,
          )) {
            nearBoundary = false;
            break;
          }
        }
      }
      diffRuns.add(<String, Object?>{
        'kind': kind,
        'start_frame': runStart,
        'end_frame': runEnd,
        'start_seconds': startSec,
        'end_seconds': endSec,
        'duration_ms': durationMs,
        'max_speaker_count_delta': runMaxDelta,
        'near_baseline_boundary_250ms': nearBoundary,
      });
      activeKind = null;
      runMaxDelta = 0;
    }

    for (var i = 0; i < maxLen; i++) {
      final a = i < left.length ? left[i] : 0;
      final b = i < right.length ? right[i] : 0;
      String? kind;
      if (a != b) {
        differing++;
        first ??= i;
        final delta = (a - b).abs();
        if (delta > maxDelta) maxDelta = delta;
        if (a > 0 && b == 0) {
          kind = 'lost';
          lostActiveFrames++;
          final center =
              i * PyannoteMobileService.frameStepSec +
              PyannoteMobileService.frameDurationSec / 2.0;
          if (_isNearAnyBoundary(
            center,
            baseline.rawIntervals ?? const <PyannoteInterval>[],
            boundaryThresholdSec,
          )) {
            boundaryLostFrames250ms++;
          } else {
            interiorLostFrames250ms++;
          }
        } else if (a == 0 && b > 0) {
          kind = 'added';
          addedActiveFrames++;
        } else if (a > 0 && b > 0) {
          kind = 'speaker_count_changed';
          changedActiveSpeakerCountFrames++;
        }
      }

      if (kind != activeKind) {
        flushRun();
        if (kind != null) {
          activeKind = kind;
          runStart = i;
          runEnd = i;
          runMaxDelta = (a - b).abs();
        }
      } else if (kind != null) {
        runEnd = i;
        final delta = (a - b).abs();
        if (delta > runMaxDelta) runMaxDelta = delta;
      }
    }
    flushRun();

    final baseIntervals = baseline.protectedIntervals!;
    final currentIntervals = current.protectedIntervals!;
    final baseSeconds = baseline.protectedSeconds!;
    final currentSeconds = current.protectedSeconds!;
    final intersection = _intersectionSeconds(baseIntervals, currentIntervals);
    final union = baseSeconds + currentSeconds - intersection;
    final iou = union > 0 ? intersection / union : 1.0;
    final speedup = current.inferenceMs > 0
        ? baseline.inferenceMs / current.inferenceMs
        : null;

    final baseRaw = baseline.rawIntervals ?? const <PyannoteInterval>[];
    final currentRaw = current.rawIntervals ?? const <PyannoteInterval>[];
    var fullyMissedSpeechIntervals = 0;
    var fullyMissedSpeechSeconds = 0.0;
    var partialMissedSpeechIntervals = 0;
    for (final interval in baseRaw) {
      final overlap = _intervalOverlapWithList(interval, currentRaw);
      final duration = math.max(0.0, interval.end - interval.start).toDouble();
      if (overlap <= 1e-12) {
        fullyMissedSpeechIntervals++;
        fullyMissedSpeechSeconds += duration;
      } else if (overlap + 1e-9 < duration) {
        partialMissedSpeechIntervals++;
      }
    }

    final lostRuns = diffRuns.where((e) => e['kind'] == 'lost').toList();
    final rawIntersection = _intersectionSeconds(baseRaw, currentRaw);
    final baseRawSeconds = _intervalSeconds(baseRaw);
    final currentRawSeconds = _intervalSeconds(currentRaw);
    final lostActiveSeconds = math
        .max(0.0, baseRawSeconds - rawIntersection)
        .toDouble();
    final addedActiveSeconds = math
        .max(0.0, currentRawSeconds - rawIntersection)
        .toDouble();
    final maxContiguousLostMs = lostRuns.fold<double>(0.0, (value, run) {
      final duration = (run['duration_ms'] as num).toDouble();
      return duration > value ? duration : value;
    });
    final protectedLostSeconds = math
        .max(0.0, baseSeconds - intersection)
        .toDouble();
    final protectedAddedSeconds = math
        .max(0.0, currentSeconds - intersection)
        .toDouble();
    final boundaryOnlyCandidate =
        lostActiveFrames > 0 &&
        fullyMissedSpeechIntervals == 0 &&
        interiorLostFrames250ms == 0 &&
        changedActiveSpeakerCountFrames == 0;

    return PyannoteBenchmarkOutcome(
      config: current.config,
      success: current.success,
      sessionCreateMs: current.sessionCreateMs,
      inferenceMs: current.inferenceMs,
      totalMs: current.totalMs,
      frameCounts: current.frameCounts,
      frameSha256: current.frameSha256,
      chunkCount: current.chunkCount,
      frameCount: current.frameCount,
      rawIntervals: current.rawIntervals,
      protectedIntervals: current.protectedIntervals,
      protectedSeconds: current.protectedSeconds,
      error: current.error,
      differingFrames: differing,
      firstDifferingFrame: first,
      maxSpeakerCountDelta: maxDelta,
      protectedSecondsDelta: currentSeconds - baseSeconds,
      protectedIntervalIoU: iou,
      exactFrameMatch: differing == 0 && left.length == right.length,
      speedupVsBaseline: speedup,
      lostActiveFrames: lostActiveFrames,
      addedActiveFrames: addedActiveFrames,
      changedActiveSpeakerCountFrames: changedActiveSpeakerCountFrames,
      lostActiveSeconds: lostActiveSeconds,
      addedActiveSeconds: addedActiveSeconds,
      fullyMissedSpeechIntervals: fullyMissedSpeechIntervals,
      fullyMissedSpeechSeconds: fullyMissedSpeechSeconds,
      partialMissedSpeechIntervals: partialMissedSpeechIntervals,
      protectedLostSeconds: protectedLostSeconds,
      protectedAddedSeconds: protectedAddedSeconds,
      maxContiguousLostMs: maxContiguousLostMs,
      boundaryLostFrames250ms: boundaryLostFrames250ms,
      interiorLostFrames250ms: interiorLostFrames250ms,
      boundaryOnlyCandidate: boundaryOnlyCandidate,
      diffRuns: diffRuns,
    );
  }

  static bool _isNearAnyBoundary(
    double timestamp,
    List<PyannoteInterval> intervals,
    double thresholdSec,
  ) {
    for (final interval in intervals) {
      if ((timestamp - interval.start).abs() <= thresholdSec ||
          (timestamp - interval.end).abs() <= thresholdSec) {
        return true;
      }
    }
    return false;
  }

  static double _intervalOverlapWithList(
    PyannoteInterval interval,
    List<PyannoteInterval> others,
  ) {
    var total = 0.0;
    for (final other in others) {
      if (other.end <= interval.start) continue;
      if (other.start >= interval.end) break;
      total += math.max(
        0.0,
        math.min(interval.end, other.end) -
            math.max(interval.start, other.start),
      );
    }
    return total;
  }

  static Future<void> _logOutcome(
    PyannoteBenchmarkOutcome outcome,
    PyannoteBenchmarkOutcome? baseline,
  ) async {
    if (!outcome.success) {
      await AppLogger.log(
        'PYANNOTE[BENCH][RESULT] id=${outcome.config.id} success=false '
        'error=${outcome.error}',
      );
      return;
    }
    await AppLogger.log(
      'PYANNOTE[BENCH][RESULT] id=${outcome.config.id} success=true '
      'provider=${outcome.config.provider} batch=${outcome.config.batchSize} '
      'threads=${outcome.config.intraOpThreads} graph=${outcome.config.graphOptimization.name} '
      'step=${outcome.config.stepSec} padding=${outcome.config.paddingSec} sessionCreateMs=${outcome.sessionCreateMs} '
      'inferenceMs=${outcome.inferenceMs} totalMs=${outcome.totalMs} '
      'chunks=${outcome.chunkCount} frames=${outcome.frameCount} '
      'frameSha256=${outcome.frameSha256} exact=${outcome.exactFrameMatch} '
      'differingFrames=${outcome.differingFrames} firstDiff=${outcome.firstDifferingFrame} '
      'maxDelta=${outcome.maxSpeakerCountDelta} protectedSeconds=${outcome.protectedSeconds?.toStringAsFixed(6)} '
      'protectedDelta=${outcome.protectedSecondsDelta?.toStringAsFixed(6)} '
      'iou=${outcome.protectedIntervalIoU?.toStringAsFixed(9)} '
      'speedup=${outcome.speedupVsBaseline?.toStringAsFixed(3)} '
      'baseline=${baseline?.config.id}',
    );
    if (baseline == null) return;

    await AppLogger.log(
      'PYANNOTE[BENCH][VOICE] id=${outcome.config.id} '
      'lostActiveFrames=${outcome.lostActiveFrames} '
      'addedActiveFrames=${outcome.addedActiveFrames} '
      'speakerCountChangedFrames=${outcome.changedActiveSpeakerCountFrames} '
      'lostActiveSeconds=${outcome.lostActiveSeconds?.toStringAsFixed(6)} '
      'addedActiveSeconds=${outcome.addedActiveSeconds?.toStringAsFixed(6)} '
      'fullyMissedSpeechIntervals=${outcome.fullyMissedSpeechIntervals} '
      'fullyMissedSpeechSeconds=${outcome.fullyMissedSpeechSeconds?.toStringAsFixed(6)} '
      'partialMissedSpeechIntervals=${outcome.partialMissedSpeechIntervals} '
      'protectedLostSeconds=${outcome.protectedLostSeconds?.toStringAsFixed(6)} '
      'protectedAddedSeconds=${outcome.protectedAddedSeconds?.toStringAsFixed(6)} '
      'maxContiguousLostMs=${outcome.maxContiguousLostMs?.toStringAsFixed(3)} '
      'boundaryLostFrames250ms=${outcome.boundaryLostFrames250ms} '
      'interiorLostFrames250ms=${outcome.interiorLostFrames250ms} '
      'boundaryOnlyCandidate=${outcome.boundaryOnlyCandidate}',
    );

    for (final run in outcome.diffRuns ?? const <Map<String, Object?>>[]) {
      await AppLogger.log(
        'PYANNOTE[BENCH][DIFF] id=${outcome.config.id} '
        'kind=${run['kind']} frames=${run['start_frame']}-${run['end_frame']} '
        'start=${(run['start_seconds'] as num).toDouble().toStringAsFixed(6)} '
        'end=${(run['end_seconds'] as num).toDouble().toStringAsFixed(6)} '
        'durationMs=${(run['duration_ms'] as num).toDouble().toStringAsFixed(3)} '
        'maxDelta=${run['max_speaker_count_delta']} '
        'nearBoundary250ms=${run['near_baseline_boundary_250ms']}',
      );
    }
  }

  static void _accumulateBatch(
    Object? outputValue,
    int globalChunkStart,
    int batchLength,
    double stepSec,
    Float64List summed,
    Uint16List contributors,
  ) {
    if (outputValue is! List || outputValue.length != batchLength) {
      throw StateError('PYANNOTE_BENCH_OUTPUT_BATCH_SHAPE');
    }
    for (var localChunk = 0; localChunk < batchLength; localChunk++) {
      final chunk = outputValue[localChunk];
      if (chunk is! List || chunk.length != expectedFramesPerChunk) {
        throw StateError('PYANNOTE_BENCH_OUTPUT_FRAME_SHAPE');
      }
      final startFrame = _closestSegmentationFrame(
        (globalChunkStart + localChunk) * stepSec +
            0.5 * PyannoteMobileService.frameDurationSec,
      );
      for (var frame = 0; frame < expectedFramesPerChunk; frame++) {
        final scores = chunk[frame];
        if (scores is! List || scores.length != _powersetSpeakerCounts.length) {
          throw StateError('PYANNOTE_BENCH_OUTPUT_CLASS_SHAPE');
        }
        var bestIndex = 0;
        var bestScore = (scores[0] as num).toDouble();
        for (
          var classIndex = 1;
          classIndex < _powersetSpeakerCounts.length;
          classIndex++
        ) {
          final score = (scores[classIndex] as num).toDouble();
          if (score > bestScore) {
            bestScore = score;
            bestIndex = classIndex;
          }
        }
        final aggregateIndex = startFrame + frame;
        if (aggregateIndex < 0 || aggregateIndex >= summed.length) continue;
        summed[aggregateIndex] += _powersetSpeakerCounts[bestIndex];
        contributors[aggregateIndex] += 1;
      }
    }
  }

  static List<int> _segmentationChunkStarts(
    int numSamples,
    int sourceRate,
    double stepSec,
  ) {
    final windowSamples = (PyannoteMobileService.windowSec * sourceRate)
        .round();
    final stepSamples = (stepSec * sourceRate).round();
    final completeCount = numSamples >= windowSamples
        ? 1 + (numSamples - windowSamples) ~/ stepSamples
        : 0;
    final hasLastChunk =
        numSamples < windowSamples ||
        ((numSamples - windowSamples) % stepSamples > 0);
    final starts = List<int>.generate(
      completeCount,
      (index) => index * stepSamples,
      growable: true,
    );
    if (hasLastChunk) starts.add(completeCount * stepSamples);
    return starts;
  }

  static int _aggregateFrameCount(int chunkCount, double stepSec) {
    if (chunkCount <= 0) return 0;
    final endTime =
        PyannoteMobileService.windowSec +
        (chunkCount - 1) * stepSec +
        0.5 * PyannoteMobileService.frameDurationSec;
    return _closestSegmentationFrame(endTime) + 1;
  }

  static int _closestSegmentationFrame(double timestamp) {
    return _roundHalfToEven(
      (timestamp - 0.5 * PyannoteMobileService.frameDurationSec) /
          PyannoteMobileService.frameStepSec,
    );
  }

  static int _roundHalfToEven(double value) {
    if (!value.isFinite) {
      throw StateError('PYANNOTE_BENCH_AGGREGATION_NONFINITE');
    }
    final floor = value.floor();
    final fraction = value - floor;
    const epsilon = 1e-12;
    if (fraction < 0.5 - epsilon) return floor;
    if (fraction > 0.5 + epsilon) return floor + 1;
    return floor.isEven ? floor : floor + 1;
  }

  static List<PyannoteInterval> _countsToIntervals(Uint8List frameCounts) {
    final intervals = <PyannoteInterval>[];
    int? startIndex;
    for (var index = 0; index <= frameCounts.length; index++) {
      final active = index < frameCounts.length && frameCounts[index] > 0;
      if (active && startIndex == null) {
        startIndex = index;
      } else if (!active && startIndex != null) {
        intervals.add(
          PyannoteInterval(
            startIndex * PyannoteMobileService.frameStepSec,
            (index - 1) * PyannoteMobileService.frameStepSec +
                PyannoteMobileService.frameDurationSec,
          ),
        );
        startIndex = null;
      }
    }
    return intervals;
  }

  static List<PyannoteInterval> _mergeIntervals(
    List<PyannoteInterval> intervals, {
    required double paddingSec,
    required double durationSec,
  }) {
    final normalized = <PyannoteInterval>[];
    for (final interval in intervals) {
      final start = math.max(0.0, interval.start - paddingSec);
      final end = math.min(durationSec, interval.end + paddingSec);
      if (end > start) normalized.add(PyannoteInterval(start, end));
    }
    normalized.sort((a, b) => a.start.compareTo(b.start));
    final merged = <PyannoteInterval>[];
    for (final interval in normalized) {
      if (merged.isNotEmpty && interval.start <= merged.last.end) {
        final previous = merged.removeLast();
        merged.add(
          PyannoteInterval(
            previous.start,
            math.max(previous.end, interval.end),
          ),
        );
      } else {
        merged.add(interval);
      }
    }
    return merged;
  }

  static double _intervalSeconds(List<PyannoteInterval> intervals) {
    return intervals.fold<double>(
      0.0,
      (sum, interval) =>
          sum + math.max(0.0, interval.end - interval.start).toDouble(),
    );
  }

  static double _intersectionSeconds(
    List<PyannoteInterval> left,
    List<PyannoteInterval> right,
  ) {
    var i = 0;
    var j = 0;
    var total = 0.0;
    while (i < left.length && j < right.length) {
      final a = left[i];
      final b = right[j];
      total += math.max(
        0.0,
        math.min(a.end, b.end) - math.max(a.start, b.start),
      );
      if (a.end <= b.end) {
        i++;
      } else {
        j++;
      }
    }
    return total;
  }
}

class _BenchmarkAnalysis {
  const _BenchmarkAnalysis({
    required this.chunkCount,
    required this.frameCounts,
    required this.rawIntervals,
    required this.protectedIntervals,
    required this.protectedSeconds,
  });

  final int chunkCount;
  final Uint8List frameCounts;
  final List<PyannoteInterval> rawIntervals;
  final List<PyannoteInterval> protectedIntervals;
  final double protectedSeconds;
}

class _Pcm16Wave {
  _Pcm16Wave({
    required this.file,
    required this.audioFormat,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataLength,
  });

  final RandomAccessFile file;
  final int audioFormat;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int dataOffset;
  final int dataLength;

  int get bytesPerSample => bitsPerSample ~/ 8;
  int get sampleCount => dataLength ~/ (bytesPerSample * channels);
  double get durationSec => sampleCount / sampleRate;

  static Future<_Pcm16Wave> open(String path) async {
    final raf = await File(path).open(mode: FileMode.read);
    try {
      final header = await raf.read(12);
      if (header.length != 12 ||
          _ascii(header, 0, 4) != 'RIFF' ||
          _ascii(header, 8, 4) != 'WAVE') {
        throw StateError('PYANNOTE_BENCH_WAV_RIFF_INVALID');
      }
      int? audioFormat;
      int? channels;
      int? sampleRate;
      int? bitsPerSample;
      int? dataOffset;
      int? dataLength;
      final fileLength = await raf.length();
      while ((await raf.position()) + 8 <= fileLength) {
        final chunkHeader = await raf.read(8);
        if (chunkHeader.length < 8) break;
        final id = _ascii(chunkHeader, 0, 4);
        final size = _u32le(chunkHeader, 4);
        final payloadOffset = await raf.position();
        if (id == 'fmt ') {
          final fmt = await raf.read(math.min(size, 40));
          if (fmt.length < 16) {
            throw StateError('PYANNOTE_BENCH_WAV_FMT_INCOMPLETE');
          }
          audioFormat = _u16le(fmt, 0);
          channels = _u16le(fmt, 2);
          sampleRate = _u32le(fmt, 4);
          bitsPerSample = _u16le(fmt, 14);
        } else if (id == 'data') {
          dataOffset = payloadOffset;
          dataLength = size;
        }
        await raf.setPosition(payloadOffset + size + (size.isOdd ? 1 : 0));
        if (audioFormat != null && dataOffset != null) break;
      }
      if (audioFormat == null ||
          channels == null ||
          sampleRate == null ||
          bitsPerSample == null ||
          dataOffset == null ||
          dataLength == null) {
        throw StateError('PYANNOTE_BENCH_WAV_CHUNKS_MISSING');
      }
      return _Pcm16Wave(
        file: raf,
        audioFormat: audioFormat,
        channels: channels,
        sampleRate: sampleRate,
        bitsPerSample: bitsPerSample,
        dataOffset: dataOffset,
        dataLength: dataLength,
      );
    } catch (_) {
      await raf.close();
      rethrow;
    }
  }

  Future<int> readNormalizedInto({
    required int startSample,
    required int maxSamples,
    required Float32List target,
    required int targetOffset,
  }) async {
    if (startSample >= sampleCount || maxSamples <= 0) return 0;
    final available = math.min(maxSamples, sampleCount - startSample);
    final byteCount = available * 2;
    await file.setPosition(dataOffset + startSample * 2);
    final bytes = await file.read(byteCount);
    final usableSamples = bytes.length ~/ 2;
    for (var i = 0; i < usableSamples; i++) {
      var raw = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
      if ((raw & 0x8000) != 0) raw -= 0x10000;
      target[targetOffset + i] = raw / 32768.0;
    }
    return usableSamples;
  }

  Future<void> close() => file.close();

  static String _ascii(List<int> bytes, int offset, int length) =>
      String.fromCharCodes(bytes.sublist(offset, offset + length));

  static int _u16le(List<int> bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _u32le(List<int> bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}
