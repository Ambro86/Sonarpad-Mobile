import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';
import '../services/calendar/calendar_service.dart';
import '../services/audio_player_service.dart';
import '../services/app_settings_service.dart';
import '../services/voice_dictionary_service.dart';
import '../tts/edge_tts_bridge.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CalendarDayScreen extends StatefulWidget {
  final DateTime date;
  const CalendarDayScreen({super.key, required this.date});

  @override
  State<CalendarDayScreen> createState() => _CalendarDayScreenState();
}

class _CalendarDayScreenState extends State<CalendarDayScreen> {
  final _service = CalendarService();
  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  final _tts = EdgeTtsBridge();
  final _flutterTts = FlutterTts();
  final _voiceDictionary = VoiceDictionaryService();

  List<CalendarEvent> _events = [];
  bool _speaking = false;
  String? _saint;

  bool _saintLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_saintLoaded) {
      _saintLoaded = true;
      _loadSaint();
    }
  }

  Future<void> _loadSaint() async {
    final l10n = AppLocalizations.of(context);
    final s = await _service.getSaintAsync(widget.date, l10n.localeName);
    if (mounted) setState(() => _saint = s);
  }

  Future<void> _loadEvents() async {
    final evs = await _service.getEventsForDate(widget.date);
    if (mounted) {
      setState(() {
        _events = evs;
      });
    }
  }

  Future<void> _addReminder() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addReminder),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.writeReminder,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancelReminder),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                final ev = CalendarEvent(
                  id: const Uuid().v4(),
                  date: widget.date,
                  text: ctrl.text.trim(),
                );
                await _service.addEvent(ev);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _loadEvents();
              }
            },
            child: Text(l10n.saveReminder),
          ),
        ],
      ),
    );
  }

  Future<void> _readAll() async {
    final l10n = AppLocalizations.of(context);
    final dayFormat = DateFormat('EEEE d MMMM yyyy', l10n.localeName);
    final titleStr = dayFormat.format(widget.date);

    final holiday = _service.getHoliday(widget.date, l10n.localeName);
    final quote = _service.getQuote(widget.date, l10n.localeName);

    final buffer = StringBuffer();
    buffer.writeln(titleStr);
    if (holiday != null) buffer.writeln(holiday);
    if (_events.isNotEmpty) {
      buffer.writeln(l10n.reminders);
      for (var e in _events) {
        buffer.writeln(e.text);
      }
    }

    if (_saint != null) {
      buffer.writeln('${l10n.saintOfTheDay}: $_saint');
    }

    buffer.writeln(l10n.quoteOfTheDay);
    buffer.writeln(quote);

    final dictionaryEntries = await _voiceDictionary.loadEntries();
    final textToRead =
        _voiceDictionary.applyToText(buffer.toString(), dictionaryEntries);

    if (!mounted) return;
    setState(() => _speaking = true);

    try {
      final engine = await _settings.loadTtsEngine();
      if (engine == 'system') {
        final sysLang = await _settings.loadSystemTtsLanguage();
        final sysVoice = await _settings.loadSystemTtsVoice();
        if (sysVoice != null) {
          await _flutterTts.setVoice({"name": sysVoice, "locale": sysLang});
        } else {
          await _flutterTts.setLanguage(sysLang);
        }
        await _flutterTts.awaitSpeakCompletion(true);
        await _flutterTts.speak(textToRead);
      } else {
        final voice = await _settings.loadTtsVoice();
        final file = await _tts.speakToFile(text: textToRead, voice: voice);
        await _audio.playFilesSequentially([file]);
      }
    } catch (e) {
      debugPrint('Error TTS: $e');
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  void _stopReading() {
    _flutterTts.stop();
    _audio.stop();
    setState(() => _speaking = false);
  }

  String _shareText({
    required String title,
    required String? holiday,
    required String? saint,
    required String quote,
    required AppLocalizations l10n,
    required bool includeReminders,
  }) {
    final buffer = StringBuffer()..writeln(title);
    if (holiday != null) buffer.writeln('\n$holiday');
    if (saint != null) {
      buffer.writeln('\n${l10n.saintOfTheDay}: $saint');
    }
    if (includeReminders && _events.isNotEmpty) {
      buffer.writeln('\n${l10n.reminders}');
      for (final event in _events) {
        buffer.writeln(event.text);
      }
    }
    buffer.writeln('\n"$quote"');
    return buffer.toString().trim();
  }

  Future<void> _shareDay({
    required String title,
    required String? holiday,
    required String? saint,
    required String quote,
    required AppLocalizations l10n,
  }) async {
    var includeReminders = false;
    if (_events.isNotEmpty) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.shareCalendarDayOptions),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.shareCalendarDayOnly),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.shareCalendarDayWithReminder),
            ),
          ],
        ),
      );
      if (choice == null) return;
      includeReminders = choice;
    }

    final shareText = _shareText(
      title: title,
      holiday: holiday,
      saint: saint,
      quote: quote,
      l10n: l10n,
      includeReminders: includeReminders,
    );
    // ignore: deprecated_member_use
    await Share.share(shareText);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _audio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = l10n.localeName;

    final dayFormat = DateFormat('EEEE d MMMM yyyy', lang);
    final titleStr = dayFormat.format(widget.date);
    final capTitle = titleStr[0].toUpperCase() + titleStr.substring(1);

    final holiday = _service.getHoliday(widget.date, lang);
    final quote = _service.getQuote(widget.date, lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(capTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.share,
            onPressed: () => _shareDay(
              title: capTitle,
              holiday: holiday,
              saint: _saint,
              quote: quote,
              l10n: l10n,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(capTitle, style: Theme.of(context).textTheme.headlineMedium),
          if (holiday != null) ...[
            const SizedBox(height: 8),
            Text(holiday,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ],
          const SizedBox(height: 24),
          if (_events.isNotEmpty) ...[
            Text(l10n.reminders,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final ev in _events)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(ev.text),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: l10n.removeReminder,
                    onPressed: () async {
                      await _service.removeEvent(ev.id);
                      _loadEvents();
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: _addReminder,
            icon: const Icon(Icons.add),
            label: Text(l10n.addReminder),
          ),
          if (_saint != null) ...[
            const SizedBox(height: 32),
            Text('${l10n.saintOfTheDay}: $_saint',
                style: Theme.of(context).textTheme.titleMedium),
          ],
          const SizedBox(height: 32),
          Text(l10n.quoteOfTheDay,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(quote,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_speaking)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _readAll,
                    icon: const Icon(Icons.volume_up),
                    label: Text(l10n.listenToAll),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _stopReading,
                    icon: const Icon(Icons.stop),
                    label: Text(l10n.stopReading),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
