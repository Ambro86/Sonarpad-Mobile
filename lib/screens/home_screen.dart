import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../l10n/ui_radio_localizations.dart';
import '../l10n/ui_route_localizations.dart';
import '../l10n/ui_audiodescription_localizations.dart';
import '../screens/document_reader_screen.dart';
import '../screens/documents_screen.dart';
import '../services/accessibility_feedback_service.dart';
import '../services/app_settings_service.dart';
import '../services/document_library_service.dart';
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
  bool _isSecretCodeValid = false;
  bool _isTvCodeValid = false;
  bool _isRaiPlayValid = false;
  bool _isGroupingEnabled = false;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _initAppLinks();
  }

  void _initAppLinks() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      _appLinks = AppLinks();
      _appLinks.getInitialLink().then((uri) {
        if (uri != null && uri.scheme == 'file') {
          _handleIncomingFile(uri);
        }
      }).catchError((_) {});

      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        if (uri.scheme == 'file') {
          _handleIncomingFile(uri);
        }
      }, onError: (_) {});
    } catch (e) {
      // Ignore exceptions in test
    }
  }

  Future<void> _handleIncomingFile(Uri uri) async {
    try {
      String decodedPath = Uri.decodeComponent(uri.path);
      final originalFile = File(decodedPath);
      if (!await originalFile.exists()) return;

      final basename = p.basename(originalFile.path);

      final lib = DocumentLibraryService();
      await lib.load();
      final doc = await lib.importFile(originalFile, originalName: basename);
      await lib.add(doc);

      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/documents'),
            builder: (_) => const DocumentsScreen(),
          ),
          (route) => route.isFirst,
        );
        navigator.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/documents/reader'),
            builder: (_) => DocumentReaderScreen(document: doc),
          ),
        );
      }
    } catch (e) {
      debugPrint('HomeScreen: Errore importazione file condiviso: $e');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
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
    final isItalian = l10n.locale.languageCode == 'it';

    final readingItems = [
      _HomeButton(
        label: l10n.documents,
        onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/documents'),
      ),
      _HomeButton(
        label: l10n.importFromWikipedia,
        onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/wikipedia'),
      ),
      if (isItalian)
        _HomeButton(
          label: 'BdCiechi',
          onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/bdciechi'),
        ),
    ];

    final mediaItems = [
      _HomeButton(
        label: l10n.radio,
        onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/radio'),
      ),
      _HomeButton(
        label: l10n.podcasts,
        onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/podcasts'),
      ),
      if (_isTvCodeValid && isItalian)
        _HomeButton(
          label: 'TV',
          onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/tv'),
        ),
      if (_isRaiPlayValid && isItalian)
        _HomeButton(
          label: 'RaiPlay',
          onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/raiplay'),
        ),
      if (_isSecretCodeValid && isItalian)
        _HomeButton(
          label: 'RaiPlay Sound',
          onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/raiplaysound'),
        ),
      if (_isSecretCodeValid && isItalian)
        _HomeButton(
          label: l10n.audiodescriptionTitle,
          onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/audiodescriptions'),
        ),
    ];

    final utilityItems = [
      _HomeButton(
        label: l10n.calendar,
        onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/calendar'),
      ),
      _HomeButton(
        label: l10n.news,
        onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/news'),
      ),
      _HomeButton(
        label: l10n.routeTitle,
        onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/route'),
      ),
      if (isItalian)
        _HomeButton(
          label: 'Orari di apertura',
          onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/orari_apertura'),
        ),
      if (_isSecretCodeValid && isItalian)
        _HomeButton(
          label: 'Pagine Bianche e Gialle',
          onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/italiaonline'),
        ),
      if (isItalian)
        _HomeButton(
          label: 'Ricerca Farmaci AIFA',
          onPressed: () => AccessibilityFeedbackService.goNamed(context, routeName: '/aifa'),
        ),
    ];

    List<Widget> children = [];
    if (_isGroupingEnabled) {
      children = [
        _HomeButton(
          label: l10n.categoryReading,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoryScreen(title: l10n.categoryReading, children: readingItems),
            ));
          },
        ),
        _HomeButton(
          label: l10n.categoryMedia,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoryScreen(title: l10n.categoryMedia, children: mediaItems),
            ));
          },
        ),
        _HomeButton(
          label: l10n.categoryUtilities,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoryScreen(title: l10n.categoryUtilities, children: utilityItems),
            ));
          },
        ),
      ];
    } else {
      children = [
        ...readingItems,
        ...mediaItems,
        ...utilityItems,
      ];
    }

    children.addAll([
      _HomeButton(
        label: l10n.settings,
        onPressed: () => AccessibilityFeedbackService.goNamed(
          context,
          routeName: '/settings',
        ).then((_) => _load()),
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
  const _HomeButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
