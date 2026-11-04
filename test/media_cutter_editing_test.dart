import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/media_cutter_editing.dart';

void main() {
  test(
    'selects thirty seconds from forty minutes without changing other parts',
    () {
      final parts = [(0, 1200, true), (1200, 1230, true), (1230, 2400, true)];
      final selected = selectCutterParts(
        parts,
        keep: (p) => p.$3,
        key: (p) => '${p.$1}:${p.$2}',
        selected: '1200:1230',
      );
      expect(selected, [(1200, 1230, true)]);
      expect(parts, hasLength(3));
      expect(
        selectCutterParts(
          parts,
          keep: (p) => p.$3,
          key: (p) => '${p.$1}:${p.$2}',
        ),
        parts,
      );
      expect(
        selectCutterParts(
          parts,
          keep: (p) => p.$3,
          key: (p) => '${p.$1}:${p.$2}',
          selected: 'obsolete',
        ),
        parts,
      );
      expect(
        selectCutterParts(
          [(0, 5, false), (5, 9, true)],
          keep: (p) => p.$3,
          key: (p) => '${p.$1}',
          selected: '0',
        ),
        [(5, 9, true)],
      );
    },
  );

  test(
    'time input accepts seconds and clock formats, rejects invalid ranges',
    () {
      const maximum = Duration(minutes: 40);
      for (final value in ['1230', '20:30', '00:20:30']) {
        expect(
          parseCutterPosition(value, maximum),
          const Duration(minutes: 20, seconds: 30),
        );
      }
      expect(
        parseCutterPosition('1:02,5', maximum),
        const Duration(milliseconds: 62500),
      );
      expect(parseCutterPosition('40:00', maximum), maximum);
      for (final value in [
        '',
        '-1',
        'NaN',
        'Infinity',
        '1:60',
        '40:01',
        '1.5:00',
      ]) {
        expect(parseCutterPosition(value, maximum), isNull, reason: value);
      }
    },
  );

  test('insertion preserves every source range at start, middle and end', () {
    for (final before in [0, 1200, 2400]) {
      final ranges = cutterInsertionRanges(
        original: 'original',
        duration: const Duration(seconds: 2400),
        inserted: 'intro',
        insertedDuration: const Duration(seconds: 30),
        before: Duration(seconds: before),
      );
      expect(
        ranges.fold<int>(0, (sum, range) => sum + range.duration.inSeconds),
        2430,
      );
      expect(
        ranges.where((r) => r.path == 'intro').single.duration.inSeconds,
        30,
      );
      final originals = ranges.where((r) => r.path == 'original').toList();
      expect(originals.first.start, Duration.zero);
      expect(originals.last.end.inSeconds, 2400);
    }
  });

  test(
    'marker reset preserves existing cuts and all five controls exist in both renderers',
    () {
      final source = File(
        'lib/screens/media_cutter_screen.dart',
      ).readAsStringSync();
      final clear = source.substring(
        source.indexOf('  void _clearMarkers()'),
        source.indexOf('  Future<void> _goToTime()'),
      );
      expect(clear, contains('_guidedCutStart = null'));
      expect(clear, contains('_guidedCutEnd = null'));
      expect(clear, isNot(contains('_parts =')));
      expect(clear, isNot(contains('_splitPoints =')));
      for (final key in [
        'SaveScope',
        'ExportVideo',
        'GoToTime',
        'ClearMarkers',
        'InsertMedia',
      ]) {
        expect(
          'l10n.mediaCutter$key'.allMatches(source).length,
          greaterThanOrEqualTo(2),
        );
      }
    },
  );

  bool available;
  try {
    available =
        Process.runSync('ffmpeg', ['-version']).exitCode == 0 &&
        Process.runSync('ffprobe', ['-version']).exitCode == 0;
  } catch (_) {
    available = false;
  }
  final skip = available ? false : 'FFmpeg and FFprobe are required';
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sonarpad-cutter-smoke-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<void> ffmpeg(List<String> args) async {
    final result = await Process.run('ffmpeg', ['-v', 'error', ...args]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  Future<Map<String, dynamic>> probe(String path) async {
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_streams',
      '-show_format',
      '-of',
      'json',
      path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  Future<List<int>> pixel(String path, String at) async {
    final result = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-ss',
      at,
      '-i',
      path,
      '-frames:v',
      '1',
      '-vf',
      'crop=2:2:(iw-2)/2:(ih-2)/2,scale=1:1',
      '-pix_fmt',
      'rgb24',
      '-f',
      'rawvideo',
      '-',
    ], stdoutEncoding: null);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return result.stdout as List<int>;
  }

  test(
    'real audio exports to black video and chosen image with audio and correct duration',
    () async {
      final audio = '${root.path}/voice.wav';
      await ffmpeg([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=880:duration=1',
        audio,
      ]);
      final image = File('${root.path}/red.ppm');
      await image.writeAsBytes([
        ...ascii.encode('P6\n2 2\n255\n'),
        for (var i = 0; i < 4; i++) ...[255, 0, 0],
      ]);
      for (final chosen in [null, image.path]) {
        final output = '${root.path}/${chosen == null ? 'black' : 'image'}.mp4';
        await ffmpeg(
          cutterStillVideoArguments(
            audio: audio,
            output: output,
            duration: const Duration(seconds: 1),
            image: chosen,
          ),
        );
        final info = await probe(output);
        expect(
          (info['streams'] as List).map((s) => s['codec_type']),
          containsAll(['audio', 'video']),
        );
        expect(
          double.parse(info['format']['duration'] as String),
          closeTo(1, 0.15),
        );
        final color = await pixel(output, '0.3');
        expect(color, hasLength(3));
        if (chosen == null) {
          expect(color.every((v) => v < 10), isTrue);
        } else {
          expect(color[0], greaterThan(220));
          expect(color[1], lessThan(20));
        }
      }
    },
    skip: skip,
  );

  test(
    'real mixed insertion preserves video before and after and adds audible audio',
    () async {
      final video = '${root.path}/original.mp4';
      final audio = '${root.path}/intro.wav';
      await ffmpeg([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'color=c=red:s=320x240:r=25:d=1',
        '-c:v',
        'mpeg4',
        video,
      ]);
      await ffmpeg([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=880:duration=0.5',
        audio,
      ]);
      final ranges = cutterInsertionRanges(
        original: video,
        duration: const Duration(seconds: 1),
        inserted: audio,
        insertedDuration: const Duration(milliseconds: 500),
        before: const Duration(milliseconds: 500),
      );
      final paths = <String>[];
      for (var i = 0; i < ranges.length; i++) {
        final output = '${root.path}/segment$i.mp4';
        final isVideo = ranges[i].path == video;
        await ffmpeg(
          cutterInsertionSegmentArguments(
            range: ranges[i],
            output: output,
            sourceVideo: isVideo,
            sourceAudio: !isVideo,
            outputVideo: true,
            outputAudio: true,
            videoMap: '0:v:0',
            audioMap: '0:a:0',
            codecs: [
              '-c:v',
              'mpeg4',
              '-q:v',
              '4',
              '-pix_fmt',
              'yuv420p',
              '-video_track_timescale',
              '90000',
              '-c:a',
              'aac',
              '-ar',
              '44100',
              '-ac',
              '2',
            ],
          ),
        );
        paths.add(output);
      }
      final list = File('${root.path}/concat.txt');
      await list.writeAsString(
        paths.map((path) => "file '${path.replaceAll('\\', '/')}'").join('\n'),
      );
      final output = '${root.path}/joined.mp4';
      await ffmpeg([
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        list.path,
        '-c',
        'copy',
        output,
      ]);
      final info = await probe(output);
      expect(
        double.parse(info['format']['duration'] as String),
        closeTo(1.5, 0.25),
      );
      expect((await pixel(output, '0.2'))[0], greaterThan(220));
      expect((await pixel(output, '0.75')).every((v) => v < 10), isTrue);
      expect((await pixel(output, '1.3'))[0], greaterThan(220));
      final level = await Process.run('ffmpeg', [
        '-hide_banner',
        '-ss',
        '0.65',
        '-i',
        output,
        '-t',
        '0.2',
        '-vn',
        '-af',
        'volumedetect',
        '-f',
        'null',
        '-',
      ]);
      final match = RegExp(
        r'mean_volume: ([-\d.]+) dB',
      ).firstMatch('${level.stderr}');
      expect(match, isNotNull);
      expect(double.parse(match!.group(1)!), greaterThan(-40));
      expect(await File(video).exists(), isTrue);
    },
    skip: skip,
  );
}
