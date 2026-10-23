import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/raiplay_service.dart';
import 'package:sonarpad_mobile_starter/services/raiplay_media_export_adapter.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_media_export_service.dart';

const item=SonarTubeItem(kind:SonarTubeItemKind.video,id:'rai',title:'Film',url:'https://example.org/master.m3u8');
const italian='#EXT-X-MEDIA:TYPE=AUDIO,LANGUAGE="ita",NAME="Italiano",URI="ita.m3u8"';
const described='#EXT-X-MEDIA:TYPE=AUDIO,LANGUAGE="des",NAME="Audiodescrizione",URI="ad.m3u8"';
void main() {
  for(final adFirst in [true,false]) {
    test('MP3 and described MP4 use AD; regular MP4 uses Italian (AD first: $adFirst)',() async {
      final result=RaiPlayService().resolveHlsPlaybackUrlsFromPlaylist(
        'https://example.org/master.m3u8?token=test',
        '#EXTM3U\n${adFirst ? described : italian}\n${adFirst ? italian : described}',logChildUrls:false);
      expect(result.hasDescribedAudio,isTrue);
      final ad=await RaiPlayMediaExportAdapter(result).resolve(item);
      final regular=await RaiPlayMediaExportAdapter(result,preferDescription:false).resolve(item);
      expect(ad.audioUrl,'https://example.org/ad.m3u8?token=test');
      expect(regular.audioUrl,'https://example.org/ita.m3u8?token=test');
      expect(ad.videoUrl,'https://example.org/master.m3u8?token=test');
      expect(regular.videoUrl,ad.videoUrl);
    });
  }
  test('without AD, MP3 falls back to Italian and described option is unavailable',() async {
    final result=RaiPlayService().resolveHlsPlaybackUrlsFromPlaylist(item.url,'#EXTM3U\n$italian',logChildUrls:false);
    expect(result.hasDescribedAudio,isFalse);
    expect((await RaiPlayMediaExportAdapter(result).resolve(item)).audioUrl,'https://example.org/ita.m3u8');
  });
  test('progressive media stays a single muxed input',() async {
    const media=RaiPlayResolvedMedia(audioUrl:'https://example.org/film.mp4',videoUrl:'https://example.org/film.mp4');
    for(final prefer in [true,false]) {
      final resolved=await RaiPlayMediaExportAdapter(media,preferDescription:prefer).resolve(item);
      expect(resolved.videoUrl,isNull);expect(resolved.audioUrl,media.audioUrl);
    }
  });
  test('regular export uses a non-described fallback if Italian is absent',() async {
    final result=RaiPlayService().resolveHlsPlaybackUrlsFromPlaylist(item.url,
      '#EXTM3U\n$described\n#EXT-X-MEDIA:TYPE=AUDIO,LANGUAGE="eng",NAME="English",URI="en.m3u8"',logChildUrls:false);
    expect(result.hasDescribedAudio,isTrue);
    expect((await RaiPlayMediaExportAdapter(result,preferDescription:false).resolve(item)).audioUrl,'https://example.org/en.m3u8');
  });
  test('Rai HTTP headers precede every remote input',() {
    final args=SonarTubeMediaExportService.withInputHeaders(['-y','-i','https://video','-i','https://audio','-c','copy','out.mp4'],RaiPlayMediaExportAdapter.headers);
    expect(args.where((s)=>s=='-headers'),hasLength(2));
    expect(args[1],'-headers');expect(args[2],contains('Referer: https://www.raiplay.it/\r\n'));
    expect(args[3],'-i');expect(args.last,'out.mp4');
  });
  test('existing exports and local inputs remain unchanged',() {
    final args=['-i','local.mp4','out.mp3'];
    expect(SonarTubeMediaExportService.withInputHeaders(args,{}),same(args));
    expect(SonarTubeMediaExportService.withInputHeaders(args,RaiPlayMediaExportAdapter.headers),args);
  });
  test('save action is gated, exposed in both renderers and excluded from duplicate semantics',() {
    final screen=File('lib/screens/raiplay_screen.dart').readAsStringSync();
    expect(screen,contains("language != 'it' || !RecordingFeatureAccess.isCodeValid(code)"));
    expect(screen,contains("AccessibleCustomAction(id: 'save_content'"));
    expect(screen,contains("AccessibleVisualAction(id: 'save_content'"));
    expect(screen,contains('CustomSemanticsAction(label: AppLocalizations.of(context).saveMediaContent)'));
    expect(screen,contains('ExcludeSemantics('));
    expect(screen,contains('resolved.hasDescribedAudio ? RaiPlayMediaExportAdapter(resolved) : null'));
    final dialog=File('lib/widgets/sonartube_save_media_dialog.dart').readAsStringSync();
    expect(dialog,contains('if (describedService != null)'));
    expect(dialog,contains('service: mp3Service ?? service'));
    expect(dialog,contains('format == _SonarTubeSaveFormat.mp4Described ? describedService! : service'));
  });
}
