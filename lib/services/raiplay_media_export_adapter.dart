import 'raiplay_service.dart';
import 'sonartube_service.dart';

/// Reuses the format/export UI while keeping RaiPlay resolution independent
/// from YouTube, including the audio track selected by RaiPlay's resolver.
class RaiPlayMediaExportAdapter extends SonarTubeService {
  RaiPlayMediaExportAdapter(this.media, {this.preferDescription = true});
  final RaiPlayResolvedMedia media;
  final bool preferDescription;
  static const headers = <String, String>{
    'Origin': 'https://www.raiplay.it',
    'Referer': 'https://www.raiplay.it/',
    'User-Agent': 'Mozilla/5.0 Sonarpad',
  };
  @override
  Future<SonarTubeResolvedMedia> resolve(SonarTubeItem item) async {
    final audio = preferDescription ? media.audioUrl : media.standardAudioUrl ?? media.videoUrl;
    return SonarTubeResolvedMedia(title:item.title,audioUrl:audio,
      videoUrl:media.videoUrl == audio ? null : media.videoUrl);
  }
}
