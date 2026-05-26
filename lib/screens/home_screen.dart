import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ui_radio_localizations.dart';
import '../l10n/ui_route_localizations.dart';
import '../l10n/ui_audiodescription_localizations.dart';
import '../models/document_item.dart';
import '../screens/document_reader_screen.dart';
import '../services/accessibility_feedback_service.dart';
import '../services/app_settings_service.dart';
import '../services/document_library_service.dart';
import '../services/raiplay_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/tv_service.dart';

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
      // Gestione link iniziali all'avvio
      _appLinks.getInitialLink().then((uri) {
        if (uri != null && uri.scheme == 'file') {
          _handleIncomingFile(uri);
        }
      }).catchError((_) {}); // Ignore errors in test
      
      // Gestione link in streaming (app già aperta)
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        if (uri.scheme == 'file') {
          _handleIncomingFile(uri);
        }
      }, onError: (_) {});
    } catch (e) {
      // Ignora eccezioni durante i widget test
    }
  }

  Future<void> _handleIncomingFile(Uri uri) async {
    try {
      // uri.path su iOS può contenere l'host 'localhost' o essere assoluto
      String decodedPath = Uri.decodeComponent(uri.path);
      // Rimuovi slash iniziale se su Windows, ma su iOS/Android di solito va bene
      // File gestisce bene il path assoluto
      final originalFile = File(decodedPath);
      if (!await originalFile.exists()) return;

      final appDir = await getApplicationDocumentsDirectory();
      final ext = p.extension(originalFile.path).replaceAll('.', '');
      final basename = p.basename(originalFile.path);
      final id = const Uuid().v4();
      final newPath = p.join(appDir.path, '$id.$ext');

      await originalFile.copy(newPath);

      final doc = DocumentItem(
        id: id,
        name: basename,
        path: '$id.$ext',
        extension: ext,
        addedAt: DateTime.now(),
      );

      final lib = DocumentLibraryService();
      await lib.load();
      await lib.add(doc);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
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
    final isItalian = l10n.locale.languageCode == 'it';
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
              onPressed: () => AccessibilityFeedbackService.goNamed(
                context,
                routeName: '/documents',
              ),
            ),
            _HomeButton(
              label: l10n.news,
              onPressed: () => AccessibilityFeedbackService.goNamed(
                context,
                routeName: '/news',
              ),
            ),
            _HomeButton(
              label: l10n.podcasts,
              onPressed: () => AccessibilityFeedbackService.goNamed(
                context,
                routeName: '/podcasts',
              ),
            ),
            _HomeButton(
              label: l10n.radio,
              onPressed: () => AccessibilityFeedbackService.goNamed(
                context,
                routeName: '/radio',
              ),
            ),
            if (_isTvCodeValid && isItalian)
              _HomeButton(
                label: 'TV',
                onPressed: () => AccessibilityFeedbackService.goNamed(
                  context,
                  routeName: '/tv',
                ),
              ),
            if (_isSecretCodeValid && isItalian) ...[
              _HomeButton(
                label: l10n.audiodescriptionTitle,
                onPressed: () => AccessibilityFeedbackService.goNamed(
                  context,
                  routeName: '/audiodescriptions',
                ),
              ),
              _HomeButton(
                label: 'RaiPlay Sound',
                onPressed: () => AccessibilityFeedbackService.goNamed(
                  context,
                  routeName: '/raiplaysound',
                ),
              ),
            ],
            if (_isRaiPlayValid && isItalian)
              _HomeButton(
                label: 'RaiPlay',
                onPressed: () => AccessibilityFeedbackService.goNamed(
                  context,
                  routeName: '/raiplay',
                ),
              ),
            _HomeButton(
              label: l10n.importFromWikipedia,
              onPressed: () => AccessibilityFeedbackService.goNamed(
                context,
                routeName: '/wikipedia',
              ),
            ),
            if (isItalian)
              _HomeButton(
                label: 'Ricerca Farmaci AIFA',
                onPressed: () => AccessibilityFeedbackService.goNamed(
                  context,
                  routeName: '/aifa',
                ),
              ),
            _HomeButton(
              label: l10n.routeTitle,
              onPressed: () => AccessibilityFeedbackService.goNamed(
                context,
                routeName: '/route',
              ),
            ),
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
