import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonarpad_mobile_starter/services/media_cutter_seek_step_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first run uses the existing five-second default', () async {
    expect(await MediaCutterSeekStepPreferences.load(),
        const Duration(seconds: 5));
  });

  test('one-second choice survives a fresh preferences read', () async {
    await MediaCutterSeekStepPreferences.save(const Duration(seconds: 1));
    expect(await MediaCutterSeekStepPreferences.load(),
        const Duration(seconds: 1));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt(MediaCutterSeekStepPreferences.storageKey), 1000);
  });

  test('all existing navigation steps can be saved and restored', () async {
    for (final step in MediaCutterSeekStepPreferences.allowedSteps) {
      await MediaCutterSeekStepPreferences.save(step);
      expect(await MediaCutterSeekStepPreferences.load(), step);
    }
  });

  test('invalid stored value reverts to five seconds safely', () async {
    SharedPreferences.setMockInitialValues({
      MediaCutterSeekStepPreferences.storageKey: 12345,
    });
    expect(await MediaCutterSeekStepPreferences.load(),
        const Duration(seconds: 5));
  });

  test('unsupported steps cannot overwrite user preference', () async {
    await MediaCutterSeekStepPreferences.save(const Duration(seconds: 1));
    await expectLater(
      MediaCutterSeekStepPreferences.save(const Duration(seconds: 3)),
      throwsArgumentError,
    );
    expect(await MediaCutterSeekStepPreferences.load(),
        const Duration(seconds: 1));
  });
}
