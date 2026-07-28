import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Media Cutter production export contract', () {
    late String source;
    late String exportPipeline;

    setUpAll(() {
      source = File('lib/screens/media_cutter_screen.dart').readAsStringSync();
      final start = source.indexOf('Future<void> _exportKeptParts(');
      final end = source.indexOf('void _updateExportProgress(', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      exportPipeline = source.substring(start, end);
    });

    test('uses real stream probing instead of extension-only detection', () {
      expect(source, contains('FFprobeKit.getMediaInformation'));
      expect(source, contains('_isAttachedPictureStream'));
      expect(source, contains('_inputProbe = probe'));
      expect(source, contains('_isVideo = probe.hasVideo'));
      expect(source, contains('_preferredStream(videoStreams)'));
      expect(source, contains('_preferredStream(audioStreams)'));
    });

    test('never makes required export streams optional', () {
      expect(exportPipeline, isNot(contains('0:v:0?')));
      expect(exportPipeline, isNot(contains('0:a:0?')));
      expect(
        exportPipeline,
        contains('_inputStreamMap(source, video: true)'),
      );
      expect(
        exportPipeline,
        contains('_inputStreamMap(source, video: false)'),
      );
    });

    test('does not disable video for video exports', () {
      final videoMap = exportPipeline.indexOf(
        '_inputStreamMap(source, video: true)',
      );
      final optionalAudioOnlyVn = exportPipeline.indexOf(
        "if (!source.hasVideo) args.add('-vn');",
      );
      expect(videoMap, greaterThanOrEqualTo(0));
      expect(optionalAudioOnlyVn, greaterThan(videoMap));
      expect(
        exportPipeline,
        isNot(contains("if (source.hasVideo) args.add('-vn')")),
      );
    });

    test('stages, validates, then publishes the final file', () {
      expect(exportPipeline, contains('_pendingOutputPath(output)'));
      expect(exportPipeline, contains("label: 'file finale'"));
      expect(exportPipeline, contains('deepDecode: true'));
      expect(exportPipeline, contains('_publishValidatedOutput('));
      expect(exportPipeline, contains("'pending output'"));
    });

    test('normalizes segments and has a concat re-encode fallback', () {
      expect(source, contains('aresample=44100:async=1:first_pts=0'));
      expect(source, contains('channel_layouts=stereo'));
      expect(exportPipeline, contains("'concat stream copy'"));
      expect(exportPipeline, contains("'concat re-encode fallback'"));
    });

    test('normalizes mono iPhone recordings before applying effects', () {
      final filterStart = source.indexOf('String? _audioFilterForPart(');
      final loopStart = source.indexOf(
        'for (final slot in activeSlots)',
        filterStart,
      );
      expect(filterStart, greaterThanOrEqualTo(0));
      expect(loopStart, greaterThan(filterStart));
      final setup = source.substring(filterStart, loopStart);
      expect(setup, contains('channel_layouts=stereo'));
    });

    test('keeps communication effects audible and mono-compatible', () {
      final effectsStart = source.indexOf('String? _audioFilterForEffect(');
      final effectsEnd = source.indexOf('String _pitchFilter(', effectsStart);
      expect(effectsStart, greaterThanOrEqualTo(0));
      expect(effectsEnd, greaterThan(effectsStart));
      final effects = source.substring(effectsStart, effectsEnd);
      expect(effects, contains('final strength = math.sqrt(amount);'));
      expect(
        RegExp(r'pan=mono\|c0=0\.5\*c0\+0\.5\*c1').allMatches(effects).length,
        greaterThanOrEqualTo(4),
      );
      expect(
        RegExp(r'pan=stereo\|FL=c0\|FR=c0').allMatches(effects).length,
        greaterThanOrEqualTo(4),
      );
    });

    test('checks expected streams, duration and decode points', () {
      expect(source, contains('non contiene la traccia video attesa'));
      expect(source, contains('non contiene la traccia audio attesa'));
      expect(source, contains('_durationToleranceMs'));
      expect(source, contains("'validate \$label video start'"));
      expect(source, contains("'validate \$label audio end'"));
      expect(source, contains("'validate \$label junction"));
    });

    test('applies fades after every other audio effect', () {
      expect(source, contains('filters.addAll(_terminalFadeFilters('));
      expect(
        source,
        contains('slot.effect == _MediaPartEffect.fadeIn ||'),
      );
      expect(
        source,
        contains('slot.effect == _MediaPartEffect.fadeOut'),
      );
    });

    test('applies underwater fades after mixing the bubbles', () {
      final underwaterStart =
          source.indexOf('String? _underwaterAudioFilterForPart(');
      final underwaterEnd = source.indexOf(
          'List<_MediaPartEffect> _activeEffects(', underwaterStart);
      expect(underwaterStart, greaterThanOrEqualTo(0));
      expect(underwaterEnd, greaterThan(underwaterStart));
      final underwater = source.substring(underwaterStart, underwaterEnd);
      expect(underwater, contains('_MediaPartEffect.fadeIn'));
      expect(underwater, contains('_MediaPartEffect.fadeOut'));
      expect(underwater, contains('...terminalFades'));
      expect(
        underwater.indexOf('amix=inputs=2'),
        lessThan(underwater.indexOf(r'$outputFilters[outa]')),
      );
    });
  });
}
