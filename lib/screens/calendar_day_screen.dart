import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';
import '../services/calendar/calendar_service.dart';
import '../services/audio_player_service.dart';
import '../services/app_settings_service.dart';
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

  List<CalendarEvent> _events = [];
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
    final dayFormat = DateFormat('EEEE d MMMM yyyy', l10n.locale.languageCode);
    final titleStr = dayFormat.format(widget.date);
    
    final holiday = _service.getHoliday(widget.date, l10n.locale.languageCode);
    final saint = _service.getSaint(widget.date, l10n.locale.languageCode);
    final quote = _service.getQuote(widget.date, l10n.locale.languageCode);

    final buffer = StringBuffer();
    buffer.writeln(titleStr);
    if (holiday != null) buffer.writeln(holiday);
    if (_events.isNotEmpty) {
      buffer.writeln(l10n.reminders);
      for (var e in _events) {
        buffer.writeln(e.text);
      }
    }
    
    if (saint != null) {
      buffer.writeln('${l10n.saintOfTheDay}: $saint');
    }
    
    buffer.writeln(l10n.quoteOfTheDay);
    buffer.writeln(quote);

    final textToRead = buffer.toString();

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

  @override
  void dispose() {
    _flutterTts.stop();
    _audio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = l10n.locale.languageCode;
    
    final dayFormat = DateFormat('EEEE d MMMM yyyy', lang);
    final titleStr = dayFormat.format(widget.date);
    final capTitle = titleStr[0].toUpperCase() + titleStr.substring(1);

    final holiday = _service.getHoliday(widget.date, lang);
    final saint = _service.getSaint(widget.date, lang);
    final quote = _service.getQuote(widget.date, lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(capTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Condividi',
            onPressed: () {
              final shareText = '$capTitle\n\n${holiday != null ? '$holiday\n' : ''}${saint != null ? '${l10n.saintOfTheDay}: $saint\n\n' : ''}"$quote"';
              // ignore: deprecated_member_use
              Share.share(shareText);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(capTitle, style: Theme.of(context).textTheme.headlineMedium),
          if (holiday != null) ...[
            const SizedBox(height: 8),
            Text(holiday, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ],
          const SizedBox(height: 24),
          
          if (_events.isNotEmpty) ...[
            Text(l10n.reminders, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final ev in _events)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(ev.text),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
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

          if (saint != null) ...[
            const SizedBox(height: 32),
            Text('${l10n.saintOfTheDay}: $saint', style: Theme.of(context).textTheme.titleMedium),
          ],

          const SizedBox(height: 32),
          Text(l10n.quoteOfTheDay, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(quote, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),

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
                    label: const Text('Ascolta tutto'),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _stopReading,
                    icon: const Icon(Icons.stop),
                    label: const Text('Ferma lettura'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
