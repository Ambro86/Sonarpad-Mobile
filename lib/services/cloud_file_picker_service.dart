import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_lookup.dart';
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
    bool importCompleted = false;
    int lastReportedDecile = -1;
    DateTime? dialogOpenedAt;
    Future<void>? dialogClosed;

    void openDialog() {
      if (dialogIsOpen || !context.mounted) {
        return;
      }
      dialogIsOpen = true;
      dialogOpenedAt = DateTime.now();
      // Do not wait for this Future: native stream copying must continue while
      // the accessible dialog is visible.
      dialogClosed = showDialog<void>(
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
                ValueListenableBuilder<_CloudCopyProgress>(
                  valueListenable: progress,
                  builder: (context, state, _) => TextButton(
                    onPressed: cancelRequested || state.stage == 'done'
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
                ),
              ],
            ),
          );
        },
      );
    }

    try {
      unawaited(AppLogger.log(
        'Cloud file picker: opening native picker on '
        '${Platform.isIOS ? 'iOS' : 'Android'}',
      ));
      subscription = _events.receiveBroadcastStream().listen((raw) {
        if (raw is! Map || importCompleted) {
          return;
        }
        final data = Map<String, dynamic>.from(raw);
        final stage = data['stage']?.toString() ?? 'copying';
        final copied = (data['copied'] as num?)?.toInt() ?? 0;
        final total = (data['total'] as num?)?.toInt() ?? -1;
        final decile = total > 0 ? (copied * 10 ~/ total).clamp(0, 10).toInt() : -1;
        if (stage == 'preparing' ||
            (stage == 'copying' && decile != lastReportedDecile)) {
          lastReportedDecile = decile;
          unawaited(AppLogger.log(
            'Cloud file picker: stage=$stage copied=$copied total=$total',
          ));
        }
        if (stage == 'preparing' || stage == 'copying') {
          openDialog();
          if (!cancelRequested) {
            progress.value = _CloudCopyProgress(
              stage: stage,
              current: copied,
              total: total,
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
      // Small/cached iCloud imports can finish before the progress event is
      // rendered. In that case still show the same dialog for long enough to
      // be perceived, with 100% based on the bytes actually imported.
      openDialog();
      final completedBytes = raw.fold<int>(0, (sum, item) {
        if (item is! Map) return sum;
        return sum + ((item['size'] as num?)?.toInt() ?? 0);
      });
      importCompleted = true;
      progress.value = _CloudCopyProgress(
        stage: 'done',
        current: completedBytes,
        total: completedBytes,
      );
      unawaited(AppLogger.log(
        'Cloud file picker: import complete files=${raw.length} '
        'bytes=$completedBytes progressDialog=$dialogIsOpen',
      ));
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
      if (dialogIsOpen) {
        // iCloud may already have cached the file, so the native copy lasts
        // only milliseconds. Do not dismiss the dialog before VoiceOver can
        // find it. This delay is presentation time, NOT fabricated progress.
        if (!cancelRequested && dialogOpenedAt != null) {
          const minimumVisibility = Duration(milliseconds: 900);
          final elapsed = DateTime.now().difference(dialogOpenedAt!);
          if (elapsed < minimumVisibility) {
            await Future<void>.delayed(minimumVisibility - elapsed);
          }
        }
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        // Keep the notifier alive until the route has finished closing.
        if (dialogClosed != null) {
          await dialogClosed;
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
    final l10n = lookupSupportedAppLocalizations(language);
    return _CloudPickerLabels(
      l10n.cloudFilePickerLoading,
      l10n.cloudFilePickerPreparing,
      l10n.cloudFilePickerUnknownSize,
      l10n.cancel,
      l10n.cloudFilePickerCancelling,
    );
  }
}
