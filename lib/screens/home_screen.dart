import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/accessibility_feedback_service.dart';
import '../services/app_settings_service.dart';
import '../services/raiplay_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/tv_service.dart';
import 'category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settings = AppSettingsService();
  final _raiPlaySoundService = RaiPlaySoundService();
  final _raiPlayService = RaiPlayService();
  final _settingsFocusNode = FocusNode(debugLabel: 'home-settings');
  bool _isSecretCodeValid = false;
  bool _isTvCodeValid = false;
  bool _isRaiPlayValid = false;
  bool _isGroupingEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _settingsFocusNode.dispose();
    super.dispose();
  }

  void _restoreSettingsFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _settingsFocusNode.requestFocus();
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        _settingsFocusNode.requestFocus();
      });
    });
  }

  Future<void> _load() async {
    final code = await _settings.getTvSecretCode();
    final isValidTv = TvService().isSecretCodeValid(code);
    final isValidRaiSound = _raiPlaySoundService.isSecretCodeValid(code);
    final isValidRaiPlay = _raiPlayService.isSecretCodeValid(code);
    final isGroupingEnabled = await _settings.isHomeGroupingEnabled();
    if (!mounted) return;
    setState(() {
      _isTvCodeValid = isValidTv;
      _isSecretCodeValid = isValidRaiSound;
      _isRaiPlayValid = isValidRaiPlay;
      _isGroupingEnabled = isGroupingEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isItalian = l10n.localeName == 'it';
    // La sezione AIFA/farmaci usa dati italiani: deve rimanere visibile solo
    // quando l'app è in italiano, come Biblioteca Digitale, RaiPlay e TV.
    final showItalianPharmacyFeature = isItalian;

    final readingItems = [
      _HomeButton(
        label: l10n.documents,
        onPressed: () => AccessibilityFeedbackService.goNamed(context,
            routeName: '/documents'),
      ),
      _HomeButton(
        label: l10n.importFromWikipedia,
        onPressed: () => AccessibilityFeedbackService.goNamed(context,
            routeName: '/wikipedia'),
      ),
      _HomeButton(
        label: l10n.news,
        onPressed: () =>
            AccessibilityFeedbackService.goNamed(context, routeName: '/news'),
      ),
      if (isItalian)
        _HomeButton(
          label: 'Biblioteca digitale',
          onPressed: () => AccessibilityFeedbackService.goNamed(context,
              routeName: '/bdciechi'),
        ),
    ];

    final mediaItems = [
      _HomeButton(
        label: l10n.radio,
        onPressed: () =>
            AccessibilityFeedbackService.goNamed(context, routeName: '/radio'),
      ),
      _HomeButton(
        label: l10n.podcasts,
        onPressed: () => AccessibilityFeedbackService.goNamed(context,
            routeName: '/podcasts'),
      ),
      _HomeButton(
        label: l10n.convertMediaTitle,
        onPressed: () => AccessibilityFeedbackService.goNamed(context,
            routeName: '/convert_media'),
      ),
      _HomeButton(
        label: l10n.mediaCutterTitle,
        onPressed: () => AccessibilityFeedbackService.goNamed(context,
            routeName: '/media_cutter'),
      ),
      _HomeButton(
        label: l10n.cinemaTitle,
        onPressed: () => AccessibilityFeedbackService.goNamed(context,
            routeName: '/cinema'),
      ),
      if (_isTvCodeValid && isItalian)
        _HomeButton(
          label: 'TV',
          onPressed: () =>
              AccessibilityFeedbackService.goNamed(context, routeName: '/tv'),
        ),
      if (_isRaiPlayValid && isItalian)
        _HomeButton(
          label: 'RaiPlay',
          onPressed: () => AccessibilityFeedbackService.goNamed(context,
              routeName: '/raiplay'),
        ),
      if (_isSecretCodeValid && isItalian)
        _HomeButton(
          label: 'RaiPlay Sound',
          onPressed: () => AccessibilityFeedbackService.goNamed(context,
              routeName: '/raiplaysound'),
        ),
      if (_isSecretCodeValid && isItalian)
        _HomeButton(
          label: l10n.audiodescriptionTitle,
          onPressed: () => AccessibilityFeedbackService.goNamed(context,
              routeName: '/audiodescriptions'),
        ),
    ];

    final utilityItems = [
      _HomeButton(
        label: l10n.calendar,
        onPressed: () => AccessibilityFeedbackService.goNamed(context,
            routeName: '/calendar'),
      ),
      _HomeButton(
        label: l10n.voiceDictionaryTitle,
        onPressed: () => AccessibilityFeedbackService.goNamed(context,
            routeName: '/voice_dictionary'),
      ),
      _HomeButton(
        label: l10n.meteoTitle,
        onPressed: () =>
            AccessibilityFeedbackService.goNamed(context, routeName: '/meteo'),
      ),
      _HomeButton(
        label: l10n.routeTitle,
        onPressed: () =>
            AccessibilityFeedbackService.goNamed(context, routeName: '/route'),
      ),
      if (isItalian)
        _HomeButton(
          label: 'Orari di apertura',
          onPressed: () => AccessibilityFeedbackService.goNamed(context,
              routeName: '/orari_apertura'),
        ),
      if (_isSecretCodeValid && isItalian)
        _HomeButton(
          label: 'Pagine Bianche e Gialle',
          onPressed: () => AccessibilityFeedbackService.goNamed(context,
              routeName: '/italiaonline'),
        ),
      if (showItalianPharmacyFeature)
        _HomeButton(
          label: l10n.pharmacyFeatureTitle,
          onPressed: () =>
              AccessibilityFeedbackService.goNamed(context, routeName: '/aifa'),
        ),
    ];

    List<Widget> children = [];
    if (_isGroupingEnabled) {
      children = [
        _HomeButton(
          label: l10n.categoryReading,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoryScreen(
                  title: l10n.categoryReading, children: readingItems),
            ));
          },
        ),
        _HomeButton(
          label: l10n.categoryMedia,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoryScreen(
                  title: l10n.categoryMedia, children: mediaItems),
            ));
          },
        ),
        _HomeButton(
          label: l10n.categoryUtilities,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoryScreen(
                  title: l10n.categoryUtilities, children: utilityItems),
            ));
          },
        ),
      ];
    } else {
      children = [
        _HomeButton(
            label: l10n.documents,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/documents')),
        _HomeButton(
            label: l10n.calendar,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/calendar')),
        _HomeButton(
            label: l10n.news,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/news')),
        _HomeButton(
            label: l10n.meteoTitle,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/meteo')),
        _HomeButton(
            label: l10n.podcasts,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/podcasts')),
        _HomeButton(
            label: l10n.convertMediaTitle,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/convert_media')),
        _HomeButton(
            label: l10n.mediaCutterTitle,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/media_cutter')),
        _HomeButton(
            label: l10n.cinemaTitle,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/cinema')),
        _HomeButton(
            label: l10n.radio,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/radio')),
        if (_isTvCodeValid && isItalian)
          _HomeButton(
              label: 'TV',
              onPressed: () => AccessibilityFeedbackService.goNamed(context,
                  routeName: '/tv')),
        if (_isSecretCodeValid && isItalian)
          _HomeButton(
              label: 'RaiPlay Sound',
              onPressed: () => AccessibilityFeedbackService.goNamed(context,
                  routeName: '/raiplaysound')),
        if (_isRaiPlayValid && isItalian)
          _HomeButton(
              label: 'RaiPlay',
              onPressed: () => AccessibilityFeedbackService.goNamed(context,
                  routeName: '/raiplay')),
        if (_isSecretCodeValid && isItalian)
          _HomeButton(
              label: l10n.audiodescriptionTitle,
              onPressed: () => AccessibilityFeedbackService.goNamed(context,
                  routeName: '/audiodescriptions')),
        _HomeButton(
            label: l10n.importFromWikipedia,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/wikipedia')),
        _HomeButton(
            label: l10n.voiceDictionaryTitle,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/voice_dictionary')),
        if (_isSecretCodeValid && isItalian)
          _HomeButton(
              label: 'Biblioteca digitale',
              onPressed: () => AccessibilityFeedbackService.goNamed(context,
                  routeName: '/bdciechi')),
        _HomeButton(
            label: l10n.routeTitle,
            onPressed: () => AccessibilityFeedbackService.goNamed(context,
                routeName: '/route')),
        if (isItalian)
          _HomeButton(
              label: 'Orari di apertura',
              onPressed: () => AccessibilityFeedbackService.goNamed(context,
                  routeName: '/orari_apertura')),
        if (_isSecretCodeValid && isItalian)
          _HomeButton(
              label: 'Pagine Bianche e Gialle',
              onPressed: () => AccessibilityFeedbackService.goNamed(context,
                  routeName: '/italiaonline')),
        if (showItalianPharmacyFeature)
          _HomeButton(
              label: l10n.pharmacyFeatureTitle,
              onPressed: () => AccessibilityFeedbackService.goNamed(context,
                  routeName: '/aifa')),
      ];
    }

    children.addAll([
      _HomeButton(
        label: l10n.settings,
        focusNode: _settingsFocusNode,
        onPressed: () async {
          final appLanguage = await AccessibilityFeedbackService.goNamed<String>(
            context,
            routeName: '/settings',
          );
          if (!context.mounted) return;
          await _load();
          if (!context.mounted) return;
          if (appLanguage != null &&
              appLanguage != Localizations.localeOf(context).languageCode) {
            await Future<void>.delayed(Duration.zero);
            if (!context.mounted) return;
            SonarpadApp.setLocale(context, Locale(appLanguage));
          }
          _restoreSettingsFocus();
        },
      ),
      _HomeButton(
        label: l10n.info,
        onPressed: () => AccessibilityFeedbackService.goNamed(
          context,
          routeName: '/info',
        ),
      ),
    ]);

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
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  const _HomeButton({
    required this.label,
    required this.onPressed,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(
        focusNode: focusNode,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
