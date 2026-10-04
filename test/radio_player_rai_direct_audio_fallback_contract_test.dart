import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RAI audio-only playback uses resolved child audio before the master', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(source, contains('if (!_isVideoEnabled) {'));
    expect(
      source,
      contains('final hasDedicatedAudio = selectedAudioUrl != streams.videoUrl;'),
    );
    expect(
      source,
      contains('RAI direct audio selected because video is disabled'),
    );
    expect(source, contains('streamUrl: selectedAudioUrl,'));
    expect(source, contains('preferRaiAudioDescription: false,'));
    expect(
      source,
      contains('raiNormalAudioFallbackUrl: normalAudioFallbackUrl,'),
    );

    expect(
      RegExp(
        r"if \(!_isVideoEnabled\) \{[\s\S]*?if \(hasDedicatedAudio\) \{[\s\S]*?streamUrl: selectedAudioUrl,[\s\S]*?raiNormalAudioFallbackUrl: normalAudioFallbackUrl,[\s\S]*?return;",
      ).hasMatch(source),
      isTrue,
      reason: 'With video off, resolved AD/ITA child audio must be opened directly.',
    );
  });

  test('RAI keeps master for video and as compatibility when child audio is unavailable', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(
      source,
      contains('RAI direct audio unavailable; using master compatibility'),
    );
    expect(
      RegExp(
        r"RAI direct audio unavailable; using master compatibility[\s\S]*?streamUrl: streams\.videoUrl,[\s\S]*?enableRaiDirectAudioFallback: true,",
      ).hasMatch(source),
      isTrue,
    );
    expect(
      source,
      contains('RAI MediaKit master playback selected'),
    );
    expect(
      RegExp(
        r"RAI MediaKit master playback selected[\s\S]*?streamUrl: streams\.videoUrl,[\s\S]*?enableRaiDirectAudioFallback: false,",
      ).hasMatch(source),
      isTrue,
      reason: 'Normal video playback must continue using the master stream.',
    );
  });

  test('RAI direct AD falls back to direct ITA only if needed', () {
    final playerSource =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();
    final tvSource = File('lib/services/tv_service.dart').readAsStringSync();

    expect(
      playerSource,
      contains('final streams = await TvService().resolveAudioDescriptionStreams('),
    );
    expect(playerSource, contains('streamUrl: selectedAudioUrl,'));
    expect(
      playerSource,
      contains('raiNormalAudioFallbackUrl: normalAudioFallbackUrl,'),
    );
    expect(
      playerSource,
      contains('RAI direct AD stalled for 6s; falling back to direct ITA'),
    );
    expect(
      playerSource,
      contains('bool _raiNormalAudioFallbackInProgress = false;'),
    );
    expect(
      RegExp(
        r'_scheduleRaiNormalAudioFallback[\s\S]*?_raiNormalAudioFallbackInProgress[\s\S]*?_activateRaiNormalAudioFallback',
      ).hasMatch(playerSource),
      isTrue,
      reason: 'The AD->ITA watchdog must have its own re-entry guard.',
    );
    expect(
      RegExp(
        r'_activateRaiNormalAudioFallback[\s\S]*?_raiNormalAudioFallbackInProgress = true;[\s\S]*?_raiNormalAudioFallbackInProgress = false;',
      ).hasMatch(playerSource),
      isTrue,
      reason: 'Direct ITA fallback needs its own guard while AD open is pending.',
    );
    expect(playerSource, contains('streamUrl: normalAudioUrl,'));

    expect(tvSource, contains('final String normalAudioUrl;'));
    expect(tvSource, contains('final normalAudioUrl = itaUrl ?? finalMasterUrl;'));
    expect(tvSource, contains('final audioUrl = adUrl ?? itaUrl ?? finalMasterUrl;'));
    expect(
      tvSource,
      isNot(contains('break; // AD trovata: precedenza assoluta, non cercare oltre')),
    );
  });

  test('RAI compatibility recovery waits six seconds and preserves working playback', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(source, contains('Timer(const Duration(seconds: 6)'));
    expect(
      source,
      contains('position > Duration.zero || duration > Duration.zero'),
    );
    expect(
      source,
      contains('RAI direct-audio fallback not needed after 6s'),
    );
    expect(
      source,
      contains('RAI primary playback recovered while resolving fallback'),
    );
  });

  test('RAI stalled playback is stopped with a bounded timeout before dispose', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(
      source,
      contains('await player.stop().timeout(const Duration(seconds: 2));'),
    );
    expect(
      source,
      contains('continuing with normal dispose'),
    );
    expect(
      source,
      contains("stage: 'master'"),
    );
    expect(
      source,
      contains("stage: 'direct AD'"),
    );
  });
  test('RAI audiodescription preference is opt-out, code-gated in settings, and defaults on', () {
    final playerSource =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();
    final settingsSource =
        File('lib/screens/settings_screen.dart').readAsStringSync();
    final serviceSource =
        File('lib/services/app_settings_service.dart').readAsStringSync();

    expect(serviceSource, contains("'sonarpad_prefer_rai_audio_description'"));
    expect(
      serviceSource,
      contains('prefs.getBool(_preferRaiAudioDescriptionKey) ?? true'),
    );
    expect(
      settingsSource,
      contains('RecordingFeatureAccess.isCodeValid(tvSecretCode)'),
    );
    expect(
      settingsSource,
      contains("if (_extraFeaturesUnlocked)"),
    );
    expect(
      settingsSource,
      contains("id: 'prefer_rai_audio_description'"),
    );
    expect(
      playerSource,
      contains('await _settings.preferRaiAudioDescription();'),
    );
    expect(
      playerSource,
      contains('!_preferRaiAudioDescription &&'),
    );
    expect(
      playerSource,
      contains('? streams.normalAudioUrl'),
    );
    expect(
      playerSource,
      contains('_preferRaiAudioDescription && streams.hasAudioDescription'),
    );
    expect(playerSource, contains('selectRaiPreferredAudioTrack: true'));
    expect(
      playerSource,
      contains('final selectedTrack = preferAudioDescription'),
    );
    expect(
      playerSource,
      contains('? (describedTrack ?? italianTrack)'),
    );
    expect(
      playerSource,
      contains(': italianTrack;'),
    );
  });

  test('RAI audiodescription preference labels are localized in every ARB', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'));
    for (final file in arbFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        contains('\"settingsPreferRaiAudioDescription\"'),
        reason: file.path,
      );
      expect(
        source,
        contains('\"settingsPreferRaiAudioDescriptionHint\"'),
        reason: file.path,
      );
    }
  });

}
