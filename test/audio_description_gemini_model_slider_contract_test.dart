import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File('lib/screens/create_ai_audiodescription_screen.dart')
      .readAsStringSync().replaceAll('\r\n', '\n');

  test('Gemini API key uses a discrete model slider with a stable focus', () {
    final start = screen.indexOf("id: 'model',");
    final end = screen.indexOf("id: 'refresh_models',", start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final model = screen.substring(start, end);
    expect(model, contains("kind: 'slider'"));
    expect(model, contains('accessibilityButtonTrait: false'));
    expect(model, contains('sliderValue: geminiModelIndex.toDouble()'));
    expect(model, contains('sliderMin: 0'));
    expect(model, contains('sliderMax: (geminiModels.length - 1).toDouble()'));
    expect(model, contains('sliderStep: 1'));
    expect(model, contains('sliderIncreasedValueLabel:'));
    expect(model, contains('sliderDecreasedValueLabel:'));
    expect(model, contains('geminiModels[index]'));
    expect(model, isNot(contains("kind: 'picker'")));
  });

  test('model slider selects synchronously and persists the Gemini model', () {
    final start = screen.indexOf("id == 'model' && _provider == 'gemini'");
    final end = screen.indexOf("id == 'mp3_bitrate'", start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final handler = screen.substring(start, end);
    expect(handler, contains('value.round().clamp(0, geminiModels.length - 1).toInt()'));
    expect(handler, contains('setState(() => _model = newModel)'));
    expect(handler, contains('AiAudioDescriptionPreferences.saveGeminiModel(newModel)'));
    expect(screen, contains("if (_provider == 'gemini') ...["));
    final managedStart = screen.indexOf("id: 'sonarpad_model_info',");
    final refreshControl = screen.indexOf("id: 'refresh_models',");
    final languageControl = screen.indexOf("id: 'language'", managedStart);
    expect(refreshControl, greaterThanOrEqualTo(0));
    expect(managedStart, greaterThan(refreshControl));
    expect(languageControl, greaterThan(managedStart));
    expect(
      screen.substring(managedStart, languageControl),
      contains('l10n.audioDescriptionServerManagedModel'),
    );
  });

  test('Brief retry progress exposes the stage and percentage exactly once', () {
    final start = screen.indexOf('Widget _buildRunningBody(');
    final end = screen.indexOf('@override\n  Widget build(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final running = screen.substring(start, end);
    expect(running, contains('child: ExcludeSemantics('));
    expect(running, contains('child: LinearProgressIndicator('));
    expect(running, contains("id: 'progress'"));
    expect(running, contains('title: _stage'));
    expect(running, contains(r"value: '${(_progress * 100).round()}%'"));
    expect(running, isNot(contains('semanticsLabel: _stage')));
    expect(running, isNot(contains('semanticsValue:')));
    expect(screen, contains("'brief_retry' => l10n.audioDescriptionStageBriefRetry"));
    expect(screen, contains("id: 'cancel'"));
  });

  test('0.5.1 release notes stay source-neutral for expanded radio search', () {
    final entries = jsonDecode(File('assets/changelog.json').readAsStringSync()) as List;
    expect((entries.first as Map)['version'], '0.5.1');
    const languages = [
      'it', 'en', 'fr', 'es', 'pt', 'pt_BR', 'pl', 'cs',
      'de', 'zh_CN', 'uk', 'ro', 'tr',
    ];
    for (final language in languages) {
      final notes = ((entries.first as Map)[language] as List).cast<String>();
      // The original 24 notes remain; later 0.5.1 notes may be appended.
      expect(notes.length, greaterThanOrEqualTo(24));
      expect(notes.length, ((entries.first as Map)['it'] as List).length,
          reason: language);
      expect(notes.skip(21).join(' '), isNot(contains('Radio Browser')));
      expect(notes.skip(21).join(' '), isNot(contains('Radio-Browser')));
      expect(notes.skip(21).join(' '), isNot(contains('RadioBOSS')));
      expect(notes.skip(21).join(' '), isNot(contains('**')));
    }
  });
}
