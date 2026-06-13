import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'saints_data.dart';

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
    return events
        .where((e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day)
        .toList();
  }

  String? getHoliday(DateTime date, String languageCode) {
    final lang = languageCode.split('_').first.split('-').first;
    final day = date.day;
    final month = date.month;


    if (lang == 'cs') {
      if (day == 1 && month == 1) return "Nový rok";
      if (day == 1 && month == 5) return "Svátek práce";
      if (day == 8 && month == 5) return "Den vítězství";
      if (day == 5 && month == 7) return "Den slovanských věrozvěstů Cyrila a Metoděje";
      if (day == 6 && month == 7) return "Den upálení mistra Jana Husa";
      if (day == 28 && month == 9) return "Den české státnosti";
      if (day == 28 && month == 10) return "Den vzniku samostatného československého státu";
      if (day == 17 && month == 11) return "Den boje za svobodu a demokracii";
      if (day == 24 && month == 12) return "Štědrý den";
      if (day == 25 && month == 12) return "1. svátek vánoční";
      if (day == 26 && month == 12) return "2. svátek vánoční";
      return null;
    }

    if (lang == 'pl') {
      if (day == 1 && month == 1) return "Nowy Rok";
      if (day == 6 && month == 1) return "Święto Trzech Króli";
      if (day == 1 && month == 5) return "Święto Pracy";
      if (day == 3 && month == 5) return "Święto Konstytucji 3 Maja";
      if (day == 15 && month == 8) return "Wniebowzięcie Najświętszej Maryi Panny";
      if (day == 1 && month == 11) return "Wszystkich Świętych";
      if (day == 11 && month == 11) return "Narodowe Święto Niepodległości";
      if (day == 25 && month == 12) return "Boże Narodzenie";
      if (day == 26 && month == 12) return "Drugi dzień Świąt Bożego Narodzenia";
      return null;
    }

    if (lang == 'pt') {
      if (day == 1 && month == 1) return "Ano Novo";
      if (day == 6 && month == 1) return "Epifania";
      if (day == 25 && month == 4) return "Dia da Liberdade";
      if (day == 1 && month == 5) return "Dia do Trabalhador";
      if (day == 10 && month == 6) return "Dia de Portugal";
      if (day == 15 && month == 8) return "Assunção de Nossa Senhora";
      if (day == 1 && month == 11) return "Todos os Santos";
      if (day == 8 && month == 12) return "Imaculada Conceição";
      if (day == 25 && month == 12) return "Natal";
      return null;
    }

    if (lang != 'it') return null; // Fallback per ora: festività solo italiano e portoghese.

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
    final key = "${date.day}-${date.month}";
    final lang = languageCode.split('_').first.split('-').first;
    final localEntry = kSaintsData[key];
    if (localEntry == null) return null;
    final localName = localEntry[lang] ?? localEntry[languageCode];
    if (localName == null || localName.isEmpty) return null;
    return localName;
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
      return "Non disponibile";
    }

    if (lang == 'pt') return "Não disponível";
    if (lang == 'pl') return "Niedostępne";
    if (lang == 'cs') return "Není dostupné";

    // 3. Per le altre lingue, se il dizionario non ha dati restituisce null
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
    final lang = languageCode.split('_').first.split('-').first;
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
    final quotesPt = [
      "A felicidade não é ter o que se deseja, mas desejar o que se tem. - Oscar Wilde",
      "O sucesso é a soma de pequenos esforços repetidos dia após dia. - Robert Collier",
      "Nunca é tarde demais para ser o que poderias ter sido. - George Eliot",
      "A vida é o que acontece enquanto estás ocupado a fazer outros planos. - John Lennon",
      "A melhor forma de prever o futuro é inventá-lo. - Alan Kay",
      "Sê a mudança que queres ver no mundo. - Mahatma Gandhi",
      "A única forma de fazer um grande trabalho é amar o que fazes. - Steve Jobs",
      "Cada dia é uma nova oportunidade para mudar a tua vida. - Anónimo",
    ];

    final quotesCs = [
      "Štěstí nespočívá v tom mít, co chceme, ale chtít to, co máme. - Oscar Wilde",
      "Úspěch je součet malých úsilí opakovaných den za dnem. - Robert Collier",
      "Nikdy není pozdě stát se tím, kým jsme mohli být. - George Eliot",
      "Život je to, co se děje, když jsme zaneprázdněni jinými plány. - John Lennon",
      "Nejlepší způsob, jak předpovědět budoucnost, je vytvořit ji. - Alan Kay",
      "Buď změnou, kterou chceš vidět ve světě. - Mahatma Gandhi",
      "Jediný způsob, jak dělat skvělou práci, je milovat to, co děláš. - Steve Jobs",
      "Každý den je nová příležitost změnit svůj život. - Anonym",
    ];
    final quotesPl = [
      "Szczęście nie polega na posiadaniu tego, czego się pragnie, lecz na pragnieniu tego, co się ma. - Oscar Wilde",
      "Sukces jest sumą małych wysiłków powtarzanych dzień po dniu. - Robert Collier",
      "Nigdy nie jest za późno, aby stać się tym, kim można było być. - George Eliot",
      "Życie jest tym, co dzieje się, gdy jesteś zajęty robieniem innych planów. - John Lennon",
      "Najlepszym sposobem przewidywania przyszłości jest jej tworzenie. - Alan Kay",
      "Bądź zmianą, którą pragniesz ujrzeć w świecie. - Mahatma Gandhi",
      "Jedynym sposobem wykonywania wspaniałej pracy jest kochanie tego, co się robi. - Steve Jobs",
      "Każdy dzień jest nową szansą, aby zmienić swoje życie. - Anonim",
    ];

    List<String> list;
    switch (lang) {
      case 'it':
        list = quotesIt;
        break;
      case 'fr':
        list = quotesFr;
        break;
      case 'es':
        list = quotesEs;
        break;
      case 'pt':
        list = quotesPt;
        break;
      case 'pl':
        list = quotesPl;
        break;
      case 'cs':
        list = quotesCs;
        break;
      default:
        list = quotesEn;
        break;
    }
    // Usiamo il numero di giorni dall'epoca (1970) per ciclare in modo perfetto
    // su tutte le frasi nell'array in ordine, così da garantire una frase diversa ogni giorno.
    final daysSinceEpoch = date.difference(DateTime.utc(1970, 1, 1)).inDays;
    return list[daysSinceEpoch % list.length];
  }
}
