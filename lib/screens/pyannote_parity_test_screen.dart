import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pyannote_parity_service.dart';

class PyannoteParityTestScreen extends StatefulWidget {
  const PyannoteParityTestScreen({super.key});

  @override
  State<PyannoteParityTestScreen> createState() =>
      _PyannoteParityTestScreenState();
}

class _PyannoteParityTestScreenState extends State<PyannoteParityTestScreen> {
  final _service = const PyannoteParityService();
  bool _running = false;
  double _progress = 0.0;
  String _status =
      'Scegli un file audio o video. Per il primo confronto usa il test rapido.';
  PyannoteParityArtifacts? _lastArtifacts;

  Future<void> _runTest({required bool fullFile}) async {
    if (_running) return;
    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.trim().isEmpty) return;

    setState(() {
      _running = true;
      _progress = 0.0;
      _lastArtifacts = null;
      _status = fullFile
          ? 'Preparazione del test completo...'
          : 'Preparazione del test rapido sui primi 2 minuti...';
    });

    try {
      final artifacts = await _service.run(
        sourcePath: path,
        limitSeconds: fullFile ? null : 120.0,
        onProgress: (progress, status) {
          if (!mounted) return;
          setState(() {
            _progress = progress.clamp(0.0, 1.0).toDouble();
            _status = status;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _lastArtifacts = artifacts;
        _progress = 1.0;
        _status =
            'Test mobile completato. ${artifacts.result.protectedIntervals.length} '
            'intervalli protetti, ${artifacts.result.protectedSeconds.toStringAsFixed(3)} '
            'secondi di dialogo protetto. Condividi WAV e JSON e usa lo stesso WAV '
            'nel test Windows.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Test pyannote fallito: $error';
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _shareLast() async {
    final artifacts = _lastArtifacts;
    if (artifacts == null) return;
    if (!await File(artifacts.wavPath).exists() ||
        !await File(artifacts.jsonPath).exists()) {
      setState(() => _status = 'I file dell’ultimo test non sono più disponibili.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile(artifacts.wavPath),
          XFile(artifacts.jsonPath),
        ],
        text: 'Sonarpad: test parità pyannote mobile. '
            'Usare il WAV canonico allegato anche sul test Windows.',
        subject: 'Test pyannote Sonarpad',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artifacts = _lastArtifacts;
    return Scaffold(
      appBar: AppBar(title: const Text('Test pyannote mobile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Questo test usa lo stesso modello ONNX pyannote di Windows. '
            'Il WAV canonico generato qui deve essere usato anche su Windows, '
            'così il confronto misura il modello e non la decodifica del file.',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _running ? null : () => _runTest(fullFile: false),
            child: const Text('Test rapido pyannote: primi 2 minuti'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _running ? null : () => _runTest(fullFile: true),
            child: const Text('Test completo pyannote: intero file'),
          ),
          const SizedBox(height: 16),
          if (_running) ...<Widget>[
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 8),
          ],
          Semantics(
            liveRegion: true,
            child: Text(_status),
          ),
          if (artifacts != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'ONNX Runtime ${artifacts.result.runtimeVersion}; '
              'modello SHA-256 ${artifacts.result.modelSha256}; '
              'durata ${artifacts.result.durationSec.toStringAsFixed(3)} secondi; '
              'tempo analisi ${(artifacts.result.elapsedMs / 1000).toStringAsFixed(1)} secondi.',
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _running ? null : _shareLast,
              child: const Text('Condividi WAV canonico e risultato JSON mobile'),
            ),
          ],
        ],
      ),
    );
  }
}

