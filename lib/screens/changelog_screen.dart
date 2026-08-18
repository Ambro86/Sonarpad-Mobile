import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/changelog_service.dart';
import '../widgets/native_ios_accessible_view.dart';

class ChangelogScreen extends StatelessWidget {
  final ChangelogEntry entry;
  final String languageCode;

  const ChangelogScreen({
    super.key,
    required this.entry,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final changes = entry.changesFor(languageCode);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.whatIsNew)),
      body: SafeArea(
        child: useNativeIosAccessibleViews
            ? NativeIosAccessibleList(
                sections: [NativeIosListSection(
                  header: l10n.whatIsNewInVersion(entry.version),
                  rows: [
                    for (var i = 0; i < changes.length; i++)
                      NativeIosListRow(id: 'change_$i', kind: 'text', title: changes[i]),
                  ],
                )],
                onEvent: (_) {},
              )
            : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: changes.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                l10n.whatIsNewInVersion(entry.version),
                style: Theme.of(context).textTheme.titleMedium,
              );
            }
            return ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(changes[index - 1]),
            );
          },
        ),
      ),
    );
  }
}

Future<void> showChangelogDialog({
  required BuildContext context,
  required ChangelogEntry entry,
  required String languageCode,
}) async {
  final l10n = AppLocalizations.of(context);
  final changes = entry.changesFor(languageCode);

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.whatIsNewInVersion(entry.version)),
      content: useNativeIosAccessibleViews
          ? SizedBox(
              width: 500,
              height: 380,
              child: NativeIosAccessibleList(
                sections: [NativeIosListSection(rows: [
                  for (var i = 0; i < changes.length; i++)
                    NativeIosListRow(id: 'change_$i', kind: 'text', title: changes[i]),
                ])],
                onEvent: (_) {},
              ),
            )
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final change in changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('- $change'),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}
