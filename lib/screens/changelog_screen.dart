import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/changelog_service.dart';
import 'package:sonarpad_mobile_starter/utils/accessibility_list_behavior.dart';

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
        child: ListView.separated(
          scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
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
      content: SingleChildScrollView(
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
