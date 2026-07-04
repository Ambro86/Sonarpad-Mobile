import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'pocket_tts_model_service.dart';
import '../utils/app_logger.dart';

/// Bridge Flutter -> iOS per Pocket TTS.
///
/// Android resta sicuro: su piattaforme diverse da iOS il bridge risponde
/// sempre "non disponibile" e non prova a caricare librerie native.
///
/// Il lato iOS deve essere collegato a PocketTTS.xcframework usando il canale
/// `sonarpad/pocket_tts` e i metodi:
/// - `isAvailable({modelPath})` -> bool
/// - `synthesizeToFile({text, voice, language, speed, pitch, modelPath})`
///   -> String path file audio, oppure Uint8List audio WAV
class PocketTtsBridge {
  static const MethodChannel _channel = MethodChannel('sonarpad/pocket_tts');
  final PocketTtsModelService _modelService;

  PocketTtsBridge({PocketTtsModelService? modelService})
      : _modelService = modelService ?? PocketTtsModelService();

  bool get isSupportedPlatform => Platform.isIOS;

  Future<bool> isAvailable({String? modelPath}) async {
    if (!isSupportedPlatform) {
      await AppLogger.log('Pocket TTS: isAvailable=false, platform not supported');
      return false;
    }
    try {
      final effectiveModelPath = modelPath ?? (await _modelService.status()).modelPath;
      if (effectiveModelPath == null || effectiveModelPath.trim().isEmpty) {
        await AppLogger.log('Pocket TTS: isAvailable=false, modelPath empty');
        return false;
      }
      final available = await _channel.invokeMethod<bool>('isAvailable', {
            'modelPath': effectiveModelPath,
          }) ??
          false;
      await AppLogger.log(
        'Pocket TTS: isAvailable=$available modelPath=$effectiveModelPath',
      );
      return available;
    } on MissingPluginException {
      await AppLogger.log('Pocket TTS: isAvailable=false, native plugin missing');
      return false;
    } catch (e) {
      await AppLogger.log('Pocket TTS: isAvailable error=$e');
      return false;
    }
  }

  Future<File> speakToFile({
    required String text,
    String? voice,
    String language = 'auto',
    double speed = 1.0,
    double pitch = 1.0,
    String? modelPath,
  }) async {
    if (!isSupportedPlatform) {
      throw UnsupportedError('Pocket TTS è disponibile solo su iOS.');
    }
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ArgumentError('Testo vuoto per Pocket TTS.');
    }

    final effectiveModelPath = modelPath ?? (await _modelService.status()).modelPath;
    if (effectiveModelPath == null || effectiveModelPath.trim().isEmpty) {
      throw Exception('Modello Pocket TTS non scaricato.');
    }

    try {
      await AppLogger.log(
        'Pocket TTS: synthesize start chars=${trimmedText.length} '
        'voice=${voice ?? 'default'} language=$language speed=$speed '
        'pitch=$pitch modelPath=$effectiveModelPath',
      );
      final startedAt = DateTime.now();
      final result = await _channel.invokeMethod<dynamic>('synthesizeToFile', {
        'text': trimmedText,
        'voice': voice,
        'language': language,
        'speed': speed,
        'pitch': pitch,
        'modelPath': effectiveModelPath,
      });

      if (result is Map) {
        final path = result['path']?.toString() ?? '';
        final cached = result['cachedEngine'];
        final audioSamples = result['audioSamples'];
        if (path.trim().isNotEmpty) {
          final file = File(path.trim());
          if (await file.exists() && await file.length() > 0) {
            final size = await file.length();
            await AppLogger.log(
              'Pocket TTS: synthesize completed file=${file.path} size=$size '
              'cachedEngine=$cached audioSamples=$audioSamples '
              'elapsedMs=${DateTime.now().difference(startedAt).inMilliseconds}',
            );
            return file;
          }
        }
      }

      if (result is String && result.trim().isNotEmpty) {
        final file = File(result.trim());
        if (await file.exists() && await file.length() > 0) {
          final size = await file.length();
          await AppLogger.log(
            'Pocket TTS: synthesize completed file=${file.path} size=$size '
            'elapsedMs=${DateTime.now().difference(startedAt).inMilliseconds}',
          );
          return file;
        }
      }

      if (result is Uint8List && result.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/sonarpad_pocket_tts_${DateTime.now().microsecondsSinceEpoch}.wav',
        );
        await file.writeAsBytes(result, flush: true);
        await AppLogger.log(
          'Pocket TTS: synthesize completed Uint8List file=${file.path} '
          'size=${result.length} elapsedMs=${DateTime.now().difference(startedAt).inMilliseconds}',
        );
        return file;
      }

      throw Exception('Pocket TTS non ha restituito audio valido.');
    } on MissingPluginException {
      await AppLogger.log('Pocket TTS: synthesize failed, native plugin missing');
      throw Exception(
        'Pocket TTS iOS non è ancora collegato al progetto nativo.',
      );
    } catch (e) {
      await AppLogger.log('Pocket TTS: synthesize error=$e');
      rethrow;
    }
  }
}
