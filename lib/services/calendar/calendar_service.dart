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
      "Un viaggio di mille miglia comincia con un solo passo. - Lao Tzu",
      "La speranza è un sogno fatto da svegli. - Aristotele",
      "La pazienza è amara, ma il suo frutto è dolce. - Jean-Jacques Rousseau",
      "Conosci te stesso. - Iscrizione del tempio di Delfi",
      "Dove c'è volontà, c'è una via. - Proverbio",
      "A poco a poco si va lontano. - Proverbio",
      "La goccia scava la pietra, non con la forza ma cadendo spesso. - Ovidio",
      "La natura non fa nulla invano. - Aristotele",
      "La fortuna aiuta gli audaci. - Virgilio",
      "La conoscenza è potere. - Francis Bacon",
      "Nessun vento è favorevole per chi non sa dove andare. - Seneca",
      "Fa' ogni cosa con calma e ordine. - Marco Aurelio",
      "La semplicità è la massima raffinatezza. - Leonardo da Vinci",
      "Chi cerca trova. - Proverbio",
      "Il tempo rivela ogni cosa. - Tertulliano",
      "Imparare è come remare controcorrente: se smetti, torni indietro. - Proverbio cinese",
      "La gentilezza non costa nulla, ma vale moltissimo. - Proverbio",
      "Le radici dello studio sono amare, ma i frutti sono dolci. - Proverbio",
      "Non contare i giorni, fai in modo che i giorni contino. - Proverbio",
      "Dopo la tempesta viene il sereno. - Proverbio",
      "La moderazione è il tesoro più grande. - Esiodo",
      "Una parola buona riscalda tre mesi d'inverno. - Proverbio giapponese",
      "Meglio accendere una candela che maledire il buio. - Proverbio",
      "La via si costruisce camminando. - Proverbio",
      "Chi ben comincia è a metà dell'opera. - Aristotele",
      "Il coraggio cresce osando. - Proverbio",
      "Ogni seme ha il suo tempo per fiorire. - Proverbio",
      "La costanza vince la fatica. - Proverbio",
      "Anche il più lungo inverno teme la primavera. - Proverbio",
      "Una mente aperta trova sempre una strada. - Proverbio",
      "Ascolta molto, parla poco. - Proverbio",
      "Il silenzio è talvolta la risposta più saggia. - Proverbio",
      "La gratitudine trasforma ciò che abbiamo in ciò che ci basta. - Proverbio",
      "Il miglior momento per iniziare è adesso. - Proverbio",
      "Un cuore sereno vede più lontano. - Proverbio",
      "La gioia condivisa si moltiplica. - Proverbio",
      "Chi impara ogni giorno resta giovane. - Proverbio",
      "Anche la strada più lunga si percorre un passo alla volta. - Proverbio",
      "La calma è una forma di forza. - Proverbio",
      "Nel mezzo di ogni difficoltà si trova un'opportunità. - Albert Einstein",
      "La luce più preziosa è quella che accendi dentro di te. - Proverbio",
      "La costanza trasforma gli obiettivi in risultati. - Jim Rohn",
      "La perseveranza apre porte che la fretta lascia chiuse. - Proverbio",
      "Il riposo è parte del cammino. - Proverbio",
      "Chi semina pazienza raccoglie pace. - Proverbio",
      "Ogni grande risultato nasce da un primo passo. - Proverbio",
      "L'abitudine rende leggero ciò che all'inizio pesa. - Proverbio",
      "Ogni giorno porta con sé una lezione. - Proverbio",
      "Guarda avanti con fiducia, ma cammina con umiltà. - Proverbio",
      "La verità è semplice, anche quando il cammino non lo è. - Proverbio",
      "Sorridere è un modo gentile di essere forti. - Proverbio",
      "Chi dà valore al tempo dà valore alla vita. - Proverbio",
      "Le parole buone restano a lungo nel cuore. - Proverbio",
      "Non serve correre: serve non fermarsi. - Proverbio",
      "Una meta chiara alleggerisce il viaggio. - Proverbio",
      "La fedeltà ai piccoli impegni prepara alle grandi cose. - Proverbio",
      "Ogni alba porta un invito a ricominciare. - Proverbio",
      "La gentilezza apre porte che la forza non vede. - Proverbio",
      "Chi ascolta con il cuore trova parole migliori. - Proverbio",
      "La speranza cresce quando viene condivisa. - Proverbio",
      "Un passo sincero vale più di cento promesse. - Proverbio",
      "La pazienza aiuta i sogni a diventare realtà. - Proverbio",
      "Dove metti cura, nasce bellezza. - Proverbio",
      "Il coraggio non cancella la paura: le insegna la strada. - Proverbio",
      "Ogni errore può diventare una mappa. - Proverbio",
      "La fiducia si costruisce con gesti piccoli e veri. - Proverbio",
      "Un giorno difficile non cancella tutto ciò che hai costruito. - Proverbio",
      "Chi porta luce agli altri illumina anche la propria strada. - Proverbio",
      "La saggezza comincia quando impariamo a fare silenzio. - Proverbio",
      "Il tempo dato con amore non è mai perduto. - Proverbio",
      "Quando si chiude una porta, può aprirsi una strada nuova. - Proverbio",
      "Chi sa fermarsi trova bellezza anche nelle cose semplici. - Proverbio",
      "Non c'è vento contrario per chi sa aggiustare le vele. - Proverbio",
      "Dove l’orgoglio si fa da parte, può nascere la pace. - Proverbio",
      "Un pensiero buono può cambiare il peso di una giornata. - Proverbio",
      "La cura dei dettagli rende grande anche ciò che è semplice. - Proverbio",
      "Chi resta fedele al bene non cammina mai invano. - Proverbio",
      "La memoria custodisce, ma il perdono libera. - Proverbio",
      "Ogni talento fiorisce quando diventa dono per gli altri. - Proverbio",
      "Il domani si prepara con la cura di oggi. - Proverbio",
      "La voce più forte è spesso quella della coerenza. - Proverbio",
      "Una mano tesa accorcia molte distanze. - Proverbio",
      "La serenità nasce quando impariamo ad accettare ciò che non possiamo cambiare. - Proverbio",
      "Il vero progresso lascia spazio anche agli altri. - Proverbio",
      "Chi ringrazia vede ricchezza anche nelle cose semplici. - Proverbio",
      "La luce del mattino non chiede permesso al buio. - Proverbio",
      "La costanza avvicina i sogni alla realtà. - Proverbio",
      "La bontà seminata in silenzio ritorna quando meno te l'aspetti. - Proverbio",
      "L'umiltà rende leggera anche la vittoria. - Proverbio",
      "La strada giusta è quella che lascia il cuore in pace. - Proverbio",
      "Chi sa aspettare capisce che ogni cosa ha il suo tempo. - Proverbio",
      "Ogni buona abitudine è una promessa mantenuta a se stessi. - Proverbio",
      "Il sapere cresce quando diventa dono. - Proverbio",
      "Accettare i propri limiti è una forma di saggezza. - Proverbio",
      "La fiducia cresce nei piccoli gesti di ogni giorno. - Proverbio",
      "Il giorno più semplice può contenere una grande svolta. - Proverbio",
      "La cura comincia dalle cose che nessuno vede. - Proverbio",
      "Non tutto ciò che tarda è perduto. - Proverbio",
      "Una parola calma può spegnere un incendio. - Proverbio",
      "Chi coltiva pazienza raccoglie chiarezza. - Proverbio",
      "La gratitudine illumina anche le giornate più semplici. - Proverbio",
      "Ogni passo fatto con onestà avvicina alla meta. - Proverbio",
      "La forza vera sa essere gentile. - Proverbio",
      "Il cuore impara camminando. - Proverbio",
      "Una mente curiosa non invecchia mai. - Proverbio",
      "La luce si riconosce meglio dopo il buio. - Proverbio",
      "Chi costruisce ponti trova più strade. - Proverbio",
      "Il bene fatto in silenzio parla a lungo. - Proverbio",
      "La prudenza non ferma il viaggio: lo protegge. - Proverbio",
      "Ogni cambiamento ha bisogno di basi solide. - Proverbio",
      "La promessa più importante è quella mantenuta nei fatti. - Proverbio",
      "Il tempo insegna a chi sa ascoltarlo. - Proverbio",
      "Dove c'è rispetto, la distanza si accorcia. - Proverbio",
      "La creatività nasce quando la paura lascia spazio al gioco. - Proverbio",
      "Un cuore sereno vede il mondo con più chiarezza. - Proverbio",
      "Non perdere la tenerezza: è una forma di coraggio. - Proverbio",
      "La costanza trasforma il difficile in possibile. - Proverbio",
      "Chi riconosce i propri limiti apre spazio alla crescita. - Proverbio",
      "Ogni incontro può insegnarci qualcosa di nuovo. - Proverbio",
      "La scelta migliore è quella che fa bene anche agli altri. - Proverbio",
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
      "Every journey of a thousand miles begins with a single step. - Lao Tzu",
      "Hope is a waking dream. - Aristotle",
      "Patience is bitter, but its fruit is sweet. - Jean-Jacques Rousseau",
      "Know yourself. - Inscription at Delphi",
      "Where there is a will, there is a way. - Proverb",
      "Little by little, one goes far. - Proverb",
      "Dripping water hollows out stone, not by force but by falling often. - Ovid",
      "Nature does nothing in vain. - Aristotle",
      "Fortune favors the bold. - Virgil",
      "Knowledge is power. - Francis Bacon",
      "No wind is favorable to those who do not know where they are going. - Seneca",
      "Do everything calmly and in good order. - Marcus Aurelius",
      "Simplicity is the ultimate sophistication. - Leonardo da Vinci",
      "Seek and you shall find. - Proverb",
      "Time reveals all things. - Tertullian",
      "Learning is like rowing upstream: if you stop, you drift back. - Chinese proverb",
      "Kindness costs nothing, but it is worth a great deal. - Proverb",
      "The roots of study are bitter, but the fruits are sweet. - Proverb",
      "Do not count the days; make the days count. - Proverb",
      "After the storm comes calm. - Proverb",
      "Moderation is the greatest treasure. - Hesiod",
      "One kind word can warm three winter months. - Japanese proverb",
      "It is better to light a candle than to curse the darkness. - Proverb",
      "The path is made by walking. - Proverb",
      "Well begun is half done. - Aristotle",
      "Courage grows by daring. - Proverb",
      "Every seed has its own time to bloom. - Proverb",
      "Steadiness conquers fatigue. - Proverb",
      "Even the longest winter fears spring. - Proverb",
      "An open mind always finds a way. - Proverb",
      "Listen much, speak little. - Proverb",
      "Silence is sometimes the wisest answer. - Proverb",
      "Gratitude helps us see that what we have is enough. - Proverb",
      "The best time to begin is now. - Proverb",
      "A peaceful heart sees farther. - Proverb",
      "Shared joy multiplies. - Proverb",
      "Those who learn every day stay young. - Proverb",
      "Even the longest road is traveled one step at a time. - Proverb",
      "Calm is a form of strength. - Proverb",
      "In the middle of every difficulty lies opportunity. - Albert Einstein",
      "The most precious light is the one you kindle within yourself. - Proverb",
      "Consistency turns goals into results. - Jim Rohn",
      "Perseverance opens doors that haste leaves closed. - Proverb",
      "Rest is part of the journey. - Proverb",
      "Those who sow patience reap peace. - Proverb",
      "Every great result begins with a first step. - Proverb",
      "Habit makes light what felt heavy at first. - Proverb",
      "Every day carries a lesson. - Proverb",
      "Look ahead with confidence, but walk with humility. - Proverb",
      "Truth is simple, even when the path is not. - Proverb",
      "Smiling is a gentle way of being strong. - Proverb",
      "Those who value time value life. - Proverb",
      "Kind words stay in the heart for a long time. - Proverb",
      "There is no need to run; there is need not to stop. - Proverb",
      "A clear goal lightens the journey. - Proverb",
      "Faithfulness in small commitments prepares us for great things. - Proverb",
      "Every dawn brings an invitation to begin again. - Proverb",
      "Kindness opens doors that force cannot see. - Proverb",
      "Those who listen with the heart find better words. - Proverb",
      "Hope grows when it is shared. - Proverb",
      "One sincere step is worth more than a hundred promises. - Proverb",
      "Patience helps dreams become reality. - Proverb",
      "Where you put care, beauty is born. - Proverb",
      "Courage does not erase fear; it teaches it the way. - Proverb",
      "Every mistake can become a map. - Proverb",
      "Trust is built with small and true gestures. - Proverb",
      "A difficult day does not erase everything you have built. - Proverb",
      "Those who bring light to others also brighten their own path. - Proverb",
      "Wisdom begins when we learn to be silent. - Proverb",
      "Time given with love is never lost. - Proverb",
      "When one door closes, a new path may open. - Proverb",
      "Those who know how to pause find beauty even in simple things. - Proverb",
      "No wind is against those who know how to adjust their sails. - Proverb",
      "Where pride steps aside, peace can be born. - Proverb",
      "A good thought can change the weight of a day. - Proverb",
      "Care for details makes even simple things great. - Proverb",
      "Those who remain faithful to good never walk in vain. - Proverb",
      "Memory preserves, but forgiveness frees. - Proverb",
      "Every talent blooms when it becomes a gift for others. - Proverb",
      "Tomorrow is prepared with today's care. - Proverb",
      "The strongest voice is often the voice of consistency. - Proverb",
      "An outstretched hand shortens many distances. - Proverb",
      "Serenity begins when we learn to accept what we cannot change. - Proverb",
      "True progress leaves room for others too. - Proverb",
      "Those who give thanks see wealth even in simple things. - Proverb",
      "Morning light does not ask darkness for permission. - Proverb",
      "Consistency brings dreams closer to reality. - Proverb",
      "Goodness sown in silence returns when you least expect it. - Proverb",
      "Humility makes even victory feel light. - Proverb",
      "The right road is the one that leaves the heart at peace. - Proverb",
      "Those who know how to wait understand that everything has its time. - Proverb",
      "Every good habit is a promise kept to yourself. - Proverb",
      "Knowledge grows when it becomes a gift. - Proverb",
      "Accepting your limits is a form of wisdom. - Proverb",
      "Trust grows through small everyday gestures. - Proverb",
      "The simplest day can hold a great turning point. - Proverb",
      "Care begins with the things no one sees. - Proverb",
      "Not everything that is delayed is lost. - Proverb",
      "A calm word can put out a fire. - Proverb",
      "Those who cultivate patience harvest clarity. - Proverb",
      "Gratitude brightens even the simplest days. - Proverb",
      "Every honest step brings the goal closer. - Proverb",
      "True strength knows how to be kind. - Proverb",
      "The heart learns by walking. - Proverb",
      "A curious mind never grows old. - Proverb",
      "Light is recognized better after darkness. - Proverb",
      "Those who build bridges find more roads. - Proverb",
      "Good done in silence speaks for a long time. - Proverb",
      "Prudence does not stop the journey: it protects it. - Proverb",
      "Every change needs solid foundations. - Proverb",
      "The most important promise is the one kept in deeds. - Proverb",
      "Time teaches those who know how to listen to it. - Proverb",
      "Where there is respect, distance becomes shorter. - Proverb",
      "Creativity is born when fear makes room for play. - Proverb",
      "A serene heart sees the world more clearly. - Proverb",
      "Do not lose tenderness: it is a form of courage. - Proverb",
      "Steadiness turns the difficult into the possible. - Proverb",
      "Those who recognize their limits make room for growth. - Proverb",
      "Every encounter can teach us something new. - Proverb",
      "The best choice is the one that benefits others too. - Proverb",
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
      "Un voyage de mille lieues commence par un seul pas. - Lao Tseu",
      "L'espérance est un rêve éveillé. - Aristote",
      "La patience est amère, mais son fruit est doux. - Jean-Jacques Rousseau",
      "Connais-toi toi-même. - Inscription de Delphes",
      "Où il y a une volonté, il y a un chemin. - Proverbe",
      "Petit à petit, on va loin. - Proverbe",
      "La goutte creuse la pierre, non par la force, mais en tombant souvent. - Ovide",
      "La nature ne fait rien en vain. - Aristote",
      "La fortune sourit aux audacieux. - Virgile",
      "Le savoir est un pouvoir. - Francis Bacon",
      "Aucun vent n'est favorable à qui ne sait pas où il va. - Sénèque",
      "Fais chaque chose avec calme et ordre. - Marc Aurèle",
      "La simplicité est la sophistication suprême. - Léonard de Vinci",
      "Qui cherche trouve. - Proverbe",
      "Le temps révèle toute chose. - Tertullien",
      "Apprendre, c'est comme ramer à contre-courant : si l'on s'arrête, on recule. - Proverbe chinois",
      "La gentillesse ne coûte rien, mais elle vaut beaucoup. - Proverbe",
      "Les racines de l'étude sont amères, mais les fruits sont doux. - Proverbe",
      "Ne compte pas les jours, fais que les jours comptent. - Proverbe",
      "Après la tempête vient le calme. - Proverbe",
      "La modération est le plus grand trésor. - Hésiode",
      "Une parole bienveillante réchauffe trois mois d'hiver. - Proverbe japonais",
      "Mieux vaut allumer une bougie que maudire l'obscurité. - Proverbe",
      "Le chemin se fait en marchant. - Proverbe",
      "Bien commencé est à moitié fait. - Aristote",
      "Le courage grandit lorsqu'on ose. - Proverbe",
      "Chaque graine a son temps pour fleurir. - Proverbe",
      "La constance triomphe de la fatigue. - Proverbe",
      "Même le plus long hiver craint le printemps. - Proverbe",
      "Un esprit ouvert trouve toujours un chemin. - Proverbe",
      "Écoute beaucoup, parle peu. - Proverbe",
      "Le silence est parfois la réponse la plus sage. - Proverbe",
      "La gratitude transforme ce que nous avons en ce qui nous suffit. - Proverbe",
      "Le meilleur moment pour commencer, c'est maintenant. - Proverbe",
      "Un cœur paisible voit plus loin. - Proverbe",
      "La joie partagée se multiplie. - Proverbe",
      "Qui apprend chaque jour reste jeune. - Proverbe",
      "Même la route la plus longue se parcourt un pas à la fois. - Proverbe",
      "Le calme est une forme de force. - Proverbe",
      "Au milieu de toute difficulté se trouve une occasion. - Albert Einstein",
      "La lumière la plus précieuse est celle que tu allumes en toi. - Proverbe",
      "La constance transforme les objectifs en résultats. - Jim Rohn",
      "La persévérance ouvre des portes que la hâte laisse fermées. - Proverbe",
      "Le repos fait partie du chemin. - Proverbe",
      "Qui sème la patience récolte la paix. - Proverbe",
      "Tout grand résultat naît d'un premier pas. - Proverbe",
      "L'habitude rend léger ce qui pesait au début. - Proverbe",
      "Chaque jour apporte sa leçon. - Proverbe",
      "Regarde devant avec confiance, mais marche avec humilité. - Proverbe",
      "La vérité est simple, même lorsque le chemin ne l'est pas. - Proverbe",
      "Sourire est une manière douce d'être fort. - Proverbe",
      "Qui donne de la valeur au temps donne de la valeur à la vie. - Proverbe",
      "Les bonnes paroles restent longtemps dans le cœur. - Proverbe",
      "Il ne faut pas courir : il faut ne pas s'arrêter. - Proverbe",
      "Un but clair allège le voyage. - Proverbe",
      "La fidélité aux petits engagements prépare aux grandes choses. - Proverbe",
      "Chaque aube apporte une invitation à recommencer. - Proverbe",
      "La gentillesse ouvre des portes que la force ne voit pas. - Proverbe",
      "Qui écoute avec le cœur trouve de meilleurs mots. - Proverbe",
      "L'espérance grandit lorsqu'elle est partagée. - Proverbe",
      "Un pas sincère vaut plus que cent promesses. - Proverbe",
      "La patience aide les rêves à devenir réalité. - Proverbe",
      "Là où tu mets du soin, la beauté naît. - Proverbe",
      "Le courage n'efface pas la peur ; il lui montre le chemin. - Proverbe",
      "Chaque erreur peut devenir une carte. - Proverbe",
      "La confiance se construit par de petits gestes vrais. - Proverbe",
      "Un jour difficile n'efface pas tout ce que tu as construit. - Proverbe",
      "Qui apporte de la lumière aux autres éclaire aussi sa propre route. - Proverbe",
      "La sagesse commence quand nous apprenons à nous taire. - Proverbe",
      "Le temps donné avec amour n'est jamais perdu. - Proverbe",
      "Quand une porte se ferme, un nouveau chemin peut s'ouvrir. - Proverbe",
      "Qui sait s'arrêter trouve de la beauté même dans les choses simples. - Proverbe",
      "Aucun vent n'est contraire à qui sait ajuster ses voiles. - Proverbe",
      "Là où l'orgueil s'efface, la paix peut naître. - Proverbe",
      "Une bonne pensée peut changer le poids d'une journée. - Proverbe",
      "Le soin des détails rend grand même ce qui est simple. - Proverbe",
      "Qui reste fidèle au bien ne marche jamais en vain. - Proverbe",
      "La mémoire garde, mais le pardon libère. - Proverbe",
      "Tout talent fleurit lorsqu'il devient un don pour les autres. - Proverbe",
      "Demain se prépare avec le soin d'aujourd'hui. - Proverbe",
      "La voix la plus forte est souvent celle de la cohérence. - Proverbe",
      "Une main tendue raccourcit bien des distances. - Proverbe",
      "La sérénité naît lorsque nous apprenons à accepter ce que nous ne pouvons pas changer. - Proverbe",
      "Le vrai progrès laisse aussi de la place aux autres. - Proverbe",
      "Qui remercie voit de la richesse même dans les choses simples. - Proverbe",
      "La lumière du matin ne demande pas la permission à l'obscurité. - Proverbe",
      "La constance rapproche les rêves de la réalité. - Proverbe",
      "La bonté semée en silence revient quand on s'y attend le moins. - Proverbe",
      "L'humilité rend même la victoire légère. - Proverbe",
      "La bonne route est celle qui laisse le cœur en paix. - Proverbe",
      "Qui sait attendre comprend que chaque chose a son temps. - Proverbe",
      "Toute bonne habitude est une promesse tenue envers soi-même. - Proverbe",
      "Le savoir grandit quand il devient un don. - Proverbe",
      "Accepter ses propres limites est une forme de sagesse. - Proverbe",
      "La confiance grandit dans les petits gestes du quotidien. - Proverbe",
      "Le jour le plus simple peut contenir un grand tournant. - Proverbe",
      "Le soin commence par les choses que personne ne voit. - Proverbe",
      "Tout ce qui tarde n'est pas perdu. - Proverbe",
      "Une parole calme peut éteindre un incendie. - Proverbe",
      "Celui qui cultive la patience récolte la clarté. - Proverbe",
      "La gratitude illumine même les journées les plus simples. - Proverbe",
      "Chaque pas fait avec honnêteté rapproche du but. - Proverbe",
      "La vraie force sait être douce. - Proverbe",
      "Le cœur apprend en marchant. - Proverbe",
      "Un esprit curieux ne vieillit jamais. - Proverbe",
      "On reconnaît mieux la lumière après l'obscurité. - Proverbe",
      "Celui qui bâtit des ponts trouve plus de chemins. - Proverbe",
      "Le bien fait en silence parle longtemps. - Proverbe",
      "La prudence n'arrête pas le voyage : elle le protège. - Proverbe",
      "Tout changement a besoin de bases solides. - Proverbe",
      "La promesse la plus importante est celle que l'on tient par les actes. - Proverbe",
      "Le temps enseigne à qui sait l'écouter. - Proverbe",
      "Là où il y a du respect, la distance se raccourcit. - Proverbe",
      "La créativité naît quand la peur laisse place au jeu. - Proverbe",
      "Un cœur serein voit le monde avec plus de clarté. - Proverbe",
      "Ne perds pas la tendresse : c'est une forme de courage. - Proverbe",
      "La constance transforme le difficile en possible. - Proverbe",
      "Celui qui reconnaît ses limites ouvre un espace à la croissance. - Proverbe",
      "Chaque rencontre peut nous apprendre quelque chose de nouveau. - Proverbe",
      "Le meilleur choix est celui qui fait aussi du bien aux autres. - Proverbe",
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
      "Un viaje de mil millas comienza con un solo paso. - Lao Tse",
      "La esperanza es un sueño despierto. - Aristóteles",
      "La paciencia es amarga, pero su fruto es dulce. - Jean-Jacques Rousseau",
      "Conócete a ti mismo. - Inscripción de Delfos",
      "Donde hay voluntad, hay un camino. - Proverbio",
      "Poco a poco se llega lejos. - Proverbio",
      "La gota horada la piedra, no por la fuerza, sino por caer a menudo. - Ovidio",
      "La naturaleza no hace nada en vano. - Aristóteles",
      "La fortuna favorece a los audaces. - Virgilio",
      "El conocimiento es poder. - Francis Bacon",
      "Ningún viento es favorable para quien no sabe adónde va. - Séneca",
      "Haz cada cosa con calma y orden. - Marco Aurelio",
      "La sencillez es la máxima sofisticación. - Leonardo da Vinci",
      "Quien busca, encuentra. - Proverbio",
      "El tiempo revela todas las cosas. - Tertuliano",
      "Aprender es como remar contra corriente: si te detienes, retrocedes. - Proverbio chino",
      "La amabilidad no cuesta nada, pero vale muchísimo. - Proverbio",
      "Las raíces del estudio son amargas, pero sus frutos son dulces. - Proverbio",
      "No cuentes los días; haz que los días cuenten. - Proverbio",
      "Después de la tormenta llega la calma. - Proverbio",
      "La moderación es el mayor tesoro. - Hesíodo",
      "Una palabra amable calienta tres meses de invierno. - Proverbio japonés",
      "Más vale encender una vela que maldecir la oscuridad. - Proverbio",
      "El camino se hace al andar. - Proverbio",
      "Bien empezado es medio hecho. - Aristóteles",
      "El valor crece al atreverse. - Proverbio",
      "Cada semilla tiene su tiempo para florecer. - Proverbio",
      "La constancia vence al cansancio. - Proverbio",
      "Incluso el invierno más largo teme a la primavera. - Proverbio",
      "Una mente abierta siempre encuentra un camino. - Proverbio",
      "Escucha mucho y habla poco. - Proverbio",
      "El silencio es a veces la respuesta más sabia. - Proverbio",
      "La gratitud transforma lo que tenemos en lo que nos basta. - Proverbio",
      "El mejor momento para empezar es ahora. - Proverbio",
      "Un corazón sereno ve más lejos. - Proverbio",
      "La alegría compartida se multiplica. - Proverbio",
      "Quien aprende cada día se mantiene joven. - Proverbio",
      "Incluso el camino más largo se recorre paso a paso. - Proverbio",
      "La calma es una forma de fuerza. - Proverbio",
      "En medio de toda dificultad se encuentra una oportunidad. - Albert Einstein",
      "La luz más valiosa es la que enciendes dentro de ti. - Proverbio",
      "La constancia transforma las metas en resultados. - Jim Rohn",
      "La perseverancia abre puertas que la prisa deja cerradas. - Proverbio",
      "El descanso es parte del camino. - Proverbio",
      "Quien siembra paciencia cosecha paz. - Proverbio",
      "Todo gran resultado nace de un primer paso. - Proverbio",
      "El hábito vuelve ligero lo que al principio pesa. - Proverbio",
      "Cada día trae consigo una lección. - Proverbio",
      "Mira hacia adelante con confianza, pero camina con humildad. - Proverbio",
      "La verdad es sencilla, aunque el camino no lo sea. - Proverbio",
      "Sonreír es una forma amable de ser fuerte. - Proverbio",
      "Quien valora el tiempo valora la vida. - Proverbio",
      "Las buenas palabras permanecen mucho tiempo en el corazón. - Proverbio",
      "No hace falta correr: hace falta no detenerse. - Proverbio",
      "Una meta clara aligera el viaje. - Proverbio",
      "La fidelidad a los pequeños compromisos prepara para las grandes cosas. - Proverbio",
      "Cada amanecer trae una invitación a empezar de nuevo. - Proverbio",
      "La amabilidad abre puertas que la fuerza no ve. - Proverbio",
      "Quien escucha con el corazón encuentra mejores palabras. - Proverbio",
      "La esperanza crece cuando se comparte. - Proverbio",
      "Un paso sincero vale más que cien promesas. - Proverbio",
      "La paciencia ayuda a los sueños a hacerse realidad. - Proverbio",
      "Donde pones cuidado, nace la belleza. - Proverbio",
      "El valor no borra el miedo: le enseña el camino. - Proverbio",
      "Cada error puede convertirse en un mapa. - Proverbio",
      "La confianza se construye con gestos pequeños y verdaderos. - Proverbio",
      "Un día difícil no borra todo lo que has construido. - Proverbio",
      "Quien lleva luz a los demás ilumina también su propio camino. - Proverbio",
      "La sabiduría comienza cuando aprendemos a guardar silencio. - Proverbio",
      "El tiempo dado con amor nunca se pierde. - Proverbio",
      "Cuando se cierra una puerta, puede abrirse un camino nuevo. - Proverbio",
      "Quien sabe detenerse encuentra belleza incluso en las cosas sencillas. - Proverbio",
      "No hay viento contrario para quien sabe ajustar las velas. - Proverbio",
      "Donde el orgullo se hace a un lado, puede nacer la paz. - Proverbio",
      "Un buen pensamiento puede cambiar el peso de un día. - Proverbio",
      "El cuidado de los detalles hace grande incluso lo sencillo. - Proverbio",
      "Quien permanece fiel al bien nunca camina en vano. - Proverbio",
      "La memoria guarda, pero el perdón libera. - Proverbio",
      "Todo talento florece cuando se convierte en un regalo para los demás. - Proverbio",
      "El mañana se prepara con el cuidado de hoy. - Proverbio",
      "La voz más fuerte suele ser la de la coherencia. - Proverbio",
      "Una mano tendida acorta muchas distancias. - Proverbio",
      "La serenidad nace cuando aprendemos a aceptar lo que no podemos cambiar. - Proverbio",
      "El verdadero progreso deja espacio también a los demás. - Proverbio",
      "Quien agradece ve riqueza incluso en las cosas sencillas. - Proverbio",
      "La luz de la mañana no pide permiso a la oscuridad. - Proverbio",
      "La constancia acerca los sueños a la realidad. - Proverbio",
      "La bondad sembrada en silencio vuelve cuando menos la esperas. - Proverbio",
      "La humildad vuelve ligera incluso la victoria. - Proverbio",
      "El camino correcto es el que deja el corazón en paz. - Proverbio",
      "Quien sabe esperar entiende que cada cosa tiene su tiempo. - Proverbio",
      "Cada buen hábito es una promesa cumplida a uno mismo. - Proverbio",
      "El saber crece cuando se convierte en regalo. - Proverbio",
      "Aceptar los propios límites es una forma de sabiduría. - Proverbio",
      "La confianza crece en los pequeños gestos de cada día. - Proverbio",
      "El día más sencillo puede contener un gran cambio. - Proverbio",
      "El cuidado empieza por las cosas que nadie ve. - Proverbio",
      "No todo lo que tarda está perdido. - Proverbio",
      "Una palabra serena puede apagar un incendio. - Proverbio",
      "Quien cultiva paciencia cosecha claridad. - Proverbio",
      "La gratitud ilumina incluso los días más sencillos. - Proverbio",
      "Cada paso dado con honestidad acerca a la meta. - Proverbio",
      "La verdadera fuerza sabe ser amable. - Proverbio",
      "El corazón aprende caminando. - Proverbio",
      "Una mente curiosa nunca envejece. - Proverbio",
      "La luz se reconoce mejor después de la oscuridad. - Proverbio",
      "Quien construye puentes encuentra más caminos. - Proverbio",
      "El bien hecho en silencio habla durante mucho tiempo. - Proverbio",
      "La prudencia no detiene el viaje: lo protege. - Proverbio",
      "Todo cambio necesita bases sólidas. - Proverbio",
      "La promesa más importante es la que se cumple con hechos. - Proverbio",
      "El tiempo enseña a quien sabe escucharlo. - Proverbio",
      "Donde hay respeto, la distancia se acorta. - Proverbio",
      "La creatividad nace cuando el miedo deja espacio al juego. - Proverbio",
      "Un corazón sereno ve el mundo con más claridad. - Proverbio",
      "No pierdas la ternura: es una forma de valentía. - Proverbio",
      "La constancia transforma lo difícil en posible. - Proverbio",
      "Quien reconoce sus límites abre espacio al crecimiento. - Proverbio",
      "Cada encuentro puede enseñarnos algo nuevo. - Proverbio",
      "La mejor elección es la que también hace bien a los demás. - Proverbio",
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
      "Uma viagem de mil milhas começa com um único passo. - Lao Tzu",
      "A esperança é um sonho acordado. - Aristóteles",
      "A paciência é amarga, mas o seu fruto é doce. - Jean-Jacques Rousseau",
      "Conhece-te a ti mesmo. - Inscrição de Delfos",
      "Onde há vontade, há caminho. - Provérbio",
      "Pouco a pouco se vai longe. - Provérbio",
      "A gota escava a pedra, não pela força, mas por cair muitas vezes. - Ovídio",
      "A natureza nada faz em vão. - Aristóteles",
      "A sorte favorece os audazes. - Virgílio",
      "Conhecimento é poder. - Francis Bacon",
      "Nenhum vento é favorável para quem não sabe para onde vai. - Séneca",
      "Faz cada coisa com calma e ordem. - Marco Aurélio",
      "A simplicidade é a maior sofisticação. - Leonardo da Vinci",
      "Quem procura encontra. - Provérbio",
      "O tempo revela todas as coisas. - Tertuliano",
      "Aprender é como remar contra a corrente: se paras, voltas para trás. - Provérbio chinês",
      "A gentileza não custa nada, mas vale muito. - Provérbio",
      "As raízes do estudo são amargas, mas os frutos são doces. - Provérbio",
      "Não contes os dias; faz com que os dias contem. - Provérbio",
      "Depois da tempestade vem a bonança. - Provérbio",
      "A moderação é o maior tesouro. - Hesíodo",
      "Uma palavra bondosa aquece três meses de inverno. - Provérbio japonês",
      "Mais vale acender uma vela do que amaldiçoar a escuridão. - Provérbio",
      "O caminho faz-se caminhando. - Provérbio",
      "Começar bem é ter metade do caminho feito. - Aristóteles",
      "A coragem cresce quando se ousa. - Provérbio",
      "Cada semente tem o seu tempo para florir. - Provérbio",
      "A constância vence o cansaço. - Provérbio",
      "Mesmo o inverno mais longo teme a primavera. - Provérbio",
      "Uma mente aberta encontra sempre um caminho. - Provérbio",
      "Ouve muito, fala pouco. - Provérbio",
      "O silêncio é por vezes a resposta mais sábia. - Provérbio",
      "A gratidão transforma o que temos naquilo que nos basta. - Provérbio",
      "O melhor momento para começar é agora. - Provérbio",
      "Um coração sereno vê mais longe. - Provérbio",
      "A alegria partilhada multiplica-se. - Provérbio",
      "Quem aprende todos os dias permanece jovem. - Provérbio",
      "Até a estrada mais longa se percorre um passo de cada vez. - Provérbio",
      "A calma é uma forma de força. - Provérbio",
      "No meio de cada dificuldade encontra-se uma oportunidade. - Albert Einstein",
      "A luz mais preciosa é a que acendes dentro de ti. - Provérbio",
      "A constância transforma objetivos em resultados. - Jim Rohn",
      "A perseverança abre portas que a pressa deixa fechadas. - Provérbio",
      "O descanso faz parte do caminho. - Provérbio",
      "Quem semeia paciência colhe paz. - Provérbio",
      "Todo grande resultado nasce de um primeiro passo. - Provérbio",
      "O hábito torna leve o que ao início pesa. - Provérbio",
      "Cada dia traz consigo uma lição. - Provérbio",
      "Olha em frente com confiança, mas caminha com humildade. - Provérbio",
      "A verdade é simples, mesmo quando o caminho não o é. - Provérbio",
      "Sorrir é uma forma gentil de ser forte. - Provérbio",
      "Quem valoriza o tempo valoriza a vida. - Provérbio",
      "As boas palavras ficam muito tempo no coração. - Provérbio",
      "Não é preciso correr: é preciso não parar. - Provérbio",
      "Uma meta clara alivia a viagem. - Provérbio",
      "A fidelidade aos pequenos compromissos prepara para grandes coisas. - Provérbio",
      "Cada amanhecer traz um convite para recomeçar. - Provérbio",
      "A gentileza abre portas que a força não vê. - Provérbio",
      "Quem escuta com o coração encontra palavras melhores. - Provérbio",
      "A esperança cresce quando é partilhada. - Provérbio",
      "Um passo sincero vale mais do que cem promessas. - Provérbio",
      "A paciência ajuda os sonhos a tornarem-se realidade. - Provérbio",
      "Onde pões cuidado, nasce beleza. - Provérbio",
      "A coragem não apaga o medo: ensina-lhe o caminho. - Provérbio",
      "Cada erro pode tornar-se um mapa. - Provérbio",
      "A confiança constrói-se com gestos pequenos e verdadeiros. - Provérbio",
      "Um dia difícil não apaga tudo o que construíste. - Provérbio",
      "Quem leva luz aos outros ilumina também o próprio caminho. - Provérbio",
      "A sabedoria começa quando aprendemos a fazer silêncio. - Provérbio",
      "O tempo dado com amor nunca se perde. - Provérbio",
      "Quando uma porta se fecha, pode abrir-se um novo caminho. - Provérbio",
      "Quem sabe parar encontra beleza até nas coisas simples. - Provérbio",
      "Não há vento contrário para quem sabe ajustar as velas. - Provérbio",
      "Onde o orgulho se põe de lado, a paz pode nascer. - Provérbio",
      "Um bom pensamento pode mudar o peso de um dia. - Provérbio",
      "O cuidado com os detalhes torna grande até o que é simples. - Provérbio",
      "Quem permanece fiel ao bem nunca caminha em vão. - Provérbio",
      "A memória guarda, mas o perdão liberta. - Provérbio",
      "Todo talento floresce quando se torna um dom para os outros. - Provérbio",
      "O amanhã prepara-se com o cuidado de hoje. - Provérbio",
      "A voz mais forte é muitas vezes a da coerência. - Provérbio",
      "Uma mão estendida encurta muitas distâncias. - Provérbio",
      "A serenidade nasce quando aprendemos a aceitar o que não podemos mudar. - Provérbio",
      "O verdadeiro progresso deixa espaço também para os outros. - Provérbio",
      "Quem agradece vê riqueza até nas coisas simples. - Provérbio",
      "A luz da manhã não pede licença à escuridão. - Provérbio",
      "A constância aproxima os sonhos da realidade. - Provérbio",
      "A bondade semeada em silêncio regressa quando menos esperas. - Provérbio",
      "A humildade torna leve até a vitória. - Provérbio",
      "O caminho certo é aquele que deixa o coração em paz. - Provérbio",
      "Quem sabe esperar entende que cada coisa tem o seu tempo. - Provérbio",
      "Cada bom hábito é uma promessa cumprida a si mesmo. - Provérbio",
      "O saber cresce quando se torna um dom. - Provérbio",
      "Aceitar os próprios limites é uma forma de sabedoria. - Provérbio",
      "A confiança cresce nos pequenos gestos de cada dia. - Provérbio",
      "O dia mais simples pode conter uma grande viragem. - Provérbio",
      "O cuidado começa pelas coisas que ninguém vê. - Provérbio",
      "Nem tudo o que tarda está perdido. - Provérbio",
      "Uma palavra calma pode apagar um incêndio. - Provérbio",
      "Quem cultiva paciência colhe clareza. - Provérbio",
      "A gratidão ilumina até os dias mais simples. - Provérbio",
      "Cada passo dado com honestidade aproxima da meta. - Provérbio",
      "A verdadeira força sabe ser gentil. - Provérbio",
      "O coração aprende caminhando. - Provérbio",
      "Uma mente curiosa nunca envelhece. - Provérbio",
      "A luz reconhece-se melhor depois da escuridão. - Provérbio",
      "Quem constrói pontes encontra mais caminhos. - Provérbio",
      "O bem feito em silêncio fala por muito tempo. - Provérbio",
      "A prudência não interrompe a viagem: protege-a. - Provérbio",
      "Toda a mudança precisa de bases sólidas. - Provérbio",
      "A promessa mais importante é a que se cumpre com atos. - Provérbio",
      "O tempo ensina quem sabe escutá-lo. - Provérbio",
      "Onde há respeito, a distância encurta. - Provérbio",
      "A criatividade nasce quando o medo dá espaço ao jogo. - Provérbio",
      "Um coração sereno vê o mundo com mais clareza. - Provérbio",
      "Não percas a ternura: é uma forma de coragem. - Provérbio",
      "A constância transforma o difícil em possível. - Provérbio",
      "Quem reconhece os próprios limites abre espaço ao crescimento. - Provérbio",
      "Cada encontro pode ensinar-nos algo novo. - Provérbio",
      "A melhor escolha é a que também faz bem aos outros. - Provérbio",
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
      "Cesta dlouhá tisíc mil začíná jediným krokem. - Lao-c'",
      "Naděje je bdělý sen. - Aristotelés",
      "Trpělivost je hořká, ale její plody jsou sladké. - Jean-Jacques Rousseau",
      "Poznej sám sebe. - Nápis v Delfách",
      "Kde je vůle, tam je cesta. - Přísloví",
      "Pomalu a jistě se dojde daleko. - Přísloví",
      "Kapka vyhloubí kámen ne silou, ale tím, že často dopadá. - Ovidius",
      "Příroda nedělá nic zbytečně. - Aristotelés",
      "Štěstí přeje odvážným. - Vergilius",
      "Vědění je moc. - Francis Bacon",
      "Žádný vítr není příznivý tomu, kdo neví, kam míří. - Seneca",
      "Dělej každou věc klidně a v pořádku. - Marcus Aurelius",
      "Jednoduchost je nejvyšší vytříbenost. - Leonardo da Vinci",
      "Kdo hledá, najde. - Přísloví",
      "Čas odhalí všechny věci. - Tertullianus",
      "Učení je jako veslování proti proudu: když přestaneš, vracíš se zpět. - Čínské přísloví",
      "Laskavost nic nestojí, ale má velikou cenu. - Přísloví",
      "Kořeny učení jsou hořké, ale plody jsou sladké. - Přísloví",
      "Nepočítej dny, zařiď, aby se dny počítaly. - Přísloví",
      "Po bouři přichází klid. - Přísloví",
      "Umírněnost je největší poklad. - Hésiodos",
      "Jedno laskavé slovo zahřeje tři zimní měsíce. - Japonské přísloví",
      "Lepší je zapálit svíčku než proklínat tmu. - Přísloví",
      "Cesta vzniká chůzí. - Přísloví",
      "Dobře začít znamená mít polovinu hotovo. - Aristotelés",
      "Odvaha roste, když si troufáme. - Přísloví",
      "Každé semeno má svůj čas rozkvést. - Přísloví",
      "Vytrvalost vítězí nad únavou. - Přísloví",
      "I nejdelší zima se bojí jara. - Přísloví",
      "Otevřená mysl si vždy najde cestu. - Přísloví",
      "Hodně poslouchej, málo mluv. - Přísloví",
      "Ticho je někdy nejmoudřejší odpověď. - Přísloví",
      "Vděčnost proměňuje to, co máme, v to, co nám stačí. - Přísloví",
      "Nejlepší čas začít je právě teď. - Přísloví",
      "Klidné srdce dohlédne dál. - Přísloví",
      "Sdílená radost se násobí. - Přísloví",
      "Kdo se učí každý den, zůstává mladý. - Přísloví",
      "I ta nejdelší cesta se jde krok za krokem. - Přísloví",
      "Klid je forma síly. - Přísloví",
      "Uprostřed každé obtíže je příležitost. - Albert Einstein",
      "Nejcennější světlo je to, které rozsvítíš v sobě. - Přísloví",
      "Vytrvalost mění cíle ve výsledky. - Jim Rohn",
      "Vytrvalost otevírá dveře, které spěch nechává zavřené. - Přísloví",
      "Odpočinek je součástí cesty. - Přísloví",
      "Kdo seje trpělivost, sklízí pokoj. - Přísloví",
      "Každý velký výsledek začíná prvním krokem. - Přísloví",
      "Zvyk odlehčuje tomu, co bylo zpočátku těžké. - Přísloví",
      "Každý den přináší své ponaučení. - Přísloví",
      "Dívej se vpřed s důvěrou, ale kráčej s pokorou. - Přísloví",
      "Pravda je jednoduchá, i když cesta jednoduchá není. - Přísloví",
      "Usmívat se je laskavý způsob, jak být silný. - Přísloví",
      "Kdo si váží času, váží si života. - Přísloví",
      "Dobrá slova zůstávají dlouho v srdci. - Přísloví",
      "Není třeba běžet; je třeba nezastavit se. - Přísloví",
      "Jasný cíl ulehčuje cestu. - Přísloví",
      "Věrnost malým závazkům připravuje na velké věci. - Přísloví",
      "Každé svítání přináší pozvání začít znovu. - Přísloví",
      "Laskavost otevírá dveře, které síla nevidí. - Přísloví",
      "Kdo naslouchá srdcem, nachází lepší slova. - Přísloví",
      "Naděje roste, když se sdílí. - Přísloví",
      "Jeden upřímný krok má větší cenu než sto slibů. - Přísloví",
      "Trpělivost pomáhá snům stát se skutečností. - Přísloví",
      "Kam vložíš péči, tam se rodí krása. - Přísloví",
      "Odvaha nemaže strach: ukazuje mu cestu. - Přísloví",
      "Každá chyba se může stát mapou. - Přísloví",
      "Důvěra se buduje malými a opravdovými gesty. - Přísloví",
      "Těžký den nesmaže vše, co jsme vybudovali. - Přísloví",
      "Kdo přináší světlo druhým, osvětluje i svou vlastní cestu. - Přísloví",
      "Moudrost začíná, když se učíme mlčet. - Přísloví",
      "Čas darovaný s láskou není nikdy ztracený. - Přísloví",
      "Když se jedny dveře zavřou, může se otevřít nová cesta. - Přísloví",
      "Kdo se umí zastavit, nachází krásu i v obyčejných věcech. - Přísloví",
      "Žádný vítr není proti tomu, kdo umí nastavit plachty. - Přísloví",
      "Kde pýcha ustoupí, může se zrodit pokoj. - Přísloví",
      "Dobrá myšlenka může změnit tíhu dne. - Přísloví",
      "Péče o detaily činí velkým i to, co je jednoduché. - Přísloví",
      "Kdo zůstává věrný dobru, nekráčí nikdy nadarmo. - Přísloví",
      "Paměť uchovává, ale odpuštění osvobozuje. - Přísloví",
      "Každý talent rozkvétá, když se stane darem pro druhé. - Přísloví",
      "Zítřek se připravuje péčí dneška. - Přísloví",
      "Nejsilnější hlas je často hlas důslednosti. - Přísloví",
      "Podaná ruka zkracuje mnoho vzdáleností. - Přísloví",
      "Klid se rodí, když se učíme přijímat to, co nemůžeme změnit. - Přísloví",
      "Skutečný pokrok nechává místo i druhým. - Přísloví",
      "Kdo děkuje, vidí bohatství i v jednoduchých věcech. - Přísloví",
      "Ranní světlo nežádá tmu o svolení. - Přísloví",
      "Vytrvalost přibližuje sny skutečnosti. - Přísloví",
      "Dobrota zasetá v tichu se vrací, když ji nejméně čekáš. - Přísloví",
      "Pokora činí i vítězství lehkým. - Přísloví",
      "Správná cesta přináší srdci klid. - Přísloví",
      "Kdo umí čekat, chápe, že všechno má svůj čas. - Přísloví",
      "Každý dobrý návyk je slib dodržený sám sobě. - Přísloví",
      "Vědění roste, když se stává darem. - Přísloví",
      "Přijmout vlastní hranice je forma moudrosti. - Přísloví",
      "Důvěra roste v malých každodenních gestech. - Přísloví",
      "I nejjednodušší den může nést velký obrat. - Přísloví",
      "Péče začíná u věcí, které nikdo nevidí. - Přísloví",
      "Ne všechno, co se opozdí, je ztraceno. - Přísloví",
      "Klidné slovo může uhasit požár. - Přísloví",
      "Kdo pěstuje trpělivost, sklízí jasnost. - Přísloví",
      "Vděčnost rozjasňuje i ty nejjednodušší dny. - Přísloví",
      "Každý poctivý krok přibližuje k cíli. - Přísloví",
      "Skutečná síla umí být laskavá. - Přísloví",
      "Srdce se učí chůzí. - Přísloví",
      "Zvědavá mysl nikdy nestárne. - Přísloví",
      "Světlo se lépe poznává po tmě. - Přísloví",
      "Kdo staví mosty, nachází více cest. - Přísloví",
      "Dobro vykonané v tichu mluví dlouho. - Přísloví",
      "Opatrnost nezastavuje cestu: chrání ji. - Přísloví",
      "Každá změna potřebuje pevné základy. - Přísloví",
      "Nejdůležitější slib je ten, který se plní skutky. - Přísloví",
      "Čas učí ty, kdo mu umějí naslouchat. - Přísloví",
      "Kde je respekt, tam se vzdálenost zkracuje. - Přísloví",
      "Tvořivost se rodí, když strach dá prostor hře. - Přísloví",
      "Klidné srdce vidí svět jasněji. - Přísloví",
      "Neztrať něhu: je to forma odvahy. - Přísloví",
      "Vytrvalost mění obtížné v možné. - Přísloví",
      "Kdo rozpozná své hranice, otevírá prostor růstu. - Přísloví",
      "Každé setkání nás může naučit něco nového. - Přísloví",
      "Nejlepší volba je ta, která prospívá i druhým. - Přísloví",
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
      "Podróż tysiąca mil zaczyna się od jednego kroku. - Laozi",
      "Nadzieja jest snem na jawie. - Arystoteles",
      "Cierpliwość jest gorzka, ale jej owoc jest słodki. - Jean-Jacques Rousseau",
      "Poznaj samego siebie. - Napis w Delfach",
      "Gdzie jest wola, tam jest droga. - Przysłowie",
      "Powoli, krok po kroku, dochodzi się daleko. - Przysłowie",
      "Kropla drąży kamień nie siłą, lecz częstym spadaniem. - Owidiusz",
      "Natura nie czyni nic na próżno. - Arystoteles",
      "Szczęście sprzyja odważnym. - Wergiliusz",
      "Wiedza to potęga. - Francis Bacon",
      "Żaden wiatr nie jest pomyślny dla tego, kto nie wie, dokąd zmierza. - Seneka",
      "Rób wszystko spokojnie i w dobrym porządku. - Marek Aureliusz",
      "Prostota jest najwyższym wyrafinowaniem. - Leonardo da Vinci",
      "Kto szuka, ten znajdzie. - Przysłowie",
      "Czas ujawnia wszystko. - Tertulian",
      "Uczenie się jest jak wiosłowanie pod prąd: jeśli przestaniesz, cofasz się. - Przysłowie chińskie",
      "Życzliwość nic nie kosztuje, a jest bardzo cenna. - Przysłowie",
      "Korzenie nauki są gorzkie, lecz owoce słodkie. - Przysłowie",
      "Nie licz dni, spraw, by dni się liczyły. - Przysłowie",
      "Po burzy przychodzi spokój. - Przysłowie",
      "Umiar jest największym skarbem. - Hezjod",
      "Jedno życzliwe słowo ogrzewa trzy zimowe miesiące. - Przysłowie japońskie",
      "Lepiej zapalić świecę, niż przeklinać ciemność. - Przysłowie",
      "Drogę tworzy się, idąc. - Przysłowie",
      "Dobrze zaczęte to połowa dzieła. - Arystoteles",
      "Odwaga rośnie, gdy człowiek się odważa. - Przysłowie",
      "Każde ziarno ma swój czas, by zakwitnąć. - Przysłowie",
      "Wytrwałość zwycięża zmęczenie. - Przysłowie",
      "Nawet najdłuższa zima boi się wiosny. - Przysłowie",
      "Otwarty umysł zawsze znajduje drogę. - Przysłowie",
      "Słuchaj dużo, mów mało. - Przysłowie",
      "Milczenie bywa czasem najmądrzejszą odpowiedzią. - Przysłowie",
      "Wdzięczność sprawia, że to, co mamy, staje się wystarczające. - Przysłowie",
      "Najlepszy moment, by zacząć, jest teraz. - Przysłowie",
      "Spokojne serce widzi dalej. - Przysłowie",
      "Dzielona radość się mnoży. - Przysłowie",
      "Kto uczy się każdego dnia, pozostaje młody. - Przysłowie",
      "Nawet najdłuższą drogę pokonuje się krok po kroku. - Przysłowie",
      "Spokój jest formą siły. - Przysłowie",
      "Pośród każdej trudności kryje się okazja. - Albert Einstein",
      "Najcenniejsze światło to to, które zapalasz w sobie. - Przysłowie",
      "Konsekwencja zamienia cele w wyniki. - Jim Rohn",
      "Wytrwałość otwiera drzwi, które pośpiech zostawia zamknięte. - Przysłowie",
      "Odpoczynek jest częścią drogi. - Przysłowie",
      "Kto sieje cierpliwość, zbiera pokój. - Przysłowie",
      "Każdy wielki rezultat zaczyna się od pierwszego kroku. - Przysłowie",
      "Nawyk czyni lekkim to, co na początku było ciężkie. - Przysłowie",
      "Każdy dzień niesie swoją lekcję. - Przysłowie",
      "Patrz naprzód z ufnością, ale idź z pokorą. - Przysłowie",
      "Prawda jest prosta, nawet gdy droga taka nie jest. - Przysłowie",
      "Uśmiech jest łagodnym sposobem bycia silnym. - Przysłowie",
      "Kto ceni czas, ceni życie. - Przysłowie",
      "Dobre słowa na długo zostają w sercu. - Przysłowie",
      "Nie trzeba biec: trzeba się nie zatrzymywać. - Przysłowie",
      "Jasny cel czyni podróż lżejszą. - Przysłowie",
      "Wierność małym zobowiązaniom przygotowuje do wielkich rzeczy. - Przysłowie",
      "Każdy świt przynosi zaproszenie, by zacząć od nowa. - Przysłowie",
      "Życzliwość otwiera drzwi, których siła nie dostrzega. - Przysłowie",
      "Kto słucha sercem, znajduje lepsze słowa. - Przysłowie",
      "Nadzieja rośnie, gdy się nią dzielimy. - Przysłowie",
      "Jeden szczery krok jest wart więcej niż sto obietnic. - Przysłowie",
      "Cierpliwość pomaga marzeniom stać się rzeczywistością. - Przysłowie",
      "Gdzie wkładasz troskę, tam rodzi się piękno. - Przysłowie",
      "Odwaga nie usuwa strachu: pokazuje mu drogę. - Przysłowie",
      "Każdy błąd może stać się mapą. - Przysłowie",
      "Zaufanie buduje się małymi i prawdziwymi gestami. - Przysłowie",
      "Trudny dzień nie przekreśla wszystkiego, co udało ci się zbudować. - Przysłowie",
      "Kto niesie światło innym, rozjaśnia także własną drogę. - Przysłowie",
      "Mądrość zaczyna się, gdy uczymy się milczeć. - Przysłowie",
      "Czas dany z miłością nigdy nie jest stracony. - Przysłowie",
      "Kiedy zamykają się jedne drzwi, może otworzyć się nowa droga. - Przysłowie",
      "Kto potrafi się zatrzymać, znajduje piękno nawet w prostych rzeczach. - Przysłowie",
      "Nie ma przeciwnego wiatru dla tego, kto umie ustawić żagle. - Przysłowie",
      "Tam, gdzie duma ustępuje, może narodzić się pokój. - Przysłowie",
      "Dobra myśl może zmienić ciężar dnia. - Przysłowie",
      "Troska o szczegóły czyni wielkim nawet to, co proste. - Przysłowie",
      "Kto pozostaje wierny dobru, nigdy nie idzie na próżno. - Przysłowie",
      "Pamięć przechowuje, ale przebaczenie uwalnia. - Przysłowie",
      "Każdy talent rozkwita, gdy staje się darem dla innych. - Przysłowie",
      "Jutro przygotowuje się troską dnia dzisiejszego. - Przysłowie",
      "Najsilniejszy głos to często głos konsekwencji. - Przysłowie",
      "Wyciągnięta ręka skraca wiele odległości. - Przysłowie",
      "Spokój rodzi się, gdy uczymy się akceptować to, czego nie możemy zmienić. - Przysłowie",
      "Prawdziwy postęp zostawia miejsce także dla innych. - Przysłowie",
      "Kto dziękuje, widzi bogactwo nawet w prostych rzeczach. - Przysłowie",
      "Poranne światło nie prosi ciemności o pozwolenie. - Przysłowie",
      "Konsekwencja przybliża marzenia do rzeczywistości. - Przysłowie",
      "Dobro zasiane w ciszy wraca, gdy najmniej się tego spodziewasz. - Przysłowie",
      "Pokora czyni lekkim nawet zwycięstwo. - Przysłowie",
      "Właściwa droga daje sercu spokój. - Przysłowie",
      "Kto umie czekać, rozumie, że wszystko ma swój czas. - Przysłowie",
      "Każdy dobry nawyk jest obietnicą dotrzymaną samemu sobie. - Przysłowie",
      "Wiedza rośnie, gdy staje się darem. - Przysłowie",
      "Akceptowanie własnych ograniczeń jest formą mądrości. - Przysłowie",
      "Zaufanie rośnie dzięki małym codziennym gestom. - Przysłowie",
      "Najprostszy dzień może zawierać wielki zwrot. - Przysłowie",
      "Troska zaczyna się od rzeczy, których nikt nie widzi. - Przysłowie",
      "Nie wszystko, co się opóźnia, jest stracone. - Przysłowie",
      "Spokojne słowo może ugasić pożar. - Przysłowie",
      "Kto pielęgnuje cierpliwość, zbiera jasność. - Przysłowie",
      "Wdzięczność rozjaśnia nawet najprostsze dni. - Przysłowie",
      "Każdy uczciwy krok przybliża do celu. - Przysłowie",
      "Prawdziwa siła potrafi być życzliwa. - Przysłowie",
      "Serce uczy się, idąc. - Przysłowie",
      "Ciekawy umysł nigdy się nie starzeje. - Przysłowie",
      "Światło lepiej rozpoznaje się po ciemności. - Przysłowie",
      "Kto buduje mosty, znajduje więcej dróg. - Przysłowie",
      "Dobro czynione w ciszy przemawia długo. - Przysłowie",
      "Roztropność nie zatrzymuje podróży: ona ją chroni. - Przysłowie",
      "Każda zmiana potrzebuje solidnych podstaw. - Przysłowie",
      "Najważniejsza obietnica to ta spełniona czynami. - Przysłowie",
      "Czas uczy tych, którzy potrafią go słuchać. - Przysłowie",
      "Tam, gdzie jest szacunek, odległość się skraca. - Przysłowie",
      "Kreatywność rodzi się, gdy strach ustępuje miejsca zabawie. - Przysłowie",
      "Spokojne serce widzi świat wyraźniej. - Przysłowie",
      "Nie trać czułości: to forma odwagi. - Przysłowie",
      "Wytrwałość przemienia trudne w możliwe. - Przysłowie",
      "Kto rozpoznaje własne granice, otwiera przestrzeń na rozwój. - Przysłowie",
      "Każde spotkanie może nauczyć nas czegoś nowego. - Przysłowie",
      "Najlepszy wybór to ten, który służy także innym. - Przysłowie",
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
    // Usiamo solo anno, mese e giorno in UTC per evitare effetti di fuso orario
    // o ora legale: due date consecutive avanzano sempre di una citazione.
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);
    final daysSinceEpoch = normalizedDate.difference(DateTime.utc(1970, 1, 1)).inDays;
    return list[daysSinceEpoch % list.length];
  }
}
