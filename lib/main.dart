import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
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
import 'screens/wikipedia_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SonarpadApp());
}

class SonarpadApp extends StatelessWidget {
  const SonarpadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonarpad',
      debugShowCheckedModeBanner: false,
      locale: const Locale('it'),
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
        '/info': (_) => const InfoScreen(),
      },
    );
  }
}
