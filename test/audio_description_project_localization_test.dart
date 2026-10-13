import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_en.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_es.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_ro.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_tr.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_zh.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_project_strings.dart';

void main() {
  test('project labels preserve existing translations and fallback fields', () {
    final spanish = AudioDescriptionProjectStrings(AppLocalizationsEs());
    final romanian = AudioDescriptionProjectStrings(AppLocalizationsRo());
    final turkish = AudioDescriptionProjectStrings(AppLocalizationsTr());

    expect(spanish.title, 'Modificar proyecto de audiodescripción');
    expect(spanish.engine, 'Reading engine');
    expect(spanish.cancel, 'Cancel');
    expect(romanian.title, 'Editează proiectul de audiodescriere');
    expect(romanian.cancel, 'Anulează');
    expect(turkish.title, 'Sesli betimleme projesini düzenle');
    expect(turkish['menu'], turkish.title);
    expect(turkish['title'], turkish.title);
    expect(turkish['unknown-key'], 'unknown-key');
  });

  test('duration validation preserves caller formatting and opaque arguments', () {
    final english = AudioDescriptionProjectStrings(AppLocalizationsEn());
    final turkish = AudioDescriptionProjectStrings(AppLocalizationsTr());

    expect(
      english.tooLong(actual: '12.50', available: '7.00'),
      'The synthesized description lasts 12.50 seconds, but only 7.00 seconds '
      'are available. The previous text was not changed.',
    );
    expect(
      turkish.tooLong(actual: '{available}', available: '7.00'),
      'Oluşturulan sesli betimleme {available} saniye sürüyor, ancak yalnızca '
      '7.00 saniyelik süre var. Önceki metin değiştirilmedi.',
    );
    expect(
      turkish['tooLong'],
      turkish.tooLong(actual: '{actual}', available: '{available}'),
    );
  });

  test('timing details bind each argument once without template replacement', () {
    final strings = AudioDescriptionProjectStrings(AppLocalizationsTr());

    expect(
      strings.details(
        source: 'scene{start}',
        start: 'start{end}',
        end: 'end{source}',
        duration: 'duration{mode}',
        mode: 'mode{duration}',
      ),
      'Sahne scene{start} sn; MP3 start{end}-end{source} sn; '
      'ses duration{mode} sn; mode{duration}',
    );
    expect(
      strings['details'],
      strings.details(
        source: '{source}',
        start: '{start}',
        end: '{end}',
        duration: '{duration}',
        mode: '{mode}',
      ),
    );
  });

  test('video import labels keep the simplified Chinese alias consistent', () {
    final chinese = AppLocalizationsZh();
    final simplifiedChinese = AppLocalizationsZhCn();

    expect(chinese.audioDescriptionProjectChooseFromFiles, '从文件选择视频');
    expect(chinese.audioDescriptionProjectImportFromPhotos, '从照片导入视频');
    expect(
      chinese.audioDescriptionProjectChooseFromFiles,
      simplifiedChinese.audioDescriptionProjectChooseFromFiles,
    );
    expect(
      chinese.audioDescriptionProjectImportFromPhotos,
      simplifiedChinese.audioDescriptionProjectImportFromPhotos,
    );
  });
}
