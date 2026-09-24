import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/pyannote_parity_service.dart';
import '../utils/app_logger.dart';
import '../widgets/universal_accessible_view.dart';

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
  String? _status;
  String? _technicalError;
  PyannoteParityArtifacts? _lastArtifacts;

  Future<void> _runTest({required bool fullFile}) async {
    if (_running) {
      await AppLogger.log(
        'PYANNOTE[UI] run ignored because another test is running',
      );
      return;
    }

    await AppLogger.log(
      'PYANNOTE[UI] picker opening fullFile=$fullFile',
    );
    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      await AppLogger.log('PYANNOTE[UI] picker cancelled or empty path');
      return;
    }

    final selected = File(path);
    final exists = await selected.exists();
    final bytes = exists ? await selected.length() : -1;
    await AppLogger.log(
      'PYANNOTE[UI] file selected '
      'path="$path" exists=$exists bytes=$bytes fullFile=$fullFile',
    );

    final l10n = AppLocalizations.of(context);
    setState(() {
      _running = true;
      _progress = 0.0;
      _technicalError = null;
      _lastArtifacts = null;
      _status = fullFile
          ? l10n.pyannotePreparingFull
          : l10n.pyannotePreparingQuick;
    });

    try {
      await AppLogger.log(
        'PYANNOTE[UI] service.run start '
        'limitSeconds=${fullFile ? 'null' : '120.0'}',
      );
      final artifacts = await _service.run(
        sourcePath: path,
        limitSeconds: fullFile ? null : 120.0,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress.clamp(0.0, 1.0).toDouble();
          });
        },
      );
      if (!mounted) return;
      await AppLogger.log(
        'PYANNOTE[UI] service.run success '
        'wav="${artifacts.wavPath}" json="${artifacts.jsonPath}" '
        'protectedIntervals=${artifacts.result.protectedIntervals.length} '
        'protectedSeconds=${artifacts.result.protectedSeconds.toStringAsFixed(6)}',
      );
      setState(() {
        _lastArtifacts = artifacts;
        _progress = 1.0;
        _status = l10n.pyannoteCompletedStatus;
      });
    } catch (error, stackTrace) {
      await AppLogger.log(
        'PYANNOTE[UI] service.run FAILED '
        'type=${error.runtimeType} error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _status = l10n.pyannoteFailure;
        _technicalError = error.toString();
      });
    } finally {
      await AppLogger.log('PYANNOTE[UI] run finished fullFile=$fullFile');
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _shareLast() async {
    final artifacts = _lastArtifacts;
    if (artifacts == null) {
      await AppLogger.log(
        'PYANNOTE[UI] share requested without artifacts',
      );
      return;
    }
    await AppLogger.log(
      'PYANNOTE[UI] share artifacts requested '
      'wav="${artifacts.wavPath}" json="${artifacts.jsonPath}"',
    );
    final l10n = AppLocalizations.of(context);
    if (!await File(artifacts.wavPath).exists() ||
        !await File(artifacts.jsonPath).exists()) {
      setState(() {
        _status = l10n.pyannoteFilesUnavailable;
        _technicalError = null;
      });
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile(artifacts.wavPath),
          XFile(artifacts.jsonPath),
        ],
        text: l10n.pyannoteShareText,
        subject: l10n.pyannoteShareSubject,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _status ?? l10n.pyannoteInitialStatus;
    final statusValue = _running
        ? '$status ${(_progress * 100).round()}%'
        : status;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pyannoteTestTitle)),
      body: UniversalAccessibleList(
        initialFocusId: 'quick_test',
        sections: <AccessibleListSection>[
          AccessibleListSection(
            rows: <AccessibleListRow>[
              AccessibleListRow(
                id: 'instructions',
                title: l10n.pyannoteTestInstructions,
                kind: 'text',
                accessibilityButtonTrait: false,
              ),
              AccessibleListRow(
                id: 'quick_test',
                title: l10n.pyannoteQuickTest,
                kind: 'button',
                enabled: !_running,
                onActivate: () => _runTest(fullFile: false),
              ),
              AccessibleListRow(
                id: 'full_test',
                title: l10n.pyannoteFullTest,
                kind: 'button',
                enabled: !_running,
                onActivate: () => _runTest(fullFile: true),
              ),
              AccessibleListRow(
                id: 'status',
                title: l10n.info,
                value: statusValue,
                kind: 'text',
                accessibilityButtonTrait: false,
              ),
              if (_technicalError != null)
                AccessibleListRow(
                  id: 'technical_error',
                  title: l10n.technicalErrorGeneric,
                  value: _technicalError,
                  kind: 'text',
                  accessibilityButtonTrait: false,
                ),
              if (_lastArtifacts != null)
                AccessibleListRow(
                  id: 'share_artifacts',
                  title: l10n.pyannoteShareArtifacts,
                  kind: 'button',
                  enabled: !_running,
                  onActivate: _shareLast,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
