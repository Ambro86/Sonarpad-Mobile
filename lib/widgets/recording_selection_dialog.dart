import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/utils/accessibility_list_behavior.dart';

enum RecordingSelectionAction { share, delete }

class RecordingSelectionResult {
  const RecordingSelectionResult({
    required this.action,
    required this.recordings,
  });

  final RecordingSelectionAction action;
  final List<File> recordings;
}

Future<RecordingSelectionResult?> showRecordingSelectionDialog(
  BuildContext context,
  List<File> recordings,
) {
  final l10n = AppLocalizations.of(context);
  final selectedPaths = <String>{};

  return showDialog<RecordingSelectionResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(l10n.selectRecordings),
        content: SizedBox(
          width: 560,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: recordings.isEmpty
                ? Text(l10n.noRecordings)
                : ListView.builder(
                    scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
                    shrinkWrap: true,
                    itemCount: recordings.length,
                    itemBuilder: (context, index) {
                      final recording = recordings[index];
                      final selected = selectedPaths.contains(recording.path);
                      return CheckboxListTile(
                        value: selected,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(p.basenameWithoutExtension(recording.path)),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value ?? false) {
                              selectedPaths.add(recording.path);
                            } else {
                              selectedPaths.remove(recording.path);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.back),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: selectedPaths.isEmpty
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: dialogContext,
                      builder: (confirmationContext) => AlertDialog(
                        title: Text(l10n.deleteItem),
                        content: Text(
                          l10n.deleteRecordingsConfirmation(
                            selectedPaths.length,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(confirmationContext, false),
                            child: Text(l10n.no),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(confirmationContext, true),
                            child: Text(l10n.deleteItem),
                          ),
                        ],
                      ),
                    );
                    if (confirmed ?? false) {
                      if (!dialogContext.mounted) return;
                      Navigator.pop(
                        dialogContext,
                        RecordingSelectionResult(
                          action: RecordingSelectionAction.delete,
                          recordings: recordings
                              .where(
                                (recording) =>
                                    selectedPaths.contains(recording.path),
                              )
                              .toList(),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.delete_outline),
            label: Text('${l10n.deleteItem} (${selectedPaths.length})'),
          ),
          FilledButton.icon(
            onPressed: selectedPaths.isEmpty
                ? null
                : () => Navigator.pop(
                    dialogContext,
                    RecordingSelectionResult(
                      action: RecordingSelectionAction.share,
                      recordings: recordings
                          .where(
                            (recording) =>
                                selectedPaths.contains(recording.path),
                          )
                          .toList(),
                    ),
                  ),
            icon: const Icon(Icons.share),
            label: Text('${l10n.share} (${selectedPaths.length})'),
          ),
        ],
      ),
    ),
  );
}
