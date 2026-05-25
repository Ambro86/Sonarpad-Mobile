import 'dart:io';
import 'dart:developer' as dev;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppLogger {
  static const String _logFileName = 'app_debug_log.txt';
  
  static Future<File> get _logFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _logFileName));
  }

  static Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message\n';
    dev.log(logMessage.trim());

    try {
      final file = await _logFile;
      await file.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      dev.log('AppLogger: Impossibile scrivere sul file di log: $e');
    }
  }

  static Future<String> readLogs() async {
    try {
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
      final file = await _logFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      dev.log('AppLogger: Impossibile cancellare i log: $e');
    }
  }
}
