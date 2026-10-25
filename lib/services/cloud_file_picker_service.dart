import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_lookup.dart';
import '../utils/app_logger.dart';

/// Native picker followed by a cancellable, byte-counted import.
/// iOS can download a provider item BEFORE didPickDocumentsAt is called; neither
/// file_picker nor this bridge receives progress for that system-owned phase.
/// Percentages below describe only the subsequent copy into Sonarpad.
/// Desktop platforms retain their previous picker implementation.
class CloudFilePicker {
  CloudFilePicker._();

  static const MethodChannel _channel =
      MethodChannel('sonarpad/cloud_file_picker');
  static const EventChannel _events =
      EventChannel('sonarpad/cloud_file_picker_progress');
  static bool _busy = false;

  // Test seam for the method/event-channel contract on desktop test runners.
  // It is read only inside assert, and cannot change a release build's routing.
  static bool? debugUseNativePicker;

  static Future<FilePickerResult?> pickFiles({
    required BuildContext context,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
    String? Function(String extension)? unsupportedFileMessage,
  }) async {
    var useNativePicker = Platform.isAndroid || Platform.isIOS;
    assert(() {
      useNativePicker = debugUseNativePicker ?? useNativePicker;
      return true;
    }());
    if (!useNativePicker) {
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
    final elapsed = Stopwatch()..start();
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    Timer? dialogTimer;
    DialogRoute<void>? dialogRoute;
    NavigatorState? dialogNavigator;

    void openDialog() {
      if (dialogIsOpen || importCompleted || !context.mounted) {
        return;
      }
      dialogIsOpen = true;
      dialogNavigator = Navigator.of(context, rootNavigator: true);
      final route = DialogRoute<void>(
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
                      : (state.stage == 'preparing' || (state.stage == 'copying' && state.current == 0))
                      ? labels.preparing
                      : '${labels.copying}. ${percent == null ? labels.unknownSize : '$percent%'}';
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
                      ExcludeSemantics(
                        child: LinearProgressIndicator(value: fraction),
                      ),
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
                            unawaited(
                              _channel.invokeMethod<void>('cancel').catchError(
                                (Object error, StackTrace stack) {
                                  unawaited(AppLogger.log(
                                    'Cloud file picker: cancel failed $error\n$stack',
                                  ));
                                },
                              ),
                            );
                          },
                    child: Text(labels.cancel),
                  ),
                ),
              ],
            ),
          );
        },
      );
      dialogRoute = route;
      unawaited(dialogNavigator!.push<void>(route));
    }

    void scheduleDialog() {
      if (dialogIsOpen || dialogTimer != null || importCompleted) return;
      // Do not flash a finished copy at 100% just to make it look observable.
      // Only an import still in progress after this delay needs a modal route.
      dialogTimer = Timer(const Duration(milliseconds: 250), openDialog);
    }

    try {
      unawaited(AppLogger.log(
        'Cloud file picker: opening native picker on '
        '${Platform.isIOS ? 'iOS' : 'Android'} request=$requestId',
      ));
      subscription = _events.receiveBroadcastStream().listen((raw) {
        if (raw is! Map || importCompleted) {
          return;
        }
        final data = Map<String, dynamic>.from(raw);
        final eventRequest = data['requestId']?.toString();
        if (eventRequest != null && eventRequest != requestId) return;
        final stage = data['stage']?.toString() ?? 'copying';
        if (stage == 'picker_presented' || stage == 'selection_received' ||
            stage == 'picker_dismissed') {
          // Lifecycle is observable; selecting versus cloud downloading inside
          // Files is not. In particular, never present a loading modal here.
          unawaited(AppLogger.log(
            'Cloud file picker: stage=$stage request=$requestId '
            'elapsedMs=${elapsed.elapsedMilliseconds} '
            'nativeElapsedMs=${data['elapsedMs']} files=${data['fileCount']}',
          ));
          return;
        }
        final copied = (data['copied'] as num?)?.toInt() ?? 0;
        final total = (data['total'] as num?)?.toInt() ?? -1;
        final decile = total > 0 ? (copied * 10 ~/ total).clamp(0, 10).toInt() : -1;
        if (stage == 'preparing' ||
            (stage == 'copying' && decile != lastReportedDecile)) {
          lastReportedDecile = decile;
          unawaited(AppLogger.log(
            'Cloud file picker: stage=$stage copied=$copied total=$total '
            'request=$requestId elapsedMs=${elapsed.elapsedMilliseconds}',
          ));
        }
        if (stage == 'preparing' || stage == 'copying') {
          scheduleDialog();
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
        'requestId': requestId,
        'allowMultiple': allowMultiple,
        'allowedExtensions': type == FileType.custom
            ? (allowedExtensions ?? <String>[])
            : <String>[],
      });
      importCompleted = true;
      dialogTimer?.cancel();
      if (cancelRequested || raw == null || raw.isEmpty) {
        return null;
      }
      final completedBytes = raw.fold<int>(0, (sum, item) {
        if (item is! Map) return sum;
        return sum + ((item['size'] as num?)?.toInt() ?? 0);
      });
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
        final message = error.code == 'unsupported_file_type' && error.details is String
            ? unsupportedFileMessage?.call((error.details as String).toLowerCase())
            : null;
        _showPickerError(context, message: message);
      }
      return null;
    } catch (error, stack) {
      await AppLogger.log('Cloud file picker: unexpected error=$error\n$stack');
      if (context.mounted) {
        _showPickerError(context);
      }
      return null;
    } finally {
      importCompleted = true;
      dialogTimer?.cancel();
      await subscription?.cancel();
      final route = dialogRoute;
      final navigator = dialogNavigator;
      if (route != null && navigator != null && navigator.mounted) {
        // Close only our own route: another modal might have been opened by
        // navigation or error handling while the native import was running.
        if (route.isCurrent) {
          navigator.pop();
        } else if (route.isActive) {
          navigator.removeRoute(route);
        }
        // popped completes before the exit animation; completed waits until
        // the ValueListenableBuilder is actually removed before disposing it.
        await route.completed;
      }
      progress.dispose();
      _busy = false;
    }
  }
  static void _showPickerError(BuildContext context, {String? message}) {
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      duration: Duration(seconds: message == null ? 4 : 15),
      content: Text(message ?? l10n.fileOpenError(l10n.technicalErrorGeneric)),
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
  double? get fraction => total <= 0 || (current == 0 && stage != 'done')
      ? null : (current / total).clamp(0.0, 1.0);
}

class _CloudPickerLabels {
  const _CloudPickerLabels(this.loading, this.preparing, this.unknownSize,
      this.copying, this.cancel, this.cancelling);
  final String loading;
  final String preparing;
  final String unknownSize;
  final String copying;
  final String cancel;
  final String cancelling;

  static _CloudPickerLabels forLanguage(String language) {
    final l10n = lookupSupportedAppLocalizations(language);
    return _CloudPickerLabels(
      l10n.cloudFilePickerLoading,
      l10n.cloudFilePickerPreparing,
      l10n.cloudFilePickerUnknownSize,
      l10n.cloudFilePickerCopying,
      l10n.cancel,
      l10n.cloudFilePickerCancelling,
    );
  }
}
