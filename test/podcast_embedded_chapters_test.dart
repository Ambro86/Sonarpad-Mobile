import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:sonarpad_mobile_starter/screens/podcast_chapters_screen.dart';
import 'package:sonarpad_mobile_starter/services/podcast_service.dart';

const _accessOnAudioUrl =
    'https://pinecast.com/listen/f2d89618-33c6-462e-9a38-1cbe88026a53.mp3'
    '?source=rss&ext=asset.mp3';

const _accessOnEpisode = PodcastEpisode(
  title: 'The BrailleNote Evolve from HumanWare',
  description: '',
  audioUrl: _accessOnAudioUrl,
);

void main() {
  test('parses the embedded chapter format used by Access On', () {
    final service = PodcastService();
    final chapters = service.parseEmbeddedMediaChapters([
      {
        'start_time': '7328.917000',
        'tags': {'title': 'Closing and contact info'},
      },
      {
        'start_time': '0.000000',
        'tags': {'TITLE': 'Looking ahead to our gaming Access On webinar'},
      },
      {
        'start_time': '133.988000',
        'tags': {'title': 'What is BrailleNote Evolve'},
      },
    ]);

    expect(chapters, hasLength(3));
    expect(chapters.first.start, Duration.zero);
    expect(chapters[1].title, 'What is BrailleNote Evolve');
    expect(chapters[1].start, const Duration(milliseconds: 133988));
    expect(chapters.last.start, const Duration(milliseconds: 7328917));
  });

  test(
    'falls back from RSS metadata to chapters embedded in the MP3',
    () async {
      String? probedUrl;
      final service = PodcastService(
        client: MockClient((_) async => http.Response('not used', 404)),
        embeddedChapterLoader: (url) async {
          probedUrl = url;
          return const [
            PodcastChapter(
              start: Duration(milliseconds: 133988),
              title: 'What is BrailleNote Evolve',
            ),
          ];
        },
      );

      final chapters = await service.fetchEpisodeChapters(_accessOnEpisode);

      expect(probedUrl, _accessOnAudioUrl);
      expect(chapters.single.start, const Duration(milliseconds: 133988));
    },
  );

  testWidgets('selecting a chapter returns its exact seek position', (
    tester,
  ) async {
    Duration? selectedPosition;
    const chapters = [
      PodcastChapter(
        start: Duration(milliseconds: 133988),
        title: 'What is BrailleNote Evolve',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selectedPosition = await Navigator.push<Duration>(
                context,
                MaterialPageRoute(
                  builder: (_) => PodcastChaptersScreen(
                    episode: _accessOnEpisode,
                    chapters: chapters,
                  ),
                ),
              );
            },
            child: const Text('Apri capitoli'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri capitoli'));
    await tester.pumpAndSettle();
    expect(find.text('2:13'), findsOneWidget);

    await tester.tap(find.text('What is BrailleNote Evolve'));
    await tester.pumpAndSettle();

    expect(selectedPosition, const Duration(milliseconds: 133988));
  });
}
