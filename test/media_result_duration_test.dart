import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_en.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_it.dart';
import 'package:sonarpad_mobile_starter/l10n/localized_dynamic_labels.dart';
import 'package:sonarpad_mobile_starter/utils/sonarmusic_item_subtitle.dart';

void main() {
  test('result duration uses the same human wording as the playback slider', () {
    final it = AppLocalizationsIt();
    expect(it.formatMediaResultDuration('4:32'), '4 minuti e 32 secondi');
    expect(it.formatMediaResultDuration('1:15:30'),
        '1 ora, 15 minuti e 30 secondi');
    expect(it.formatMediaResultDuration('62:03'),
        '1 ora, 2 minuti e 3 secondi');
    expect(it.formatMediaResultDuration('0:05'), '5 secondi');
    expect(it.formatMediaResultDuration('1:00'), '1 minuto');
    expect(it.formatMediaResultDuration('0:00'), '0 secondi');
    expect(it.formatMediaResultDuration('DIRETTA'), 'DIRETTA');
    expect(it.formatMediaResultDuration('1:99'), '1:99');
  });

  test('human duration reuses language-specific units', () {
    final en = AppLocalizationsEn();
    expect(en.formatMediaResultDuration('4:32'), '4 minutes and 32 seconds');
    expect(en.formatMediaResultDuration('1:15:30'),
        '1 hour, 15 minutes and 30 seconds');
  });

  test('SonarMusic formats the duration once, before other metadata', () {
    final it = AppLocalizationsIt();
    String format(String clock) =>
        it.sourceDurationValue(it.formatMediaResultDuration(clock));
    expect(sonarMusicItemSubtitle(
      title: 'Lontano Da Qui', kind: 'video', kindLabel: 'Video musicali',
      duration: '4:22', subtitle: 'Video musicali • 616K riproduzioni • 4:22',
      formatDuration: format,
    ), 'Video musicali. Durata: 4 minuti e 22 secondi. 616K riproduzioni');
    expect(sonarMusicItemSubtitle(
      title: 'Lontano Da Qui', kind: 'video', kindLabel: 'Video musicali',
      subtitle: 'Video musicali • 616K riproduzioni • 4:22',
      formatDuration: format,
    ), 'Video musicali. Durata: 4 minuti e 22 secondi. 616K riproduzioni');
    expect(sonarMusicItemSubtitle(
      title: 'Brano', kind: 'song', kindLabel: 'Brani',
      artist: 'Elisa', duration: '1:15:30',
      subtitle: 'Elisa • 1:15:30 • Album', formatDuration: format,
    ), 'Brani. Elisa. Durata: 1 ora, 15 minuti e 30 secondi. Album');
  });
}
