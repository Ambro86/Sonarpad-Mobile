import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/media_preservation_service.dart';
import '../utils/status_message.dart';

class _PreserveDialogState {
  const _PreserveDialogState({
    required this.progress,
    required this.cancelling,
    required this.stage,
    this.completed = false,
  });

  final double? progress;
  final bool cancelling;
  final MediaPreservationStage stage;
  final bool completed;
}

/// Runs a media preservation download behind a clean Material progress dialog.
/// The transfer itself remains asynchronous and streamed by
/// [MediaPreservationService], so this dialog never blocks the Flutter UI
/// thread. The Cancel button aborts the active HTTP transfer and the service
/// removes any partial temporary file. After a successful save, the same
/// dialog becomes a non-dismissible confirmation and remains on screen until
/// the user explicitly presses OK or the optional saved-file action.
Future<MediaPreservationResult?> preserveMediaWithProgress(
  BuildContext context, {
  required String title,
  required Future<String> Function() resolveUrl,
  String? fileName,
  String? savedActionLabel,
  Future<void> Function(String path)? onSavedAction,
}) async {
  final l10n = AppLocalizations.of(context);
  final token = MediaPreservationCancellationToken();
  final state = ValueNotifier<_PreserveDialogState>(
    const _PreserveDialogState(
      progress: 0,
      cancelling: false,
      stage: MediaPreservationStage.downloading,
    ),
  );
  BuildContext? dialogContext;
  var lastPercent = -1;
  String? savedPath;

  final dialogFuture = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.preserveMedia),
            content: ValueListenableBuilder<_PreserveDialogState>(
              valueListenable: state,
              builder: (context, value, _) {
                if (value.completed) {
                  return Semantics(
                    liveRegion: true,
                    container: true,
                    label: l10n.preserveMediaSaved,
                    child: ExcludeSemantics(
                      child: Text(l10n.preserveMediaSaved),
                    ),
                  );
                }

                final fraction = value.progress;
                final statusLabel =
                    value.stage == MediaPreservationStage.downloading
                        ? l10n.download
                        : l10n.preserveMediaSaving;
                final percent = fraction == null
                    ? null
                    : (fraction * 100).round().clamp(0, 100);
                return Semantics(
                  liveRegion: true,
                  container: true,
                  label: statusLabel,
                  value: percent == null ? null : '$percent%',
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(statusLabel),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: fraction),
                        const SizedBox(height: 12),
                        Text(
                          percent == null ? '—%' : '$percent%',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            actions: [
              ValueListenableBuilder<_PreserveDialogState>(
                valueListenable: state,
                builder: (context, value, _) {
                  if (value.completed) {
                    return Wrap(
                      children: [
                        if (savedPath != null && onSavedAction != null && savedActionLabel != null)
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(savedActionLabel),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(l10n.ok),
                        ),
                      ],
                    );
                  }
                  return TextButton(
                    onPressed: value.cancelling ||
                            value.stage == MediaPreservationStage.saving
                        ? null
                        : () {
                            state.value = _PreserveDialogState(
                              progress: value.progress,
                              cancelling: true,
                              stage: value.stage,
                            );
                            token.cancel();
                          },
                    child: Text(l10n.cancel),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

  // Let Material mount the dialog before starting network/file activity.
  await WidgetsBinding.instance.endOfFrame;

  try {
    token.throwIfCancelled();
    final url = await resolveUrl();
    token.throwIfCancelled();
    final result = await MediaPreservationService().preserveMp3(
      url: url,
      title: title,
      fileName: fileName,
      onSaved: onSavedAction == null ? null : (path) => savedPath = path,
      cancellationToken: token,
      onProgress: (progress) {
        final fraction = progress.fraction;
        if (fraction == null) {
          if (state.value.progress != null) {
            state.value = _PreserveDialogState(
              progress: null,
              cancelling: state.value.cancelling,
              stage: progress.stage,
            );
          }
          return;
        }
        final percent = (fraction * 100).floor().clamp(0, 100);
        if (percent == lastPercent &&
            progress.stage == MediaPreservationStage.downloading) {
          return;
        }
        lastPercent = percent;
        state.value = _PreserveDialogState(
          progress: fraction,
          cancelling: state.value.cancelling,
          stage: progress.stage,
        );
      },
    );
    if (!context.mounted) return result;
    if (result == MediaPreservationResult.savedInSonarpad) {
      state.value = const _PreserveDialogState(
        progress: 1,
        cancelling: false,
        stage: MediaPreservationStage.saving,
        completed: true,
      );
      // The success confirmation intentionally remains modal until the user
      // chooses OK or the saved-file action. PopScope prevents every
      // other dismissal path.
      final openSaved = await dialogFuture;
      dialogContext = null;
      if (openSaved == true && context.mounted && savedPath != null) {
        await onSavedAction!(savedPath!);
      }
    }
    return result;
  } on MediaPreservationCancelled {
    return null;
  } catch (_) {
    if (context.mounted) {
      showStatusMessage(context, l10n.preserveMediaError);
    }
    return null;
  } finally {
    final activeDialogContext = dialogContext;
    if (activeDialogContext != null && activeDialogContext.mounted) {
      try {
        Navigator.of(activeDialogContext).pop();
      } catch (_) {}
    }
    try {
      await dialogFuture;
    } catch (_) {}
    state.dispose();
  }
}
