import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum MediaExportPreference { ask, documents, share }

class ConverterPreferences {
  const ConverterPreferences({
    this.format = 'mp3',
    this.bitrate = 192,
    this.wavBitDepth = 'pcm16',
    this.oggQuality = 5,
    this.flacCompression = 5,
    this.destination = MediaExportPreference.ask,
  });

  final String format;
  final int bitrate;
  final String wavBitDepth;
  final int oggQuality;
  final int flacCompression;
  final MediaExportPreference destination;

  factory ConverterPreferences.fromJson(Map data) {
    int number(String key, int fallback, int min, int max) {
      final value = data[key];
      return value is int && value >= min && value <= max ? value : fallback;
    }

    return ConverterPreferences(
      format: const ['mp3', 'aac', 'm4b', 'mp4', 'avi', 'mov', 'opus',
        'ogg', 'flac', 'wav', 'aiff'].contains(data['format'])
          ? data['format'] as String : 'mp3',
      bitrate: number('bitrate', 192, 64, 320),
      wavBitDepth: const ['pcm16', 'pcm24', 'pcm32', 'float32']
          .contains(data['wavBitDepth']) ? data['wavBitDepth'] as String : 'pcm16',
      oggQuality: number('oggQuality', 5, 0, 10),
      flacCompression: number('flacCompression', 5, 0, 12),
      destination: MediaExportPreference.values.firstWhere(
        (value) => value.name == data['destination'],
        orElse: () => MediaExportPreference.ask,
      ),
    );
  }

  Map<String, Object> toJson() => {
    'format': format, 'bitrate': bitrate, 'wavBitDepth': wavBitDepth,
    'oggQuality': oggQuality, 'flacCompression': flacCompression,
    'destination': destination.name,
  };
}

/// Device preferences, separate from caches and from the report's contents.
class PersistentFormPreferences {
  static const _reportKey = 'sonarpad_report_contact';
  static const _converterKey = 'sonarpad_converter_preferences';
  static Future<void> _writes = Future<void>.value();

  Future<Map> _read(String key) async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.get(key);
      final value = raw is String ? jsonDecode(raw) : null;
      return value is Map ? value : const {};
    } on FormatException {
      return const {};
    }
  }

  Future<void> _write(String key, Map<String, Object> data) {
    final encoded = jsonEncode(data);
    final operation = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, encoded)) {
        throw StateError('form_preferences_write_failed');
      }
    });
    // A failed write must not prevent subsequent edits from being saved.
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<({String name, String email})> loadReportContact() async {
    final data = await _read(_reportKey);
    return (name: data['name'] is String ? data['name'] as String : '',
      email: data['email'] is String ? data['email'] as String : '');
  }

  Future<void> saveReportContact({required String name, required String email}) =>
      _write(_reportKey, {'name': name.trim(), 'email': email.trim()});

  Future<ConverterPreferences> loadConverter() async =>
      ConverterPreferences.fromJson(await _read(_converterKey));

  Future<void> saveConverter(ConverterPreferences value) =>
      _write(_converterKey, value.toJson());
}
