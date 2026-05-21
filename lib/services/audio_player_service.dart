import 'dart:io';
import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _stopRequested = false;

  Future<void> playUrl(String url) async {
    _stopRequested = false;
    await _player.setUrl(url);
    if (!_stopRequested) await _player.play();
  }

  Future<void> playFile(File file) async {
    _stopRequested = false;
    await _player.setFilePath(file.path);
    if (!_stopRequested) await _player.play();
  }

  /// Riproduce più file in sequenza. Serve per la lettura “a streaming”:
  /// il primo blocco parte subito, mentre i blocchi successivi vengono generati
  /// e riprodotti uno dopo l'altro.
  Future<void> playFilesSequentially(
    List<File> files, {
    void Function(int index, File file)? onChunkStarted,
  }) async {
    _stopRequested = false;
    for (var i = 0; i < files.length; i++) {
      if (_stopRequested) break;
      final file = files[i];
      onChunkStarted?.call(i, file);
      await _player.setFilePath(file.path);
      if (_stopRequested) break;
      await _player.play();
      await _player.playerStateStream.firstWhere(
        (state) =>
            state.processingState == ProcessingState.completed ||
            _stopRequested,
      );
      await _player.stop();
    }
  }

  Future<void> stop() async {
    _stopRequested = true;
    await _player.stop();
  }

  Future<void> dispose() => _player.dispose();
}
