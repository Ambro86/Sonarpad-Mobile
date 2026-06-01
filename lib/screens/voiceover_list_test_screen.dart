import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class VoiceOverListTestScreen extends StatelessWidget {
  const VoiceOverListTestScreen({super.key});

  static const _rowCount = 300;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voiceOverListTestTitle),
      ),
      body: SafeArea(
        child: ListView.builder(
          addSemanticIndexes: false,
          itemCount: _rowCount,
          semanticChildCount: _rowCount,
          itemBuilder: (context, index) {
            final number = index + 1;
            final rowLabel = l10n.voiceOverListTestRow(number, _rowCount);
            final rowContent = l10n.voiceOverListTestContent(number);

            return IndexedSemantics(
              index: index,
              child: Semantics(
                container: true,
                label: '$rowLabel, $rowContent',
                child: ExcludeSemantics(
                  child: ListTile(
                    title: Text(rowLabel),
                    subtitle: Text(rowContent),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
