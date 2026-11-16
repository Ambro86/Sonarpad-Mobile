import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'universal_accessible_view.dart';

Future<int?> showTmdbSelectionDialog(
  BuildContext context, {
  required String title,
  required List<String> options,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (dialogContext) => Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            Expanded(
              child: UniversalAccessibleList(
                debugTag: 'tmdb-selection',
                initialFocusId: options.isEmpty ? null : 'tmdb_0',
                sections: [
                  AccessibleListSection(
                    rows: [
                      for (var i = 0; i < options.length; i++)
                        AccessibleListRow(
                          id: 'tmdb_$i',
                          title: options[i],
                          kind: 'button',
                        ),
                    ],
                  ),
                ],
                onEvent: (event) {
                  final id = event.id;
                  if (event.type != 'activate' ||
                      id == null ||
                      !id.startsWith('tmdb_')) {
                    return;
                  }
                  final index = int.tryParse(id.substring(5));
                  if (index != null && index >= 0 && index < options.length) {
                    Navigator.pop(dialogContext, index);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
