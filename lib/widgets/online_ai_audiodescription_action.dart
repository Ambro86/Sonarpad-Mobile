import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/online_ai_audiodescription_source_service.dart';
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
    prepare: () => OnlineAiAudiodescriptionSourceService().importSonarTubeVideo(
      service: service,
      item: item,
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
    prepare: () => OnlineAiAudiodescriptionSourceService().importRemoteVideo(
      url: url,
      title: title,
      headers: headers,
    ),
  );
}

Future<void> _prepareAndOpenAiAudiodescription(
  BuildContext context, {
  required Future<String> Function() prepare,
}) async {
  final l10n = AppLocalizations.of(context);
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
            label: 'Preparazione del video in corso',
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Flexible(child: Text('Preparazione del video in corso…')),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  await WidgetsBinding.instance.endOfFrame;
  String? sourcePath;
  try {
    sourcePath = await prepare();
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
  }

  if (!context.mounted) return;
  if (sourcePath == null || sourcePath.trim().isEmpty) {
    showStatusMessage(context, l10n.technicalErrorGeneric);
    return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/audio-description/create-ai'),
      builder: (_) => CreateAiAudiodescriptionScreen(
        initialSourcePath: sourcePath,
      ),
    ),
  );
}
