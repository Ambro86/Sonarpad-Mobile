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

/// Saves one SonarTube video to a temporary local export and then presents the
/// same destination choice used by Media Cutter and AI audio descriptions.
Future<void> saveSonarTubeMediaWithDestination(
  BuildContext context, {
  required SonarTubeService service,
  required SonarTubeItem item,
}) async {
  if (item.kind != SonarTubeItemKind.video || item.isLive) return;

  final l10n = AppLocalizations.of(context);
  final exporter = SonarTubeMediaExportService();
  BuildContext? progressContext;

  final progressFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      progressContext = dialogContext;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: Semantics(
            liveRegion: true,
            container: true,
            label: l10n.mediaCutterSaving,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Flexible(child: Text(l10n.mediaCutterSaving)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  await WidgetsBinding.instance.endOfFrame;

  String? filePath;
  try {
    filePath = await exporter.export(service: service, item: item);
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
