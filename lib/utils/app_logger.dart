import 'dart:io';
import 'dart:developer' as dev;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppLogger {
  static const String _logFileName = 'app_debug_log.txt';
  static const int _maxLogBytes = 8 * 1024 * 1024;
  static const int _maxArchivedLogs = 3;
  static Future<void>? _writeQueue;

  // Reads and explicit clears share the write queue so rotation cannot split
  // an exported snapshot or race with a new log entry.
  static Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = (_writeQueue ?? Future<void>.value()).then((_) => action());
    late final Future<void> settled;
    void release() {
      if (identical(_writeQueue, settled)) _writeQueue = null;
    }

    settled = result.then<void>(
      (_) => release(),
      onError: (Object error, StackTrace stack) => release(),
    );
    _writeQueue = settled;
    return result;
  }

  static Future<File> get _logFile async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, _logFileName));
  }

  /// Rimuove i vecchi file tecnici che alcune versioni salvavano nella
  /// cartella Documenti visibile tramite File/iTunes. Il log resta disponibile
  /// dal pulsante "Copia log", ma viene salvato in Application Support.
  static Future<void> cleanupVisibleDebugArtifacts() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // Elimina solo file tecnici con nomi univoci di Sonarpad.
      // Non rimuovere nomi generici come log.txt, debug log.txt o
      // debug_log.txt: un utente potrebbe averli importati o creati
      // volontariamente come normali documenti.
      final candidates = <File>[
        File(p.join(appDir.path, _logFileName)),
        File(p.join(appDir.path, 'debug_parser_html.txt')),
        File(p.join(appDir.path, 'debug_parser_text.txt')),
        File(p.join(appDir.path, 'Documenti', _logFileName)),
        File(p.join(appDir.path, 'Documenti', 'debug_parser_html.txt')),
        File(p.join(appDir.path, 'Documenti', 'debug_parser_text.txt')),
      ];

      for (final file in candidates) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      dev.log('AppLogger: Impossibile pulire i vecchi log visibili: $e');
    }
  }

  static Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message\n';
    dev.log(logMessage.trim());

    await _enqueue(() => _append(logMessage));
  }

  static File _archive(File file, int index) => File('${file.path}.$index');

  static Future<void> _rotate(File file) async {
    final oldest = _archive(file, _maxArchivedLogs);
    final discarded = await oldest.exists();
    if (discarded) await oldest.delete();
    for (var index = _maxArchivedLogs - 1; index >= 1; index--) {
      final previous = _archive(file, index);
      if (await previous.exists()) {
        await previous.rename(_archive(file, index + 1).path);
      }
    }
    await file.rename(_archive(file, 1).path);
    await file.writeAsString(
      '[${DateTime.now().toIso8601String()}] [AppLogger] log_rotated '
      'retained_archives=$_maxArchivedLogs oldest_discarded=$discarded\n',
      mode: FileMode.write,
    );
  }

  static Future<void> _append(String logMessage) async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        final size = await file.length();
        if (size > _maxLogBytes) {
          await _rotate(file);
        }
      }
      await file.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      dev.log('AppLogger: Impossibile scrivere sul file di log: $e');
    }
  }

  static Future<String> readLogs() => _enqueue(() async {
    try {
      final file = await _logFile;
      final content = StringBuffer();
      var found = false;
      // Every read (viewer, clipboard and report ZIP) includes retained history.
      for (final segment in [
        for (var index = _maxArchivedLogs; index >= 1; index--)
          _archive(file, index),
        file,
      ]) {
        if (!await segment.exists()) continue;
        found = true;
        final text = await segment.readAsString();
        content.write(text);
        if (text.isNotEmpty && !text.endsWith('\n')) content.writeln();
      }
      if (!found) return 'Nessun log trovato.';
      final logs = content.toString();
      return logs.trim().isEmpty ? 'Log vuoto.' : logs;
    } catch (e) {
      return 'Errore durante la lettura dei log: $e';
    }
  });

  static Future<void> clearLogs() => _enqueue(() async {
    try {
      final file = await _logFile;
      for (final segment in [
        file,
        for (var index = 1; index <= _maxArchivedLogs; index++)
          _archive(file, index),
      ]) {
        if (await segment.exists()) await segment.delete();
      }
    } catch (e) {
      dev.log('AppLogger: Impossibile cancellare i log: $e');
    }
  });
}
