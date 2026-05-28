import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rhttp_plus/rhttp_plus.dart' as rhttp;

import 'l10n/app_localizations.dart';
import 'services/app_settings_service.dart';
import 'screens/documents_screen.dart';
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
import 'screens/bdciechi_login_screen.dart';
import 'screens/route_screen.dart';
import 'screens/audiodescription_recent_screen.dart';
import 'screens/orari_apertura_search_screen.dart';

import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await rhttp.Rhttp.init();
  } catch (error) {
    debugPrint('Errore inizializzazione rhttp_plus: $error');
  }
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
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
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    AppSettingsService().loadAppLanguage().then((lang) {
      if (mounted) {
        setState(() {
          _locale = Locale(lang);
        });
      }
    });
  }

  void setLocale(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
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

    return MaterialApp(
      title: 'Sonarpad',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007BFF),
          primary: const Color(0xFF007BFF),
          secondary: const Color(0xFF0056b3),
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
      ),
      home: const HomeScreen(),
      routes: {
        '/documents': (_) => const DocumentsScreen(),
        '/news': (_) => const NewsScreen(),
        '/podcasts': (_) => const PodcastScreen(),
        '/radio': (_) => const RadioScreen(),
        '/tv': (_) => const TvScreen(),
        '/raiplaysound': (_) => const RaiPlaySoundScreen(),
        '/raiplay': (_) => const RaiPlayScreen(),
        '/wikipedia': (_) => const WikipediaScreen(),
        '/bdciechi': (_) => const BdCiechiLoginScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/aifa': (_) => const AifaSearchScreen(),
        '/orari_apertura': (_) => OrariAperturaSearchScreen(),
        '/route': (_) => const RouteScreen(),
        '/audiodescriptions': (_) => const AudiodescriptionRecentScreen(),
        '/info': (_) => const InfoScreen(),
      },
    );
  }
}
