import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_plus/onnxruntime_plus.dart';

import '../utils/app_logger.dart';

class PyannoteInterval {
  const PyannoteInterval(this.start, this.end);

  final double start;
  final double end;

  List<double> toJson() => <double>[start, end];
}

class PyannoteMobileResult {
  const PyannoteMobileResult({
    required this.durationSec,
    required this.sampleCount,
    required this.chunkCount,
    required this.frameCounts,
    required this.rawIntervals,
    required this.protectedIntervals,
    required this.modelSha256,
    required this.runtimeVersion,
    required this.inputName,
    required this.outputNames,
    required this.elapsedMs,
  });

  final double durationSec;
  final int sampleCount;
  final int chunkCount;
  final Uint8List frameCounts;
  final List<PyannoteInterval> rawIntervals;
  final List<PyannoteInterval> protectedIntervals;
  final String modelSha256;
  final String runtimeVersion;
  final String inputName;
  final List<String> outputNames;
  final int elapsedMs;

  double get protectedSeconds => protectedIntervals.fold<double>(
        0.0,
        (value, interval) => value + interval.end - interval.start,
      );
}

class PyannoteMobileService {
  PyannoteMobileService._();

  static final PyannoteMobileService instance = PyannoteMobileService._();

  static const String modelAsset =
      'assets/models/pyannote-segmentation/model.onnx';
  static const String modelRevision =
      '3533c8cf8e369892e6b79ff1bf80f7b0286a54ee';
  static const String expectedModelSha256 =
      '6575e57e9375c114545391ffecda0096060df55ae544d40472cdf412d115d35d';

  static const int sampleRate = 16000;
  static const double windowSec = 10.0;
  static const double stepSec = 1.0;
  static const double frameDurationSec = 0.0619375;
  static const double frameStepSec = 0.016875;
  static const int batchSize = 32;
  static int get intraOpThreads =>
      math.max(1, math.min(4, Platform.numberOfProcessors));
  static const int expectedFramesPerChunk = 589;
  static const double defaultPaddingSec = 0.25;

  // Equivalent to summing the three columns of Windows POWERSET_MAPPING.
  static const List<int> _powersetSpeakerCounts = <int>[0, 1, 1, 1, 2, 2, 2];

  OrtSession? _session;
  String? _modelSha256;
  bool _ortInitialized = false;

  Future<void> _ensureSession() async {
    if (_session != null) {
      await AppLogger.log(
        'PYANNOTE[ORT] session reuse input=${_session!.inputNames} '
        'outputs=${_session!.outputNames}',
      );
      return;
    }

    await AppLogger.log(
      'PYANNOTE[ORT] ensureSession start '
      'platform=${Platform.operatingSystem} '
      'osVersion="${Platform.operatingSystemVersion}" '
      'processors=${Platform.numberOfProcessors} '
      'intraOpThreads=$intraOpThreads '
      'modelAsset=$modelAsset',
    );

    try {
      await AppLogger.log('PYANNOTE[MODEL] asset load start');
      final modelData = await rootBundle.load(modelAsset);
      final modelBytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );
      final hash = sha256.convert(modelBytes).toString();
      await AppLogger.log(
        'PYANNOTE[MODEL] asset load success '
        'bytes=${modelBytes.length} sha256=$hash '
        'expected=$expectedModelSha256 revision=$modelRevision',
      );

      if (hash != expectedModelSha256) {
        throw StateError(
          'PYANNOTE_MODEL_SHA256_MISMATCH:$expectedModelSha256:$hash',
        );
      }

      if (!_ortInitialized) {
        await AppLogger.log(
          'PYANNOTE[ORT] resolving OrtEnv.instance and OrtGetApiBase...',
        );
        try {
          OrtEnv.instance.init(
            level: OrtLoggingLevel.info,
            logId: 'SonarpadPyannote',
          );
          _ortInitialized = true;
          await AppLogger.log(
            'PYANNOTE[ORT] OrtEnv.init success version=${OrtEnv.version}',
          );
        } catch (error, stackTrace) {
          await AppLogger.log(
            'PYANNOTE[ORT] OrtEnv.init FAILED '
            'type=${error.runtimeType} error=$error\n$stackTrace',
          );
          rethrow;
        }
      } else {
        await AppLogger.log(
          'PYANNOTE[ORT] environment already initialized '
          'version=${OrtEnv.version}',
        );
      }

      await AppLogger.log(
        'PYANNOTE[ORT] creating session options '
        'intraOpThreads=$intraOpThreads',
      );
      final options = OrtSessionOptions()
        ..setIntraOpNumThreads(intraOpThreads)
        ..setInterOpNumThreads(1)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

      OrtSession? session;
      try {
        await AppLogger.log(
          'PYANNOTE[ORT] OrtSession.fromBuffer start '
          'modelBytes=${modelBytes.length}',
        );
        session = OrtSession.fromBuffer(modelBytes, options);
        await AppLogger.log(
          'PYANNOTE[ORT] OrtSession.fromBuffer success '
          'inputs=${session.inputNames} outputs=${session.outputNames}',
        );

        if (session.inputNames.isEmpty || session.outputNames.isEmpty) {
          throw StateError('PYANNOTE_MODEL_IO_INVALID');
        }
      } catch (error, stackTrace) {
        session?.release();
        await AppLogger.log(
          'PYANNOTE[ORT] session creation FAILED '
          'type=${error.runtimeType} error=$error\n$stackTrace',
        );
        rethrow;
      } finally {
        options.release();
        await AppLogger.log('PYANNOTE[ORT] session options released');
      }

      _session = session;
      _modelSha256 = hash;
      await AppLogger.log(
        'PYANNOTE[ORT] ensureSession complete '
        'version=${OrtEnv.version} sha256=$hash',
      );
    } catch (error, stackTrace) {
      await AppLogger.log(
        'PYANNOTE[ORT] ensureSession FAILED '
        'type=${error.runtimeType} error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<PyannoteMobileResult> analyzeCanonicalWav(
    String wavPath, {
    double paddingSec = defaultPaddingSec,
    void Function(double progress)? onProgress,
  }) async {
    final overallStarted = DateTime.now();
    await AppLogger.log(
      'PYANNOTE[ANALYZE] start wav="$wavPath" '
      'padding=$paddingSec sampleRateExpected=$sampleRate '
      'window=$windowSec step=$stepSec batchSize=$batchSize',
    );

    try {
      await _ensureSession();
      final session = _session!;
      await AppLogger.log(
        'PYANNOTE[ANALYZE] session ready '
        'input=${session.inputNames.first} outputs=${session.outputNames}',
      );

      final wavFile = File(wavPath);
      final wavExists = await wavFile.exists();
      final wavBytes = wavExists ? await wavFile.length() : -1;
      await AppLogger.log(
        'PYANNOTE[WAV] before open exists=$wavExists bytes=$wavBytes',
      );

      final wav = await _Pcm16Wave.open(wavPath);
      try {
        await AppLogger.log(
          'PYANNOTE[WAV] opened '
          'format=${wav.audioFormat} channels=${wav.channels} '
          'sampleRate=${wav.sampleRate} bits=${wav.bitsPerSample} '
          'samples=${wav.sampleCount} duration=${wav.durationSec.toStringAsFixed(6)} '
          'dataOffset=${wav.dataOffset} dataLength=${wav.dataLength}',
        );

        if (wav.channels != 1 ||
            wav.bitsPerSample != 16 ||
            wav.audioFormat != 1) {
          throw StateError('PYANNOTE_WAV_FORMAT_INVALID');
        }
        if (wav.sampleRate != sampleRate) {
          throw StateError('PYANNOTE_WAV_SAMPLE_RATE_INVALID');
        }

        final starts = _segmentationChunkStarts(
          wav.sampleCount,
          wav.sampleRate,
        );
        final chunkCount = starts.length;
        await AppLogger.log(
          'PYANNOTE[ANALYZE] chunk plan '
          'chunkCount=$chunkCount firstStart=${starts.isEmpty ? -1 : starts.first} '
          'lastStart=${starts.isEmpty ? -1 : starts.last}',
        );

        if (chunkCount == 0) {
          final result = PyannoteMobileResult(
            durationSec: wav.durationSec,
            sampleCount: wav.sampleCount,
            chunkCount: 0,
            frameCounts: Uint8List(0),
            rawIntervals: const <PyannoteInterval>[],
            protectedIntervals: const <PyannoteInterval>[],
            modelSha256: _modelSha256!,
            runtimeVersion: OrtEnv.version,
            inputName: session.inputNames.first,
            outputNames: List<String>.from(session.outputNames),
            elapsedMs:
                DateTime.now().difference(overallStarted).inMilliseconds,
          );
          await AppLogger.log(
            'PYANNOTE[ANALYZE] no chunks; returning empty result',
          );
          return result;
        }

        final aggregateFrameCount = _aggregateFrameCount(chunkCount);
        final summed = Float64List(aggregateFrameCount);
        final contributors = Uint16List(aggregateFrameCount);
        final windowSamples = (windowSec * wav.sampleRate).round();
        final inputName = session.inputNames.first;
        var processedChunks = 0;
        var batchNumber = 0;
        final totalBatches = (chunkCount + batchSize - 1) ~/ batchSize;

        await AppLogger.log(
          'PYANNOTE[ANALYZE] buffers '
          'aggregateFrames=$aggregateFrameCount '
          'windowSamples=$windowSamples totalBatches=$totalBatches',
        );

        for (var batchStart = 0;
            batchStart < chunkCount;
            batchStart += batchSize) {
          batchNumber++;
          final batchStarted = DateTime.now();
          final currentBatchSize =
              math.min(batchSize, chunkCount - batchStart);
          await AppLogger.log(
            'PYANNOTE[BATCH] $batchNumber/$totalBatches prepare '
            'chunkStart=$batchStart size=$currentBatchSize '
            'floatCount=${currentBatchSize * windowSamples} isolate=true',
          );

          final batchTransfer = await Isolate.run(
            () => _readNormalizedBatchTransfer(
              wavPath: wavPath,
              dataOffset: wav.dataOffset,
              sampleCount: wav.sampleCount,
              windowSamples: windowSamples,
              starts: starts.sublist(
                batchStart,
                batchStart + currentBatchSize,
              ),
            ),
          );
          final batch = batchTransfer.materialize().asFloat32List();

          await AppLogger.log(
            'PYANNOTE[BATCH] $batchNumber/$totalBatches PCM loaded off-main-isolate; '
            'creating tensor shape=[$currentBatchSize,1,$windowSamples]',
          );

          final input = OrtValueTensor.createTensorWithDataList(
            batch,
            <int>[currentBatchSize, 1, windowSamples],
          );
          final runOptions = OrtRunOptions();
          List<OrtValue?>? outputs;
          try {
            await AppLogger.log(
              'PYANNOTE[BATCH] $batchNumber/$totalBatches '
              'session.runAsync start inputName=$inputName',
            );
            outputs = await session.runAsync(
              runOptions,
              <String, OrtValue>{inputName: input},
            );
            await AppLogger.log(
              'PYANNOTE[BATCH] $batchNumber/$totalBatches '
              'session.runAsync returned '
              'outputs=${outputs?.length ?? -1} '
              'firstNull=${outputs == null || outputs.isEmpty ? true : outputs.first == null}',
            );
            if (outputs == null || outputs.isEmpty || outputs.first == null) {
              throw StateError('PYANNOTE_RUNTIME_NO_OUTPUT');
            }
            _accumulateBatch(
              outputs.first!.value,
              batchStart,
              currentBatchSize,
              summed,
              contributors,
            );
            await AppLogger.log(
              'PYANNOTE[BATCH] $batchNumber/$totalBatches accumulated',
            );
          } catch (error, stackTrace) {
            await AppLogger.log(
              'PYANNOTE[BATCH] $batchNumber/$totalBatches FAILED '
              'type=${error.runtimeType} error=$error\n$stackTrace',
            );
            rethrow;
          } finally {
            input.release();
            runOptions.release();
            outputs?.forEach((value) => value?.release());
          }

          processedChunks += currentBatchSize;
          final elapsed =
              DateTime.now().difference(batchStarted).inMilliseconds;
          final progress = processedChunks / chunkCount;
          await AppLogger.log(
            'PYANNOTE[BATCH] $batchNumber/$totalBatches complete '
            'processed=$processedChunks/$chunkCount '
            'progress=${(progress * 100).toStringAsFixed(2)}% '
            'elapsedMs=$elapsed',
          );
          onProgress?.call(progress);
        }

        await AppLogger.log(
          'PYANNOTE[POST] aggregation rounding start '
          'frames=$aggregateFrameCount',
        );
        final frameCounts = Uint8List(aggregateFrameCount);
        for (var i = 0; i < aggregateFrameCount; i++) {
          final divisor = contributors[i];
          final average = divisor == 0 ? 0.0 : summed[i] / divisor;
          frameCounts[i] =
              _roundHalfToEven(average).clamp(0, 255).toInt();
        }

        final rawIntervals = _countsToIntervals(frameCounts);
        final protectedIntervals = _mergeIntervals(
          rawIntervals,
          paddingSec: paddingSec,
          durationSec: wav.durationSec,
        );
        final protectedSeconds = protectedIntervals.fold<double>(
          0.0,
          (value, interval) => value + interval.end - interval.start,
        );
        final frameHash = sha256.convert(frameCounts).toString();
        final elapsedMs =
            DateTime.now().difference(overallStarted).inMilliseconds;

        await AppLogger.log(
          'PYANNOTE[RESULT] success '
          'runtime=${OrtEnv.version} chunks=$chunkCount '
          'frames=${frameCounts.length} frameSha256=$frameHash '
          'rawIntervals=${rawIntervals.length} '
          'protectedIntervals=${protectedIntervals.length} '
          'protectedSeconds=${protectedSeconds.toStringAsFixed(6)} '
          'elapsedMs=$elapsedMs',
        );

        return PyannoteMobileResult(
          durationSec: wav.durationSec,
          sampleCount: wav.sampleCount,
          chunkCount: chunkCount,
          frameCounts: frameCounts,
          rawIntervals: rawIntervals,
          protectedIntervals: protectedIntervals,
          modelSha256: _modelSha256!,
          runtimeVersion: OrtEnv.version,
          inputName: inputName,
          outputNames: List<String>.from(session.outputNames),
          elapsedMs: elapsedMs,
        );
      } finally {
        await wav.close();
        await AppLogger.log('PYANNOTE[WAV] file closed');
      }
    } catch (error, stackTrace) {
      await AppLogger.log(
        'PYANNOTE[ANALYZE] FAILED '
        'type=${error.runtimeType} error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  void _accumulateBatch(
    Object? outputValue,
    int globalChunkStart,
    int batchLength,
    Float64List summed,
    Uint16List contributors,
  ) {
    if (outputValue is! List || outputValue.length != batchLength) {
      throw StateError(
        'PYANNOTE_OUTPUT_BATCH_SHAPE:${outputValue is List ? outputValue.length : 'non-lista'}:$batchLength',
      );
    }

    for (var localChunk = 0; localChunk < batchLength; localChunk++) {
      final chunk = outputValue[localChunk];
      if (chunk is! List || chunk.length != expectedFramesPerChunk) {
        throw StateError(
          'PYANNOTE_OUTPUT_FRAME_SHAPE:${globalChunkStart + localChunk}:${chunk is List ? chunk.length : 'non-lista'}:$expectedFramesPerChunk',
        );
      }
      final startFrame = _closestSegmentationFrame(
        (globalChunkStart + localChunk) * stepSec + 0.5 * frameDurationSec,
      );

      for (var frame = 0; frame < expectedFramesPerChunk; frame++) {
        final scores = chunk[frame];
        if (scores is! List || scores.length != _powersetSpeakerCounts.length) {
          throw StateError(
            'PYANNOTE_OUTPUT_CLASS_SHAPE:$frame:${scores is List ? scores.length : 'non-lista'}',
          );
        }
        var bestIndex = 0;
        var bestScore = (scores[0] as num).toDouble();
        for (var classIndex = 1;
            classIndex < _powersetSpeakerCounts.length;
            classIndex++) {
          final score = (scores[classIndex] as num).toDouble();
          // NumPy argmax keeps the first index on ties.
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

  static List<int> _segmentationChunkStarts(int numSamples, int sourceRate) {
    final windowSamples = (windowSec * sourceRate).round();
    final stepSamples = (stepSec * sourceRate).round();
    final completeCount = numSamples >= windowSamples
        ? 1 + (numSamples - windowSamples) ~/ stepSamples
        : 0;
    final hasLastChunk = numSamples < windowSamples ||
        ((numSamples - windowSamples) % stepSamples > 0);
    final starts = List<int>.generate(
      completeCount,
      (index) => index * stepSamples,
      growable: true,
    );
    if (hasLastChunk) starts.add(completeCount * stepSamples);
    return starts;
  }

  static int _aggregateFrameCount(int chunkCount) {
    final endTime = windowSec +
        (chunkCount - 1) * stepSec +
        0.5 * frameDurationSec;
    return _closestSegmentationFrame(endTime) + 1;
  }

  static int _closestSegmentationFrame(double timestamp) {
    return _roundHalfToEven(
      (timestamp - 0.5 * frameDurationSec) / frameStepSec,
    );
  }

  static int _roundHalfToEven(double value) {
    if (!value.isFinite) {
      throw StateError('PYANNOTE_AGGREGATION_NONFINITE');
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
            startIndex * frameStepSec,
            (index - 1) * frameStepSec + frameDurationSec,
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
          PyannoteInterval(previous.start, math.max(previous.end, interval.end)),
        );
      } else {
        merged.add(interval);
      }
    }
    return merged;
  }
}


Future<TransferableTypedData> _readNormalizedBatchTransfer({
  required String wavPath,
  required int dataOffset,
  required int sampleCount,
  required int windowSamples,
  required List<int> starts,
}) async {
  final batch = Float32List(starts.length * windowSamples);
  final file = await File(wavPath).open(mode: FileMode.read);
  try {
    for (var row = 0; row < starts.length; row++) {
      final startSample = starts[row];
      if (startSample >= sampleCount) continue;
      final available = math.min(windowSamples, sampleCount - startSample);
      final byteCount = available * 2;
      await file.setPosition(dataOffset + startSample * 2);
      final bytes = await file.read(byteCount);
      final usableSamples = bytes.length ~/ 2;
      final targetOffset = row * windowSamples;
      for (var i = 0; i < usableSamples; i++) {
        var raw = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
        if ((raw & 0x8000) != 0) raw -= 0x10000;
        batch[targetOffset + i] = raw / 32768.0;
      }
    }
    return TransferableTypedData.fromList(
      <Uint8List>[batch.buffer.asUint8List()],
    );
  } finally {
    await file.close();
  }
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
        throw StateError('PYANNOTE_WAV_RIFF_INVALID');
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
            throw StateError('PYANNOTE_WAV_FMT_INCOMPLETE');
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
        throw StateError('PYANNOTE_WAV_CHUNKS_MISSING');
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
