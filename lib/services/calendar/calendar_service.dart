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
      "Il vero viaggio di scoperta non consiste nel cercare nuove terre, ma nell’avere nuovi occhi. - Marcel Proust",
      "L'unico modo per fare un ottimo lavoro è amare quello che fai. - Steve Jobs",
      "L’essenziale è invisibile agli occhi. - Antoine de Saint-Exupéry",
      "Un viaggio di mille miglia comincia con un solo passo. - Lao Tzu",
      "La speranza è un sogno fatto da svegli. - Aristotele",
      "La pazienza è amara, ma il suo frutto è dolce. - Jean-Jacques Rousseau",
      "Bisogna avere ancora il caos dentro di sé per generare una stella danzante. - Friedrich Nietzsche",
      "La bellezza salverà il mondo. - Fëdor Dostoevskij",
      "So di non sapere. - Socrate",
      "La goccia scava la pietra, non con la forza ma cadendo spesso. - Ovidio",
      "La natura non fa nulla invano. - Aristotele",
      "La fortuna aiuta gli audaci. - Virgilio",
      "La conoscenza è potere. - Francis Bacon",
      "Nessun vento è favorevole per chi non sa dove andare. - Seneca",
      "Fa' ogni cosa con calma e ordine. - Marco Aurelio",
      "La semplicità è la massima raffinatezza. - Leonardo da Vinci",
      "Il cuore ha le sue ragioni che la ragione non conosce. - Blaise Pascal",
      "Il tempo rivela ogni cosa. - Tertulliano",
      "Diventa ciò che sei. - Friedrich Nietzsche",
      "Chi ha un perché per vivere può sopportare quasi ogni come. - Friedrich Nietzsche",
      "Non c’è nulla di permanente tranne il cambiamento. - Eraclito",
      "Tutto scorre. - Eraclito",
      "Sembra sempre impossibile finché non viene fatto. - Nelson Mandela",
      "La moderazione è il tesoro più grande. - Esiodo",
      "Nella vita non c’è nulla da temere, solo da capire. - Marie Curie",
      "L’immaginazione è più importante della conoscenza. - Albert Einstein",
      "Nessun atto di gentilezza, per piccolo che sia, è mai sprecato. - Esopo",
      "Chi ben comincia è a metà dell'opera. - Aristotele",
      "Siamo tutti nel fango, ma alcuni di noi guardano le stelle. - Oscar Wilde",
      "Non è perché le cose sono difficili che non osiamo, ma è perché non osiamo che sono difficili. - Seneca",
      "Le persone sono come le biciclette: riescono a mantenere l’equilibrio solo se continuano a muoversi. - Albert Einstein",
      "La misura dell’intelligenza è la capacità di cambiare. - Albert Einstein",
      "Fatti non foste a viver come bruti, ma per seguir virtute e canoscenza. - Dante Alighieri",
      "Amor, ch’a nullo amato amar perdona. - Dante Alighieri",
      "Nel mezzo del cammin di nostra vita mi ritrovai per una selva oscura. - Dante Alighieri",
      "Essere, o non essere, questo è il dilemma. - William Shakespeare",
      "Sappiamo ciò che siamo, ma non ciò che potremmo essere. - William Shakespeare",
      "Nessuno può farti sentire inferiore senza il tuo consenso. - Eleanor Roosevelt",
      "Viviamo tutti sotto lo stesso cielo, ma non tutti abbiamo lo stesso orizzonte. - Konrad Adenauer",
      "Ama tutti, credi a pochi e non far del male a nessuno. - William Shakespeare",
      "La brevità è l’anima della saggezza. - William Shakespeare",
      "Non sono le cose che ci turbano, ma i giudizi che diamo sulle cose. - Epitteto",
      "Nel mezzo di ogni difficoltà si trova un'opportunità. - Albert Einstein",
      "Nessun uomo è libero se non è padrone di se stesso. - Epitteto",
      "La costanza trasforma gli obiettivi in risultati. - Jim Rohn",
      "La felicità della tua vita dipende dalla qualità dei tuoi pensieri. - Marco Aurelio",
      "La nostra vita è ciò che i nostri pensieri ne fanno. - Marco Aurelio",
      "Il tempo è la cosa più preziosa che un uomo possa spendere. - Teofrasto",
      "Chi poco pensa, molto erra. - Leonardo da Vinci",
      "La sapienza è figliola dell’esperienza. - Leonardo da Vinci",
      "Non si vede bene che col cuore. - Antoine de Saint-Exupéry",
      "Tutti i grandi sono stati bambini una volta. - Antoine de Saint-Exupéry",
      "Le stelle sono illuminate perché ognuno possa un giorno trovare la sua. - Antoine de Saint-Exupéry",
      "La libertà comincia dall’ironia. - Victor Hugo",
      "La coscienza è la voce dell’anima. - Jean-Jacques Rousseau",
      "L’uomo è nato libero, ma ovunque è in catene. - Jean-Jacques Rousseau",
      "Il dubbio è l’inizio della sapienza. - Cartesio",
      "Penso, dunque sono. - Cartesio",
      "La meraviglia è il principio della conoscenza. - Platone",
      "La musica dà un’anima all’universo, ali al pensiero, slancio all’immaginazione. - Platone",
      "L’uomo è un animale sociale. - Aristotele",
      "La felicità dipende da noi stessi. - Aristotele",
      "Scegli il lavoro che ami e non lavorerai neppure un giorno in tutta la tua vita. - Confucio",
      "Ovunque tu vada, vacci con tutto il cuore. - Confucio",
      "Non importa quanto vai piano, l’importante è non fermarsi. - Confucio",
      "Studia il passato se vuoi prevedere il futuro. - Confucio",
      "Chi conosce gli altri è sapiente; chi conosce se stesso è illuminato. - Laozi",
      "Chi si accontenta è ricco. - Laozi",
      "Le parole gentili sono brevi e facili da dire, ma la loro eco è eterna. - Madre Teresa",
      "Non possiamo fare grandi cose, ma solo piccole cose con grande amore. - Madre Teresa",
      "La pace comincia con un sorriso. - Madre Teresa",
      "Occhio per occhio rende il mondo cieco. - Mahatma Gandhi",
      "La forza non deriva dalla capacità fisica, ma da una volontà indomabile. - Mahatma Gandhi",
      "La vita è un mistero da vivere, non un problema da risolvere. - Søren Kierkegaard",
      "La vita può essere capita solo all’indietro, ma va vissuta in avanti. - Søren Kierkegaard",
      "Chi lotta può perdere, chi non lotta ha già perso. - Bertolt Brecht",
      "Là dove cresce il pericolo, cresce anche ciò che salva. - Friedrich Hölderlin",
      "Due cose riempiono l’animo di ammirazione: il cielo stellato sopra di me e la legge morale in me. - Immanuel Kant",
      "Abbi il coraggio di servirti della tua propria intelligenza. - Immanuel Kant",
      "L’uomo è ciò in cui crede. - Anton Čechov",
      "La bellezza è una promessa di felicità. - Stendhal",
      "Il futuro appartiene a coloro che credono nella bellezza dei propri sogni. - Eleanor Roosevelt",
      "Non si nasce donne: si diventa. - Simone de Beauvoir",
      "La cultura è l’unico bene dell’umanità che, diviso fra tutti, anziché diminuire diventa più grande. - Hans-Georg Gadamer",
      "Se comprendere è impossibile, conoscere è necessario. - Primo Levi",
      "La memoria è necessaria, dobbiamo ricordare. - Primo Levi",
      "Prendete la vita con leggerezza, che leggerezza non è superficialità. - Italo Calvino",
      "L’inferno dei viventi non è qualcosa che sarà; se ce n’è uno, è quello che è già qui. - Italo Calvino",
      "La fantasia è un posto dove ci piove dentro. - Italo Calvino",
      "La realtà non è mai come la si vede: la verità è soprattutto immaginazione. - René Magritte",
      "La vita imita l’arte più di quanto l’arte imiti la vita. - Oscar Wilde",
      "Sii te stesso; tutti gli altri sono già occupati. - Oscar Wilde",
      "Non c’è notte tanto lunga da impedire al sole di risorgere. - Khalil Gibran",
      "Il lavoro è amore reso visibile. - Khalil Gibran",
      "La tenerezza e la gentilezza non sono sintomi di debolezza, ma manifestazioni di forza. - Khalil Gibran",
      "Non piangere perché è finita, sorridi perché è accaduto. - Dr. Seuss",
      "L’educazione è l’arma più potente che puoi usare per cambiare il mondo. - Nelson Mandela",
      "Ciò che sappiamo è una goccia, ciò che ignoriamo è un oceano. - Isaac Newton",
      "Se ho visto più lontano, è perché stavo sulle spalle di giganti. - Isaac Newton",
      "Un giorno senza sorriso è un giorno perso. - Charlie Chaplin",
      "La vita è troppo importante per essere presa sul serio. - Oscar Wilde",
      "Dobbiamo coltivare il nostro giardino. - Voltaire",
      "Il sonno della ragione genera mostri. - Francisco Goya",
      "Senza musica, la vita sarebbe un errore. - Friedrich Nietzsche",
      "Ciò che non mi uccide mi rende più forte. - Friedrich Nietzsche",
      "I limiti del mio linguaggio sono i limiti del mio mondo. - Ludwig Wittgenstein",
      "Dove non si può parlare, si deve tacere. - Ludwig Wittgenstein",
      "L’uomo è condannato a essere libero. - Jean-Paul Sartre",
      "Tutto ciò che puoi immaginare è reale. - Pablo Picasso",
      "Ogni bambino è un artista. Il problema è rimanere artisti da adulti. - Pablo Picasso",
      "L’arte lava via dall’anima la polvere della vita quotidiana. - Pablo Picasso",
      "La vita senza ricerca non è degna di essere vissuta. - Socrate",
      "L’importante non è vivere, ma vivere bene. - Socrate",
      "La verità è figlia del tempo. - Francis Bacon",
      "Un uomo che osa sprecare un’ora del suo tempo non ha scoperto il valore della vita. - Charles Darwin",
      "La storia è maestra di vita. - Cicerone",
      "Finché c’è vita c’è speranza. - Cicerone",
      "Il futuro dipende da ciò che facciamo nel presente. - Mahatma Gandhi",
      "La libertà è come l’aria: ci si accorge di quanto vale quando comincia a mancare. - Piero Calamandrei",
      "Se vogliamo che tutto rimanga com’è, bisogna che tutto cambi. - Giuseppe Tomasi di Lampedusa",
      "Chi apre la porta di una scuola chiude una prigione. - Victor Hugo",
      "Le radici dell’educazione sono amare, ma il frutto è dolce. - Aristotele",
      "Dove c’è amore c’è vita. - Mahatma Gandhi",
    ];
    final quotesEn = [
      "Happiness is not having what you want, but wanting what you have. - Oscar Wilde",
      "Success is the sum of small efforts, repeated day in and day out. - Robert Collier",
      "It is never too late to be what you might have been. - George Eliot",
      "Life is what happens to you while you're busy making other plans. - John Lennon",
      "The best way to predict the future is to invent it. - Alan Kay",
      "The real voyage of discovery consists not in seeking new lands but in having new eyes. - Marcel Proust",
      "The only way to do great work is to love what you do. - Steve Jobs",
      "What is essential is invisible to the eye. - Antoine de Saint-Exupéry",
      "Every journey of a thousand miles begins with a single step. - Lao Tzu",
      "Hope is a waking dream. - Aristotle",
      "Patience is bitter, but its fruit is sweet. - Jean-Jacques Rousseau",
      "One must still have chaos in oneself to give birth to a dancing star. - Friedrich Nietzsche",
      "Beauty will save the world. - Fyodor Dostoevsky",
      "I know that I know nothing. - Socrates",
      "Dripping water hollows out stone, not by force but by falling often. - Ovid",
      "Nature does nothing in vain. - Aristotle",
      "Fortune favors the bold. - Virgil",
      "Knowledge is power. - Francis Bacon",
      "No wind is favorable to those who do not know where they are going. - Seneca",
      "Do everything calmly and in good order. - Marcus Aurelius",
      "Simplicity is the ultimate sophistication. - Leonardo da Vinci",
      "The heart has its reasons, of which reason knows nothing. - Blaise Pascal",
      "Time reveals all things. - Tertullian",
      "Become who you are. - Friedrich Nietzsche",
      "He who has a why to live can bear almost any how. - Friedrich Nietzsche",
      "There is nothing permanent except change. - Heraclitus",
      "Everything flows. - Heraclitus",
      "It always seems impossible until it is done. - Nelson Mandela",
      "Moderation is the greatest treasure. - Hesiod",
      "Nothing in life is to be feared, it is only to be understood. - Marie Curie",
      "Imagination is more important than knowledge. - Albert Einstein",
      "No act of kindness, no matter how small, is ever wasted. - Aesop",
      "Well begun is half done. - Aristotle",
      "We are all in the gutter, but some of us are looking at the stars. - Oscar Wilde",
      "It is not because things are difficult that we do not dare, but because we do not dare that they are difficult. - Seneca",
      "People are like bicycles: they can keep their balance only as long as they keep moving. - Albert Einstein",
      "The measure of intelligence is the ability to change. - Albert Einstein",
      "You were not made to live like brutes, but to follow virtue and knowledge. - Dante Alighieri",
      "Love, which excuses no loved one from loving. - Dante Alighieri",
      "Midway upon the journey of our life I found myself within a dark forest. - Dante Alighieri",
      "To be, or not to be, that is the question. - William Shakespeare",
      "We know what we are, but know not what we may be. - William Shakespeare",
      "No one can make you feel inferior without your consent. - Eleanor Roosevelt",
      "We all live under the same sky, but we do not all have the same horizon. - Konrad Adenauer",
      "Love all, trust a few, do wrong to none. - William Shakespeare",
      "Brevity is the soul of wit. - William Shakespeare",
      "It is not things that disturb us, but our judgments about things. - Epictetus",
      "In the middle of every difficulty lies opportunity. - Albert Einstein",
      "No man is free who is not master of himself. - Epictetus",
      "Consistency turns goals into results. - Jim Rohn",
      "The happiness of your life depends upon the quality of your thoughts. - Marcus Aurelius",
      "Our life is what our thoughts make it. - Marcus Aurelius",
      "Time is the most valuable thing a man can spend. - Theophrastus",
      "He who thinks little errs much. - Leonardo da Vinci",
      "Wisdom is the daughter of experience. - Leonardo da Vinci",
      "One sees clearly only with the heart. - Antoine de Saint-Exupéry",
      "All grown-ups were once children. - Antoine de Saint-Exupéry",
      "The stars are lit so that everyone may one day find his own. - Antoine de Saint-Exupéry",
      "Freedom begins with irony. - Victor Hugo",
      "Conscience is the voice of the soul. - Jean-Jacques Rousseau",
      "Man is born free, and everywhere he is in chains. - Jean-Jacques Rousseau",
      "Doubt is the beginning of wisdom. - Descartes",
      "I think, therefore I am. - Descartes",
      "Wonder is the beginning of knowledge. - Plato",
      "Music gives a soul to the universe, wings to the mind, flight to the imagination. - Plato",
      "Man is a social animal. - Aristotle",
      "Happiness depends upon ourselves. - Aristotle",
      "Choose a job you love, and you will never have to work a day in your life. - Confucius",
      "Wherever you go, go with all your heart. - Confucius",
      "It does not matter how slowly you go as long as you do not stop. - Confucius",
      "Study the past if you would define the future. - Confucius",
      "He who knows others is wise; he who knows himself is enlightened. - Laozi",
      "He who is content is rich. - Laozi",
      "Kind words can be short and easy to speak, but their echoes are truly endless. - Mother Teresa",
      "We cannot do great things, only small things with great love. - Mother Teresa",
      "Peace begins with a smile. - Mother Teresa",
      "An eye for an eye makes the whole world blind. - Mahatma Gandhi",
      "Strength does not come from physical capacity, but from an indomitable will. - Mahatma Gandhi",
      "Life is a mystery to be lived, not a problem to be solved. - Søren Kierkegaard",
      "Life can only be understood backwards, but it must be lived forwards. - Søren Kierkegaard",
      "Those who fight may lose; those who do not fight have already lost. - Bertolt Brecht",
      "Where danger grows, that which saves also grows. - Friedrich Hölderlin",
      "Two things fill the mind with awe: the starry sky above me and the moral law within me. - Immanuel Kant",
      "Have the courage to use your own understanding. - Immanuel Kant",
      "Man is what he believes. - Anton Chekhov",
      "Beauty is a promise of happiness. - Stendhal",
      "The future belongs to those who believe in the beauty of their dreams. - Eleanor Roosevelt",
      "One is not born, but rather becomes, a woman. - Simone de Beauvoir",
      "Culture is the only good of humanity that grows greater when shared by all. - Hans-Georg Gadamer",
      "If understanding is impossible, knowing is necessary. - Primo Levi",
      "Memory is necessary; we must remember. - Primo Levi",
      "Take life lightly, for lightness is not superficiality. - Italo Calvino",
      "The hell of the living is not something to come; if there is one, it is already here. - Italo Calvino",
      "Fantasy is a place where it rains inside. - Italo Calvino",
      "Reality is never as we see it: truth is above all imagination. - René Magritte",
      "Life imitates art far more than art imitates life. - Oscar Wilde",
      "Be yourself; everyone else is already taken. - Oscar Wilde",
      "No night is so long that it can prevent the sun from rising again. - Khalil Gibran",
      "Work is love made visible. - Khalil Gibran",
      "Tenderness and kindness are not signs of weakness, but expressions of strength. - Khalil Gibran",
      "Don’t cry because it’s over, smile because it happened. - Dr. Seuss",
      "Education is the most powerful weapon you can use to change the world. - Nelson Mandela",
      "What we know is a drop; what we do not know is an ocean. - Isaac Newton",
      "If I have seen further, it is by standing on the shoulders of giants. - Isaac Newton",
      "A day without laughter is a day wasted. - Charlie Chaplin",
      "Life is too important to be taken seriously. - Oscar Wilde",
      "We must cultivate our garden. - Voltaire",
      "The sleep of reason produces monsters. - Francisco Goya",
      "Without music, life would be a mistake. - Friedrich Nietzsche",
      "What does not kill me makes me stronger. - Friedrich Nietzsche",
      "The limits of my language are the limits of my world. - Ludwig Wittgenstein",
      "Whereof one cannot speak, thereof one must be silent. - Ludwig Wittgenstein",
      "Man is condemned to be free. - Jean-Paul Sartre",
      "Everything you can imagine is real. - Pablo Picasso",
      "Every child is an artist. The problem is staying an artist when you grow up. - Pablo Picasso",
      "Art washes away from the soul the dust of everyday life. - Pablo Picasso",
      "The unexamined life is not worth living. - Socrates",
      "The important thing is not to live, but to live well. - Socrates",
      "Truth is the daughter of time. - Francis Bacon",
      "A man who dares to waste one hour of time has not discovered the value of life. - Charles Darwin",
      "History is the teacher of life. - Cicero",
      "While there is life, there is hope. - Cicero",
      "The future depends on what we do in the present. - Mahatma Gandhi",
      "Freedom is like air: you realize its value when it begins to run out. - Piero Calamandrei",
      "If we want everything to stay as it is, everything must change. - Giuseppe Tomasi di Lampedusa",
      "He who opens a school door closes a prison. - Victor Hugo",
      "The roots of education are bitter, but the fruit is sweet. - Aristotle",
      "Where there is love, there is life. - Mahatma Gandhi",
    ];
    final quotesFr = [
      "Le bonheur n'est pas d'avoir ce que l'on veut, mais de vouloir ce que l'on a. - Oscar Wilde",
      "Le succès est la somme de petits efforts, répétés jour après jour. - Robert Collier",
      "Il n'est jamais trop tard pour être ce que vous auriez pu être. - George Eliot",
      "La vie, c'est ce qui arrive quand on a d'autres projets. - John Lennon",
      "La meilleure façon de prédire l'avenir est de l'inventer. - Alan Kay",
      "Le véritable voyage de découverte ne consiste pas à chercher de nouveaux paysages, mais à avoir de nouveaux yeux. - Marcel Proust",
      "La seule façon de faire du bon travail est d'aimer ce que vous faites. - Steve Jobs",
      "L’essentiel est invisible pour les yeux. - Antoine de Saint-Exupéry",
      "Un voyage de mille lieues commence par un seul pas. - Lao Tseu",
      "L'espérance est un rêve éveillé. - Aristote",
      "La patience est amère, mais son fruit est doux. - Jean-Jacques Rousseau",
      "Il faut encore porter du chaos en soi pour pouvoir enfanter une étoile dansante. - Friedrich Nietzsche",
      "La beauté sauvera le monde. - Fiodor Dostoïevski",
      "Je sais que je ne sais rien. - Socrate",
      "La goutte creuse la pierre, non par la force, mais en tombant souvent. - Ovide",
      "La nature ne fait rien en vain. - Aristote",
      "La fortune sourit aux audacieux. - Virgile",
      "Le savoir est un pouvoir. - Francis Bacon",
      "Aucun vent n'est favorable à qui ne sait pas où il va. - Sénèque",
      "Fais chaque chose avec calme et ordre. - Marc Aurèle",
      "La simplicité est la sophistication suprême. - Léonard de Vinci",
      "Le cœur a ses raisons que la raison ne connaît point. - Blaise Pascal",
      "Le temps révèle toute chose. - Tertullien",
      "Deviens ce que tu es. - Friedrich Nietzsche",
      "Celui qui a un pourquoi pour vivre peut supporter presque tous les comment. - Friedrich Nietzsche",
      "Rien n’est permanent, sauf le changement. - Héraclite",
      "Tout s’écoule. - Héraclite",
      "Cela semble toujours impossible jusqu’à ce que ce soit fait. - Nelson Mandela",
      "La modération est le plus grand trésor. - Hésiode",
      "Dans la vie, rien n’est à craindre, tout est à comprendre. - Marie Curie",
      "L’imagination est plus importante que la connaissance. - Albert Einstein",
      "Aucun acte de gentillesse, aussi petit soit-il, n'est jamais perdu. - Ésope",
      "Bien commencé est à moitié fait. - Aristote",
      "Nous sommes tous dans le caniveau, mais certains d'entre nous regardent les étoiles. - Oscar Wilde",
      "Ce n'est pas parce que les choses sont difficiles que nous n'osons pas, mais parce que nous n'osons pas qu'elles sont difficiles. - Sénèque",
      "Les personnes sont comme des bicyclettes: elles gardent l'équilibre seulement si elles continuent d'avancer. - Albert Einstein",
      "La mesure de l’intelligence est la capacité de changer. - Albert Einstein",
      "Vous n’êtes pas faits pour vivre comme des brutes, mais pour suivre vertu et connaissance. - Dante Alighieri",
      "Amour, qui n’exempte aucun aimé d’aimer en retour. - Dante Alighieri",
      "Au milieu du chemin de notre vie, je me retrouvai dans une forêt obscure. - Dante Alighieri",
      "Être ou ne pas être, telle est la question. - William Shakespeare",
      "Nous savons ce que nous sommes, mais non ce que nous pourrions être. - William Shakespeare",
      "Personne ne peut vous faire sentir inférieur sans votre consentement. - Eleanor Roosevelt",
      "Nous vivons tous sous le même ciel, mais nous n'avons pas tous le même horizon. - Konrad Adenauer",
      "Aime tous, crois-en peu, ne fais de tort à personne. - William Shakespeare",
      "La brièveté est l’âme de l’esprit. - William Shakespeare",
      "Ce ne sont pas les choses qui nous troublent, mais les jugements que nous portons sur elles. - Épictète",
      "Au milieu de toute difficulté se trouve une occasion. - Albert Einstein",
      "Aucun homme n’est libre s’il n’est maître de lui-même. - Épictète",
      "La constance transforme les objectifs en résultats. - Jim Rohn",
      "Le bonheur de ta vie dépend de la qualité de tes pensées. - Marc Aurèle",
      "Notre vie est ce que nos pensées en font. - Marc Aurèle",
      "Le temps est la chose la plus précieuse qu’un homme puisse dépenser. - Théophraste",
      "Qui pense peu se trompe beaucoup. - Léonard de Vinci",
      "La sagesse est fille de l’expérience. - Léonard de Vinci",
      "On ne voit bien qu’avec le cœur. - Antoine de Saint-Exupéry",
      "Toutes les grandes personnes ont d’abord été des enfants. - Antoine de Saint-Exupéry",
      "Les étoiles sont éclairées pour que chacun puisse un jour retrouver la sienne. - Antoine de Saint-Exupéry",
      "La liberté commence par l’ironie. - Victor Hugo",
      "La conscience est la voix de l’âme. - Jean-Jacques Rousseau",
      "L’homme est né libre, et partout il est dans les fers. - Jean-Jacques Rousseau",
      "Le doute est le commencement de la sagesse. - Descartes",
      "Je pense, donc je suis. - Descartes",
      "L’émerveillement est le commencement de la connaissance. - Platon",
      "La musique donne une âme à l’univers, des ailes à l’esprit, un élan à l’imagination. - Platon",
      "L’homme est un animal social. - Aristote",
      "Le bonheur dépend de nous-mêmes. - Aristote",
      "Choisis un travail que tu aimes et tu n’auras pas à travailler un seul jour de ta vie. - Confucius",
      "Où que tu ailles, vas-y de tout ton cœur. - Confucius",
      "Peu importe la lenteur avec laquelle tu avances, pourvu que tu ne t’arrêtes pas. - Confucius",
      "Étudie le passé si tu veux prévoir l’avenir. - Confucius",
      "Qui connaît les autres est sage; qui se connaît soi-même est éclairé. - Laozi",
      "Celui qui sait se contenter est riche. - Laozi",
      "Les mots gentils peuvent être courts et faciles à dire, mais leur écho est éternel. - Mère Teresa",
      "Nous ne pouvons pas faire de grandes choses, seulement de petites choses avec un grand amour. - Mère Teresa",
      "La paix commence par un sourire. - Mère Teresa",
      "Œil pour œil rend le monde aveugle. - Mahatma Gandhi",
      "La force ne vient pas de la capacité physique, mais d’une volonté indomptable. - Mahatma Gandhi",
      "La vie est un mystère à vivre, non un problème à résoudre. - Søren Kierkegaard",
      "La vie ne peut être comprise qu’en regardant en arrière, mais elle doit être vécue en avant. - Søren Kierkegaard",
      "Qui lutte peut perdre; qui ne lutte pas a déjà perdu. - Bertolt Brecht",
      "Là où croît le péril croît aussi ce qui sauve. - Friedrich Hölderlin",
      "Deux choses remplissent l’âme d’admiration: le ciel étoilé au-dessus de moi et la loi morale en moi. - Immanuel Kant",
      "Aie le courage de te servir de ta propre intelligence. - Immanuel Kant",
      "L’homme est ce en quoi il croit. - Anton Tchekhov",
      "La beauté est une promesse de bonheur. - Stendhal",
      "L’avenir appartient à ceux qui croient à la beauté de leurs rêves. - Eleanor Roosevelt",
      "On ne naît pas femme: on le devient. - Simone de Beauvoir",
      "La culture est le seul bien de l’humanité qui grandit quand il est partagé entre tous. - Hans-Georg Gadamer",
      "Si comprendre est impossible, connaître est nécessaire. - Primo Levi",
      "La mémoire est nécessaire, nous devons nous souvenir. - Primo Levi",
      "Prenez la vie avec légèreté, car la légèreté n’est pas superficialité. - Italo Calvino",
      "L’enfer des vivants n’est pas quelque chose qui sera; s’il y en a un, il est déjà ici. - Italo Calvino",
      "La fantaisie est un endroit où il pleut dedans. - Italo Calvino",
      "La réalité n’est jamais telle qu’on la voit: la vérité est surtout imagination. - René Magritte",
      "La vie imite l’art bien plus que l’art n’imite la vie. - Oscar Wilde",
      "Sois toi-même; tous les autres sont déjà pris. - Oscar Wilde",
      "Aucune nuit n’est assez longue pour empêcher le soleil de se lever à nouveau. - Khalil Gibran",
      "Le travail est l’amour rendu visible. - Khalil Gibran",
      "La tendresse et la gentillesse ne sont pas des signes de faiblesse, mais des manifestations de force. - Khalil Gibran",
      "Ne pleure pas parce que c’est fini, souris parce que c’est arrivé. - Dr. Seuss",
      "L’éducation est l’arme la plus puissante que tu puisses utiliser pour changer le monde. - Nelson Mandela",
      "Ce que nous savons est une goutte; ce que nous ignorons est un océan. - Isaac Newton",
      "Si j’ai vu plus loin, c’est en me tenant sur les épaules de géants. - Isaac Newton",
      "Une journée sans rire est une journée perdue. - Charlie Chaplin",
      "La vie est trop importante pour être prise au sérieux. - Oscar Wilde",
      "Il faut cultiver notre jardin. - Voltaire",
      "Le sommeil de la raison engendre des monstres. - Francisco Goya",
      "Sans musique, la vie serait une erreur. - Friedrich Nietzsche",
      "Ce qui ne me tue pas me rend plus fort. - Friedrich Nietzsche",
      "Les limites de mon langage sont les limites de mon monde. - Ludwig Wittgenstein",
      "Ce dont on ne peut parler, il faut le taire. - Ludwig Wittgenstein",
      "L’homme est condamné à être libre. - Jean-Paul Sartre",
      "Tout ce que tu peux imaginer est réel. - Pablo Picasso",
      "Chaque enfant est un artiste. Le problème est de rester artiste en grandissant. - Pablo Picasso",
      "L’art lave l’âme de la poussière de la vie quotidienne. - Pablo Picasso",
      "Une vie sans examen ne vaut pas la peine d’être vécue. - Socrate",
      "L’important n’est pas de vivre, mais de bien vivre. - Socrate",
      "La vérité est fille du temps. - Francis Bacon",
      "Un homme qui ose perdre une heure de son temps n’a pas découvert la valeur de la vie. - Charles Darwin",
      "L’histoire est maîtresse de vie. - Cicéron",
      "Tant qu’il y a de la vie, il y a de l’espoir. - Cicéron",
      "L’avenir dépend de ce que nous faisons dans le présent. - Mahatma Gandhi",
      "La liberté est comme l’air: on se rend compte de sa valeur quand elle commence à manquer. - Piero Calamandrei",
      "Si nous voulons que tout reste tel quel, il faut que tout change. - Giuseppe Tomasi di Lampedusa",
      "Celui qui ouvre une porte d’école ferme une prison. - Victor Hugo",
      "Les racines de l’éducation sont amères, mais le fruit est doux. - Aristote",
      "Là où il y a de l’amour, il y a de la vie. - Mahatma Gandhi",
    ];
    final quotesEs = [
      "La felicidad no es tener lo que quieres, sino querer lo que tienes. - Oscar Wilde",
      "El éxito es la suma de pequeños esfuerzos, repetidos día tras día. - Robert Collier",
      "Nunca es demasiado tarde para ser lo que podrías haber sido. - George Eliot",
      "La vida es lo que te pasa mientras estás ocupado haciendo otros planes. - John Lennon",
      "La mejor forma de predecir el futuro es inventarlo. - Alan Kay",
      "El verdadero viaje de descubrimiento no consiste en buscar nuevas tierras, sino en mirar con nuevos ojos. - Marcel Proust",
      "La única forma de hacer un gran trabajo es amar lo que haces. - Steve Jobs",
      "Lo esencial es invisible a los ojos. - Antoine de Saint-Exupéry",
      "Un viaje de mil millas comienza con un solo paso. - Lao Tse",
      "La esperanza es un sueño despierto. - Aristóteles",
      "La paciencia es amarga, pero su fruto es dulce. - Jean-Jacques Rousseau",
      "Hay que llevar todavía caos dentro de sí para poder dar a luz una estrella danzante. - Friedrich Nietzsche",
      "La belleza salvará al mundo. - Fiódor Dostoyevski",
      "Solo sé que no sé nada. - Sócrates",
      "La gota horada la piedra, no por la fuerza, sino por caer a menudo. - Ovidio",
      "La naturaleza no hace nada en vano. - Aristóteles",
      "La fortuna favorece a los audaces. - Virgilio",
      "El conocimiento es poder. - Francis Bacon",
      "Ningún viento es favorable para quien no sabe adónde va. - Séneca",
      "Haz cada cosa con calma y orden. - Marco Aurelio",
      "La sencillez es la máxima sofisticación. - Leonardo da Vinci",
      "El corazón tiene razones que la razón no entiende. - Blaise Pascal",
      "El tiempo revela todas las cosas. - Tertuliano",
      "Llega a ser quien eres. - Friedrich Nietzsche",
      "Quien tiene un porqué para vivir puede soportar casi cualquier cómo. - Friedrich Nietzsche",
      "Nada es permanente excepto el cambio. - Heráclito",
      "Todo fluye. - Heráclito",
      "Siempre parece imposible hasta que se hace. - Nelson Mandela",
      "La moderación es el mayor tesoro. - Hesíodo",
      "En la vida no hay nada que temer, solo que comprender. - Marie Curie",
      "La imaginación es más importante que el conocimiento. - Albert Einstein",
      "Ningún acto de bondad, por pequeño que sea, se desperdicia jamás. - Esopo",
      "Bien empezado es medio hecho. - Aristóteles",
      "Todos estamos en la cuneta, pero algunos miramos las estrellas. - Oscar Wilde",
      "No es porque las cosas sean difíciles que no nos atrevemos, sino porque no nos atrevemos que son difíciles. - Séneca",
      "Las personas son como las bicicletas: solo mantienen el equilibrio si siguen moviéndose. - Albert Einstein",
      "La medida de la inteligencia es la capacidad de cambiar. - Albert Einstein",
      "No fuisteis hechos para vivir como brutos, sino para seguir virtud y conocimiento. - Dante Alighieri",
      "Amor, que a ningún amado perdona amar. - Dante Alighieri",
      "A mitad del camino de nuestra vida me encontré en una selva oscura. - Dante Alighieri",
      "Ser o no ser, esa es la cuestión. - William Shakespeare",
      "Sabemos lo que somos, pero no lo que podríamos ser. - William Shakespeare",
      "Nadie puede hacerte sentir inferior sin tu consentimiento. - Eleanor Roosevelt",
      "Todos vivimos bajo el mismo cielo, pero no todos tenemos el mismo horizonte. - Konrad Adenauer",
      "Ama a todos, confía en pocos y no hagas daño a nadie. - William Shakespeare",
      "La brevedad es el alma del ingenio. - William Shakespeare",
      "No son las cosas las que nos perturban, sino los juicios que hacemos sobre ellas. - Epicteto",
      "En medio de toda dificultad se encuentra una oportunidad. - Albert Einstein",
      "Ningún hombre es libre si no es dueño de sí mismo. - Epicteto",
      "La constancia transforma las metas en resultados. - Jim Rohn",
      "La felicidad de tu vida depende de la calidad de tus pensamientos. - Marco Aurelio",
      "Nuestra vida es lo que nuestros pensamientos hacen de ella. - Marco Aurelio",
      "El tiempo es lo más valioso que un hombre puede gastar. - Teofrasto",
      "Quien piensa poco, yerra mucho. - Leonardo da Vinci",
      "La sabiduría es hija de la experiencia. - Leonardo da Vinci",
      "Solo se ve bien con el corazón. - Antoine de Saint-Exupéry",
      "Todos los mayores fueron niños alguna vez. - Antoine de Saint-Exupéry",
      "Las estrellas están iluminadas para que cada uno pueda encontrar algún día la suya. - Antoine de Saint-Exupéry",
      "La libertad comienza con la ironía. - Victor Hugo",
      "La conciencia es la voz del alma. - Jean-Jacques Rousseau",
      "El hombre nace libre, pero en todas partes está encadenado. - Jean-Jacques Rousseau",
      "La duda es el comienzo de la sabiduría. - Descartes",
      "Pienso, luego existo. - Descartes",
      "El asombro es el principio del conocimiento. - Platón",
      "La música da alma al universo, alas al pensamiento y vuelo a la imaginación. - Platón",
      "El hombre es un animal social. - Aristóteles",
      "La felicidad depende de nosotros mismos. - Aristóteles",
      "Elige un trabajo que ames y no tendrás que trabajar ni un día de tu vida. - Confucio",
      "Dondequiera que vayas, ve con todo tu corazón. - Confucio",
      "No importa lo despacio que vayas, siempre que no te detengas. - Confucio",
      "Estudia el pasado si quieres prever el futuro. - Confucio",
      "Quien conoce a los demás es sabio; quien se conoce a sí mismo está iluminado. - Laozi",
      "Quien sabe contentarse es rico. - Laozi",
      "Las palabras amables pueden ser breves y fáciles de decir, pero su eco es eterno. - Madre Teresa",
      "No podemos hacer grandes cosas, solo pequeñas cosas con gran amor. - Madre Teresa",
      "La paz comienza con una sonrisa. - Madre Teresa",
      "Ojo por ojo deja ciego al mundo entero. - Mahatma Gandhi",
      "La fuerza no proviene de la capacidad física, sino de una voluntad indomable. - Mahatma Gandhi",
      "La vida es un misterio que vivir, no un problema que resolver. - Søren Kierkegaard",
      "La vida solo puede entenderse hacia atrás, pero debe vivirse hacia adelante. - Søren Kierkegaard",
      "Quien lucha puede perder; quien no lucha ya ha perdido. - Bertolt Brecht",
      "Donde crece el peligro, crece también lo que salva. - Friedrich Hölderlin",
      "Dos cosas llenan el ánimo de admiración: el cielo estrellado sobre mí y la ley moral en mí. - Immanuel Kant",
      "Ten el valor de servirte de tu propia inteligencia. - Immanuel Kant",
      "El hombre es aquello en lo que cree. - Antón Chéjov",
      "La belleza es una promesa de felicidad. - Stendhal",
      "El futuro pertenece a quienes creen en la belleza de sus sueños. - Eleanor Roosevelt",
      "No se nace mujer: se llega a serlo. - Simone de Beauvoir",
      "La cultura es el único bien de la humanidad que crece cuando se comparte entre todos. - Hans-Georg Gadamer",
      "Si comprender es imposible, conocer es necesario. - Primo Levi",
      "La memoria es necesaria, debemos recordar. - Primo Levi",
      "Tomaos la vida con ligereza, porque ligereza no es superficialidad. - Italo Calvino",
      "El infierno de los vivos no es algo que será; si existe uno, es el que ya está aquí. - Italo Calvino",
      "La fantasía es un lugar donde llueve dentro. - Italo Calvino",
      "La realidad nunca es como se la ve: la verdad es ante todo imaginación. - René Magritte",
      "La vida imita al arte mucho más de lo que el arte imita a la vida. - Oscar Wilde",
      "Sé tú mismo; todos los demás ya están ocupados. - Oscar Wilde",
      "No hay noche tan larga que impida al sol volver a salir. - Khalil Gibran",
      "El trabajo es amor hecho visible. - Khalil Gibran",
      "La ternura y la gentileza no son signos de debilidad, sino manifestaciones de fuerza. - Khalil Gibran",
      "No llores porque terminó, sonríe porque sucedió. - Dr. Seuss",
      "La educación es el arma más poderosa que puedes usar para cambiar el mundo. - Nelson Mandela",
      "Lo que sabemos es una gota; lo que ignoramos es un océano. - Isaac Newton",
      "Si he visto más lejos, es porque estaba sobre hombros de gigantes. - Isaac Newton",
      "Un día sin risa es un día perdido. - Charlie Chaplin",
      "La vida es demasiado importante para tomársela en serio. - Oscar Wilde",
      "Debemos cultivar nuestro jardín. - Voltaire",
      "El sueño de la razón produce monstruos. - Francisco Goya",
      "Sin música, la vida sería un error. - Friedrich Nietzsche",
      "Lo que no me mata me hace más fuerte. - Friedrich Nietzsche",
      "Los límites de mi lenguaje son los límites de mi mundo. - Ludwig Wittgenstein",
      "De lo que no se puede hablar, hay que callar. - Ludwig Wittgenstein",
      "El hombre está condenado a ser libre. - Jean-Paul Sartre",
      "Todo lo que puedes imaginar es real. - Pablo Picasso",
      "Todo niño es un artista. El problema es seguir siendo artista al crecer. - Pablo Picasso",
      "El arte lava del alma el polvo de la vida cotidiana. - Pablo Picasso",
      "Una vida sin examen no merece ser vivida. - Sócrates",
      "Lo importante no es vivir, sino vivir bien. - Sócrates",
      "La verdad es hija del tiempo. - Francis Bacon",
      "Un hombre que se atreve a perder una hora de su tiempo no ha descubierto el valor de la vida. - Charles Darwin",
      "La historia es maestra de vida. - Cicerón",
      "Mientras hay vida, hay esperanza. - Cicerón",
      "El futuro depende de lo que hacemos en el presente. - Mahatma Gandhi",
      "La libertad es como el aire: uno se da cuenta de cuánto vale cuando empieza a faltar. - Piero Calamandrei",
      "Si queremos que todo siga como está, es necesario que todo cambie. - Giuseppe Tomasi di Lampedusa",
      "Quien abre la puerta de una escuela cierra una prisión. - Victor Hugo",
      "Las raíces de la educación son amargas, pero el fruto es dulce. - Aristóteles",
      "Donde hay amor, hay vida. - Mahatma Gandhi",
    ];
    final quotesPt = [
      "A felicidade não é ter o que se deseja, mas desejar o que se tem. - Oscar Wilde",
      "O sucesso é a soma de pequenos esforços repetidos dia após dia. - Robert Collier",
      "Nunca é tarde demais para ser o que poderias ter sido. - George Eliot",
      "A vida é o que acontece enquanto estás ocupado a fazer outros planos. - John Lennon",
      "A melhor forma de prever o futuro é inventá-lo. - Alan Kay",
      "A verdadeira viagem de descoberta não consiste em procurar novas terras, mas em ter novos olhos. - Marcel Proust",
      "A única forma de fazer um grande trabalho é amar o que fazes. - Steve Jobs",
      "O essencial é invisível aos olhos. - Antoine de Saint-Exupéry",
      "Uma viagem de mil milhas começa com um único passo. - Lao Tzu",
      "A esperança é um sonho acordado. - Aristóteles",
      "A paciência é amarga, mas o seu fruto é doce. - Jean-Jacques Rousseau",
      "É preciso ainda ter caos dentro de si para dar à luz uma estrela dançante. - Friedrich Nietzsche",
      "A beleza salvará o mundo. - Fiódor Dostoiévski",
      "Só sei que nada sei. - Sócrates",
      "A gota escava a pedra, não pela força, mas por cair muitas vezes. - Ovídio",
      "A natureza nada faz em vão. - Aristóteles",
      "A sorte favorece os audazes. - Virgílio",
      "Conhecimento é poder. - Francis Bacon",
      "Nenhum vento é favorável para quem não sabe para onde vai. - Séneca",
      "Faz cada coisa com calma e ordem. - Marco Aurélio",
      "A simplicidade é a maior sofisticação. - Leonardo da Vinci",
      "O coração tem razões que a razão desconhece. - Blaise Pascal",
      "O tempo revela todas as coisas. - Tertuliano",
      "Torna-te quem és. - Friedrich Nietzsche",
      "Quem tem um porquê para viver pode suportar quase qualquer como. - Friedrich Nietzsche",
      "Nada é permanente, exceto a mudança. - Heráclito",
      "Tudo flui. - Heráclito",
      "Parece sempre impossível até ser feito. - Nelson Mandela",
      "A moderação é o maior tesouro. - Hesíodo",
      "Na vida, nada deve ser temido, apenas compreendido. - Marie Curie",
      "A imaginação é mais importante do que o conhecimento. - Albert Einstein",
      "Nenhum ato de bondade, por menor que seja, é desperdiçado. - Esopo",
      "Começar bem é ter metade do caminho feito. - Aristóteles",
      "Estamos todos na sarjeta, mas alguns de nós olham para as estrelas. - Oscar Wilde",
      "Não é porque as coisas são difíceis que não ousamos, mas porque não ousamos que elas são difíceis. - Sêneca",
      "As pessoas são como as bicicletas: só mantêm o equilíbrio se continuarem em movimento. - Albert Einstein",
      "A medida da inteligência é a capacidade de mudar. - Albert Einstein",
      "Não fostes feitos para viver como brutos, mas para seguir virtude e conhecimento. - Dante Alighieri",
      "Amor, que a nenhum amado perdoa amar. - Dante Alighieri",
      "No meio do caminho da nossa vida, encontrei-me numa selva escura. - Dante Alighieri",
      "Ser ou não ser, eis a questão. - William Shakespeare",
      "Sabemos o que somos, mas não o que poderemos ser. - William Shakespeare",
      "Ninguém pode fazer-te sentir inferior sem o teu consentimento. - Eleanor Roosevelt",
      "Vivemos todos debaixo do mesmo céu, mas nem todos temos o mesmo horizonte. - Konrad Adenauer",
      "Ama todos, confia em poucos e não faças mal a ninguém. - William Shakespeare",
      "A brevidade é a alma do engenho. - William Shakespeare",
      "Não são as coisas que nos perturbam, mas os juízos que fazemos sobre elas. - Epicteto",
      "No meio de cada dificuldade encontra-se uma oportunidade. - Albert Einstein",
      "Nenhum homem é livre se não é senhor de si mesmo. - Epicteto",
      "A constância transforma objetivos em resultados. - Jim Rohn",
      "A felicidade da tua vida depende da qualidade dos teus pensamentos. - Marco Aurélio",
      "A nossa vida é aquilo que os nossos pensamentos fazem dela. - Marco Aurélio",
      "O tempo é a coisa mais preciosa que um homem pode gastar. - Teofrasto",
      "Quem pensa pouco erra muito. - Leonardo da Vinci",
      "A sabedoria é filha da experiência. - Leonardo da Vinci",
      "Só se vê bem com o coração. - Antoine de Saint-Exupéry",
      "Todos os adultos foram crianças um dia. - Antoine de Saint-Exupéry",
      "As estrelas são iluminadas para que cada um possa um dia encontrar a sua. - Antoine de Saint-Exupéry",
      "A liberdade começa pela ironia. - Victor Hugo",
      "A consciência é a voz da alma. - Jean-Jacques Rousseau",
      "O homem nasce livre, mas por toda parte está acorrentado. - Jean-Jacques Rousseau",
      "A dúvida é o começo da sabedoria. - Descartes",
      "Penso, logo existo. - Descartes",
      "O espanto é o princípio do conhecimento. - Platão",
      "A música dá alma ao universo, asas ao pensamento e impulso à imaginação. - Platão",
      "O homem é um animal social. - Aristóteles",
      "A felicidade depende de nós mesmos. - Aristóteles",
      "Escolhe um trabalho que ames e não terás de trabalhar um único dia da tua vida. - Confúcio",
      "Para onde quer que vás, vai com todo o coração. - Confúcio",
      "Não importa quão devagar vás, desde que não pares. - Confúcio",
      "Estuda o passado se quiseres prever o futuro. - Confúcio",
      "Quem conhece os outros é sábio; quem se conhece a si mesmo é iluminado. - Laozi",
      "Quem sabe contentar-se é rico. - Laozi",
      "As palavras gentis podem ser breves e fáceis de dizer, mas o seu eco é eterno. - Madre Teresa",
      "Não podemos fazer grandes coisas, apenas pequenas coisas com grande amor. - Madre Teresa",
      "A paz começa com um sorriso. - Madre Teresa",
      "Olho por olho deixa o mundo inteiro cego. - Mahatma Gandhi",
      "A força não vem da capacidade física, mas de uma vontade indomável. - Mahatma Gandhi",
      "A vida é um mistério a viver, não um problema a resolver. - Søren Kierkegaard",
      "A vida só pode ser compreendida olhando para trás, mas deve ser vivida para a frente. - Søren Kierkegaard",
      "Quem luta pode perder; quem não luta já perdeu. - Bertolt Brecht",
      "Onde cresce o perigo, cresce também aquilo que salva. - Friedrich Hölderlin",
      "Duas coisas enchem a alma de admiração: o céu estrelado acima de mim e a lei moral dentro de mim. - Immanuel Kant",
      "Tem a coragem de te servires da tua própria inteligência. - Immanuel Kant",
      "O homem é aquilo em que acredita. - Anton Tchékhov",
      "A beleza é uma promessa de felicidade. - Stendhal",
      "O futuro pertence àqueles que acreditam na beleza dos seus sonhos. - Eleanor Roosevelt",
      "Não se nasce mulher: torna-se mulher. - Simone de Beauvoir",
      "A cultura é o único bem da humanidade que cresce quando é partilhado por todos. - Hans-Georg Gadamer",
      "Se compreender é impossível, conhecer é necessário. - Primo Levi",
      "A memória é necessária; devemos recordar. - Primo Levi",
      "Levemos a vida com leveza, pois leveza não é superficialidade. - Italo Calvino",
      "O inferno dos vivos não é algo que será; se há um, é o que já está aqui. - Italo Calvino",
      "A fantasia é um lugar onde chove por dentro. - Italo Calvino",
      "A realidade nunca é como a vemos: a verdade é sobretudo imaginação. - René Magritte",
      "A vida imita a arte muito mais do que a arte imita a vida. - Oscar Wilde",
      "Sê tu mesmo; todos os outros já estão ocupados. - Oscar Wilde",
      "Não há noite tão longa que impeça o sol de voltar a nascer. - Khalil Gibran",
      "O trabalho é amor tornado visível. - Khalil Gibran",
      "A ternura e a gentileza não são sinais de fraqueza, mas manifestações de força. - Khalil Gibran",
      "Não chores porque acabou, sorri porque aconteceu. - Dr. Seuss",
      "A educação é a arma mais poderosa que podes usar para mudar o mundo. - Nelson Mandela",
      "O que sabemos é uma gota; o que ignoramos é um oceano. - Isaac Newton",
      "Se vi mais longe, foi por estar sobre ombros de gigantes. - Isaac Newton",
      "Um dia sem riso é um dia perdido. - Charlie Chaplin",
      "A vida é demasiado importante para ser levada a sério. - Oscar Wilde",
      "Devemos cultivar o nosso jardim. - Voltaire",
      "O sono da razão produz monstros. - Francisco Goya",
      "Sem música, a vida seria um erro. - Friedrich Nietzsche",
      "O que não me mata torna-me mais forte. - Friedrich Nietzsche",
      "Os limites da minha linguagem são os limites do meu mundo. - Ludwig Wittgenstein",
      "Daquilo de que não se pode falar, deve-se calar. - Ludwig Wittgenstein",
      "O homem está condenado a ser livre. - Jean-Paul Sartre",
      "Tudo o que podes imaginar é real. - Pablo Picasso",
      "Toda criança é artista. O problema é continuar artista ao crescer. - Pablo Picasso",
      "A arte lava da alma a poeira da vida quotidiana. - Pablo Picasso",
      "Uma vida sem reflexão não merece ser vivida. - Sócrates",
      "O importante não é viver, mas viver bem. - Sócrates",
      "A verdade é filha do tempo. - Francis Bacon",
      "Um homem que se atreve a desperdiçar uma hora do seu tempo não descobriu o valor da vida. - Charles Darwin",
      "A história é mestra da vida. - Cícero",
      "Enquanto há vida, há esperança. - Cícero",
      "O futuro depende do que fazemos no presente. - Mahatma Gandhi",
      "A liberdade é como o ar: percebemos o seu valor quando começa a faltar. - Piero Calamandrei",
      "Se queremos que tudo fique como está, é preciso que tudo mude. - Giuseppe Tomasi di Lampedusa",
      "Quem abre a porta de uma escola fecha uma prisão. - Victor Hugo",
      "As raízes da educação são amargas, mas o fruto é doce. - Aristóteles",
      "Onde há amor, há vida. - Mahatma Gandhi",
    ];

    final quotesCs = [
      "Štěstí nespočívá v tom mít, co chceme, ale chtít to, co máme. - Oscar Wilde",
      "Úspěch je součet malých úsilí opakovaných den za dnem. - Robert Collier",
      "Nikdy není pozdě stát se tím, kým jsme mohli být. - George Eliot",
      "Život je to, co se děje, když jsme zaneprázdněni jinými plány. - John Lennon",
      "Nejlepší způsob, jak předpovědět budoucnost, je vytvořit ji. - Alan Kay",
      "Skutečná cesta objevování nespočívá v hledání nových zemí, ale v pohledu novýma očima. - Marcel Proust",
      "Jediný způsob, jak dělat skvělou práci, je milovat to, co děláš. - Steve Jobs",
      "To podstatné je očím neviditelné. - Antoine de Saint-Exupéry",
      "Cesta dlouhá tisíc mil začíná jediným krokem. - Lao-c'",
      "Naděje je bdělý sen. - Aristotelés",
      "Trpělivost je hořká, ale její plody jsou sladké. - Jean-Jacques Rousseau",
      "Je třeba mít v sobě ještě chaos, aby člověk mohl zrodit tančící hvězdu. - Friedrich Nietzsche",
      "Krása spasí svět. - Fjodor Dostojevskij",
      "Vím, že nic nevím. - Sókratés",
      "Kapka vyhloubí kámen ne silou, ale tím, že často dopadá. - Ovidius",
      "Příroda nedělá nic zbytečně. - Aristotelés",
      "Štěstí přeje odvážným. - Vergilius",
      "Vědění je moc. - Francis Bacon",
      "Žádný vítr není příznivý tomu, kdo neví, kam míří. - Seneca",
      "Dělej každou věc klidně a v pořádku. - Marcus Aurelius",
      "Jednoduchost je nejvyšší vytříbenost. - Leonardo da Vinci",
      "Srdce má své důvody, které rozum nezná. - Blaise Pascal",
      "Čas odhalí všechny věci. - Tertullianus",
      "Staň se tím, kým jsi. - Friedrich Nietzsche",
      "Kdo má proč žít, snese téměř každé jak. - Friedrich Nietzsche",
      "Nic není trvalé kromě změny. - Hérakleitos",
      "Vše plyne. - Hérakleitos",
      "Vždycky se to zdá nemožné, dokud se to neudělá. - Nelson Mandela",
      "Umírněnost je největší poklad. - Hésiodos",
      "V životě se není čeho bát, je třeba jen rozumět. - Marie Curie",
      "Představivost je důležitější než vědění. - Albert Einstein",
      "Žádný projev laskavosti, jakkoli malý, nikdy není zbytečný. - Ezop",
      "Dobře začít znamená mít polovinu hotovo. - Aristotelés",
      "Všichni jsme ve stokách, ale někteří z nás hledí ke hvězdám. - Oscar Wilde",
      "Není to tím, že věci jsou těžké, že se neodvažujeme, ale jsou těžké proto, že se neodvažujeme. - Seneca",
      "Lidé jsou jako jízdní kola: rovnováhu si udrží jen tehdy, když se dál pohybují. - Albert Einstein",
      "Mírou inteligence je schopnost změny. - Albert Einstein",
      "Nebyli jste stvořeni, abyste žili jako zvířata, ale abyste následovali ctnost a poznání. - Dante Alighieri",
      "Láska, která žádnému milovanému neodpustí milovat. - Dante Alighieri",
      "Uprostřed cesty našeho života jsem se ocitl v temném lese. - Dante Alighieri",
      "Být, či nebýt, to je oč tu běží. - William Shakespeare",
      "Víme, co jsme, ale nevíme, čím se můžeme stát. - William Shakespeare",
      "Nikdo tě nemůže přimět cítit se méněcenně bez tvého souhlasu. - Eleanor Roosevelt",
      "Všichni žijeme pod stejným nebem, ale nemáme všichni stejný obzor. - Konrad Adenauer",
      "Miluj všechny, důvěřuj málokomu a nikomu neubližuj. - William Shakespeare",
      "Stručnost je duší vtipu. - William Shakespeare",
      "Neruší nás věci, ale naše soudy o nich. - Epiktétos",
      "Uprostřed každé obtíže je příležitost. - Albert Einstein",
      "Žádný člověk není svobodný, není-li pánem sebe sama. - Epiktétos",
      "Vytrvalost mění cíle ve výsledky. - Jim Rohn",
      "Štěstí tvého života závisí na kvalitě tvých myšlenek. - Marcus Aurelius",
      "Náš život je tím, čím jej učiní naše myšlenky. - Marcus Aurelius",
      "Čas je to nejcennější, co může člověk vydat. - Theofrastos",
      "Kdo málo přemýšlí, mnoho chybuje. - Leonardo da Vinci",
      "Moudrost je dcerou zkušenosti. - Leonardo da Vinci",
      "Správně vidíme jen srdcem. - Antoine de Saint-Exupéry",
      "Všichni dospělí byli kdysi dětmi. - Antoine de Saint-Exupéry",
      "Hvězdy jsou rozsvíceny proto, aby každý mohl jednou najít tu svou. - Antoine de Saint-Exupéry",
      "Svoboda začíná ironií. - Victor Hugo",
      "Svědomí je hlas duše. - Jean-Jacques Rousseau",
      "Člověk se rodí svobodný, ale všude je v okovech. - Jean-Jacques Rousseau",
      "Pochybnost je počátkem moudrosti. - Descartes",
      "Myslím, tedy jsem. - Descartes",
      "Úžas je počátkem poznání. - Platón",
      "Hudba dává duši vesmíru, křídla myšlenkám a vzlet představivosti. - Platón",
      "Člověk je společenský tvor. - Aristotelés",
      "Štěstí závisí na nás samých. - Aristotelés",
      "Vyber si práci, kterou miluješ, a nebudeš muset pracovat ani den v životě. - Konfucius",
      "Kamkoli jdeš, jdi celým srdcem. - Konfucius",
      "Nezáleží na tom, jak pomalu jdeš, pokud se nezastavíš. - Konfucius",
      "Studuj minulost, chceš-li předvídat budoucnost. - Konfucius",
      "Kdo zná druhé, je moudrý; kdo zná sebe, je osvícený. - Laozi",
      "Kdo se umí spokojit, je bohatý. - Laozi",
      "Laskavá slova mohou být krátká a snadno se říkají, ale jejich ozvěna je věčná. - Matka Tereza",
      "Nemůžeme dělat velké věci, jen malé věci s velkou láskou. - Matka Tereza",
      "Mír začíná úsměvem. - Matka Tereza",
      "Oko za oko oslepí celý svět. - Mahatma Gandhi",
      "Síla nepochází z tělesné schopnosti, ale z nezdolné vůle. - Mahatma Gandhi",
      "Život je tajemství k prožití, ne problém k vyřešení. - Søren Kierkegaard",
      "Život lze pochopit jen zpětně, ale žít se musí dopředu. - Søren Kierkegaard",
      "Kdo bojuje, může prohrát; kdo nebojuje, už prohrál. - Bertolt Brecht",
      "Tam, kde roste nebezpečí, roste i to, co zachraňuje. - Friedrich Hölderlin",
      "Dvě věci naplňují mysl úžasem: hvězdné nebe nade mnou a mravní zákon ve mně. - Immanuel Kant",
      "Měj odvahu používat vlastní rozum. - Immanuel Kant",
      "Člověk je tím, v co věří. - Anton Čechov",
      "Krása je příslibem štěstí. - Stendhal",
      "Budoucnost patří těm, kdo věří v krásu svých snů. - Eleanor Roosevelt",
      "Ženou se člověk nerodí: stává se jí. - Simone de Beauvoir",
      "Kultura je jediné dobro lidstva, které roste, když se sdílí se všemi. - Hans-Georg Gadamer",
      "Je-li pochopení nemožné, poznání je nezbytné. - Primo Levi",
      "Paměť je nutná, musíme si pamatovat. - Primo Levi",
      "Berte život s lehkostí, protože lehkost není povrchnost. - Italo Calvino",
      "Peklo živých není něco, co teprve bude; pokud existuje, je už tady. - Italo Calvino",
      "Fantazie je místo, kde prší uvnitř. - Italo Calvino",
      "Skutečnost nikdy není taková, jak ji vidíme: pravda je především představivost. - René Magritte",
      "Život napodobuje umění mnohem víc než umění napodobuje život. - Oscar Wilde",
      "Buď sám sebou; všichni ostatní už jsou obsazeni. - Oscar Wilde",
      "Není noc tak dlouhá, aby zabránila slunci znovu vyjít. - Khalil Gibran",
      "Práce je láska učiněná viditelnou. - Khalil Gibran",
      "Něha a laskavost nejsou známkami slabosti, ale projevy síly. - Khalil Gibran",
      "Neplač, že to skončilo; usměj se, že se to stalo. - Dr. Seuss",
      "Vzdělání je nejmocnější zbraň, kterou můžeš použít ke změně světa. - Nelson Mandela",
      "To, co víme, je kapka; to, co nevíme, je oceán. - Isaac Newton",
      "Viděl-li jsem dál, bylo to proto, že jsem stál na ramenou obrů. - Isaac Newton",
      "Den bez smíchu je promarněný den. - Charlie Chaplin",
      "Život je příliš důležitý na to, aby byl brán vážně. - Oscar Wilde",
      "Musíme pěstovat svou zahradu. - Voltaire",
      "Spánek rozumu plodí příšery. - Francisco Goya",
      "Bez hudby by byl život omylem. - Friedrich Nietzsche",
      "Co mě nezabije, to mě posílí. - Friedrich Nietzsche",
      "Hranice mého jazyka jsou hranicemi mého světa. - Ludwig Wittgenstein",
      "O čem nelze mluvit, o tom se musí mlčet. - Ludwig Wittgenstein",
      "Člověk je odsouzen ke svobodě. - Jean-Paul Sartre",
      "Všechno, co si dokážeš představit, je skutečné. - Pablo Picasso",
      "Každé dítě je umělec. Problém je zůstat umělcem, když vyroste. - Pablo Picasso",
      "Umění smývá z duše prach každodenního života. - Pablo Picasso",
      "Neprozkoumaný život nestojí za to žít. - Sókratés",
      "Důležité není žít, ale žít dobře. - Sókratés",
      "Pravda je dcerou času. - Francis Bacon",
      "Člověk, který se odváží promarnit hodinu času, neobjevil hodnotu života. - Charles Darwin",
      "Historie je učitelkou života. - Cicero",
      "Dokud je život, je naděje. - Cicero",
      "Budoucnost závisí na tom, co děláme v přítomnosti. - Mahatma Gandhi",
      "Svoboda je jako vzduch: uvědomíme si její cenu, když začne chybět. - Piero Calamandrei",
      "Chceme-li, aby všechno zůstalo tak, jak je, musí se všechno změnit. - Giuseppe Tomasi di Lampedusa",
      "Kdo otevírá dveře školy, zavírá vězení. - Victor Hugo",
      "Kořeny vzdělání jsou hořké, ale ovoce je sladké. - Aristotelés",
      "Kde je láska, tam je život. - Mahatma Gandhi",
    ];
    final quotesPl = [
      "Szczęście nie polega na posiadaniu tego, czego się pragnie, lecz na pragnieniu tego, co się ma. - Oscar Wilde",
      "Sukces jest sumą małych wysiłków powtarzanych dzień po dniu. - Robert Collier",
      "Nigdy nie jest za późno, aby stać się tym, kim można było być. - George Eliot",
      "Życie jest tym, co dzieje się, gdy jesteś zajęty robieniem innych planów. - John Lennon",
      "Najlepszym sposobem przewidywania przyszłości jest jej tworzenie. - Alan Kay",
      "Prawdziwa podróż odkrywcza nie polega na szukaniu nowych krain, lecz na patrzeniu nowymi oczami. - Marcel Proust",
      "Jedynym sposobem wykonywania wspaniałej pracy jest kochanie tego, co się robi. - Steve Jobs",
      "To, co najważniejsze, jest niewidoczne dla oczu. - Antoine de Saint-Exupéry",
      "Podróż tysiąca mil zaczyna się od jednego kroku. - Laozi",
      "Nadzieja jest snem na jawie. - Arystoteles",
      "Cierpliwość jest gorzka, ale jej owoc jest słodki. - Jean-Jacques Rousseau",
      "Trzeba mieć w sobie jeszcze chaos, by móc zrodzić tańczącą gwiazdę. - Friedrich Nietzsche",
      "Piękno ocali świat. - Fiodor Dostojewski",
      "Wiem, że nic nie wiem. - Sokrates",
      "Kropla drąży kamień nie siłą, lecz częstym spadaniem. - Owidiusz",
      "Natura nie czyni nic na próżno. - Arystoteles",
      "Szczęście sprzyja odważnym. - Wergiliusz",
      "Wiedza to potęga. - Francis Bacon",
      "Żaden wiatr nie jest pomyślny dla tego, kto nie wie, dokąd zmierza. - Seneka",
      "Rób wszystko spokojnie i w dobrym porządku. - Marek Aureliusz",
      "Prostota jest najwyższym wyrafinowaniem. - Leonardo da Vinci",
      "Serce ma swoje racje, których rozum nie zna. - Blaise Pascal",
      "Czas ujawnia wszystko. - Tertulian",
      "Stań się tym, kim jesteś. - Friedrich Nietzsche",
      "Kto ma po co żyć, zniesie prawie każde jak. - Friedrich Nietzsche",
      "Nic nie jest trwałe poza zmianą. - Heraklit",
      "Wszystko płynie. - Heraklit",
      "Zawsze wydaje się niemożliwe, dopóki nie zostanie zrobione. - Nelson Mandela",
      "Umiar jest największym skarbem. - Hezjod",
      "W życiu niczego nie trzeba się bać, trzeba to tylko zrozumieć. - Maria Skłodowska-Curie",
      "Wyobraźnia jest ważniejsza od wiedzy. - Albert Einstein",
      "Żaden akt życzliwości, choćby najmniejszy, nigdy nie idzie na marne. - Ezop",
      "Dobrze zaczęte to połowa dzieła. - Arystoteles",
      "Wszyscy tkwimy w rynsztoku, ale niektórzy z nas patrzą w gwiazdy. - Oscar Wilde",
      "To nie dlatego nie ośmielamy się, że rzeczy są trudne, lecz dlatego są trudne, że się nie ośmielamy. - Seneka",
      "Ludzie są jak rowery: zachowują równowagę tylko wtedy, gdy pozostają w ruchu. - Albert Einstein",
      "Miarą inteligencji jest zdolność do zmiany. - Albert Einstein",
      "Nie zostaliście stworzeni, by żyć jak zwierzęta, lecz by dążyć do cnoty i poznania. - Dante Alighieri",
      "Miłość, która nikomu kochanemu nie daruje kochania. - Dante Alighieri",
      "W połowie drogi naszego życia znalazłem się w ciemnym lesie. - Dante Alighieri",
      "Być albo nie być, oto jest pytanie. - William Shakespeare",
      "Wiemy, kim jesteśmy, lecz nie wiemy, kim możemy być. - William Shakespeare",
      "Nikt nie może sprawić, że poczujesz się gorszy, bez twojej zgody. - Eleanor Roosevelt",
      "Wszyscy żyjemy pod tym samym niebem, ale nie wszyscy mamy ten sam horyzont. - Konrad Adenauer",
      "Kochaj wszystkich, ufaj niewielu, nikomu nie czyń krzywdy. - William Shakespeare",
      "Zwięzłość jest duszą dowcipu. - William Shakespeare",
      "Nie rzeczy nas niepokoją, lecz nasze sądy o rzeczach. - Epiktet",
      "Pośród każdej trudności kryje się okazja. - Albert Einstein",
      "Żaden człowiek nie jest wolny, jeśli nie panuje nad sobą. - Epiktet",
      "Konsekwencja zamienia cele w wyniki. - Jim Rohn",
      "Szczęście twojego życia zależy od jakości twoich myśli. - Marek Aureliusz",
      "Nasze życie jest tym, czym czynią je nasze myśli. - Marek Aureliusz",
      "Czas jest najcenniejszą rzeczą, jaką człowiek może wydać. - Teofrast",
      "Kto mało myśli, wiele błądzi. - Leonardo da Vinci",
      "Mądrość jest córką doświadczenia. - Leonardo da Vinci",
      "Dobrze widzi się tylko sercem. - Antoine de Saint-Exupéry",
      "Wszyscy dorośli byli kiedyś dziećmi. - Antoine de Saint-Exupéry",
      "Gwiazdy świecą po to, by każdy mógł pewnego dnia odnaleźć swoją. - Antoine de Saint-Exupéry",
      "Wolność zaczyna się od ironii. - Victor Hugo",
      "Sumienie jest głosem duszy. - Jean-Jacques Rousseau",
      "Człowiek rodzi się wolny, a wszędzie tkwi w kajdanach. - Jean-Jacques Rousseau",
      "Wątpienie jest początkiem mądrości. - Kartezjusz",
      "Myślę, więc jestem. - Kartezjusz",
      "Zdziwienie jest początkiem poznania. - Platon",
      "Muzyka daje duszę wszechświatu, skrzydła myśli i lot wyobraźni. - Platon",
      "Człowiek jest istotą społeczną. - Arystoteles",
      "Szczęście zależy od nas samych. - Arystoteles",
      "Wybierz pracę, którą kochasz, a nie przepracujesz ani jednego dnia w życiu. - Konfucjusz",
      "Dokądkolwiek idziesz, idź całym sercem. - Konfucjusz",
      "Nie ma znaczenia, jak wolno idziesz, jeśli się nie zatrzymujesz. - Konfucjusz",
      "Badaj przeszłość, jeśli chcesz przewidzieć przyszłość. - Konfucjusz",
      "Kto zna innych, jest mądry; kto zna siebie, jest oświecony. - Laozi",
      "Kto umie poprzestać na swoim, jest bogaty. - Laozi",
      "Życzliwe słowa mogą być krótkie i łatwe do wypowiedzenia, ale ich echo jest wieczne. - Matka Teresa",
      "Nie możemy robić wielkich rzeczy, tylko małe rzeczy z wielką miłością. - Matka Teresa",
      "Pokój zaczyna się od uśmiechu. - Matka Teresa",
      "Oko za oko uczyni cały świat ślepym. - Mahatma Gandhi",
      "Siła nie pochodzi ze zdolności fizycznych, lecz z niezłomnej woli. - Mahatma Gandhi",
      "Życie jest tajemnicą do przeżycia, a nie problemem do rozwiązania. - Søren Kierkegaard",
      "Życie można zrozumieć tylko wstecz, ale trzeba je przeżywać naprzód. - Søren Kierkegaard",
      "Kto walczy, może przegrać; kto nie walczy, już przegrał. - Bertolt Brecht",
      "Tam, gdzie rośnie niebezpieczeństwo, rośnie także to, co ocala. - Friedrich Hölderlin",
      "Dwie rzeczy napełniają umysł podziwem: gwiaździste niebo nade mną i prawo moralne we mnie. - Immanuel Kant",
      "Miej odwagę posługiwać się własnym rozumem. - Immanuel Kant",
      "Człowiek jest tym, w co wierzy. - Anton Czechow",
      "Piękno jest obietnicą szczęścia. - Stendhal",
      "Przyszłość należy do tych, którzy wierzą w piękno swoich marzeń. - Eleanor Roosevelt",
      "Nie rodzimy się kobietami: stajemy się nimi. - Simone de Beauvoir",
      "Kultura jest jedynym dobrem ludzkości, które rośnie, gdy dzieli się je między wszystkich. - Hans-Georg Gadamer",
      "Jeśli zrozumienie jest niemożliwe, poznanie jest konieczne. - Primo Levi",
      "Pamięć jest konieczna, musimy pamiętać. - Primo Levi",
      "Bierzcie życie z lekkością, bo lekkość nie jest powierzchownością. - Italo Calvino",
      "Piekło żyjących nie jest czymś, co dopiero będzie; jeśli istnieje, to jest już tutaj. - Italo Calvino",
      "Fantazja to miejsce, w którym pada deszcz od środka. - Italo Calvino",
      "Rzeczywistość nigdy nie jest taka, jak ją widzimy: prawda jest przede wszystkim wyobraźnią. - René Magritte",
      "Życie naśladuje sztukę bardziej niż sztuka naśladuje życie. - Oscar Wilde",
      "Bądź sobą; wszyscy inni są już zajęci. - Oscar Wilde",
      "Nie ma nocy tak długiej, by mogła powstrzymać słońce przed ponownym wschodem. - Khalil Gibran",
      "Praca jest miłością uczynioną widzialną. - Khalil Gibran",
      "Czułość i życzliwość nie są oznakami słabości, lecz przejawami siły. - Khalil Gibran",
      "Nie płacz, że to się skończyło; uśmiechnij się, że się wydarzyło. - Dr. Seuss",
      "Edukacja jest najpotężniejszą bronią, której możesz użyć, aby zmienić świat. - Nelson Mandela",
      "To, co wiemy, jest kroplą; to, czego nie wiemy, jest oceanem. - Isaac Newton",
      "Jeśli widziałem dalej, to dlatego, że stałem na ramionach olbrzymów. - Isaac Newton",
      "Dzień bez śmiechu jest dniem straconym. - Charlie Chaplin",
      "Życie jest zbyt ważne, by traktować je poważnie. - Oscar Wilde",
      "Musimy uprawiać nasz ogród. - Voltaire",
      "Sen rozumu rodzi potwory. - Francisco Goya",
      "Bez muzyki życie byłoby pomyłką. - Friedrich Nietzsche",
      "Co mnie nie zabija, czyni mnie silniejszym. - Friedrich Nietzsche",
      "Granice mojego języka są granicami mojego świata. - Ludwig Wittgenstein",
      "O czym nie można mówić, o tym trzeba milczeć. - Ludwig Wittgenstein",
      "Człowiek jest skazany na wolność. - Jean-Paul Sartre",
      "Wszystko, co możesz sobie wyobrazić, jest realne. - Pablo Picasso",
      "Każde dziecko jest artystą. Problemem jest pozostać artystą, gdy się dorośnie. - Pablo Picasso",
      "Sztuka zmywa z duszy kurz codziennego życia. - Pablo Picasso",
      "Życie bez namysłu nie jest warte przeżycia. - Sokrates",
      "Ważne jest nie samo życie, lecz dobre życie. - Sokrates",
      "Prawda jest córką czasu. - Francis Bacon",
      "Człowiek, który ośmiela się zmarnować godzinę czasu, nie odkrył wartości życia. - Charles Darwin",
      "Historia jest nauczycielką życia. - Cyceron",
      "Dopóki jest życie, jest nadzieja. - Cyceron",
      "Przyszłość zależy od tego, co robimy w teraźniejszości. - Mahatma Gandhi",
      "Wolność jest jak powietrze: dostrzegamy jej wartość, gdy zaczyna jej brakować. - Piero Calamandrei",
      "Jeśli chcemy, aby wszystko pozostało tak, jak jest, wszystko musi się zmienić. - Giuseppe Tomasi di Lampedusa",
      "Kto otwiera drzwi szkoły, zamyka więzienie. - Victor Hugo",
      "Korzenie edukacji są gorzkie, ale owoc jest słodki. - Arystoteles",
      "Gdzie jest miłość, tam jest życie. - Mahatma Gandhi",
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
