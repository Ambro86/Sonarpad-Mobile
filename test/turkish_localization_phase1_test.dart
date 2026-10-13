import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/l10n/localized_dynamic_labels.dart';
import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Turkish and Turkey locales load translated controls and placeholders',
      () async {
    for (final locale in const [Locale('tr'), Locale('tr', 'TR')]) {
      expect(AppLocalizations.delegate.isSupported(locale), isTrue);
      final l10n = await AppLocalizations.delegate.load(locale);

      expect(l10n.settings, 'Ayarlar');
      expect(l10n.calendarToday, 'Bugün');
      expect(l10n.audioDescriptionLanguage, 'Sesli betimleme dili');
      expect(l10n.languageLabel('tr'), 'Türkçe');
      expect(l10n.languageLabel('tr-TR'), 'Türkçe');
      expect(l10n.radioCountryLabel('tr'), 'Türkiye');
      expect(l10n.positionLabel(3, 'Radyo'),
          '3. konum: Radyo öğesinden önce');
      expect(l10n.radioResultsFound(12), '12 radyo istasyonu bulundu');
      expect(l10n.routeDurationHoursMinutes(1, 5), '1 sa 5 dk');
    }
  });

  test('Turkish plural messages preserve singular and numeric forms',
      () async {
    for (final locale in const [Locale('tr'), Locale('tr', 'TR')]) {
      final l10n = await AppLocalizations.delegate.load(locale);

      expect(l10n.deleteRecordingsConfirmation(1),
          'Bir kayıt kalıcı olarak silinsin mi?');
      expect(l10n.deleteRecordingsConfirmation(2),
          '2 kayıt kalıcı olarak silinsin mi?');
      expect(l10n.sonarTubeVideoCount(1), '1 video');
      expect(l10n.sonarTubeVideoCount(2), '2 video');
    }
  });

  test('choosing Turkish survives a fresh settings service instance', () async {
    final settings = AppSettingsService();
    await settings.saveAppLanguage('en');
    await settings.saveAppLanguage('tr');

    expect(await AppSettingsService().loadAppLanguage(), 'tr');
  });

  test('Turkish uses Turkish voices when no voice preferences were saved',
      () async {
    await AppSettingsService().saveAppLanguage('tr');
    final reloaded = AppSettingsService();

    expect(await reloaded.loadTtsLanguage(), 'tr-TR');
    expect(await reloaded.loadTtsVoice(), 'tr-TR-EmelNeural');
    expect(await reloaded.loadSystemTtsLanguage(), 'tr-TR');
    expect(await reloaded.loadSystemTtsVoice(), isNull);
  });

  test('changing the app to Turkish preserves explicit voice preferences',
      () async {
    final settings = AppSettingsService();
    await settings.saveAppLanguage('en');
    await settings.saveTtsSettings(
      languageCode: 'fr-FR',
      voice: 'fr-FR-DeniseNeural',
    );
    await settings.saveSystemTtsLanguage('en-GB');
    await settings.saveSystemTtsVoice('saved-system-voice');
    await settings.saveAppLanguage('tr');

    final reloaded = AppSettingsService();
    expect(await reloaded.loadAppLanguage(), 'tr');
    expect(await reloaded.loadTtsLanguage(), 'fr-FR');
    expect(await reloaded.loadTtsVoice(), 'fr-FR-DeniseNeural');
    expect(await reloaded.loadSystemTtsLanguage(), 'en-GB');
    expect(await reloaded.loadSystemTtsVoice(), 'saved-system-voice');
  });

  test('other app languages retain their previous default voice settings',
      () async {
    for (final language in ['it', 'en', 'fr']) {
      await AppSettingsService().saveAppLanguage(language);
      final reloaded = AppSettingsService();

      expect(await reloaded.loadTtsLanguage(), 'it');
      expect(await reloaded.loadTtsVoice(), 'it-IT-IsabellaNeural');
      expect(await reloaded.loadSystemTtsLanguage(), 'it-IT');
    }
  });
}
