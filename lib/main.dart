import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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

import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        colorSchemeSeed: Colors.blue,
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
        '/settings': (_) => const SettingsScreen(),
        '/aifa': (_) => const AifaSearchScreen(),
        '/info': (_) => const InfoScreen(),
      },
    );
  }
}
