/// Source ranges passed to the cutter's existing segment exporter for insertion.
class CutterSourceRange {
  const CutterSourceRange(this.path, this.start, this.end);
  final String path;
  final Duration start;
  final Duration end;
  Duration get duration => end - start;
}

List<T> selectCutterParts<T>(
  Iterable<T> parts, {
  required bool Function(T) keep,
  required String Function(T) key,
  String? selected,
}) {
  final kept = parts.where(keep).toList();
  if (selected == null || !kept.any((part) => key(part) == selected)) {
    return kept;
  }
  return kept.where((part) => key(part) == selected).toList();
}

/// Normalizes inserted sources through the same segment/concat exporter.
List<String> cutterInsertionSegmentArguments({
  required CutterSourceRange range,
  required String output,
  required bool sourceVideo,
  required bool sourceAudio,
  required bool outputVideo,
  required bool outputAudio,
  required String videoMap,
  required String audioMap,
  required List<String> codecs,
}) {
  final args = <String>[
    '-y',
    '-fflags',
    '+genpts',
    '-ss',
    (range.start.inMicroseconds / 1000000).toStringAsFixed(6),
    '-i',
    range.path,
  ];
  var next = 1;
  String? video = sourceVideo ? videoMap : null;
  String? audio = sourceAudio ? audioMap : null;
  if (outputVideo && !sourceVideo) {
    video = '${next++}:v:0';
    args.addAll(['-f', 'lavfi', '-i', 'color=c=black:s=1280x720:r=25']);
  }
  if (outputAudio && !sourceAudio) {
    audio = '${next++}:a:0';
    args.addAll(['-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo']);
  }
  args.addAll([
    '-t',
    (range.duration.inMicroseconds / 1000000).toStringAsFixed(6),
  ]);
  if (outputVideo) {
    args.addAll([
      '-map',
      video!,
      '-vf',
      'scale=1280:720:force_original_aspect_ratio=decrease,'
          'pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=25',
    ]);
  } else {
    args.add('-vn');
  }
  if (outputAudio) {
    args.addAll([
      '-map',
      audio!,
      '-af',
      'aresample=44100:async=1:first_pts=0,'
          'aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo',
    ]);
  }
  return [
    ...args,
    '-sn',
    '-dn',
    '-map_metadata',
    '-1',
    '-map_chapters',
    '-1',
    ...codecs,
    '-avoid_negative_ts',
    'make_zero',
    if (outputVideo) ...[
      '-metadata:s:v:0',
      'rotate=0',
      '-movflags',
      '+faststart',
    ],
    output,
  ];
}

List<CutterSourceRange> cutterInsertionRanges({
  required String original,
  required Duration duration,
  required String inserted,
  required Duration insertedDuration,
  required Duration before,
}) {
  if (before < Duration.zero ||
      before > duration ||
      insertedDuration <= Duration.zero) {
    throw ArgumentError();
  }
  return [
    if (before > Duration.zero)
      CutterSourceRange(original, Duration.zero, before),
    CutterSourceRange(inserted, Duration.zero, insertedDuration),
    if (before < duration) CutterSourceRange(original, before, duration),
  ];
}

Duration? parseCutterPosition(String value, Duration maximum) {
  final fields = value.trim().replaceAll(',', '.').split(':');
  if (fields.isEmpty || fields.length > 3) return null;
  var seconds = 0.0;
  for (var i = 0; i < fields.length; i++) {
    final field = fields[i];
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(field) ||
        (i < fields.length - 1 && field.contains('.'))) {
      return null;
    }
    final number = double.tryParse(field);
    if (number == null || !number.isFinite || (i > 0 && number >= 60)) {
      return null;
    }
    seconds = seconds * 60 + number;
  }
  if (!seconds.isFinite || seconds > maximum.inMicroseconds / 1000000) {
    return null;
  }
  return Duration(microseconds: (seconds * 1000000).round());
}

List<String> cutterStillVideoArguments({
  required String audio,
  required String output,
  required Duration duration,
  String? image,
}) => [
  '-y',
  if (image == null) ...[
    '-f',
    'lavfi',
    '-i',
    'color=c=black:s=1280x720:r=25',
  ] else ...[
    '-loop',
    '1',
    '-framerate',
    '25',
    '-i',
    image,
  ],
  '-i',
  audio,
  '-map',
  '0:v:0',
  '-map',
  '1:a:0',
  '-vf',
  'scale=1280:720:force_original_aspect_ratio=decrease,'
      'pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1',
  '-c:v',
  'mpeg4',
  '-q:v',
  '4',
  '-pix_fmt',
  'yuv420p',
  '-c:a',
  'aac',
  '-b:a',
  '192k',
  '-t',
  (duration.inMicroseconds / 1000000).toStringAsFixed(6),
  '-shortest',
  '-movflags',
  '+faststart',
  output,
];
