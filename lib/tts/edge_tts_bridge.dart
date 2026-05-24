import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef _GenerateNative = Pointer<Utf8> Function(
  Pointer<Utf8> text,
  Pointer<Utf8> voice,
  Pointer<Utf8> outputPath,
);
typedef _GenerateDart = Pointer<Utf8> Function(
  Pointer<Utf8> text,
  Pointer<Utf8> voice,
  Pointer<Utf8> outputPath,
);

typedef _FreeNative = Void Function(Pointer<Utf8> value);
typedef _FreeDart = void Function(Pointer<Utf8> value);

class EdgeTtsBridge {
  DynamicLibrary? _lib;
  _GenerateDart? _generate;
  _FreeDart? _free;
  String? _lastLibraryPath;

  String? get lastLibraryPath => _lastLibraryPath;

  bool get isAvailable {
    try {
      _ensureLoaded();
      return _generate != null;
    } catch (_) {
      return false;
    }
  }

  Future<File> speakToFile({
    required String text,
    String voice = 'it-IT-ElsaNeural',
  }) async {
    debugPrint(
      'Sonarpad TTS: speakToFile start voice=$voice textLength=${text.length}',
    );
    _ensureLoaded();
    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'sonarpad_edge_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );

    final textPtr = text.toNativeUtf8();
    final voicePtr = voice.toNativeUtf8();
    final outPtr = outPath.toNativeUtf8();
    Pointer<Utf8> resultPtr = nullptr;
    try {
      debugPrint('Sonarpad TTS: generating output=$outPath');
      resultPtr = _generate!(textPtr, voicePtr, outPtr);
      final result = resultPtr == nullptr ? '' : resultPtr.toDartString();
      debugPrint('Sonarpad TTS: native result=$result');
      if (!result.startsWith('ok:')) {
        throw Exception(result.isEmpty
            ? 'Edge TTS non ha restituito un risultato'
            : result);
      }
      final file = File(outPath);
      if (!await file.exists()) {
        throw Exception('File audio non creato: $outPath');
      }
      final size = await file.length();
      debugPrint('Sonarpad TTS: generated file path=$outPath size=$size');
      if (size < 1000) {
        throw Exception('File audio troppo piccolo o vuoto: $size byte');
      }
      return file;
    } finally {
      calloc.free(textPtr);
      calloc.free(voicePtr);
      calloc.free(outPtr);
      if (resultPtr != nullptr && _free != null) _free!(resultPtr);
    }
  }

  /// Versione pratica “quasi streaming”: divide il testo in blocchi piccoli,
  /// genera un MP3 per blocco e permette alla UI di iniziare a riprodurre il
  /// primo blocco senza aspettare tutto l'articolo.
  Future<List<File>> speakToChunkFiles({
    required String text,
    String voice = 'it-IT-ElsaNeural',
    int maxChunkChars = 650,
    void Function(int index, int total, File file)? onChunkReady,
  }) async {
    final chunks = splitTextForStreaming(text, maxChunkChars: maxChunkChars);
    final files = <File>[];
    for (var i = 0; i < chunks.length; i++) {
      final file = await speakToFile(text: chunks[i], voice: voice);
      files.add(file);
      onChunkReady?.call(i, chunks.length, file);
    }
    return files;
  }

  List<String> splitTextForStreaming(String text, {int maxChunkChars = 650}) {
    final cleaned =
        text.replaceAll(RegExp(r'\s+'), ' ').replaceAll('...', '…').trim();
    if (cleaned.isEmpty) return const [];

    final sentenceMatches = RegExp(r'[^.!?。！？]+[.!?。！？]?').allMatches(cleaned);
    final sentences = sentenceMatches
        .map((m) => m.group(0)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final chunks = <String>[];
    final buffer = StringBuffer();

    void flush() {
      final value = buffer.toString().trim();
      if (value.isNotEmpty) chunks.add(value);
      buffer.clear();
    }

    for (final sentence in sentences) {
      if (sentence.length > maxChunkChars) {
        flush();
        var start = 0;
        while (start < sentence.length) {
          var end = start + maxChunkChars;
          if (end >= sentence.length) {
            chunks.add(sentence.substring(start).trim());
            break;
          }
          final cut = sentence.lastIndexOf(' ', end);
          if (cut > start + 80) end = cut;
          chunks.add(sentence.substring(start, end).trim());
          start = end;
        }
        continue;
      }

      final candidateLength = buffer.length + sentence.length + 1;
      if (candidateLength > maxChunkChars) flush();
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(sentence);
    }
    flush();
    return chunks;
  }

  void _ensureLoaded() {
    if (_lib != null) return;
    final candidates = _libraryCandidates();
    Object? lastError;
    for (final candidate in candidates) {
      try {
        _lib = candidate == '__process__'
            ? DynamicLibrary.process()
            : DynamicLibrary.open(candidate);
        _lastLibraryPath = candidate;
        _generate = _lib!.lookupFunction<_GenerateNative, _GenerateDart>(
          'sonarpad_edge_tts_to_file',
        );
        _free = _lib!
            .lookupFunction<_FreeNative, _FreeDart>('sonarpad_string_free');
        debugPrint('Sonarpad TTS: loaded library candidate=$candidate');
        return;
      } catch (e) {
        debugPrint(
            'Sonarpad TTS: failed library candidate=$candidate error=$e');
        lastError = e;
        _lib = null;
        _generate = null;
        _free = null;
      }
    }
    throw Exception(
        'Libreria Rust Edge TTS non caricata. Tentativi: ${candidates.join(', ')}. Ultimo errore: $lastError');
  }

  List<String> _libraryCandidates() {
    if (Platform.isIOS) return ['__process__'];
    if (Platform.isAndroid) return ['libsonarpad_tts.so'];
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final cwd = Directory.current.path;
    if (Platform.isWindows) {
      return [
        p.join(exeDir, 'sonarpad_tts.dll'),
        p.join(cwd, 'sonarpad_tts.dll'),
        'sonarpad_tts.dll',
      ];
    }
    if (Platform.isMacOS) {
      return [
        p.join(exeDir, 'libsonarpad_tts.dylib'),
        p.join(cwd, 'libsonarpad_tts.dylib'),
        'libsonarpad_tts.dylib',
      ];
    }
    if (Platform.isLinux) {
      return [
        p.join(exeDir, 'libsonarpad_tts.so'),
        p.join(cwd, 'libsonarpad_tts.so'),
        'libsonarpad_tts.so',
      ];
    }
    throw UnsupportedError('Piattaforma non supportata per Edge TTS Rust');
  }
}
