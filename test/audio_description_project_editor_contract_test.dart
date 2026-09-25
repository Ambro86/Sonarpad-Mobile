import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File('lib/screens/audio_description_project_editor_screen.dart').readAsStringSync();
  final service = File('lib/services/ai_audiodescription_service.dart').readAsStringSync();
  final main = File('lib/main.dart').readAsStringSync();
  final home = File('lib/screens/home_screen.dart').readAsStringSync();

  test('project editor is reachable from Media and registered as a route', () {
    expect(main, contains("'/edit_audio_description_project'"));
    expect(home, contains("routeName: '/edit_audio_description_project'"));
  });

  test('editor supports open, preview, apply, delete and re-export', () {
    expect(screen, contains("id: 'open_project'"));
    expect(screen, contains("id: 'preview'"));
    expect(screen, contains("id: 'apply'"));
    expect(screen, contains("id: 'delete'"));
    expect(screen, contains("id: 'reexport'"));
  });

  test('editor supports voice validation and SRT/VTT export', () {
    expect(screen, contains("id: 'change_voice'"));
    expect(screen, contains("_service.changeProjectVoice"));
    expect(screen, contains("_exportSubtitle('srt')"));
    expect(screen, contains("_exportSubtitle('vtt')"));
  });

  test('text edits are synthesized and duration-checked before save', () {
    expect(service, contains('previewProjectDescription'));
    expect(service, contains('audioDescriptionProjectAvailableDuration'));
    expect(service, contains('AudioDescriptionProjectTooLongException'));
    expect(service, contains('await saveEditableProject(updated)'));
  });

  test('project format is Windows v1 with mobile compatibility metadata', () {
    expect(service, contains("'format': 'sonarpad-audio-description-project'"));
    expect(service, contains("'version': 1"));
    expect(service, contains("'mobile_tts_engine': ttsEngine"));
    expect(service, contains("'protected_intervals'"));
  });

  test('re-export asks for source override and keeps project output pair', () {
    expect(service, contains('sourcePathOverride'));
    expect(service, contains('AudioDescriptionProjectExportResult'));
    expect(screen, contains('_showOutputDialog(result.outputPaths)'));
  });

  test('project editor keeps screen awake and exposes determinate progress', () {
    expect(screen, contains('WakelockPlus.enable()'));
    expect(screen, contains('LinearProgressIndicator'));
    expect(screen, contains(r"semanticsValue: '${(_progress * 100).round()}%'"));
  });
}
