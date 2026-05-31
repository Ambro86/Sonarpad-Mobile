import 'package:flutter/material.dart';

import '../services/changelog_service.dart';

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
    final labels = _ChangelogLabels.forLanguage(languageCode);
    final changes = entry.changesFor(languageCode);

    return Scaffold(
      appBar: AppBar(title: Text(labels.title)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: changes.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                labels.version(entry.version),
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
  final labels = _ChangelogLabels.forLanguage(languageCode);
  final changes = entry.changesFor(languageCode);

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(labels.version(entry.version)),
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
          child: Text(labels.ok),
        ),
      ],
    ),
  );
}

class _ChangelogLabels {
  final String title;
  final String ok;
  final String Function(String version) version;

  const _ChangelogLabels({
    required this.title,
    required this.ok,
    required this.version,
  });

  static _ChangelogLabels forLanguage(String languageCode) {
    return switch (languageCode) {
      'en' => _ChangelogLabels(
          title: 'What is new',
          ok: 'OK',
          version: (version) => 'What is new in version $version',
        ),
      'fr' => _ChangelogLabels(
          title: 'Nouveautes',
          ok: 'OK',
          version: (version) => 'Nouveautes de la version $version',
        ),
      'es' => _ChangelogLabels(
          title: 'Novedades',
          ok: 'OK',
          version: (version) => 'Novedades de la version $version',
        ),
      _ => _ChangelogLabels(
          title: 'Novita',
          ok: 'OK',
          version: (version) => 'Novita della versione $version',
        ),
    };
  }
}
