import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:rhttp_plus/rhttp_plus.dart' as rhttp;

import 'l10n/app_localizations.dart';
import 'models/podcast.dart';
import 'utils/app_logger.dart';
import 'services/app_settings_service.dart';
import 'services/changelog_service.dart';
import 'services/document_library_service.dart';
import 'screens/changelog_screen.dart';
import 'screens/convert_media_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/document_reader_screen.dart';
import 'screens/home_screen.dart';
import 'screens/info_screen.dart';
import 'screens/news_screen.dart';
import 'screens/podcast_screen.dart';
import 'screens/radio_screen.dart';
import 'screens/raiplay_screen.dart';
import 'screens/raiplaysound_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tv_screen.dart';
import 'screens/aifa_search_screen.dart';
import 'screens/wikipedia_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/bdciechi_login_screen.dart';
import 'screens/route_screen.dart';
import 'screens/audiodescription_recent_screen.dart';
import 'screens/orari_apertura_search_screen.dart';
import 'screens/italiaonline_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/podcast_episode_player_screen.dart';
import 'screens/voice_dictionary_screen.dart';

import 'package:just_audio_background/just_audio_background.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

ThemeData sonarpadTheme() {
  const primaryBlue = Color(0xFF0072CE);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      secondary: const Color(0xFF005A9E),
      tertiary: const Color(0xFFE6F2FF),
      surface: Colors.white,
      error: Colors.red.shade700,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.log(
    'Sonarpad bootstrap start platform=${Platform.operatingSystem} '
    'version=${Platform.operatingSystemVersion} pid=$pid',
  );
  tz_data.initializeTimeZones();
  await AppLogger.log('Sonarpad bootstrap timezone data initialized');
  try {
    await rhttp.Rhttp.init();
    await AppLogger.log('Sonarpad bootstrap rhttp_plus initialized');
  } catch (error) {
    debugPrint('Errore inizializzazione rhttp_plus: $error');
    await AppLogger.log('Sonarpad bootstrap rhttp_plus init failed: $error');
  }
  try {
    await AppLogger.log('Sonarpad bootstrap just_audio_background init start');
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
    await AppLogger.log('Sonarpad bootstrap just_audio_background init ok');
  } catch (error) {
    await AppLogger.log(
      'Sonarpad bootstrap just_audio_background init failed: $error',
    );
    rethrow;
  }
  await AppLogger.log('Sonarpad bootstrap runApp');
  runApp(const SonarpadApp());
}

class SonarpadApp extends StatefulWidget {
  const SonarpadApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    context.findAncestorStateOfType<_SonarpadAppState>()?.setLocale(newLocale);
  }

  @override
  State<SonarpadApp> createState() => _SonarpadAppState();
}

class _SonarpadAppState extends State<SonarpadApp> {
  static const _sharedMediaChannel = MethodChannel('sonarpad/shared_media');
  static const _sharedMediaEvents =
      EventChannel('sonarpad/shared_media_events');
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<dynamic>? _sharedMediaSubscription;
  Uri? _pendingSharedUri;
  Locale? _locale;
  bool _changelogChecked = false;

  @override
  void initState() {
    super.initState();
    unawaited(AppLogger.log('SonarpadApp initState'));
    _initAppLinks();
    _initSharedMediaIntents();
    AppSettingsService().loadAppLanguage().then((lang) {
      if (mounted) {
        unawaited(AppLogger.log('SonarpadApp language loaded: $lang'));
        setState(() {
          _locale = Locale(lang);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showChangelogIfNeeded(lang);
        });
      }
    });
  }

  Future<void> _showChangelogIfNeeded(String languageCode) async {
    if (_changelogChecked) return;

    if (_navigatorKey.currentState?.overlay?.context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showChangelogIfNeeded(languageCode);
      });
      return;
    }
    _changelogChecked = true;

    try {
      final service = ChangelogService();
      final entry = await service.loadCurrentEntryIfUnseen();
      if (entry == null || !mounted) return;
      final context = _navigatorKey.currentState?.overlay?.context;
      if (context == null || !context.mounted) return;
      await showChangelogDialog(
        context: context,
        entry: entry,
        languageCode: languageCode,
      );
      await service.markSeen(entry.version);
    } catch (error) {
      debugPrint('SonarpadApp: errore caricamento changelog: $error');
    }
  }

  void _initAppLinks() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final appLinks = AppLinks();
      appLinks.getInitialLink().then((uri) {
        if (uri != null && uri.scheme == 'file') {
          _handleIncomingFile(uri);
        }
      }).catchError((_) {});

      _linkSubscription = appLinks.uriLinkStream.listen((uri) {
        if (uri.scheme == 'file') {
          _handleIncomingFile(uri);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _initSharedMediaIntents() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _sharedMediaChannel
        .invokeMethod<String>('getInitialSharedFile')
        .then((path) {
      if (path == null || path.isEmpty) return;
      _handleIncomingFile(Uri.file(path));
    }).catchError((_) {});

    _sharedMediaSubscription =
        _sharedMediaEvents.receiveBroadcastStream().listen((event) {
      final path = event?.toString() ?? '';
      if (path.isEmpty) return;
      _handleIncomingFile(Uri.file(path));
    }, onError: (_) {});
  }

  Future<void> _handleIncomingFile(Uri uri) async {
    try {
      final decodedPath = Uri.decodeComponent(uri.path);
      final originalFile = File(decodedPath);
      if (!await originalFile.exists()) return;

      final basename = p.basename(originalFile.path);
      final displayName = _sharedMediaDisplayName(basename);
      final ext = p.extension(originalFile.path).toLowerCase();
      final isAudio =
          ['.mp3', '.m4a', '.wav', '.ogg', '.flac', '.aac'].contains(ext);
      final isVideo = ['.mp4', '.avi', '.mov', '.mkv'].contains(ext);
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        _pendingSharedUri = uri;
        return;
      }

      if (isAudio || isVideo) {
        final episode = PodcastEpisode(
          id: basename,
          title: displayName,
          audioUrl: originalFile.uri.toString(),
          publishedAt: DateTime.now(),
          description: '',
        );
        navigator.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/local_media_player'),
            builder: (_) => PodcastEpisodePlayerScreen(
              episode: episode,
              isVideoSupported: isVideo,
              startWithVideo: isVideo,
            ),
          ),
        );
        return;
      }

      final lib = DocumentLibraryService();
      await lib.load();
      final doc = await lib.importFile(originalFile, originalName: displayName);
      await lib.add(doc);

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
    } catch (e) {
      debugPrint('SonarpadApp: Errore importazione file condiviso: $e');
    }
  }

  String _sharedMediaDisplayName(String basename) {
    return basename.replaceFirst(
      RegExp(
        r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}_',
      ),
      '',
    );
  }

  void setLocale(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _sharedMediaSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_locale == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final pendingSharedUri = _pendingSharedUri;
    if (pendingSharedUri != null) {
      _pendingSharedUri = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleIncomingFile(pendingSharedUri);
      });
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Sonarpad',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: sonarpadTheme(),
      home: const HomeScreen(),
      routes: {
        '/documents': (_) => const DocumentsScreen(),
        '/news': (_) => const NewsScreen(),
        '/meteo': (_) => const WeatherScreen(),
        '/podcasts': (_) => const PodcastScreen(),
        '/convert_media': (_) => const ConvertMediaScreen(),
        '/radio': (_) => const RadioScreen(),
        '/tv': (_) => const TvScreen(),
        '/raiplaysound': (_) => const RaiPlaySoundScreen(),
        '/raiplay': (_) => const RaiPlayScreen(),
        '/wikipedia': (_) => const WikipediaScreen(),
        '/bdciechi': (_) => const BdCiechiLoginScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/aifa': (_) => const AifaSearchScreen(),
        '/orari_apertura': (_) => OrariAperturaSearchScreen(),
        '/italiaonline': (_) => const ItaliaOnlineScreen(),
        '/route': (_) => const RouteScreen(),
        '/audiodescriptions': (_) => const AudiodescriptionRecentScreen(),
        '/info': (_) => const InfoScreen(),
        '/calendar': (_) => const CalendarScreen(),
        '/voice_dictionary': (_) => const VoiceDictionaryScreen(),
      },
    );
  }
}
