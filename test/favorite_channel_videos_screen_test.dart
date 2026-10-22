import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/sonartube_screen.dart';
import 'package:sonarpad_mobile_starter/screens/sonarmusic_screen.dart';
import 'package:sonarpad_mobile_starter/services/favorite_channel_videos_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
class FakeLatest extends FavoriteChannelVideosService {
  @override
  Future<FavoriteChannelVideosResult> load(List<SonarTubeItem> favorites) async => const FavoriteChannelVideosResult([
    SonarTubeItem(kind: SonarTubeItemKind.video, id: 'latest',title:'Latest upload',url:'https://www.youtube.com/watch?v=latest',channel:'Artist',channelId:'UCaaaaaaaaaaaaaaaaaaaaaa',published:'2026-10-22T12:00:00Z'),
  ],0);
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final music in [false,true]) {
    testWidgets('latest ${music ? 'music' : 'tube'} videos retain accessible secondary actions', (tester) async {
      await tester.pumpWidget(MaterialApp(locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: music ? SonarMusicScreen(libraryType:'latest',latestVideosService:FakeLatest())
          : SonarTubeScreen(latestChannels:const [],latestVideosService:FakeLatest())));
      await tester.pumpAndSettle();
      final list=tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
      final row=list.sections.expand((s)=>s.rows).singleWhere((r)=>r.title=='Latest upload');
      expect(row.actions.map((a)=>a.id), contains('create_ai_audiodescription'));
      expect(row.actions.map((a)=>a.id), contains(music ? 'transcript' : 'transcribe_video'));
      expect(row.actions.map((a)=>a.id), contains(music ? 'share' : 'share_video'));
      expect(find.text('Ultimi video dai preferiti'), findsOneWidget);
      expect(row.subtitle,contains('Artist'));
      expect(row.subtitle,isNot(contains('T12:00')));
    });
  }
  testWidgets('music favorites expose latest videos button', (tester) async {
    await tester.pumpWidget(MaterialApp(locale:const Locale('it'),
      localizationsDelegates:AppLocalizations.localizationsDelegates,
      supportedLocales:AppLocalizations.supportedLocales,
      home:SonarMusicScreen(libraryType:'favorites',latestVideosService:FakeLatest())));
    await tester.pumpAndSettle();
    expect(find.text('Ultimi video'),findsOneWidget);
    await tester.tap(find.text('Ultimi video'));
    await tester.pumpAndSettle();
    expect(find.text('Ultimi video dai preferiti'),findsOneWidget);
  });
}
