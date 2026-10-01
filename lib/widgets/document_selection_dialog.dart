import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import 'universal_accessible_view.dart';

enum DocumentSelectionAction { share, delete }

class DocumentSelectionResult {
  const DocumentSelectionResult({
    required this.action,
    required this.documents,
  });

  final DocumentSelectionAction action;
  final List<DocumentItem> documents;
}

Future<DocumentSelectionResult?> showDocumentSelectionDialog(
  BuildContext context,
  List<DocumentItem> documents, {
  Set<String> initialSelectedIds = const <String>{},
  Set<String>? shareableDocumentIds,
}) async {
  final l10n = AppLocalizations.of(context);
  final availableIds = documents.map((document) => document.id).toSet();
  final selectedIds = ValueNotifier<Set<String>>(
    initialSelectedIds.intersection(availableIds),
  );
  final shareableIds = shareableDocumentIds ?? availableIds;

  void updateSelection(String id, bool selected) {
    final next = Set<String>.of(selectedIds.value);
    if (selected) {
      next.add(id);
    } else {
      next.remove(id);
    }
    selectedIds.value = next;
  }

  void updateAllSelection(bool selectAll) {
    selectedIds.value = selectAll ? Set<String>.of(availableIds) : <String>{};
  }

  List<DocumentItem> selectedDocuments(Set<String> selected) => documents
      .where((document) => selected.contains(document.id))
      .toList(growable: false);

  bool allSelectedDocumentsShareable(Set<String> selected) =>
      selected.isNotEmpty && selected.every(shareableIds.contains);

  try {
    return await showDialog<DocumentSelectionResult>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (dialogContext) {
        final title = Semantics(
          key: const ValueKey('document_selection_title_semantics'),
          container: true,
          header: true,
          label: l10n.selectDocuments,
          child: ExcludeSemantics(
            child: Text(
              l10n.selectDocuments,
              style: Theme.of(dialogContext).textTheme.headlineSmall,
            ),
          ),
        );

        Widget buildDocuments() {
          if (documents.isEmpty) {
            return Center(child: Text(l10n.documents));
          }
          return ValueListenableBuilder<Set<String>>(
            valueListenable: selectedIds,
            builder: (context, selected, _) {
              if (useSharedAccessibleViewModel) {
                return UniversalAccessibleList(
                  debugTag: 'document-selection',
                  sections: [
                    AccessibleListSection(
                      rows: [
                        for (var i = 0; i < documents.length; i++)
                          AccessibleListRow(
                            id: 'document_$i',
                            title: documents[i].displayName,
                            kind: 'toggle',
                            toggleValue: selected.contains(documents[i].id),
                            flutterChild: CheckboxListTile(
                              key: ValueKey(
                                'document_selection_${documents[i].id}',
                              ),
                              value: selected.contains(documents[i].id),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(documents[i].displayName),
                              onChanged: (value) => updateSelection(
                                documents[i].id,
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
                      event.id!.replaceFirst('document_', ''),
                    );
                    if (i == null || i < 0 || i >= documents.length) return;
                    updateSelection(documents[i].id, event.value == true);
                  },
                );
              }
              return ListView.builder(
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  return CheckboxListTile(
                    key: ValueKey('document_selection_${document.id}'),
                    value: selected.contains(document.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(document.displayName),
                    onChanged: (value) =>
                        updateSelection(document.id, value ?? false),
                  );
                },
              );
            },
          );
        }

        final actionBar = ValueListenableBuilder<Set<String>>(
          valueListenable: selectedIds,
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
                                  l10n.deleteSelectedDocumentsConfirmation,
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
                                DocumentSelectionResult(
                                  action: DocumentSelectionAction.delete,
                                  documents: selectedDocuments(selected),
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
                    onPressed: allSelectedDocumentsShareable(selected)
                        ? () => Navigator.pop(
                              dialogContext,
                              DocumentSelectionResult(
                                action: DocumentSelectionAction.share,
                                documents: selectedDocuments(selected),
                              ),
                            )
                        : null,
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
            appBar: SonarpadAppBar(
              automaticallyImplyLeading: false,
              leading: SonarpadBackButton(
                key: const ValueKey('document_selection_back_semantics'),
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
                  if (documents.isNotEmpty) ...[
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: selectedIds,
                      builder: (context, selected, _) {
                        final allSelected = selected.length == documents.length;
                        return Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton.icon(
                            key: const ValueKey(
                              'document_selection_select_all',
                            ),
                            onPressed: () => updateAllSelection(!allSelected),
                            icon: Icon(
                              allSelected ? Icons.deselect : Icons.select_all,
                            ),
                            label: Text(
                              allSelected ? l10n.deselectAll : l10n.selectAll,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(child: buildDocuments()),
                  actionBar,
                ],
              ),
            ),
          ),
        );
      },
    );
  } finally {
    selectedIds.dispose();
  }
}
