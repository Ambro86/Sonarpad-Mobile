import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nonverbal voice mode defaults ON, can be switched off and persists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect((await AiAudioDescriptionPreferences.load())['nonverbal'], isTrue);
    await AiAudioDescriptionPreferences.saveNonverbalVocals(false);
    expect((await AiAudioDescriptionPreferences.load())['nonverbal'], isFalse);
    await AiAudioDescriptionPreferences.saveNonverbalVocals(true);
    expect((await AiAudioDescriptionPreferences.load())['nonverbal'], isTrue);
  });
}
