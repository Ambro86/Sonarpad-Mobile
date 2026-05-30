import 'dart:convert';
import 'dart:math';
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

  Future<void> addEvent(CalendarEvent event) async {
    final events = await getEvents();
    events.add(event);
    await _saveEvents(events);
    
    try {
      await _syncToDeviceCalendar(event);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _syncToDeviceCalendar(CalendarEvent event) async {
    final deviceCalendarPlugin = dc.DeviceCalendarPlugin();
    var permissionsGranted = await deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
      permissionsGranted = await deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || !(permissionsGranted.data ?? false)) {
        return;
      }
    }

    final calendarsResult = await deviceCalendarPlugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data == null || calendarsResult.data!.isEmpty) {
      return;
    }

    dc.Calendar? calendar;
    try {
      calendar = calendarsResult.data!.firstWhere((c) => (c.isDefault ?? false) && !(c.isReadOnly ?? true));
    } catch (_) {
      try {
        calendar = calendarsResult.data!.firstWhere((c) => !(c.isReadOnly ?? true));
      } catch (_) {}
    }
    
    if (calendar == null) return;

    final location = tz.getLocation('Europe/Rome');
    final eventDate = tz.TZDateTime.from(event.date, location);
    
    final deviceEvent = dc.Event(
      calendar.id,
      title: event.text,
      description: 'Promemoria da Sonarpad',
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
    return events.where((e) => 
      e.date.year == date.year && 
      e.date.month == date.month && 
      e.date.day == date.day
    ).toList();
  }

  String? getHoliday(DateTime date, String languageCode) {
    if (languageCode != 'it') return null; // Fallback per ora solo italiano
    
    final day = date.day;
    final month = date.month;

    if (day == 1 && month == 1) return "Capodanno";
    if (day == 6 && month == 1) return "Epifania";
    if (day == 25 && month == 4) return "Festa della Liberazione";
    if (day == 1 && month == 5) return "Festa dei Lavoratori";
    if (day == 2 && month == 6) return "Festa della Repubblica";
    if (day == 15 && month == 8) return "Ferragosto";
    if (day == 1 && month == 11) return "Tutti i Santi";
    if (day == 8 && month == 12) return "Immacolata Concezione";
    if (day == 25 && month == 12) return "Natale";
    if (day == 26 && month == 12) return "Santo Stefano";
    
    // Non calcoliamo la Pasqua per semplicità, ma potremmo aggiungerla in futuro.
    return null;
  }

  String? getSaint(DateTime date, String languageCode) {
    if (languageCode != 'it') return null; // Solo in italiano per ora
    // Un piccolo set di santi comuni per dimostrazione, si può espandere
    final saints = {
      "1-1": "Maria SS. Madre di Dio",
      "17-1": "Sant'Antonio Abate",
      "14-2": "San Valentino",
      "19-3": "San Giuseppe",
      "23-4": "San Giorgio",
      "13-6": "Sant'Antonio di Padova",
      "24-6": "San Giovanni Battista",
      "29-6": "San Pietro e Paolo",
      "15-8": "Assunzione di Maria",
      "4-10": "San Francesco d'Assisi",
      "1-11": "Tutti i Santi",
      "6-12": "San Nicola",
      "7-12": "Sant'Ambrogio",
      "13-12": "Santa Lucia",
      "25-12": "Natale del Signore",
    };
    final key = "${date.day}-${date.month}";
    return saints[key];
  }

  String getQuote(DateTime date, String languageCode) {
    // Generiamo una citazione basata sul giorno dell'anno, così è uguale per tutti in quel giorno
    final quotesIt = [
      "La felicità non è avere quello che si desidera, ma desiderare quello che si ha. - Oscar Wilde",
      "Il successo è la somma di piccoli sforzi, ripetuti giorno dopo giorno. - Robert Collier",
      "Non è mai troppo tardi per essere ciò che avresti potuto essere. - George Eliot",
      "La vita è quello che ti succede mentre sei occupato a fare altri progetti. - John Lennon",
      "Il modo migliore per predire il futuro è inventarlo. - Alan Kay",
      "Sii il cambiamento che vuoi vedere nel mondo. - Mahatma Gandhi",
      "L'unico modo per fare un ottimo lavoro è amare quello che fai. - Steve Jobs",
      "Ogni giorno è una nuova opportunità per cambiare la tua vita. - Anonimo",
    ];
    final quotesEn = [
      "Happiness is not having what you want, but wanting what you have. - Oscar Wilde",
      "Success is the sum of small efforts, repeated day in and day out. - Robert Collier",
      "It is never too late to be what you might have been. - George Eliot",
      "Life is what happens to you while you're busy making other plans. - John Lennon",
      "The best way to predict the future is to invent it. - Alan Kay",
      "Be the change that you wish to see in the world. - Mahatma Gandhi",
      "The only way to do great work is to love what you do. - Steve Jobs",
      "Every day is a new opportunity to change your life. - Anonymous",
    ];
    final quotesFr = [
      "Le bonheur n'est pas d'avoir ce que l'on veut, mais de vouloir ce que l'on a. - Oscar Wilde",
      "Le succès est la somme de petits efforts, répétés jour après jour. - Robert Collier",
      "Il n'est jamais trop tard pour être ce que vous auriez pu être. - George Eliot",
      "La vie, c'est ce qui arrive quand on a d'autres projets. - John Lennon",
      "La meilleure façon de prédire l'avenir est de l'inventer. - Alan Kay",
      "Soyez le changement que vous voulez voir dans le monde. - Mahatma Gandhi",
      "La seule façon de faire du bon travail est d'aimer ce que vous faites. - Steve Jobs",
      "Chaque jour est une nouvelle opportunité de changer de vie. - Anonyme",
    ];
    final quotesEs = [
      "La felicidad no es tener lo que quieres, sino querer lo que tienes. - Oscar Wilde",
      "El éxito es la suma de pequeños esfuerzos, repetidos día tras día. - Robert Collier",
      "Nunca es demasiado tarde para ser lo que podrías haber sido. - George Eliot",
      "La vida es lo que te pasa mientras estás ocupado haciendo otros planes. - John Lennon",
      "La mejor forma de predecir el futuro es inventarlo. - Alan Kay",
      "Sé el cambio que quieres ver en el mundo. - Mahatma Gandhi",
      "La única forma de hacer un gran trabajo es amar lo que haces. - Steve Jobs",
      "Cada día es una nueva oportunidad para cambiar tu vida. - Anónimo",
    ];
    
    List<String> list;
    switch (languageCode) {
      case 'it': list = quotesIt; break;
      case 'fr': list = quotesFr; break;
      case 'es': list = quotesEs; break;
      default: list = quotesEn; break;
    }
    // Usiamo il numero di giorni dall'epoca (1970) per ciclare in modo perfetto
    // su tutte le frasi nell'array in ordine, così da garantire una frase diversa ogni giorno.
    final daysSinceEpoch = date.difference(DateTime.utc(1970, 1, 1)).inDays;
    return list[daysSinceEpoch % list.length];
  }
}
