import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'RaiPlay Sound filtered date rows preserve secondary and sighted-only actions',
    () {
      final source =
          File('lib/screens/raiplaysound_screen.dart').readAsStringSync();
      final start = source.indexOf('class _RaiPlaySoundDateItemsScreen');
      expect(start, greaterThanOrEqualTo(0));
      final dateScreen = source.substring(start);

      expect(dateScreen, contains("id: 'preserve_media'"));
      expect(dateScreen, contains("id: 'subscribe'"));
      expect(dateScreen, contains('List<AccessibleCustomAction>'));
      expect(dateScreen, contains('List<AccessibleVisualAction>'));
      expect(dateScreen, contains("icon: 'download'"));
      expect(dateScreen, contains("icon: 'podcast_add'"));
      expect(dateScreen, contains('ExcludeSemantics('));
      expect(dateScreen, contains("event.type == 'customAction'"));
      expect(dateScreen, contains('await onPreserveMedia(item)'));
      expect(dateScreen, contains('await onSubscribe()'));
    },
  );

  test('RaiPlay Sound main list exposes matching visible action buttons', () {
    final source =
        File('lib/screens/raiplaysound_screen.dart').readAsStringSync();
    final dateStart = source.indexOf('class _RaiPlaySoundDateSelectorScreen');
    expect(dateStart, greaterThanOrEqualTo(0));
    final mainScreen = source.substring(0, dateStart);

    expect(mainScreen, contains('visualActions: ['));
    expect(mainScreen, contains("icon: 'download'"));
    expect(mainScreen, contains("icon: 'podcast_add'"));
    expect(mainScreen, contains('Icons.download'));
    expect(mainScreen, contains('Icons.podcasts'));
  });
}
