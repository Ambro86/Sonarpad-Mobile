#!/usr/bin/env python3
from __future__ import annotations
import json, shutil, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "lib" / "services" / "pyannote_benchmark_service.dart"
SCREEN = ROOT / "lib" / "screens" / "pyannote_parity_test_screen.dart"
L10N = ROOT / "lib" / "l10n"

PROVIDER_OLD = "      if (config.coreMLFlags != null) {\n        await AppLogger.log(\n          'PYANNOTE[BENCH][COREML] append provider id=${config.id} '\n          'flags=${config.coreMLFlags!.name}',\n        );\n        final appended = options.appendCoreMLProvider(config.coreMLFlags!);\n        await AppLogger.log(\n          'PYANNOTE[BENCH][COREML] append result id=${config.id} appended=$appended',\n        );\n      }\n\n      final sessionStarted = DateTime.now();\n"
PROVIDER_NEW = "      if (config.coreMLFlags != null) {\n        await AppLogger.log(\n          'PYANNOTE[BENCH][COREML] append provider id=${config.id} '\n          'flags=${config.coreMLFlags!.name}',\n        );\n        final appended = options.appendCoreMLProvider(config.coreMLFlags!);\n        await AppLogger.log(\n          'PYANNOTE[BENCH][COREML] append result id=${config.id} appended=$appended',\n        );\n      } else if (config.provider == OrtProvider.xnnpack.value) {\n        await AppLogger.log(\n          'PYANNOTE[BENCH][XNNPACK] append provider id=${config.id} '\n          'xnnpackThreads=${config.intraOpThreads}',\n        );\n        final appended = options.appendXnnpackProvider();\n        await AppLogger.log(\n          'PYANNOTE[BENCH][XNNPACK] append result id=${config.id} appended=$appended',\n        );\n        if (!appended) {\n          throw StateError('PYANNOTE_XNNPACK_APPEND_FAILED');\n        }\n        options.setIntraOpNumThreads(1);\n        await AppLogger.log(\n          'PYANNOTE[BENCH][XNNPACK] id=${config.id} '\n          'xnnpackThreads=${config.intraOpThreads} ortIntraOpThreads=1',\n        );\n      }\n\n      final sessionStarted = DateTime.now();\n"
XNN_METHOD = '\n  Future<PyannoteBenchmarkReport> runXnnpackBenchmark({\n    required String sourcePath,\n    void Function(double progress)? onProgress,\n  }) async {\n    final started = DateTime.now();\n    bool? wakelockWasEnabled;\n    try {\n      try {\n        wakelockWasEnabled = await WakelockPlus.enabled;\n        await AppLogger.log(\n          \'PYANNOTE[XNNPACK][WAKELOCK] before enabled=$wakelockWasEnabled; enabling\',\n        );\n        await WakelockPlus.enable();\n        await AppLogger.log(\n          \'PYANNOTE[XNNPACK][WAKELOCK] enabled=${await WakelockPlus.enabled}\',\n        );\n      } catch (error, stackTrace) {\n        await AppLogger.log(\n          \'PYANNOTE[XNNPACK][WAKELOCK] enable FAILED \'\n          \'type=${error.runtimeType} error=$error\\n$stackTrace\',\n        );\n      }\n\n      final source = File(sourcePath);\n      final sourceExists = await source.exists();\n      final sourceBytes = sourceExists ? await source.length() : -1;\n      await AppLogger.log(\n        \'PYANNOTE[XNNPACK] start source="$sourcePath" exists=$sourceExists \'\n        \'bytes=$sourceBytes limitSeconds=$benchmarkSeconds \'\n        \'platform=${Platform.operatingSystem} \'\n        \'osVersion="${Platform.operatingSystemVersion}" \'\n        \'processors=${Platform.numberOfProcessors}\',\n      );\n      if (!sourceExists) {\n        throw StateError(\'PYANNOTE_XNNPACK_SOURCE_MISSING\');\n      }\n\n      final documents = await getApplicationDocumentsDirectory();\n      final outputDir = Directory(p.join(documents.path, \'pyannote_benchmarks\'));\n      await outputDir.create(recursive: true);\n      final stamp =\n          DateTime.now().toUtc().toIso8601String().replaceAll(\':\', \'-\');\n      final sourceBase = p\n          .basenameWithoutExtension(sourcePath)\n          .replaceAll(RegExp(r\'[^A-Za-z0-9._-]+\'), \'_\');\n      final wavPath =\n          p.join(outputDir.path, \'${sourceBase}_$stamp.xnnpack10m.wav\');\n      final jsonPath =\n          p.join(outputDir.path, \'${sourceBase}_$stamp.xnnpack.json\');\n\n      onProgress?.call(0.0);\n      await _createCanonicalTenMinuteWav(sourcePath, wavPath);\n      onProgress?.call(0.05);\n\n      final modelData = await rootBundle.load(PyannoteMobileService.modelAsset);\n      final modelBytes = modelData.buffer.asUint8List(\n        modelData.offsetInBytes,\n        modelData.lengthInBytes,\n      );\n      final modelHash = sha256.convert(modelBytes).toString();\n      if (modelHash != PyannoteMobileService.expectedModelSha256) {\n        throw StateError(\'PYANNOTE_XNNPACK_MODEL_SHA256_MISMATCH\');\n      }\n\n      OrtEnv.instance.ptr;\n      final providers = OrtEnv.instance.availableProviders();\n      final xnnpackAvailable = providers.contains(OrtProvider.xnnpack);\n      await AppLogger.log(\n        \'PYANNOTE[XNNPACK][ORT] version=${OrtEnv.version} \'\n        \'availableProviders=${providers.map((e) => e.value).toList()} \'\n        \'xnnpackAvailable=$xnnpackAvailable\',\n      );\n      if (!xnnpackAvailable) {\n        throw StateError(\'PYANNOTE_XNNPACK_PROVIDER_UNAVAILABLE\');\n      }\n\n      final configs = <PyannoteBenchmarkConfig>[\n        const PyannoteBenchmarkConfig(\n          id: \'xnn_ref_cpu_b32_t4_step1\',\n          provider: \'CPUExecutionProvider\',\n          batchSize: 32,\n          intraOpThreads: 4,\n          graphOptimization: GraphOptimizationLevel.ortEnableAll,\n          stepSec: 1.0,\n          paddingSec: 0.25,\n        ),\n        const PyannoteBenchmarkConfig(\n          id: \'xnnpack_b32_t2_step1\',\n          provider: \'XnnpackExecutionProvider\',\n          batchSize: 32,\n          intraOpThreads: 2,\n          graphOptimization: GraphOptimizationLevel.ortEnableAll,\n          stepSec: 1.0,\n          paddingSec: 0.25,\n        ),\n        const PyannoteBenchmarkConfig(\n          id: \'xnnpack_b32_t4_step1\',\n          provider: \'XnnpackExecutionProvider\',\n          batchSize: 32,\n          intraOpThreads: 4,\n          graphOptimization: GraphOptimizationLevel.ortEnableAll,\n          stepSec: 1.0,\n          paddingSec: 0.25,\n        ),\n        const PyannoteBenchmarkConfig(\n          id: \'xnnpack_b32_t6_step1\',\n          provider: \'XnnpackExecutionProvider\',\n          batchSize: 32,\n          intraOpThreads: 6,\n          graphOptimization: GraphOptimizationLevel.ortEnableAll,\n          stepSec: 1.0,\n          paddingSec: 0.25,\n        ),\n      ];\n\n      final outcomes = <PyannoteBenchmarkOutcome>[];\n      PyannoteBenchmarkOutcome? baseline;\n\n      for (var index = 0; index < configs.length; index++) {\n        final config = configs[index];\n        await AppLogger.log(\n          \'PYANNOTE[XNNPACK][CONFIG] ${index + 1}/${configs.length} START \'\n          \'${jsonEncode(config.toJson())}\',\n        );\n        PyannoteBenchmarkOutcome outcome;\n        try {\n          outcome = await _runConfig(\n            wavPath: wavPath,\n            modelBytes: modelBytes,\n            config: config,\n            onProgress: (inner) {\n              final overall = 0.05 +\n                  ((index + inner.clamp(0.0, 1.0)) / configs.length) * 0.90;\n              onProgress?.call(overall.clamp(0.0, 0.95));\n            },\n          );\n        } catch (error, stackTrace) {\n          await AppLogger.log(\n            \'PYANNOTE[XNNPACK][CONFIG] ${config.id} FAILED \'\n            \'type=${error.runtimeType} error=$error\\n$stackTrace\',\n          );\n          outcome = PyannoteBenchmarkOutcome(\n            config: config,\n            success: false,\n            sessionCreateMs: 0,\n            inferenceMs: 0,\n            totalMs: 0,\n            error: \'$error\',\n          );\n        }\n\n        if (index == 0 && outcome.success) {\n          baseline = outcome;\n          outcome = _withComparison(outcome, outcome);\n        } else if (outcome.success && baseline != null) {\n          outcome = _withComparison(outcome, baseline);\n        }\n        outcomes.add(outcome);\n\n        await AppLogger.log(\n          \'PYANNOTE[XNNPACK][RESULT] id=${config.id} \'\n          \'success=${outcome.success} provider=${config.provider} \'\n          \'threads=${config.intraOpThreads} \'\n          \'sessionCreateMs=${outcome.sessionCreateMs} \'\n          \'inferenceMs=${outcome.inferenceMs} totalMs=${outcome.totalMs} \'\n          \'frameSha256=${outcome.frameSha256} \'\n          \'exact=${outcome.exactFrameMatch} \'\n          \'differingFrames=${outcome.differingFrames} \'\n          \'protectedLost=${outcome.protectedLostSeconds?.toStringAsFixed(6)} \'\n          \'speedup=${outcome.speedupVsBaseline?.toStringAsFixed(3)} \'\n          \'error=${outcome.error}\',\n        );\n      }\n\n      final exactXnnpack = outcomes\n          .where(\n            (item) =>\n                item.success &&\n                item.config.provider == OrtProvider.xnnpack.value &&\n                item.exactFrameMatch == true &&\n                (item.differingFrames ?? -1) == 0 &&\n                (item.protectedLostSeconds ?? double.infinity) <= 0.000001,\n          )\n          .toList()\n        ..sort((a, b) => a.inferenceMs.compareTo(b.inferenceMs));\n\n      final best = exactXnnpack.isEmpty ? null : exactXnnpack.first;\n      await AppLogger.log(\n        \'PYANNOTE[XNNPACK][FINAL] \'\n        \'baselineInferenceMs=${baseline?.inferenceMs} \'\n        \'baselineHash=${baseline?.frameSha256} \'\n        \'exactCandidates=${exactXnnpack.length} \'\n        \'best=${best?.config.id} \'\n        \'bestInferenceMs=${best?.inferenceMs} \'\n        \'bestHash=${best?.frameSha256} \'\n        \'bestSpeedup=${best?.speedupVsBaseline?.toStringAsFixed(3)} \'\n        \'allExact=${exactXnnpack.length == 3}\',\n      );\n\n      final payload = <String, Object?>{\n        \'schema\': \'sonarpad_pyannote_xnnpack_benchmark_v1\',\n        \'created_at_utc\': DateTime.now().toUtc().toIso8601String(),\n        \'source_file\': p.basename(sourcePath),\n        \'canonical_wav_file\': p.basename(wavPath),\n        \'benchmark_seconds\': benchmarkSeconds,\n        \'model_sha256\': modelHash,\n        \'onnxruntime_version\': OrtEnv.version,\n        \'platform\': Platform.operatingSystem,\n        \'os_version\': Platform.operatingSystemVersion,\n        \'processors\': Platform.numberOfProcessors,\n        \'xnnpack_available\': xnnpackAvailable,\n        \'total_elapsed_ms\': DateTime.now().difference(started).inMilliseconds,\n        \'best_exact_xnnpack\': best?.config.id,\n        \'results\': outcomes.map((e) => e.toJson()).toList(),\n      };\n      await File(jsonPath).writeAsString(\n        const JsonEncoder.withIndent(\'  \').convert(payload),\n        flush: true,\n      );\n      await AppLogger.log(\n        \'PYANNOTE[XNNPACK] report written path="$jsonPath" \'\n        \'bytes=${await File(jsonPath).length()}\',\n      );\n      onProgress?.call(1.0);\n      return PyannoteBenchmarkReport(\n        canonicalWavPath: wavPath,\n        reportJsonPath: jsonPath,\n        outcomes: outcomes,\n      );\n    } finally {\n      if (wakelockWasEnabled != null) {\n        try {\n          if (wakelockWasEnabled) {\n            await WakelockPlus.enable();\n          } else {\n            await WakelockPlus.disable();\n          }\n          await AppLogger.log(\n            \'PYANNOTE[XNNPACK][WAKELOCK] restored \'\n            \'enabled=${await WakelockPlus.enabled} \'\n            \'previous=$wakelockWasEnabled\',\n          );\n        } catch (error, stackTrace) {\n          await AppLogger.log(\n            \'PYANNOTE[XNNPACK][WAKELOCK] restore FAILED \'\n            \'type=${error.runtimeType} error=$error\\n$stackTrace\',\n          );\n        }\n      }\n    }\n  }\n\n'
SCREEN_METHOD = '\n  Future<void> _runXnnpackBenchmark() async {\n    if (_running) return;\n    final l10n = AppLocalizations.of(context);\n    final path = await _pickMedia(operation: \'xnnpack_benchmark_10m\');\n    if (path == null || !mounted) return;\n    setState(() {\n      _running = true;\n      _progress = 0.0;\n      _technicalError = null;\n      _lastArtifacts = null;\n      _status = l10n.pyannoteXnnpackBenchmarkPreparing;\n      _activeOperation = \'xnnpack_benchmark_10m\';\n    });\n    try {\n      final report = await _benchmarkService.runXnnpackBenchmark(\n        sourcePath: path,\n        onProgress: (progress) {\n          if (!mounted) return;\n          setState(() {\n            _progress = progress.clamp(0.0, 1.0).toDouble();\n          });\n        },\n      );\n      await AppLogger.log(\n        \'PYANNOTE[UI] XNNPACK benchmark completed \'\n        \'report="${report.reportJsonPath}" outcomes=${report.outcomes.length}\',\n      );\n      if (!mounted) return;\n      setState(() {\n        _progress = 1.0;\n        _status = l10n.pyannoteXnnpackBenchmarkCompleted;\n      });\n    } catch (error, stackTrace) {\n      await AppLogger.log(\n        \'PYANNOTE[UI] XNNPACK benchmark FAILED \'\n        \'type=${error.runtimeType} error=$error\\n$stackTrace\',\n      );\n      if (!mounted) return;\n      setState(() {\n        _status = l10n.pyannoteFailure;\n        _technicalError = error.toString();\n      });\n    } finally {\n      if (mounted) {\n        setState(() {\n          _running = false;\n          _activeOperation = null;\n        });\n      } else {\n        _activeOperation = null;\n      }\n    }\n  }\n\n'
SCREEN_ROW_OLD = "              AccessibleListRow(\n                id: 'candidate_validation_5x10m',\n                title: l10n.pyannoteCandidateValidation5x10m,\n                kind: 'button',\n                enabled: !_running,\n                onActivate: _runCandidateValidation,\n              ),\n"
SCREEN_ROW_NEW = "              AccessibleListRow(\n                id: 'xnnpack_benchmark_10m',\n                title: l10n.pyannoteXnnpackBenchmark10Min,\n                kind: 'button',\n                enabled: !_running,\n                onActivate: _runXnnpackBenchmark,\n              ),\n              AccessibleListRow(\n                id: 'candidate_validation_5x10m',\n                title: l10n.pyannoteCandidateValidation5x10m,\n                kind: 'button',\n                enabled: !_running,\n                onActivate: _runCandidateValidation,\n              ),\n"
TRANSLATIONS = {'app_it.arb': {'pyannoteXnnpackBenchmark10Min': 'Benchmark CPU vs XNNPACK: primi 10 minuti', 'pyannoteXnnpackBenchmarkPreparing': 'Confronto CPU e XNNPACK sui primi 10 minuti...', 'pyannoteXnnpackBenchmarkCompleted': 'Benchmark CPU vs XNNPACK completato. Controlla il log per parità e velocità.'}, 'app_en.arb': {'pyannoteXnnpackBenchmark10Min': 'CPU vs XNNPACK benchmark: first 10 minutes', 'pyannoteXnnpackBenchmarkPreparing': 'Comparing CPU and XNNPACK on the first 10 minutes...', 'pyannoteXnnpackBenchmarkCompleted': 'CPU vs XNNPACK benchmark completed. Check the log for parity and speed.'}, 'app_de.arb': {'pyannoteXnnpackBenchmark10Min': 'CPU-vs.-XNNPACK-Benchmark: erste 10 Minuten', 'pyannoteXnnpackBenchmarkPreparing': 'CPU und XNNPACK werden in den ersten 10 Minuten verglichen...', 'pyannoteXnnpackBenchmarkCompleted': 'CPU-vs.-XNNPACK-Benchmark abgeschlossen. Prüfe das Protokoll auf Parität und Geschwindigkeit.'}, 'app_es.arb': {'pyannoteXnnpackBenchmark10Min': 'Benchmark CPU vs XNNPACK: primeros 10 minutos', 'pyannoteXnnpackBenchmarkPreparing': 'Comparando CPU y XNNPACK en los primeros 10 minutos...', 'pyannoteXnnpackBenchmarkCompleted': 'Benchmark CPU vs XNNPACK completado. Revisa el registro para ver paridad y velocidad.'}, 'app_fr.arb': {'pyannoteXnnpackBenchmark10Min': 'Benchmark CPU vs XNNPACK : 10 premières minutes', 'pyannoteXnnpackBenchmarkPreparing': 'Comparaison du CPU et de XNNPACK sur les 10 premières minutes...', 'pyannoteXnnpackBenchmarkCompleted': 'Benchmark CPU vs XNNPACK terminé. Consultez le journal pour la parité et la vitesse.'}, 'app_pt.arb': {'pyannoteXnnpackBenchmark10Min': 'Benchmark CPU vs XNNPACK: primeiros 10 minutos', 'pyannoteXnnpackBenchmarkPreparing': 'Comparando CPU e XNNPACK nos primeiros 10 minutos...', 'pyannoteXnnpackBenchmarkCompleted': 'Benchmark CPU vs XNNPACK concluído. Verifique o registo para paridade e velocidade.'}, 'app_pt_BR.arb': {'pyannoteXnnpackBenchmark10Min': 'Benchmark CPU vs XNNPACK: primeiros 10 minutos', 'pyannoteXnnpackBenchmarkPreparing': 'Comparando CPU e XNNPACK nos primeiros 10 minutos...', 'pyannoteXnnpackBenchmarkCompleted': 'Benchmark CPU vs XNNPACK concluído. Verifique o log para paridade e velocidade.'}, 'app_pl.arb': {'pyannoteXnnpackBenchmark10Min': 'Benchmark CPU vs XNNPACK: pierwsze 10 minut', 'pyannoteXnnpackBenchmarkPreparing': 'Porównywanie CPU i XNNPACK na pierwszych 10 minutach...', 'pyannoteXnnpackBenchmarkCompleted': 'Benchmark CPU vs XNNPACK zakończony. Sprawdź dziennik pod kątem zgodności i szybkości.'}, 'app_cs.arb': {'pyannoteXnnpackBenchmark10Min': 'Benchmark CPU vs XNNPACK: prvních 10 minut', 'pyannoteXnnpackBenchmarkPreparing': 'Porovnávání CPU a XNNPACK na prvních 10 minutách...', 'pyannoteXnnpackBenchmarkCompleted': 'Benchmark CPU vs XNNPACK dokončen. Zkontrolujte protokol pro shodu a rychlost.'}, 'app_uk.arb': {'pyannoteXnnpackBenchmark10Min': 'Тест CPU проти XNNPACK: перші 10 хвилин', 'pyannoteXnnpackBenchmarkPreparing': 'Порівняння CPU та XNNPACK на перших 10 хвилинах...', 'pyannoteXnnpackBenchmarkCompleted': 'Тест CPU проти XNNPACK завершено. Перевірте журнал щодо паритету та швидкості.'}, 'app_zh.arb': {'pyannoteXnnpackBenchmark10Min': 'CPU 与 XNNPACK 基准测试：前 10 分钟', 'pyannoteXnnpackBenchmarkPreparing': '正在比较前 10 分钟的 CPU 与 XNNPACK...', 'pyannoteXnnpackBenchmarkCompleted': 'CPU 与 XNNPACK 基准测试完成。请查看日志中的一致性和速度结果。'}, 'app_zh_CN.arb': {'pyannoteXnnpackBenchmark10Min': 'CPU 与 XNNPACK 基准测试：前 10 分钟', 'pyannoteXnnpackBenchmarkPreparing': '正在比较前 10 分钟的 CPU 与 XNNPACK...', 'pyannoteXnnpackBenchmarkCompleted': 'CPU 与 XNNPACK 基准测试完成。请查看日志中的一致性和速度结果。'}}

def die(msg):
    raise SystemExit(msg)

def patch_service():
    if not SERVICE.is_file():
        die(f"Missing {SERVICE}")
    text = SERVICE.read_text(encoding="utf-8")
    if "appendXnnpackProvider()" not in text:
        if PROVIDER_OLD not in text:
            die("Could not find provider block in pyannote_benchmark_service.dart")
        text = text.replace(PROVIDER_OLD, PROVIDER_NEW, 1)
        print("added XNNPACK provider handling")
    else:
        print("XNNPACK provider handling already present")
    marker = "  Future<PyannoteCandidateValidationReport> runCandidateValidation({"
    if "runXnnpackBenchmark({" not in text:
        if marker not in text:
            die("Could not find runCandidateValidation marker")
        text = text.replace(marker, XNN_METHOD + marker, 1)
        print("added runXnnpackBenchmark")
    else:
        print("runXnnpackBenchmark already present")
    SERVICE.write_text(text, encoding="utf-8")

def patch_screen():
    if not SCREEN.is_file():
        die(f"Missing {SCREEN}")
    text = SCREEN.read_text(encoding="utf-8")
    marker = "  Future<void> _runCandidateValidation() async {"
    if "_runXnnpackBenchmark()" not in text:
        if marker not in text:
            die("Could not find _runCandidateValidation marker")
        text = text.replace(marker, SCREEN_METHOD + marker, 1)
        print("added XNNPACK UI handler")
    else:
        print("XNNPACK UI handler already present")
    if "id: 'xnnpack_benchmark_10m'" not in text:
        if SCREEN_ROW_OLD not in text:
            die("Could not find candidate validation row")
        text = text.replace(SCREEN_ROW_OLD, SCREEN_ROW_NEW, 1)
        print("added XNNPACK button")
    else:
        print("XNNPACK button already present")
    SCREEN.write_text(text, encoding="utf-8")

def patch_l10n():
    files = sorted(L10N.glob("app_*.arb"))
    if not files:
        die(f"No ARB files found in {L10N}")
    fallback = TRANSLATIONS["app_en.arb"]
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        vals = TRANSLATIONS.get(path.name, fallback)
        for key, value in vals.items():
            data[key] = value
            data["@" + key] = {"description": f"Localized text for {key}."}
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"updated {path.relative_to(ROOT)}")

def run(cmd):
    print("> " + " ".join(cmd))
    subprocess.run(cmd, cwd=ROOT, check=True)

def main():
    patch_service()
    patch_screen()
    patch_l10n()
    flutter = shutil.which("flutter")
    if flutter is None:
        fixed = Path(r"C:\src\flutter\bin\flutter.BAT")
        flutter = str(fixed) if fixed.exists() else None
    if flutter:
        run([flutter, "gen-l10n"])
        print("Localization generation completed.")
    else:
        print("Flutter not found; run 'flutter gen-l10n' manually.")
    dart = shutil.which("dart")
    if dart:
        try:
            run([dart, "format", str(SERVICE), str(SCREEN)])
        except subprocess.CalledProcessError:
            print("dart format failed; continuing.")
    print()
    print("XNNPACK benchmark setup completed.")
    print("Next command:")
    print("  flutter analyze lib")

if __name__ == "__main__":
    main()
