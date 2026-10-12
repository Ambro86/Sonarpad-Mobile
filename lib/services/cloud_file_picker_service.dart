import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../utils/app_logger.dart';

/// Native document picker with a real, cancellable stream copy. On iOS and
/// Android the standard file_picker plugin may first download a cloud file
/// before returning the path and cannot report intermediate byte progress.
/// Keeping that picker would make any progress percentage misleading.
/// Other desktop platforms retain their previous picker implementation.
class CloudFilePicker {
  CloudFilePicker._();

  static const MethodChannel _channel =
      MethodChannel('sonarpad/cloud_file_picker');
  static const EventChannel _events =
      EventChannel('sonarpad/cloud_file_picker_progress');
  static bool _busy = false;

  static Future<FilePickerResult?> pickFiles({
    required BuildContext context,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return FilePicker.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: withData,
      );
    }
    if (!context.mounted || _busy) {
      return null;
    }
    _busy = true;
    final locale = Localizations.localeOf(context);
    final language = locale.countryCode == 'BR' && locale.languageCode == 'pt'
        ? 'pt_BR'
        : locale.languageCode;
    final labels = _CloudPickerLabels.forLanguage(language);
    final progress = ValueNotifier<_CloudCopyProgress>(
      const _CloudCopyProgress(stage: 'preparing', current: 0, total: -1),
    );
    StreamSubscription<dynamic>? subscription;
    bool dialogIsOpen = false;
    bool cancelRequested = false;

    void openDialog() {
      if (dialogIsOpen || !context.mounted) {
        return;
      }
      dialogIsOpen = true;
      // Do not wait for this Future: native stream copying must continue while
      // the accessible dialog is visible.
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(labels.loading),
              content: ValueListenableBuilder<_CloudCopyProgress>(
                valueListenable: progress,
                builder: (context, state, _) {
                  final fraction = state.fraction;
                  final percent = fraction == null ? null : (fraction * 100).floor();
                  final detail = state.stage == 'cancelling'
                      ? labels.cancelling
                      : state.stage == 'preparing'
                      ? labels.preparing
                      : (percent == null ? labels.unknownSize : '$percent%');
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // VoiceOver/TalkBack announce only the stable status;
                      // changing numbers remain available when navigating.
                      Semantics(
                        label: '${labels.loading}. $detail',
                        child: ExcludeSemantics(
                          child: Text(detail),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: fraction),
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: cancelRequested
                      ? null
                      : () {
                          cancelRequested = true;
                          progress.value = const _CloudCopyProgress(
                            stage: 'cancelling', current: 0, total: -1,
                          );
                          unawaited(_channel.invokeMethod<void>('cancel'));
                        },
                  child: Text(labels.cancel),
                ),
              ],
            ),
          );
        },
      ));
    }

    try {
      subscription = _events.receiveBroadcastStream().listen((raw) {
        if (raw is! Map) {
          return;
        }
        final data = Map<String, dynamic>.from(raw);
        final stage = data['stage']?.toString() ?? 'copying';
        if (stage == 'preparing' || stage == 'copying') {
          openDialog();
          if (!cancelRequested) {
            progress.value = _CloudCopyProgress(
              stage: stage,
              current: (data['copied'] as num?)?.toInt() ?? 0,
              total: (data['total'] as num?)?.toInt() ?? -1,
            );
          }
        }
      }, onError: (Object error) {
        unawaited(AppLogger.log('Cloud file picker: progress stream error=$error'));
      });
      final raw = await _channel.invokeMethod<List<dynamic>>('pickFiles', {
        'allowMultiple': allowMultiple,
        'allowedExtensions': type == FileType.custom
            ? (allowedExtensions ?? <String>[])
            : <String>[],
      });
      if (cancelRequested || raw == null || raw.isEmpty) {
        return null;
      }
      final files = <PlatformFile>[];
      for (final entry in raw) {
        final item = Map<String, dynamic>.from(entry as Map);
        final path = item['path'] as String?;
        if (path == null || path.isEmpty) {
          continue;
        }
        files.add(PlatformFile(
          name: item['name'] as String? ?? path.split(Platform.pathSeparator).last,
          size: (item['size'] as num?)?.toInt() ?? 0,
          path: path,
        ));
      }
      return files.isEmpty ? null : FilePickerResult(files);
    } on PlatformException catch (error, stack) {
      if (error.code == 'cancelled' || cancelRequested) {
        return null;
      }
      await AppLogger.log('Cloud file picker: ${error.code}: ${error.message}\n$stack');
      if (context.mounted) {
        _showPickerError(context);
      }
      return null;
    } catch (error, stack) {
      await AppLogger.log('Cloud file picker: unexpected error=$error\n$stack');
      if (context.mounted) {
        _showPickerError(context);
      }
      return null;
    } finally {
      await subscription?.cancel();
      if (dialogIsOpen && context.mounted) {
        // showDialog pushes synchronously; the builder may not yet have run
        // when a very small file finishes copying. Pop the root route safely.
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
      progress.dispose();
      _busy = false;
    }
  }
  static void _showPickerError(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(l10n.fileOpenError(l10n.technicalErrorGeneric)),
    ));
  }
}

class _CloudCopyProgress {
  const _CloudCopyProgress({
    required this.stage,
    required this.current,
    required this.total,
  });
  final String stage;
  final int current;
  final int total;
  double? get fraction => total <= 0 ? null : (current / total).clamp(0.0, 1.0);
}

class _CloudPickerLabels {
  const _CloudPickerLabels(this.loading, this.preparing, this.unknownSize, this.cancel, this.cancelling);
  final String loading;
  final String preparing;
  final String unknownSize;
  final String cancel;
  final String cancelling;

  static _CloudPickerLabels forLanguage(String language) {
    switch (language) {
      case 'it': return const _CloudPickerLabels('Caricamento del file in corso', 'Preparazione del file dal cloud…', 'Caricamento in corso…', 'Annulla', 'Annullamento in corso…');
      case 'fr': return const _CloudPickerLabels('Chargement du fichier', 'Préparation du fichier cloud…', 'Chargement en cours…', 'Annuler', 'Annulation…');
      case 'es': return const _CloudPickerLabels('Cargando archivo', 'Preparando archivo de la nube…', 'Cargando…', 'Cancelar', 'Cancelando…');
      case 'de': return const _CloudPickerLabels('Datei wird geladen', 'Cloud-Datei wird vorbereitet…', 'Wird geladen…', 'Abbrechen', 'Wird abgebrochen…');
      case 'pt': return const _CloudPickerLabels('A carregar ficheiro', 'A preparar ficheiro da nuvem…', 'A carregar…', 'Cancelar', 'Cancelando…');
      case 'pt_BR': return const _CloudPickerLabels('Carregando arquivo', 'Preparando arquivo da nuvem…', 'Carregando…', 'Cancelar', 'Cancelando…');
      case 'pl': return const _CloudPickerLabels('Wczytywanie pliku', 'Przygotowywanie pliku z chmury…', 'Wczytywanie…', 'Anuluj', 'Anulowanie…');
      case 'cs': return const _CloudPickerLabels('Načítání souboru', 'Příprava souboru z cloudu…', 'Načítání…', 'Zrušit', 'Rušení…');
      case 'ro': return const _CloudPickerLabels('Se încarcă fișierul', 'Se pregătește fișierul din cloud…', 'Se încarcă…', 'Anulează', 'Se anulează…');
      case 'uk': return const _CloudPickerLabels('Завантаження файлу', 'Підготовка файлу з хмари…', 'Завантаження…', 'Скасувати', 'Скасування…');
      case 'zh': return const _CloudPickerLabels('正在加载文件', '正在准备云端文件…', '正在加载…', '取消', '正在取消…');
      default: return const _CloudPickerLabels('Loading file', 'Preparing cloud file…', 'Loading…', 'Cancel', 'Cancelling…');
    }
  }
}
