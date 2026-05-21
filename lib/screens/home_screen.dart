import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'news_screen.dart';
import 'podcast_screen.dart';
import 'wikipedia_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.appTitle,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              semanticsLabel: l10n.homeSemanticsLabel,
            ),
            const SizedBox(height: 24),
            _HomeButton(
              label: l10n.news,
              hint: l10n.newsHint,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NewsScreen())),
            ),
            _HomeButton(
              label: l10n.podcasts,
              hint: l10n.podcastsHint,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PodcastScreen())),
            ),
            _HomeButton(
              label: l10n.importFromWikipedia,
              hint: l10n.wikipediaHint,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WikipediaScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final String label;
  final String hint;
  final VoidCallback onPressed;
  const _HomeButton(
      {required this.label, required this.hint, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: label,
        hint: hint,
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
