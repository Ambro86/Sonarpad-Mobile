import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'audio_description_project_editor_test.dart' show sampleProject;

class RepairService extends AiAudioDescriptionService {
  final calls = <int>[];
  AudioDescriptionEditableProject? saved;
  @override
  Future<AudioDescriptionProjectPreview> previewProjectDescription({
    required AudioDescriptionEditableProject project, required int index,
    required String text, bool resetCancellation = true,
  }) async {
    calls.add(index);
    if (index == 1 && text != 'Breve') {
      throw AudioDescriptionProjectTooLongException(index: index, availableSec: 3, actualSec: 5);
    }
    return const AudioDescriptionProjectPreview(path: 'unused.wav', durationSec: 2,
      availableSec: 3, ttsSpeedOverride: 1.1);
  }
  @override
  Future<void> saveEditableProject(AudioDescriptionEditableProject project) async { saved = project; }
}

Future<AudioDescriptionEditableProject> change(RepairService service,
    Future<String?> Function(AudioDescriptionProjectItem, AudioDescriptionProjectTooLongException) repair) =>
  service.changeProjectVoice(project: sampleProject('unused.json'), ttsEngine: 'gemini',
    edgeLanguage: 'it', edgeVoice: 'Achird', systemLanguage: 'it', systemVoice: null,
    speed: 1, pitch: 1, repairText: repair);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('repair retries only the rejected description and commits edited text and speed', () async {
    final service = RepairService();
    var prompts = 0;
    final result = await change(service, (item, error) async {
      expect(error.index, 1);
      expect(error.availableSec, 3);
      expect(item.text, prompts == 0 ? 'Seconda descrizione' : 'Ancora lunga');
      return ++prompts == 1 ? 'Ancora lunga' : 'Breve';
    });
    expect(service.calls, [0, 1, 1, 1]);
    expect(result.descriptions[0].text, 'Prima descrizione');
    expect(result.descriptions[1].text, 'Breve');
    expect(result.descriptions[1].originalText, 'Seconda descrizione');
    expect(result.descriptions[1].modified, isTrue);
    expect(result.descriptions[1].ttsSpeedOverride, 1.1);
    expect(service.saved, same(result));
  });
  test('cancel during repair leaves the original project and voice unsaved', () async {
    final service = RepairService();
    await expectLater(change(service, (_, _) async => null), throwsStateError);
    expect(service.calls, [0, 1]);
    expect(service.saved, isNull);
  });
}
