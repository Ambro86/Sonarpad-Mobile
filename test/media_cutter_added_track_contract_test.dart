import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('add-track action is available only after a main media file is loaded', () {
    final source =
        File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    expect(source, contains("if (_inputPath.isNotEmpty)"));
    expect(source, contains("id: 'add_track'"));
    expect(source, contains('l10n.mediaCutterAddTrack'));
    expect(source, contains('MediaCutterAddTrackScreen('));
    expect(source, contains('MaterialPageRoute<MediaCutterAddedTrackSettings>'));
  });

  test('clean Material add-track screen exposes requested controls', () {
    final source = File('lib/screens/media_cutter_add_track_screen.dart')
        .readAsStringSync();
    expect(source, contains('Scaffold('));
    expect(source, contains('FilePicker.pickFiles('));
    expect(source, contains('mediaCutterOriginalTrackVolume'));
    expect(source, contains('mediaCutterNewTrackVolume'));
    expect(source, contains('CheckboxListTile('));
    expect(source, contains('bool _loop = false;'));
    expect(source, contains('mediaCutterPreviewNewTrack'));
    expect(source, contains('mediaCutterFinalizeTrack'));
  });

  test('final export mixes the added track after cuts and supports looping', () {
    final source =
        File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    final assembly = source.indexOf("'assembled\$ext'");
    final mix = source.indexOf('_mixAddedTrackIntoExport(');
    expect(assembly, greaterThan(-1));
    expect(mix, greaterThan(-1));
    expect(source, contains("if (settings.loop) args.addAll(['-stream_loop', '-1']);"));
    expect(source, contains('amix=inputs=2:duration=first'));
    expect(source, contains('settings.originalVolumePercent'));
    expect(source, contains('settings.newTrackVolumePercent'));
    expect(source, contains('expectedAudio: source.hasAudio || addedTrack != null'));
  });

  test('all locales contain the add-track strings', () {
    const locales = [
      'it',
      'en',
      'es',
      'fr',
      'de',
      'pl',
      'cs',
      'pt',
      'pt_BR',
      'uk',
      'zh_CN',
    ];
    const keys = [
      'mediaCutterAddTrack',
      'mediaCutterChooseAudioTrack',
      'mediaCutterAddedTrackSelected',
      'mediaCutterOriginalTrackVolume',
      'mediaCutterNewTrackVolume',
      'mediaCutterLoopNewTrack',
      'mediaCutterPreviewNewTrack',
      'mediaCutterFinalizeTrack',
      'mediaCutterAddedTrackApplied',
      'mediaCutterAddedTrackInvalidAudio',
      'mediaCutterAddedTrackPreviewPreparing',
      'mediaCutterAddedTrackPreviewFailed',
      'mediaCutterMixingAddedTrack',
    ];
    for (final locale in locales) {
      final data = jsonDecode(
        File('lib/l10n/app_$locale.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in keys) {
        expect(data[key], isNotNull, reason: '$locale: $key');
        expect(data[key].toString().trim(), isNotEmpty,
            reason: '$locale: $key');
      }
    }
  });

  test('preview reuses the Media Cutter player instead of creating a second just_audio instance', () {
    final screen =
        File('lib/screens/media_cutter_add_track_screen.dart').readAsStringSync();
    final cutter =
        File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    expect(screen, isNot(contains('AudioPlayer _previewPlayer')));
    expect(screen, isNot(contains('AudioPlayer()')));
    expect(screen, contains('required this.playPreviewFile'));
    expect(screen, contains('required this.stopPreviewPlayback'));
    expect(screen, contains('await widget.playPreviewFile(preview.path)'));
    expect(cutter, contains('playPreviewFile: _playAddedTrackPreviewFile'));
    expect(cutter, contains('stopPreviewPlayback: _stopAddedTrackPreviewPlayback'));
    expect(cutter, contains('_usingAddedTrackPreviewSource'));
    expect(cutter, contains("media_cutter_added_track_preview:"));
    expect(cutter, contains('await _setAudioSourceWithRetry(_inputPath)'));
  });
}
