import 'package:flutter/material.dart';

import 'news_screen.dart';
import 'podcast_screen.dart';
import 'wikipedia_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sonarpad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Sonarpad',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              semanticsLabel: 'Sonarpad, schermata principale',
            ),
            const SizedBox(height: 24),
            _HomeButton(
              label: 'Notizie',
              hint: 'Apre le notizie da Google News RSS',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsScreen())),
            ),
            _HomeButton(
              label: 'Podcast',
              hint: 'Iscriviti ai podcast, riproduci o scarica episodi',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PodcastScreen())),
            ),
            _HomeButton(
              label: 'Importa da Wikipedia',
              hint: 'Cerca un articolo Wikipedia e importa il testo',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WikipediaScreen())),
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
  const _HomeButton({required this.label, required this.hint, required this.onPressed});

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
