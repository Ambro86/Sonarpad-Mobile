import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/pyannote_benchmark_service.dart';
import '../services/pyannote_parity_service.dart';
import '../utils/app_logger.dart';
import '../widgets/universal_accessible_view.dart';

class PyannoteParityTestScreen extends StatefulWidget {
  const PyannoteParityTestScreen({super.key});

  @override
  State<PyannoteParityTestScreen> createState() =>
      _PyannoteParityTestScreenState();
}

class _PyannoteParityTestScreenState extends State<PyannoteParityTestScreen>
    with WidgetsBindingObserver {
  final _service = const PyannoteParityService();
  final _benchmarkService = const PyannoteBenchmarkService();
  bool _running = false;
  double _progress = 0.0;
  String? _status;
  String? _technicalError;
  PyannoteParityArtifacts? _lastArtifacts;
  String? _activeOperation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final operation = _activeOperation;
    if (operation == null) return;
    unawaited(
      AppLogger.log(
        'PYANNOTE[UI][LIFECYCLE] operation=$operation state=${state.name}',
      ),
    );
  }

  Future<String?> _pickMedia({required String operation}) async {
    await AppLogger.log('PYANNOTE[UI] picker opening operation=$operation');
    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      await AppLogger.log('PYANNOTE[UI] picker cancelled operation=$operation');
      return null;
    }
    final file = File(path);
    await AppLogger.log(
      'PYANNOTE[UI] file selected operation=$operation path="$path" '
      'exists=${await file.exists()} bytes=${await file.exists() ? await file.length() : -1}',
    );
    return path;
  }

  Future<void> _runTest({required bool fullFile}) async {
    if (_running) return;
    final l10n = AppLocalizations.of(context);
    final path = await _pickMedia(
      operation: fullFile ? 'full_parity' : 'quick_parity',
    );
    if (path == null || !mounted) return;

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
      setState(() {
        _lastArtifacts = artifacts;
        _progress = 1.0;
        _status = l10n.pyannoteCompletedStatus;
      });
    } catch (error, stackTrace) {
      await AppLogger.log(
        'PYANNOTE[UI] parity FAILED type=${error.runtimeType} error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _status = l10n.pyannoteFailure;
        _technicalError = error.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _runBenchmark() async {
    if (_running) return;
    final l10n = AppLocalizations.of(context);
    final path = await _pickMedia(operation: 'benchmark_10m');
    if (path == null || !mounted) return;
    setState(() {
      _running = true;
      _progress = 0.0;
      _technicalError = null;
      _lastArtifacts = null;
      _status = l10n.pyannoteBenchmarkPreparing;
      _activeOperation = 'benchmark_10m';
    });
    try {
      final report = await _benchmarkService.run(
        sourcePath: path,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress.clamp(0.0, 1.0).toDouble();
          });
        },
      );
      await AppLogger.log(
        'PYANNOTE[UI] benchmark completed report="${report.reportJsonPath}" '
        'wav="${report.canonicalWavPath}" outcomes=${report.outcomes.length}',
      );
      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _status = l10n.pyannoteBenchmarkCompleted;
      });
    } catch (error, stackTrace) {
      await AppLogger.log(
        'PYANNOTE[UI] benchmark FAILED type=${error.runtimeType} error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _status = l10n.pyannoteFailure;
        _technicalError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _activeOperation = null;
        });
      } else {
        _activeOperation = null;
      }
    }
  }

  Future<void> _runCandidateValidation() async {
    if (_running) return;
    final l10n = AppLocalizations.of(context);
    final path = await _pickMedia(operation: 'candidate_validation_5x10m');
    if (path == null || !mounted) return;
    setState(() {
      _running = true;
      _progress = 0.0;
      _technicalError = null;
      _lastArtifacts = null;
      _status = l10n.pyannoteCandidateValidationPreparing;
      _activeOperation = 'candidate_validation_5x10m';
    });
    try {
      final report = await _benchmarkService.runCandidateValidation(
        sourcePath: path,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress.clamp(0.0, 1.0).toDouble();
          });
        },
      );
      await AppLogger.log(
        'PYANNOTE[UI] candidate validation completed '
        'report="${report.reportJsonPath}" clips=${report.clipCount} '
        'passed=${report.passed} speedup=${report.speedup.toStringAsFixed(3)} '
        'protectedLost=${report.protectedLostSeconds.toStringAsFixed(6)} '
        'fullyMissed=${report.fullyMissedSpeechIntervals} '
        'interiorLost=${report.interiorLostFrames250ms}',
      );
      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _status = report.passed
            ? l10n.pyannoteCandidateValidationPassed
            : l10n.pyannoteCandidateValidationFailed;
      });
    } catch (error, stackTrace) {
      await AppLogger.log(
        'PYANNOTE[UI] candidate validation FAILED '
        'type=${error.runtimeType} error=$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _status = l10n.pyannoteFailure;
        _technicalError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _activeOperation = null;
        });
      } else {
        _activeOperation = null;
      }
    }
  }

  Future<void> _shareLast() async {
    final artifacts = _lastArtifacts;
    if (artifacts == null) return;
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
                id: 'benchmark_10m',
                title: l10n.pyannoteBenchmark10Min,
                kind: 'button',
                enabled: !_running,
                onActivate: _runBenchmark,
              ),
              AccessibleListRow(
                id: 'candidate_validation_5x10m',
                title: l10n.pyannoteCandidateValidation5x10m,
                kind: 'button',
                enabled: !_running,
                onActivate: _runCandidateValidation,
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
