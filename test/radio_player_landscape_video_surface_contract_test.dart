import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('landscape fullscreen gives the video a real layout size', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(source, contains('Widget _buildFullscreenVideoSurface({'));
    expect(source, contains('child: LayoutBuilder('));
    expect(source, contains('final surfaceSize = Size(width, height);'));
    expect(source, contains('width: width,'));
    expect(source, contains('height: height,'));
    expect(source, contains("engine: 'media_kit'"));
    expect(source, contains("engine: 'video_player'"));

    // A native/texture-backed video must not be created at 16x9 logical
    // pixels and then depend on FittedBox to enlarge it on iOS.
    expect(
      source,
      isNot(contains('width: 16,\n              height: 9,')),
    );
    expect(
      source,
      isNot(contains('child: FittedBox(\n            fit: BoxFit.contain')),
    );
  });

  test('fullscreen video diagnostics report orientation and real surface size', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(source, contains('RadioPlayer: fullscreen orientation change'));
    expect(source, contains('RadioPlayer: fullscreen video layout engine='));
    expect(source, contains('available='));
    expect(source, contains('surface='));
    expect(source, contains('aspect='));
  });
}
