import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/media_export_destination_service.dart';
import '../services/sonartube_media_export_service.dart';
import '../services/sonartube_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';

const String sonarTubeSaveMediaLabel = 'Salva media';

enum _SonarTubeDoneAction { saveDocuments, share }

enum _SonarTubeSaveFormat { mp4, mp3 }

/// Saves one SonarTube video to a temporary local export and then presents the
/// same destination choice used by Media Cutter and AI audio descriptions.
Future<void> saveSonarTubeMediaWithDestination(
  BuildContext context, {
  required SonarTubeService service,
  required SonarTubeItem item,
}) async {
  if (item.kind != SonarTubeItemKind.video || item.isLive) return;

  final l10n = AppLocalizations.of(context);
  final format = await showDialog<_SonarTubeSaveFormat>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Text(l10n.sonarTubeSaveFormatPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _SonarTubeSaveFormat.mp3,
            ),
            child: Text(l10n.sonarTubeSaveAsMp3),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _SonarTubeSaveFormat.mp4,
            ),
            child: Text(l10n.sonarTubeSaveAsMp4),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || format == null) return;

  final exporter = SonarTubeMediaExportService();
  final exportController = SonarTubeMediaExportController();
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
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, fraction, _) {
              final percent = (fraction.clamp(0.0, 1.0) * 100).round();
              final progressLabel = '${l10n.mediaCutterSaving}: $percent%';
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
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: cancelling,
              builder: (context, isCancelling, _) => TextButton(
                onPressed: isCancelling
                    ? null
                    : () {
                        cancelled = true;
                        cancelling.value = true;
                        unawaited(exportController.cancel());
                      },
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      );
    },
  );

  await WidgetsBinding.instance.endOfFrame;

  String? filePath;
  try {
    filePath = switch (format) {
      _SonarTubeSaveFormat.mp4 => await exporter.exportMp4(
          service: service,
          item: item,
          controller: exportController,
          onProgress: (fraction) {
            if (!cancelled) progress.value = fraction;
          },
        ),
      _SonarTubeSaveFormat.mp3 => await exporter.exportMp3(
          service: service,
          item: item,
          controller: exportController,
          onProgress: (fraction) {
            if (!cancelled) progress.value = fraction;
          },
        ),
    };
  } on SonarTubeMediaExportCancelledException {
    cancelled = true;
    await AppLogger.log('SonarTube save media: export cancelled by user');
  } catch (error, stack) {
    await AppLogger.log('SonarTube save media: export failed error=$error');
    await AppLogger.log('SonarTube save media: export stack $stack');
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

  if (cancelled) {
    if (filePath != null) await exporter.cleanup(filePath);
    return;
  }

  if (!context.mounted) {
    if (filePath != null) await exporter.cleanup(filePath);
    return;
  }
  if (filePath == null) {
    showStatusMessage(context, l10n.technicalErrorGeneric);
    return;
  }

  final destination = MediaExportDestinationService();
  while (true) {
    if (!context.mounted) {
      await exporter.cleanup(filePath);
      return;
    }
    final action = await showDialog<_SonarTubeDoneAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Text(l10n.mediaProcessingCompleted),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _SonarTubeDoneAction.share,
              ),
              child: Text(l10n.share),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _SonarTubeDoneAction.saveDocuments,
              ),
              child: Text(l10n.saveInSonarpadDocuments),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) continue;

    if (action == _SonarTubeDoneAction.share) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(filePath)],
            text: p.basename(filePath),
          ),
        );
        await exporter.cleanup(filePath);
        return;
      } catch (error) {
        await AppLogger.log('SonarTube save media: share failed error=$error');
        if (context.mounted) {
          showStatusMessage(context, l10n.technicalErrorGeneric);
        }
        continue;
      }
    }

    try {
      await destination.saveInSonarpadDocuments(
        filePath,
        originalName: p.basename(filePath),
      );
      if (!context.mounted) {
        await exporter.cleanup(filePath);
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Text(l10n.exportSavedInSonarpad),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.ok),
              ),
            ],
          ),
        ),
      );
      await exporter.cleanup(filePath);
      return;
    } catch (error) {
      await AppLogger.log(
        'SonarTube save media: save in Documents failed error=$error',
      );
      if (context.mounted) {
        showStatusMessage(context, l10n.technicalErrorGeneric);
      }
    }
  }
}
