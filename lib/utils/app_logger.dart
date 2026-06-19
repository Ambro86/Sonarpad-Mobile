import 'dart:io';
import 'dart:developer' as dev;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppLogger {
  static const String _logFileName = 'app_debug_log.txt';
  static Future<void> _writeQueue = Future.value();

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

    _writeQueue = _writeQueue.then((_) => _append(logMessage));
    await _writeQueue;
  }

  static Future<void> _append(String logMessage) async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        final size = await file.length();
        if (size > 1024 * 1024) {
          await file.writeAsString('', mode: FileMode.write);
        }
      }
      await file.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      dev.log('AppLogger: Impossibile scrivere sul file di log: $e');
    }
  }

  static Future<String> readLogs() async {
    try {
      await _writeQueue;
      final file = await _logFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return 'Log vuoto.';
        return content;
      }
      return 'Nessun log trovato.';
    } catch (e) {
      return 'Errore durante la lettura dei log: $e';
    }
  }

  static Future<void> clearLogs() async {
    try {
      await _writeQueue;
      final file = await _logFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      dev.log('AppLogger: Impossibile cancellare i log: $e');
    }
  }
}
