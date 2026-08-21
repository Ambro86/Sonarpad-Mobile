import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'calendar_localization_data.g.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../models/calendar_event.dart';

import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:timezone/timezone.dart' as tz;

class CalendarService {
  static const _eventsKey = 'sonarpad_calendar_events';

  Future<List<CalendarEvent>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_eventsKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => CalendarEvent.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addEvent(
    CalendarEvent event, {
    required String deviceCalendarDescription,
  }) async {
    final events = await getEvents();
    events.add(event);
    await _saveEvents(events);

    try {
      await _syncToDeviceCalendar(
        event,
        deviceCalendarDescription: deviceCalendarDescription,
      );
    } catch (e) {
      // ignore
    }
  }

  Future<void> _syncToDeviceCalendar(
    CalendarEvent event, {
    required String deviceCalendarDescription,
  }) async {
    final deviceCalendarPlugin = dc.DeviceCalendarPlugin();
    var permissionsGranted = await deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
      permissionsGranted = await deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess ||
          !(permissionsGranted.data ?? false)) {
        return;
      }
    }

    final calendarsResult = await deviceCalendarPlugin.retrieveCalendars();
    if (!calendarsResult.isSuccess ||
        calendarsResult.data == null ||
        calendarsResult.data!.isEmpty) {
      return;
    }

    dc.Calendar? calendar;
    try {
      calendar = calendarsResult.data!
          .firstWhere((c) => (c.isDefault ?? false) && !(c.isReadOnly ?? true));
    } catch (_) {
      try {
        calendar =
            calendarsResult.data!.firstWhere((c) => !(c.isReadOnly ?? true));
      } catch (_) {}
    }

    if (calendar == null) return;

    final location = tz.getLocation('Europe/Rome');
    final eventDate = tz.TZDateTime.from(event.date, location);

    final deviceEvent = dc.Event(
      calendar.id,
      title: event.text,
      description: deviceCalendarDescription,
      start: eventDate,
      end: eventDate.add(const Duration(hours: 1)),
      allDay: true,
    );

    await deviceCalendarPlugin.createOrUpdateEvent(deviceEvent);
  }


  Future<void> removeEvent(String id) async {
    final events = await getEvents();
    events.removeWhere((e) => e.id == id);
    await _saveEvents(events);
  }

  Future<void> _saveEvents(List<CalendarEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_eventsKey, jsonString);
  }

  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final events = await getEvents();
    return events
        .where((e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day)
        .toList();
  }

  String _calendarLocaleKey(String languageCode) {
    final normalized = languageCode.toLowerCase().replaceAll('-', '_');
    if (normalized == 'pt_br') return 'pt_BR';
    if (normalized == 'zh' || normalized == 'zh_cn' || normalized.startsWith('zh_hans')) {
      return 'zh_CN';
    }
    final language = normalized.split('_').first;
    return kCalendarQuotesByLocale.containsKey(language) ? language : 'en';
  }

  String? getHoliday(DateTime date, String languageCode) {
    final locale = _calendarLocaleKey(languageCode);
    final key = "${date.day}-${date.month}";
    return kCalendarHolidaysByLocale[locale]?[key];
  }

  String? getSaint(DateTime date, String languageCode) {
    final locale = _calendarLocaleKey(languageCode);
    final key = "${date.day}-${date.month}";
    final value = kCalendarSaintsByLocale[locale]?[key];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<String?> getSaintAsync(DateTime date, String languageCode) async {
    final lang = languageCode.split('_').first.split('-').first;

    // 1. Cerca prima nel dizionario locale (tutte le lingue)
    final localName = getSaint(date, languageCode);
    if (localName != null) return localName;

    // 2. Per l'italiano, fallback live su santodelgiorno.it
    if (lang == 'it') {
      try {
        final months = [
          "gennaio",
          "febbraio",
          "marzo",
          "aprile",
          "maggio",
          "giugno",
          "luglio",
          "agosto",
          "settembre",
          "ottobre",
          "novembre",
          "dicembre"
        ];
        final day = date.day.toString().padLeft(2, '0');
        final url =
            "https://www.santodelgiorno.it/$day/${months[date.month - 1]}/";
        final res =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final saint = _extractSaintFromHtml(res.body);
          if (saint != null) return saint;
        }
      } catch (_) {}
      return null;
    }

    // For non-Italian locales the bundled dataset is authoritative.
    return null;
  }

  String? _extractSaintFromHtml(String html) {
    final document = html_parser.parse(html);
    final primaryName = document.querySelector('.NomeSantoDiOggi')?.text;
    final primarySaint = _cleanSaintName(primaryName);
    if (primarySaint != null) return primarySaint;

    final bodyText =
        document.body?.text ?? document.documentElement?.text ?? html;
    final lines = bodyText
        .split('\n')
        .map(_cleanSaintLine)
        .where((line) => line.isNotEmpty)
        .toList();

    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains('si venera:')) continue;
      for (var j = i + 1; j < lines.length && j <= i + 8; j++) {
        final saint = _cleanSaintName(lines[j]);
        if (saint != null) return saint;
      }
    }

    return null;
  }

  String _cleanSaintLine(String value) {
    return value.replaceAll('\u00a0', ' ').replaceAll('\t', ' ').trim();
  }

  String? _cleanSaintName(String? value) {
    if (value == null) return null;
    final cleaned = _cleanSaintLine(value);
    if (cleaned.isEmpty) return null;
    if (cleaned == 'Santo del Giorno') return null;
    if (cleaned == 'Cerca un santo:') return null;
    if (cleaned.startsWith('Il ') || cleaned.startsWith('Altri ')) return null;
    if (cleaned.contains('>>')) return null;
    return cleaned;
  }

  String getQuote(DateTime date, String languageCode) {
    final locale = _calendarLocaleKey(languageCode);
    final list = kCalendarQuotesByLocale[locale] ?? kCalendarQuotesByLocale['en']!;

    // Use only year, month and day in UTC so timezone/DST changes never alter
    // the quote selected for a calendar day.
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);
    final daysSinceEpoch =
        normalizedDate.difference(DateTime.utc(1970, 1, 1)).inDays;
    return list[daysSinceEpoch % list.length];
  }

}
