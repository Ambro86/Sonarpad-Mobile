import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/persistent_form_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new installs keep MP3 and ask for the destination', () async {
    final service = PersistentFormPreferences();
    final contact = await service.loadReportContact();
    expect(contact, (name: '', email: ''));
    final conversion = await service.loadConverter();
    expect(conversion.format, 'mp3');
    expect(conversion.destination, MediaExportPreference.ask);
  });

  test('report contact survives reopening, replacement and clearing', () async {
    await PersistentFormPreferences().saveReportContact(
      name: ' Ada ', email: ' ada@example.org ');
    expect(await PersistentFormPreferences().loadReportContact(),
      (name: 'Ada', email: 'ada@example.org'));
    await PersistentFormPreferences().saveReportContact(
      name: 'New name', email: '');
    expect(await PersistentFormPreferences().loadReportContact(),
      (name: 'New name', email: ''));
    await PersistentFormPreferences().saveReportContact(name: '', email: '');
    expect(await PersistentFormPreferences().loadReportContact(),
      (name: '', email: ''));
  });

  test('lossless formats and all attributes survive reopening', () async {
    for (final format in ['wav', 'flac']) {
      for (final destination in MediaExportPreference.values) {
        final settings = ConverterPreferences(format: format, bitrate: 256,
          wavBitDepth: 'float32', oggQuality: 8, flacCompression: 12,
          destination: destination);
        await PersistentFormPreferences().saveConverter(settings);
        expect((await PersistentFormPreferences().loadConverter()).toJson(),
          settings.toJson());
      }
    }
  });

  test('rapid edits are persisted in order before reopening', () async {
    final service = PersistentFormPreferences();
    final writes = [for (final format in ['mp3', 'wav', 'flac'])
      service.saveConverter(ConverterPreferences(format: format))];
    final restored = await PersistentFormPreferences().loadConverter();
    await Future.wait(writes);
    expect(restored.format, 'flac');
  });

  test('corrupt and obsolete preferences fall back safely', () async {
    for (final raw in ['not json', '[]', jsonEncode({
      'format': 'unknown', 'bitrate': -10, 'wavBitDepth': 'unknown',
      'oggQuality': 100, 'flacCompression': 'bad', 'destination': 'obsolete',
    })]) {
      SharedPreferences.setMockInitialValues({
        'sonarpad_converter_preferences': raw,
        'sonarpad_report_contact': raw,
      });
      final service = PersistentFormPreferences();
      expect((await service.loadConverter()).toJson(),
        const ConverterPreferences().toJson());
      expect(await service.loadReportContact(), (name: '', email: ''));
    }
  });
}
