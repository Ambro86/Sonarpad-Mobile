import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ui_radio_localizations.dart';
import '../services/accessibility_feedback_service.dart';
import 'info_screen.dart';
import 'news_screen.dart';
import 'podcast_screen.dart';
import 'radio_screen.dart';
import 'settings_screen.dart';
import 'wikipedia_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.settingsHint,
            onPressed: () => AccessibilityFeedbackService.push(
              context,
              builder: (_) => const SettingsScreen(),
              routeName: 'settings',
            ),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: l10n.infoHint,
            onPressed: () => AccessibilityFeedbackService.push(
              context,
              builder: (_) => const InfoScreen(),
              routeName: 'info',
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(
              label: l10n.homeSemanticsLabel,
              image: true,
              child: Image.asset(
                'assets/images/Sonarpad_Logo.png',
                height: 92,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (context, error, stackTrace) => Text(
                  l10n.appTitle,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _HomeButton(
              label: l10n.news,
              hint: l10n.newsHint,
              onPressed: () => AccessibilityFeedbackService.push(
                context,
                builder: (_) => const NewsScreen(),
                routeName: 'news',
              ),
            ),
            _HomeButton(
              label: l10n.podcasts,
              hint: l10n.podcastsHint,
              onPressed: () => AccessibilityFeedbackService.push(
                context,
                builder: (_) => const PodcastScreen(),
                routeName: 'podcasts',
              ),
            ),
            _HomeButton(
              label: l10n.radio,
              hint: l10n.radioHint,
              onPressed: () => AccessibilityFeedbackService.push(
                context,
                builder: (_) => const RadioScreen(),
                routeName: 'radio',
              ),
            ),
            _HomeButton(
              label: l10n.importFromWikipedia,
              hint: l10n.wikipediaHint,
              onPressed: () => AccessibilityFeedbackService.push(
                context,
                builder: (_) => const WikipediaScreen(),
                routeName: 'wikipedia',
              ),
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
