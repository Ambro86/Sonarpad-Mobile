import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/online_ai_audiodescription_source_service.dart';
import '../services/sonartube_media_export_service.dart';
import '../services/sonartube_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../screens/create_ai_audiodescription_screen.dart';

const String onlineCreateAiAudiodescriptionLabel =
    'Crea audiodescrizione con IA';

Future<void> createAiAudiodescriptionFromSonarTube(
  BuildContext context, {
  required SonarTubeService service,
  required SonarTubeItem item,
}) async {
  if (item.kind != SonarTubeItemKind.video || item.isLive) return;
  await _prepareAndOpenAiAudiodescription(
    context,
    includeSourceVideoWithProjectOutput: true,
    cancellablePreparation: true,
    prepare: (controller, onProgress) =>
        OnlineAiAudiodescriptionSourceService().importSonarTubeVideo(
      service: service,
      item: item,
      controller: controller,
      onProgress: onProgress,
    ),
  );
}

Future<void> createAiAudiodescriptionFromRemoteVideo(
  BuildContext context, {
  required String url,
  required String title,
  Map<String, String> headers = const <String, String>{},
}) async {
  await _prepareAndOpenAiAudiodescription(
    context,
    prepare: (_, __) => OnlineAiAudiodescriptionSourceService().importRemoteVideo(
      url: url,
      title: title,
      headers: headers,
    ),
  );
}

Future<void> _prepareAndOpenAiAudiodescription(
  BuildContext context, {
  required Future<String> Function(
    SonarTubeMediaExportController? controller,
    void Function(double fraction)? onProgress,
  ) prepare,
  bool includeSourceVideoWithProjectOutput = false,
  bool cancellablePreparation = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final controller =
      cancellablePreparation ? SonarTubeMediaExportController() : null;
  final progress = ValueNotifier<double>(0.0);
  final cancelling = ValueNotifier<bool>(false);
  var cancelled = false;
  BuildContext? progressContext;
  final progressFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      progressContext = dialogContext;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: cancellablePreparation
              ? ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (context, fraction, _) {
                    final percent =
                        (fraction.clamp(0.0, 1.0) * 100).round();
                    final progressLabel =
                        '${l10n.sonarTubeResolving}: $percent%';
                    return Semantics(
                      liveRegion: true,
                      container: true,
                      label: progressLabel,
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LinearProgressIndicator(
                              value: fraction.clamp(0.0, 1.0).toDouble(),
                            ),
                            const SizedBox(height: 8),
                            Text(progressLabel, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : Semantics(
                  liveRegion: true,
                  container: true,
                  label: l10n.sonarTubeResolving,
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 16),
                        Flexible(child: Text(l10n.sonarTubeResolving)),
                      ],
                    ),
                  ),
                ),
          actions: cancellablePreparation
              ? [
                  ValueListenableBuilder<bool>(
                    valueListenable: cancelling,
                    builder: (context, isCancelling, _) => TextButton(
                      onPressed: isCancelling
                          ? null
                          : () {
                              cancelled = true;
                              cancelling.value = true;
                              final cancelController = controller;
                              if (cancelController != null) {
                                unawaited(cancelController.cancel());
                              }
                            },
                      child: Text(l10n.cancel),
                    ),
                  ),
                ]
              : null,
        ),
      );
    },
  );

  await WidgetsBinding.instance.endOfFrame;
  String? sourcePath;
  try {
    sourcePath = await prepare(
      controller,
      cancellablePreparation
          ? (fraction) {
              if (!cancelled) progress.value = fraction;
            }
          : null,
    );
  } on SonarTubeMediaExportCancelledException {
    cancelled = true;
    await AppLogger.log(
      'Online AI audio description: SonarTube source preparation cancelled',
    );
  } catch (error, stack) {
    await AppLogger.log(
      'Online AI audio description: source preparation failed error=$error\n$stack',
    );
  } finally {
    final dialogContext = progressContext;
    if (dialogContext != null && dialogContext.mounted) {
      try {
        Navigator.of(dialogContext).pop();
      } catch (_) {}
    }
    try {
      await progressFuture;
    } catch (_) {}
    progress.dispose();
    cancelling.dispose();
  }

  if (cancelled || !context.mounted) return;
  if (sourcePath == null || sourcePath.trim().isEmpty) {
    showStatusMessage(context, l10n.technicalErrorGeneric);
    return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/audio-description/create-ai'),
      builder: (_) => CreateAiAudiodescriptionScreen(
        initialSourcePath: sourcePath,
        includeSourceVideoWithProjectOutput:
            includeSourceVideoWithProjectOutput,
      ),
    ),
  );
}
