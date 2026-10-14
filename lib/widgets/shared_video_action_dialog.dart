import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum SharedVideoAction { play, describe }

Future<SharedVideoAction?> showSharedVideoActionDialog(
  BuildContext context, {
  required String filename,
}) => showDialog<SharedVideoAction>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    return SimpleDialog(
      title: Text(filename),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, SharedVideoAction.play),
          child: Text(l10n.sharedVideoOpen),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, SharedVideoAction.describe),
          child: Text(l10n.audioDescriptionCreateAiTitle),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  },
);
