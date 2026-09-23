import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'pyannote_mobile_service.dart';

class PyannoteParityArtifacts {
  const PyannoteParityArtifacts({
    required this.wavPath,
    required this.jsonPath,
    required this.result,
  });

  final String wavPath;
  final String jsonPath;
  final PyannoteMobileResult result;
}

class PyannoteParityService {
  const PyannoteParityService();

  Future<PyannoteParityArtifacts> run({
    required String sourcePath,
    double? limitSeconds,
    void Function(double progress, String status)? onProgress,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final outputDir = Directory(p.join(documents.path, 'pyannote_parity_tests'));
    await outputDir.create(recursive: true);

    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final sourceBase = p.basenameWithoutExtension(sourcePath)
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final prefix = '${sourceBase}_$stamp';
    final wavPath = p.join(outputDir.path, '$prefix.canonical.wav');
    final jsonPath = p.join(outputDir.path, '$prefix.mobile.json');

    onProgress?.call(0.0, 'Preparazione WAV canonico mono 16 kHz...');
    final args = <String>[
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      sourcePath,
      if (limitSeconds != null) ...<String>[
        '-t',
        limitSeconds.toStringAsFixed(3),
      ],
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
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = (await session.getAllLogsAsString() ?? '').trim();
      throw StateError(
        logs.isEmpty
            ? 'FFmpeg non è riuscito a creare il WAV di test.'
            : 'FFmpeg non è riuscito a creare il WAV di test: $logs',
      );
    }
    final wavFile = File(wavPath);
    if (!await wavFile.exists() || await wavFile.length() <= 44) {
      throw StateError('Il WAV canonico di test è vuoto o mancante.');
    }

    onProgress?.call(0.03, 'Caricamento pyannote mobile...');
    final result = await PyannoteMobileService.instance.analyzeCanonicalWav(
      wavPath,
      onProgress: (progress, status) {
        onProgress?.call(0.03 + progress * 0.97, status);
      },
    );

    final frameHash = sha256.convert(result.frameCounts).toString();
    final payload = <String, Object?>{
      'schema': 'sonarpad_pyannote_parity_v1',
      'platform': 'mobile',
      'created_at_utc': DateTime.now().toUtc().toIso8601String(),
      'source_file': p.basename(sourcePath),
      'canonical_wav_file': p.basename(wavPath),
      'limit_seconds': limitSeconds,
      'model': <String, Object?>{
        'name': 'pyannote Community-1 segmentation ONNX',
        'revision': PyannoteMobileService.modelRevision,
        'sha256': result.modelSha256,
      },
      'runtime': <String, Object?>{
        'onnxruntime_version': result.runtimeVersion,
        'provider': 'CPUExecutionProvider',
        'intra_op_threads': PyannoteMobileService.intraOpThreads,
        'batch_size': PyannoteMobileService.batchSize,
        'input_name': result.inputName,
        'output_names': result.outputNames,
      },
      'audio': <String, Object?>{
        'sample_rate': PyannoteMobileService.sampleRate,
        'sample_count': result.sampleCount,
        'duration_seconds': result.durationSec,
      },
      'parameters': <String, Object?>{
        'window_seconds': PyannoteMobileService.windowSec,
        'step_seconds': PyannoteMobileService.stepSec,
        'frame_duration_seconds': PyannoteMobileService.frameDurationSec,
        'frame_step_seconds': PyannoteMobileService.frameStepSec,
        'padding_seconds': PyannoteMobileService.defaultPaddingSec,
      },
      'analysis': <String, Object?>{
        'elapsed_ms': result.elapsedMs,
        'chunk_count': result.chunkCount,
        'frame_count': result.frameCounts.length,
        'frame_counts_sha256': frameHash,
        'frame_counts_rle': _rle(result.frameCounts),
        'raw_intervals': result.rawIntervals.map((e) => e.toJson()).toList(),
        'protected_intervals':
            result.protectedIntervals.map((e) => e.toJson()).toList(),
        'protected_seconds': result.protectedSeconds,
        'protected_percent': result.durationSec <= 0
            ? 0.0
            : result.protectedSeconds / result.durationSec * 100.0,
      },
    };

    await File(jsonPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return PyannoteParityArtifacts(
      wavPath: wavPath,
      jsonPath: jsonPath,
      result: result,
    );
  }

  static List<List<int>> _rle(Uint8List values) {
    if (values.isEmpty) return const <List<int>>[];
    final output = <List<int>>[];
    var current = values.first;
    var length = 1;
    for (var i = 1; i < values.length; i++) {
      if (values[i] == current) {
        length++;
      } else {
        output.add(<int>[current, length]);
        current = values[i];
        length = 1;
      }
    }
    output.add(<int>[current, length]);
    return output;
  }
}
