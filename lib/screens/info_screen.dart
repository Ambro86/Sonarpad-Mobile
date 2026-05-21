import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.info)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.appTitle,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(l10n.infoDescription,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text(l10n.infoAuthor, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
