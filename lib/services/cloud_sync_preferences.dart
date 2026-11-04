import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Explicit inventory. Never enumerate preferences: that would include account
/// credentials, document history, local paths and cached API responses.
class CloudPreference {
  const CloudPreference(
    this.key,
    this.kind, {
    this.values,
    this.min = 0,
    this.max = 1000,
    this.field,
  });
  final String key;
  final String kind;
  final List<String>? values;
  final num min, max;
  final String? field;

  bool accepts(Object? value) {
    if (utf8.encode(jsonEncode(value)).length > 1800) return false;
    return switch (kind) {
      'bool' => value is bool,
      'int' => value is int && value >= min && value <= max,
      'double' =>
        value is num && value.isFinite && value >= min && value <= max,
      'list' =>
        value is List &&
            value.length <= 64 &&
            value.every((v) => v is String && v.length <= 80),
      _ =>
        value is String &&
            value.length <= 256 &&
            (values == null || values!.contains(value)),
    };
  }
}

class CloudSyncPreferences {
  static const specs = <String, CloudPreference>{
    'sonartube.search_type': CloudPreference(
      'sonarpad_sonartube_search_type',
      'string',
      values: ['all', 'videos', 'playlists', 'channels', 'courses', 'podcasts'],
    ),
    'sonarmusic.search_type': CloudPreference(
      'sonarpad_sonarmusic_search_type',
      'string',
      values: ['all', 'song', 'album', 'artist', 'playlist', 'video'],
    ),
    'cutter.mode': CloudPreference(
      'sonarpad_media_cutter_mode',
      'string',
      values: ['guided', 'advanced'],
    ),
    'cutter.seek_ms': CloudPreference(
      'sonarpad_media_cutter_seek_step_ms',
      'int',
      min: 1000,
      max: 600000,
    ),
    'weather.city': CloudPreference('sonarpad_weather_city', 'string'),
    'weather.unit': CloudPreference(
      'sonarpad_weather_temperature_unit',
      'string',
      values: ['celsius', 'fahrenheit'],
    ),
    'radio.language': CloudPreference('sonarpad_radio_language', 'string'),
    'radio.country': CloudPreference('sonarpad_radio_country', 'string'),
    'radio.genre': CloudPreference('sonarpad_radio_genre', 'string'),
    'podcast.country': CloudPreference('sonarpad_podcast_country', 'string'),
    'podcast.category': CloudPreference(
      'sonarpad_podcast_category_genre_id',
      'int',
      max: 100000,
    ),
    'news.language': CloudPreference(
      'news_selected_language',
      'string',
      values: [
        'italian',
        'english',
        'french',
        'spanish',
        'portuguese',
        'portugueseBrazil',
        'polish',
        'czech',
        'german',
        'dutch',
        'chineseSimplified',
        'ukrainian',
        'romanian',
        'turkish',
      ],
    ),
    'news.local_city': CloudPreference('sonarpad_news_local_city', 'string'),
    'reader.auto_bookmark': CloudPreference('sonarpad_auto_bookmark', 'bool'),
    'reader.footnotes': CloudPreference(
      'sonarpad_include_epub_footnotes_in_text',
      'bool',
    ),
    'reader.multiple_bookmarks': CloudPreference(
      'sonarpad_multiple_document_bookmarks',
      'bool',
    ),
    'reader.slider_percent': CloudPreference(
      'sonarpad_document_slider_step_percent',
      'int',
      min: 1,
      max: 30,
    ),
    'reader.sleep_minutes': CloudPreference(
      'sonarpad_document_reading_sleep_timer_minutes',
      'int',
      max: 120,
    ),
    'reader.tts_speed': CloudPreference(
      'sonarpad_tts_speed',
      'double',
      min: 0.1,
      max: 4,
    ),
    'reader.tts_pitch': CloudPreference(
      'sonarpad_tts_pitch',
      'double',
      min: 0.5,
      max: 2,
    ),
    'playback.seek_seconds': CloudPreference(
      'sonarpad_seek_slider_step',
      'int',
      min: 10,
      max: 300,
    ),
    'playback.speed_control': CloudPreference(
      'sonarpad_media_speed_control',
      'bool',
    ),
    'playback.media_speed': CloudPreference(
      'sonarpad_media_playback_speed_media',
      'double',
      min: 0.5,
      max: 2,
    ),
    'playback.podcast_speed': CloudPreference(
      'sonarpad_media_playback_speed_podcasts',
      'double',
      min: 0.5,
      max: 2,
    ),
    'playback.sonartube_speed': CloudPreference(
      'sonarpad_media_playback_speed_sonartube',
      'double',
      min: 0.5,
      max: 2,
    ),
    'playback.audiobook_speed': CloudPreference(
      'sonarpad_media_playback_speed_audiobooks',
      'double',
      min: 0.5,
      max: 2,
    ),
    'sonartube.autoplay': CloudPreference(
      'sonarpad_sonartube_autoplay',
      'bool',
    ),
    'sonartube.channel_sort': CloudPreference(
      'sonarpad_sonartube_channel_sort',
      'string',
      values: ['newest', 'oldest', 'popular'],
    ),
    'sonartube.player_actions': CloudPreference(
      'sonarpad_sonartube_player_actions',
      'list',
    ),
    'video.enabled': CloudPreference('sonarpad_video_enabled', 'bool'),
    'video.portrait': CloudPreference(
      'sonarpad_display_video_in_portrait',
      'bool',
    ),
    'tv.audio_description': CloudPreference(
      'sonarpad_prefer_rai_audio_description',
      'bool',
    ),
    'calendar.hide_saints': CloudPreference(
      'sonarpad_calendar_hide_saints',
      'bool',
    ),
    'home.grouping': CloudPreference('sonarpad_home_grouping_enabled', 'bool'),
    'home.hidden': CloudPreference('sonarpad_home_hidden_item_ids_v1', 'list'),
    'home.order': CloudPreference('sonarpad_home_item_order_v1', 'list'),
    'converter.format': CloudPreference(
      'sonarpad_converter_preferences',
      'string',
      field: 'format',
      values: [
        'mp3',
        'aac',
        'm4b',
        'mp4',
        'avi',
        'mov',
        'opus',
        'ogg',
        'flac',
        'wav',
        'aiff',
      ],
    ),
    'converter.bitrate': CloudPreference(
      'sonarpad_converter_preferences',
      'int',
      field: 'bitrate',
      min: 64,
      max: 320,
    ),
    'converter.wav_depth': CloudPreference(
      'sonarpad_converter_preferences',
      'string',
      field: 'wavBitDepth',
      values: ['pcm16', 'pcm24', 'pcm32', 'float32'],
    ),
    'converter.ogg_quality': CloudPreference(
      'sonarpad_converter_preferences',
      'int',
      field: 'oggQuality',
      max: 10,
    ),
    'converter.flac_compression': CloudPreference(
      'sonarpad_converter_preferences',
      'int',
      field: 'flacCompression',
      max: 12,
    ),
  };

  static Future<List<Map<String, dynamic>>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final items = <Map<String, dynamic>>[];
    for (final entry in specs.entries) {
      final spec = entry.value;
      Object? value = prefs.get(spec.key);
      if (spec.field != null) {
        try {
          value = value is String
              ? (jsonDecode(value) as Map)[spec.field]
              : null;
        } on FormatException {
          value = null;
        }
      }
      if (value != null && spec.accepts(value)) {
        items.add({
          'id': entry.key,
          'data': {'value': value},
        });
      }
    }
    return items;
  }

  static List<Map<String, dynamic>> project(List<Map<String, dynamic>> items) =>
      items
          .where((item) {
            final spec = specs[item['id']];
            if (spec == null) return false;
            if (!spec.accepts((item['data'] as Map)['value'])) {
              throw const FormatException('invalid_preference');
            }
            return true;
          })
          .map(
            (item) => <String, dynamic>{
              'id': item['id'],
              'data': {'value': (item['data'] as Map)['value']},
            },
          )
          .toList();

  static Future<void> write(
    List<Map<String, dynamic>> items, {
    List<Map<String, dynamic>> baseline = const [],
  }) async {
    final selected = project(items);
    final prefs = await SharedPreferences.getInstance();
    final byId = {
      for (final item in selected) item['id']: (item['data'] as Map)['value'],
    };
    // Only remove a setting if this device previously synchronized it. A new
    // installation must not interpret an absent cloud value as a local reset.
    final ids = {
      ...byId.keys,
      ...baseline.map((item) => item['id']).where(specs.containsKey),
    };
    for (final id in ids) {
      final spec = specs[id]!;
      final value = byId[id];
      bool saved;
      if (spec.field != null) {
        final data = Map<String, dynamic>.from(
          jsonDecode(prefs.getString(spec.key) ?? '{}') as Map,
        );
        if (value == null) {
          data.remove(spec.field);
        } else {
          data[spec.field!] = value;
        }
        saved = await prefs.setString(spec.key, jsonEncode(data));
      } else if (value == null) {
        saved = await prefs.remove(spec.key);
      } else if (value is bool) {
        saved = await prefs.setBool(spec.key, value);
      } else if (spec.kind == 'double') {
        saved = await prefs.setDouble(spec.key, (value as num).toDouble());
      } else if (value is int) {
        saved = await prefs.setInt(spec.key, value);
      } else if (value is List) {
        saved = await prefs.setStringList(spec.key, List<String>.from(value));
      } else {
        saved = await prefs.setString(spec.key, value as String);
      }
      if (!saved) throw const FormatException('preferences_save_failed');
    }
  }
}
