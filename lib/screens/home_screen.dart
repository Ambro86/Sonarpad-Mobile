import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ui_radio_localizations.dart';
import '../services/accessibility_feedback_service.dart';
import '../services/app_settings_service.dart';
import '../services/raiplay_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/tv_service.dart';
import 'documents_screen.dart';
import 'info_screen.dart';
import 'news_screen.dart';
import 'podcast_screen.dart';
import 'radio_screen.dart';
import 'raiplay_screen.dart';
import 'raiplaysound_screen.dart';
import 'settings_screen.dart';
import 'tv_screen.dart';
import 'wikipedia_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settings = AppSettingsService();
  final _raiPlaySoundService = RaiPlaySoundService();
  final _raiPlayService = RaiPlayService();
  bool _isSecretCodeValid = false;
  bool _isTvCodeValid = false;
  bool _isRaiPlayValid = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final code = await _settings.getTvSecretCode();
    final isValidTv = TvService().isSecretCodeValid(code);
    final isValidRaiSound = _raiPlaySoundService.isSecretCodeValid(code);
    final isValidRaiPlay = _raiPlayService.isSecretCodeValid(code);
    if (!mounted) return;
    setState(() {
      _isTvCodeValid = isValidTv;
      _isSecretCodeValid = isValidRaiSound;
      _isRaiPlayValid = isValidRaiPlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(
              excludeSemantics: true,
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
              label: l10n.documents,
              hint: l10n.documentsHint,
              onPressed: () => AccessibilityFeedbackService.push(
                context,
                builder: (_) => const DocumentsScreen(),
                routeName: 'documents',
              ),
            ),
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
            if (_isTvCodeValid)
              _HomeButton(
                label: 'TV',
                hint: 'Guarda i canali TV',
                onPressed: () => AccessibilityFeedbackService.push(
                  context,
                  builder: (_) => const TvScreen(),
                  routeName: 'tv',
                ),
              ),
            if (_isSecretCodeValid)
              _HomeButton(
                label: 'RaiPlay Sound',
                hint: 'Podcast e audiolibri Rai',
                onPressed: () => AccessibilityFeedbackService.push(
                  context,
                  builder: (_) => const RaiPlaySoundScreen(),
                  routeName: 'raiplaysound',
                ),
              ),
            if (_isRaiPlayValid)
              _HomeButton(
                label: 'RaiPlay',
                hint: 'Programmi e video Rai on demand',
                onPressed: () => AccessibilityFeedbackService.push(
                  context,
                  builder: (_) => const RaiPlayScreen(),
                  routeName: 'raiplay',
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
            _HomeButton(
              label: l10n.settings,
              hint: null,
              onPressed: () => AccessibilityFeedbackService.push(
                context,
                builder: (_) => const SettingsScreen(),
                routeName: 'settings',
              ).then((_) => _load()),
            ),
            _HomeButton(
              label: l10n.info,
              hint: null,
              onPressed: () => AccessibilityFeedbackService.push(
                context,
                builder: (_) => const InfoScreen(),
                routeName: 'info',
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
  final String? hint;
  final VoidCallback onPressed;
  const _HomeButton(
      {required this.label, this.hint, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
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
