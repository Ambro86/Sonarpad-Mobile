import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media join is a separate home feature beside media cutter', () {
    final homeService =
        File('lib/services/home_customization_service.dart').readAsStringSync();
    final catalog = File('lib/utils/home_item_catalog.dart').readAsStringSync();
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(homeService, contains("static const mediaJoin = 'media_join';"));
    expect(homeService, contains('mediaCutter,\n    mediaJoin,\n    cinema,'));
    expect(catalog, contains('HomeItemIds.mediaJoin'));
    expect(catalog, contains('return l10n.joinMediaTitle;'));
    expect(home, contains("HomeItemIds.mediaJoin => '/media_join'"));
    expect(main, contains("'/media_join': (_) => const MediaJoinScreen()"));
  });

  test('media join exposes audio and video output formats with safe defaults', () {
    final service =
        File('lib/services/media_join_service.dart').readAsStringSync();
    final screen = File('lib/screens/media_join_screen.dart').readAsStringSync();

    expect(service, contains("mp3('mp3', false)"));
    expect(service, contains("m4a('m4a', false)"));
    expect(service, contains("wav('wav', false)"));
    expect(service, contains("flac('flac', false)"));
    expect(service, contains("ogg('ogg', false)"));
    expect(service, contains("opus('opus', false)"));
    expect(service, contains("aac('aac', false)"));
    expect(service, contains("wma('wma', false)"));
    expect(service, contains("aiff('aiff', false)"));
    expect(service, contains("mp4('mp4', true)"));
    expect(service, contains("mkv('mkv', true)"));
    expect(service, contains("mov('mov', true)"));
    expect(service, contains("avi('avi', true)"));
    expect(service, contains("wmv('wmv', true)"));
    expect(service, contains("mpg('mpg', true)"));
    expect(service, contains("flv('flv', true)"));
    expect(service, contains("threeGp('3gp', true)"));
    expect(service, contains("ts('ts', true)"));
    expect(
      screen,
      contains(
        'MediaJoinOutputFormat _outputFormat = MediaJoinOutputFormat.mp3;',
      ),
    );
    expect(screen, contains('MediaJoinOutputFormat.mp4,'));
    expect(screen, contains('MediaJoinOutputFormat.mkv,'));
    expect(screen, contains('MediaJoinOutputFormat.mov,'));
    expect(screen, contains('MediaJoinOutputFormat.avi,'));
    expect(screen, contains('MediaJoinOutputFormat.wmv,'));
    expect(screen, contains('MediaJoinOutputFormat.mpg,'));
    expect(screen, contains('MediaJoinOutputFormat.flv,'));
    expect(screen, contains('MediaJoinOutputFormat.threeGp,'));
    expect(screen, contains('MediaJoinOutputFormat.ts,'));
    expect(screen, contains('MediaJoinOutputFormat.wav,'));
    expect(screen, contains('MediaJoinOutputFormat.flac,'));
    expect(screen, contains('MediaJoinOutputFormat.opus,'));
    expect(screen, contains('MediaJoinOutputFormat.aac,'));
    expect(screen, contains('MediaJoinOutputFormat.wma,'));
    expect(screen, contains('MediaJoinOutputFormat.aiff,'));
    expect(service, contains("'libmp3lame'"));
    expect(service, contains("'libvorbis'"));
    expect(service, contains("'libopus'"));
    expect(service, contains("'flac'"));
    expect(service, contains("'pcm_s16le'"));
    expect(service, contains("'pcm_s16be'"));
    expect(service, contains("'wmav2'"));
    expect(service, contains("'aac'"));
    expect(service, contains("'msmpeg4v3'"));
    expect(service, contains("'mpeg2video'"));
    expect(service, contains("'anullsrc=r=44100:cl=stereo'"));
    expect(service, contains("'color=c=black:s="));
  });

  test('media join normalizes, validates and has concat fallback', () {
    final service = File('lib/services/media_join_service.dart').readAsStringSync();

    expect(service, contains('_audioNormalizationFilter'));
    expect(service, contains('_videoAudioNormalizationFilter'));
    expect(service, contains("'video concat stream copy'"));
    expect(service, contains("'video concat re-encode fallback'"));
    expect(service, contains('validationPoints: junctions'));
    expect(service, contains("'-xerror'"));
    expect(service, contains('media_join_source_changed'));
    expect(service, contains('WakelockPlus.enable()'));
    expect(service, contains('session.cancel()'));
    expect(service, contains('FFmpegKit.cancel()'));
  });

  test('media join matches shared accessible media experience', () {
    final screen = File('lib/screens/media_join_screen.dart').readAsStringSync();
    final renderer =
        File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final iosRenderer =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(screen, contains('useSharedAccessibleViewModel'));
    expect(screen, contains('_buildSharedAccessibleJoinForm'));
    expect(screen, contains('UniversalAccessibleList('));
    expect(screen, contains("kind: 'picker'"));
    expect(screen, contains("AccessibleCustomAction(id: 'move_up'"));
    expect(screen, contains("AccessibleCustomAction(id: 'move_down'"));
    expect(screen, contains("id: 'remove'"));
    expect(screen, contains('visualActions: ['));
    expect(screen, contains("icon: 'move_up'"));
    expect(screen, contains("icon: 'move_down'"));
    expect(screen, contains("icon: 'remove'"));
    expect(screen, contains('accessibilityButtonTrait: false'));
    expect(screen, contains('mergeFlutterCustomActions: true'));
    expect(screen, contains('focusToReturnAfterStructureChange'));
    expect(renderer, contains("'move_up' => Icons.arrow_upward"));
    expect(renderer, contains("'move_down' => Icons.arrow_downward"));
    expect(iosRenderer, contains('case "move_up": return "arrow.up"'));
    expect(iosRenderer, contains('case "move_down": return "arrow.down"'));

    // Legacy renderer keeps the same visible controls, excluded from semantics.
    expect(screen, contains('CustomSemanticsAction(label: l10n.moveUp)'));
    expect(screen, contains('CustomSemanticsAction(label: l10n.moveDown)'));
    expect(screen, contains('CustomSemanticsAction(label: l10n.joinMediaRemove)'));
    expect(screen, contains('customSemanticsActions:'));
    expect(screen, contains('ExcludeSemantics('));
    expect(screen, contains('Icons.arrow_upward'));
    expect(screen, contains('Icons.arrow_downward'));
    expect(screen, contains('Icons.remove_circle_outline'));
  });

  test('all ARB locales contain media join strings', () {
    const files = [
      'app_it.arb',
      'app_en.arb',
      'app_es.arb',
      'app_fr.arb',
      'app_de.arb',
      'app_pl.arb',
      'app_cs.arb',
      'app_pt.arb',
      'app_pt_BR.arb',
      'app_zh.arb',
      'app_uk.arb',
      'app_zh_CN.arb',
      'app_ro.arb',
    ];
    const keys = <String>{
      'joinMediaTitle',
      'joinMediaDescription',
      'joinMediaAddFiles',
      'joinMediaLoadingFiles',
      'joinMediaFilesTitle',
      'joinMediaNoFiles',
      'joinMediaVideoLabel',
      'joinMediaAudioLabel',
      'joinMediaActionsHint',
      'joinMediaRemove',
      'joinMediaOutputMp4',
      'joinMediaOutputMp3',
      'joinMediaJoin',
      'joinMediaFileSkipped',
      'joinMediaFilesAdded',
      'joinMediaRemoved',
      'joinMediaNeedTwoFiles',
      'joinMediaProcessing',
      'joinMediaCancelled',
      'joinMediaFailed',
      'joinMediaPreparing',
      'joinMediaNormalizing',
      'joinMediaMerging',
      'joinMediaVerifying',
      'joinMediaCompleting',
      'joinMediaCompleted',
      'joinMediaFormat',
      'joinMediaChooseFormat',
      'joinMediaAudioFormatHint',
      'joinMediaVideoFormatHint',
      'joinMediaCancelConfirmTitle',
      'joinMediaCancelConfirmMessage',
      'joinMediaKeepWorking',
      'joinMediaConfirmCancel',
      'joinMediaCancelling',
    };
    for (final fileName in files) {
      final data = jsonDecode(
        File('lib/l10n/$fileName').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in keys) {
        expect(data.containsKey(key), isTrue, reason: '$fileName missing $key');
      }
    }
  });

  test('media join progress is cancellable only after confirmation', () {
    final screen = File('lib/screens/media_join_screen.dart').readAsStringSync();
    final service =
        File('lib/services/media_join_service.dart').readAsStringSync();

    expect(screen, contains('LinearProgressIndicator('));
    expect(screen, contains('ValueNotifier<MediaJoinProgress>'));
    expect(service, contains('FFmpegKit.executeWithArgumentsAsync'));
    expect(screen, contains('joinMediaCancelConfirmTitle'));
    expect(screen, contains('joinMediaCancelConfirmMessage'));
    expect(
      screen,
      contains("'Media join UI: cancellation confirmed by user'"),
    );
    expect(screen, contains('await cancellation.cancel();'));
    expect(service, contains('await session.cancel().timeout'));
    expect(service, contains('await FFmpegKit.cancel().timeout'));
    expect(service, contains('cancellationDispatched'));
    expect(service, contains('cancel callback timeout; treating as cancelled'));
    expect(service, contains('throw const MediaJoinCancelled();'));
  });

}
