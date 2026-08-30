import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import 'universal_accessible_view.dart';

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
) async {
  final l10n = AppLocalizations.of(context);
  final selectedPaths = ValueNotifier<Set<String>>(<String>{});

  void updateSelection(String path, bool selected) {
    final next = Set<String>.of(selectedPaths.value);
    if (selected) {
      next.add(path);
    } else {
      next.remove(path);
    }
    selectedPaths.value = next;
  }

  List<File> selectedRecordings(Set<String> selected) => recordings
      .where((recording) => selected.contains(recording.path))
      .toList();

  try {
    return await showDialog<RecordingSelectionResult>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (dialogContext) {
        final title = Semantics(
          key: const ValueKey('recording_selection_title_semantics'),
          container: true,
          header: true,
          label: l10n.selectRecordings,
          child: ExcludeSemantics(
            child: Text(
              l10n.selectRecordings,
              style: Theme.of(dialogContext).textTheme.headlineSmall,
            ),
          ),
        );

        Widget buildRecordings() {
          if (recordings.isEmpty) {
            return Center(child: Text(l10n.noRecordings));
          }
          return ValueListenableBuilder<Set<String>>(
            valueListenable: selectedPaths,
            builder: (context, selected, _) {
              if (useSharedAccessibleViewModel) {
                return UniversalAccessibleList(
                  debugTag: 'recording-selection',
                  sections: [
                    AccessibleListSection(
                      rows: [
                        for (var i = 0; i < recordings.length; i++)
                          AccessibleListRow(
                            id: 'recording_$i',
                            title: p.basenameWithoutExtension(
                              recordings[i].path,
                            ),
                            kind: 'toggle',
                            toggleValue: selected.contains(recordings[i].path),
                            flutterChild: CheckboxListTile(
                              key: ValueKey(
                                'recording_selection_${recordings[i].path}',
                              ),
                              value: selected.contains(recordings[i].path),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                p.basenameWithoutExtension(recordings[i].path),
                              ),
                              onChanged: (value) => updateSelection(
                                recordings[i].path,
                                value ?? false,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  onEvent: (event) {
                    if (event.type != 'toggle' || event.id == null) return;
                    final i = int.tryParse(
                      event.id!.replaceFirst('recording_', ''),
                    );
                    if (i == null || i >= recordings.length) return;
                    updateSelection(recordings[i].path, event.value == true);
                  },
                );
              }
              return ListView.builder(
                itemCount: recordings.length,
                itemBuilder: (context, index) {
                  final recording = recordings[index];
                  return CheckboxListTile(
                    key: ValueKey('recording_selection_${recording.path}'),
                    value: selected.contains(recording.path),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(p.basenameWithoutExtension(recording.path)),
                    onChanged: (value) =>
                        updateSelection(recording.path, value ?? false),
                  );
                },
              );
            },
          );
        }

        final actionBar = ValueListenableBuilder<Set<String>>(
          valueListenable: selectedPaths,
          builder: (context, selected, _) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: dialogContext,
                              builder: (confirmationContext) => AlertDialog(
                                title: Text(l10n.deleteItem),
                                content: Text(
                                  l10n.deleteRecordingsConfirmation(
                                    selected.length,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(
                                      confirmationContext,
                                      false,
                                    ),
                                    child: Text(l10n.no),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(
                                      confirmationContext,
                                      true,
                                    ),
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
                                  recordings: selectedRecordings(selected),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      l10n.selectionActionCount(
                        l10n.deleteItem,
                        selected.length,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            dialogContext,
                            RecordingSelectionResult(
                              action: RecordingSelectionAction.share,
                              recordings: selectedRecordings(selected),
                            ),
                          ),
                    icon: const Icon(Icons.share),
                    label: Text(
                      l10n.selectionActionCount(
                        l10n.share,
                        selected.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: BackButton(
                key: const ValueKey('recording_selection_back_semantics'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 12),
                  Expanded(child: buildRecordings()),
                  actionBar,
                ],
              ),
            ),
          ),
        );
      },
    );
  } finally {
    selectedPaths.dispose();
  }
}
