import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

class PocketTtsModelStatus {
  final bool supported;
  final bool installed;
  final String? modelPath;
  final int bytes;
  final String version;

  const PocketTtsModelStatus({
    required this.supported,
    required this.installed,
    required this.modelPath,
    required this.bytes,
    required this.version,
  });
}

class PocketTtsDownloadProgress {
  final int receivedBytes;
  final int? totalBytes;

  const PocketTtsDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0).toDouble();
  }
}

typedef PocketTtsProgressCallback = void Function(
  PocketTtsDownloadProgress progress,
);

/// Gestisce il pacchetto Pocket TTS scaricabile su richiesta.
///
/// Nota importante: iOS non deve caricare framework eseguibili scaricati a
/// runtime. Il framework nativo va comunque collegato al progetto iOS in fase
/// di build. Questo servizio scarica e conserva solo i file modello/dati che
/// possono essere letti dal bridge nativo già firmato nell'app.
class PocketTtsModelService {
  static const version = 'v0.4.1';
  static const packageFileName = 'PocketTTS-v0.4.1.zip';
  static const downloadUrl =
      'https://github.com/UnaMentis/pocket-tts-ios/releases/download/v0.4.1/PocketTTS-v0.4.1.zip';
  static const expectedSha256 =
      'f6d6258ed2d09f39bab7524a04a79fcbe44cc50e5278445ace186a90797179f5';

  static const _backupChannel = MethodChannel('sonarpad/pocket_tts_model');
  static const _manifestFileName = 'sonarpad_pocket_tts_model.json';
  static const _modelDirectoryName = 'kyutai-pocket-ios';

  bool get isSupportedPlatform => Platform.isIOS;

  Future<Directory> _rootDirectory({bool create = true}) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'PocketTTS', version));
    if (create) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _manifestFile({bool createDirectory = true}) async {
    final dir = await _rootDirectory(create: createDirectory);
    return File(p.join(dir.path, _manifestFileName));
  }

  Future<PocketTtsModelStatus> status() async {
    if (!isSupportedPlatform) {
      return const PocketTtsModelStatus(
        supported: false,
        installed: false,
        modelPath: null,
        bytes: 0,
        version: version,
      );
    }

    final manifest = await _manifestFile(createDirectory: false);
    if (!await manifest.exists()) {
      return PocketTtsModelStatus(
        supported: true,
        installed: false,
        modelPath: null,
        bytes: 0,
        version: version,
      );
    }

    try {
      final decoded = jsonDecode(await manifest.readAsString());
      final modelPath = decoded is Map ? decoded['modelPath']?.toString() : null;
      if (modelPath == null || modelPath.trim().isEmpty) {
        return PocketTtsModelStatus(
          supported: true,
          installed: false,
          modelPath: null,
          bytes: 0,
          version: version,
        );
      }
      final modelDir = Directory(modelPath);
      if (!await modelDir.exists()) {
        return PocketTtsModelStatus(
          supported: true,
          installed: false,
          modelPath: null,
          bytes: 0,
          version: version,
        );
      }
      final bytes = await _directorySize(modelDir);
      return PocketTtsModelStatus(
        supported: true,
        installed: true,
        modelPath: modelDir.path,
        bytes: bytes,
        version: version,
      );
    } catch (_) {
      return PocketTtsModelStatus(
        supported: true,
        installed: false,
        modelPath: null,
        bytes: 0,
        version: version,
      );
    }
  }

  Future<PocketTtsModelStatus> downloadAndInstall({
    PocketTtsProgressCallback? onProgress,
  }) async {
    await AppLogger.log('Pocket TTS: downloadAndInstall requested');
    if (!isSupportedPlatform) {
      await AppLogger.log('Pocket TTS: download blocked, platform not supported');
      throw UnsupportedError('Pocket TTS è disponibile solo su iOS.');
    }

    final root = await _rootDirectory();
    await AppLogger.log('Pocket TTS: root directory=${root.path}');
    final tmp = Directory(p.join(root.path, 'tmp_download'));
    final staging = Directory(p.join(root.path, 'staging'));
    final modelDir = Directory(p.join(root.path, _modelDirectoryName));
    await _deleteDirectoryIfExists(tmp);
    await _deleteDirectoryIfExists(staging);
    await tmp.create(recursive: true);
    await staging.create(recursive: true);

    final zipFile = File(p.join(tmp.path, packageFileName));
    try {
      await _downloadZip(zipFile, onProgress: onProgress);
      await AppLogger.log('Pocket TTS: download completed path=${zipFile.path} size=${await zipFile.length()}');
      final hash = await _sha256OfFile(zipFile);
      await AppLogger.log('Pocket TTS: checksum calculated sha256=$hash');
      if (hash.toLowerCase() != expectedSha256.toLowerCase()) {
        await AppLogger.log('Pocket TTS: checksum invalid expected=$expectedSha256 actual=$hash');
        throw Exception('Checksum Pocket TTS non valida.');
      }

      await AppLogger.log('Pocket TTS: extracting zip to ${staging.path}');
      await Future<void>.sync(
        () => extractFileToDisk(zipFile.path, staging.path),
      );
      final extractedModelDir = await _findModelDirectory(staging);
      if (extractedModelDir == null) {
        await _logExtractedModelCandidates(staging);
        await AppLogger.log(
          'Pocket TTS: model files not found after extract. ' 
          'Expected model.safetensors, tokenizer.model and voices/alba.safetensors.',
        );
        throw Exception(
          'File modello Pocket TTS non trovati nel pacchetto scaricato.',
        );
      }
      await AppLogger.log('Pocket TTS: extracted model directory=${extractedModelDir.path}');

      await _deleteDirectoryIfExists(modelDir);
      await modelDir.parent.create(recursive: true);
      try {
        await extractedModelDir.rename(modelDir.path);
      } catch (_) {
        await _copyDirectory(extractedModelDir, modelDir);
      }

      await _writeManifest(modelDir.path);
      final bytes = await _directorySize(modelDir);
      await AppLogger.log('Pocket TTS: model installed path=${modelDir.path} bytes=$bytes');
      await _excludeFromICloudBackup(root.path);
      await _deleteDirectoryIfExists(tmp);
      await _deleteDirectoryIfExists(staging);
      await AppLogger.log('Pocket TTS: downloadAndInstall completed');
      return status();
    } catch (e) {
      await AppLogger.log('Pocket TTS: downloadAndInstall failed error=$e');
      await _deleteDirectoryIfExists(tmp);
      await _deleteDirectoryIfExists(staging);
      rethrow;
    }
  }

  Future<void> deleteModel() async {
    await AppLogger.log('Pocket TTS: deleteModel requested');
    if (!isSupportedPlatform) {
      await AppLogger.log('Pocket TTS: deleteModel ignored, platform not supported');
      return;
    }
    final root = await _rootDirectory(create: false);
    if (await root.exists()) {
      await AppLogger.log('Pocket TTS: deleting model root=${root.path}');
      await root.delete(recursive: true);
    }
    await AppLogger.log('Pocket TTS: deleteModel completed');
  }

  Future<void> _deleteDirectoryIfExists(Directory directory) async {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _downloadZip(
    File target, {
    PocketTtsProgressCallback? onProgress,
  }) async {
    final client = HttpClient();
    try {
      client.userAgent = 'Sonarpad Mobile PocketTTS Downloader';
      final request = await client.getUrl(Uri.parse(downloadUrl));
      request.followRedirects = true;
      request.maxRedirects = 8;
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download Pocket TTS fallito: HTTP ${response.statusCode}',
          uri: Uri.parse(downloadUrl),
        );
      }

      final total = response.contentLength > 0 ? response.contentLength : null;
      await AppLogger.log('Pocket TTS: HTTP download started status=${response.statusCode} totalBytes=${total ?? -1}');
      var received = 0;
      var lastLoggedPercent = -10;
      var lastLoggedBytes = 0;
      final sink = target.openWrite();
      try {
        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(
            PocketTtsDownloadProgress(
              receivedBytes: received,
              totalBytes: total,
            ),
          );
          if (total != null && total > 0) {
            final percent = ((received / total) * 100).floor();
            if (percent >= lastLoggedPercent + 10 || percent == 100) {
              lastLoggedPercent = percent;
              await AppLogger.log('Pocket TTS: download progress $percent% received=$received total=$total');
            }
          } else if (received - lastLoggedBytes >= 10 * 1024 * 1024) {
            lastLoggedBytes = received;
            await AppLogger.log('Pocket TTS: download progress received=$received bytes');
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<Directory?> _findModelDirectory(Directory root) async {
    if (!await root.exists()) return null;

    if (await _isUsableModelDirectory(root)) {
      await AppLogger.log('Pocket TTS: model directory found at extract root=${root.path}');
      return root;
    }

    final candidates = <Directory>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! Directory) continue;
      final baseName = p.basename(entity.path);
      final usable = await _isUsableModelDirectory(entity);
      if (baseName == _modelDirectoryName && usable) {
        await AppLogger.log(
          'Pocket TTS: model directory found by expected name=${entity.path}',
        );
        return entity;
      }
      if (usable) candidates.add(entity);
    }

    if (candidates.isNotEmpty) {
      candidates.sort((a, b) => a.path.length.compareTo(b.path.length));
      await AppLogger.log(
        'Pocket TTS: model directory found by required files=${candidates.first.path}',
      );
      return candidates.first;
    }

    return null;
  }

  Future<bool> _isUsableModelDirectory(Directory directory) async {
    final model = File(p.join(directory.path, 'model.safetensors'));
    final tokenizer = File(p.join(directory.path, 'tokenizer.model'));
    final voices = Directory(p.join(directory.path, 'voices'));
    final alba = File(p.join(voices.path, 'alba.safetensors'));
    return await model.exists() &&
        await tokenizer.exists() &&
        await voices.exists() &&
        await alba.exists();
  }

  Future<void> _logExtractedModelCandidates(Directory root) async {
    if (!await root.exists()) return;
    final interesting = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final name = p.basename(entity.path).toLowerCase();
      if (entity is Directory && (name == 'models' || name == 'voices')) {
        interesting.add(entity.path);
      } else if (entity is File &&
          (name == 'model.safetensors' ||
              name == 'tokenizer.model' ||
              name.endsWith('.safetensors'))) {
        interesting.add(entity.path);
      }
      if (interesting.length >= 40) break;
    }
    await AppLogger.log(
      'Pocket TTS: extracted candidates ${interesting.isEmpty ? 'none' : interesting.join(' | ')}',
    );
  }

  Future<void> _writeManifest(String modelPath) async {
    final file = await _manifestFile();
    final data = {
      'version': version,
      'sourceUrl': downloadUrl,
      'sha256': expectedSha256,
      'modelPath': modelPath,
      'installedAt': DateTime.now().toIso8601String(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<int> _directorySize(Directory dir) async {
    var total = 0;
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false, followLinks: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  Future<void> _excludeFromICloudBackup(String path) async {
    try {
      await _backupChannel.invokeMethod<void>('excludeFromBackup', {'path': path});
      await AppLogger.log('Pocket TTS: excluded from iCloud backup path=$path');
    } on MissingPluginException {
      await AppLogger.log('Pocket TTS: excludeFromBackup native method missing, continuing');
      // Il metodo nativo è opzionale: il modello resta comunque in Application Support.
    } catch (e) {
      await AppLogger.log('Pocket TTS: excludeFromBackup failed error=$e');
      // Non bloccare il download per un errore del flag no-backup.
    }
  }
}
