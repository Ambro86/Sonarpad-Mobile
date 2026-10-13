import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';
import '../services/calendar/calendar_service.dart';
import '../services/audio_player_service.dart';
import '../services/app_settings_service.dart';
import '../services/voice_dictionary_service.dart';
import '../tts/edge_tts_bridge.dart';
import '../tts/edge_tts_retry.dart';

import 'package:flutter_tts/flutter_tts.dart';

import '../widgets/universal_accessible_view.dart';
import '../widgets/calendar_reminder_dialog.dart';

class CalendarDayScreen extends StatefulWidget {
  final DateTime date;
  final CalendarService? service;
  const CalendarDayScreen({super.key, required this.date, this.service});

  @override
  State<CalendarDayScreen> createState() => _CalendarDayScreenState();
}

class _CalendarDayScreenState extends State<CalendarDayScreen> {
  late final _service = widget.service ?? CalendarService();
  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  final _tts = EdgeTtsBridge();
  final _flutterTts = FlutterTts();
  final _voiceDictionary = VoiceDictionaryService();

  List<CalendarEvent> _events = [];
  bool _speaking = false;
  int _readingToken = 0;
  String? _saint;

  String? _saintLanguage;
  DateTime? _saintDate;
  int _saintRequest = 0;
  int _eventsRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshSaint();
  }

  @override
  void didUpdateWidget(covariant CalendarDayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.date, widget.date)) {
      _events = [];
      _loadEvents();
      _refreshSaint();
    }
  }

  void _refreshSaint() {
    final language = AppLocalizations.of(context).localeName;
    final date = widget.date;
    if (_saintLanguage == language && DateUtils.isSameDay(_saintDate, date)) {
      return;
    }
    _saintLanguage = language;
    _saintDate = date;
    // Replace a previous locale immediately with the bundled translation.
    // Keep the same accessible row identity while any fallback is loading.
    _saint = _service.getSaint(date, language);
    _loadSaint(date, language, ++_saintRequest);
  }

  Future<void> _loadSaint(DateTime date, String language, int request) async {
    final saint = await _service.getSaintAsync(date, language);
    if (mounted && request == _saintRequest && saint != _saint) {
      setState(() => _saint = saint);
    }
  }

  Future<void> _loadEvents() async {
    final request = ++_eventsRequest;
    final evs = await _service.getEventsForDate(widget.date);
    if (mounted && request == _eventsRequest) {
      setState(() {
        _events = evs;
      });
    }
  }

  Future<void> _addReminder() async {
    final l10n = AppLocalizations.of(context);
    final event = await showDialog<CalendarEvent>(
      context: context,
      builder: (_) => CalendarReminderDialog(date: widget.date),
    );
    if (event == null || !mounted) return;
    await _service.addEvent(event, deviceCalendarDescription: l10n.reminders);
    if (mounted) await _loadEvents();
  }

  String _reminderLabel(CalendarEvent event) {
    if (!event.hasTime) return event.text;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(event.date),
      alwaysUse24HourFormat: true,
    );
    return '${event.text}, $time';
  }

  Future<void> _readAll() async {
    final readingToken = ++_readingToken;
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
        buffer.writeln(_reminderLabel(e));
      }
    }

    if (_saint != null) {
      buffer.writeln('${l10n.saintOfTheDay}: $_saint');
    }

    buffer.writeln(l10n.quoteOfTheDay);
    buffer.writeln(quote);

    final dictionaryEntries = await _voiceDictionary.loadEntries();
    final textToRead = _voiceDictionary.applyToText(
      buffer.toString(),
      dictionaryEntries,
    );

    if (!mounted || readingToken != _readingToken) return;
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
        if (!EdgeTtsRetry.isTextUsable(textToRead)) return;
        final file = await EdgeTtsRetry.run(
          retryUntilCancelled: true,
          generate: () => _tts.speakToFile(text: textToRead, voice: voice),
          isActive: () => mounted && _speaking && readingToken == _readingToken,
          onRetry: (retry, delay, error) => debugPrint(
            'CalendarDay: Edge TTS retry $retry tra '
            '${delay.inMilliseconds}ms: $error',
          ),
        );
        if (file != null &&
            mounted &&
            _speaking &&
            readingToken == _readingToken) {
          await _audio.playFilesSequentially([file]);
        }
      }
    } catch (e) {
      debugPrint('Error TTS: $e');
    } finally {
      if (mounted && readingToken == _readingToken) {
        setState(() => _speaking = false);
      }
    }
  }

  void _stopReading() {
    _readingToken += 1;
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
        buffer.writeln(_reminderLabel(event));
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
    _readingToken += 1;
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
      appBar: SonarpadAppBar(
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
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'title',
                      kind: 'header',
                      title: capTitle,
                    ),
                    if (holiday != null)
                      AccessibleListRow(
                        id: 'holiday',
                        kind: 'text',
                        title: holiday,
                      ),
                    if (_events.isNotEmpty)
                      AccessibleListRow(
                        id: 'reminders_header',
                        kind: 'header',
                        title: l10n.reminders,
                      ),
                    for (var i = 0; i < _events.length; i++)
                      AccessibleListRow(
                        id: 'event_$i',
                        kind: 'text',
                        title: _reminderLabel(_events[i]),
                        actions: [
                          AccessibleCustomAction(
                            id: 'remove',
                            label: l10n.removeReminder,
                          ),
                        ],
                      ),
                    AccessibleListRow(
                      id: 'add',
                      title: l10n.addReminder,
                      kind: 'button',
                    ),
                    if (_saint != null)
                      AccessibleListRow(
                        id: 'saint',
                        kind: 'text',
                        title: '${l10n.saintOfTheDay}: $_saint',
                      ),
                    AccessibleListRow(
                      id: 'quote_header',
                      kind: 'header',
                      title: l10n.quoteOfTheDay,
                    ),
                    AccessibleListRow(id: 'quote', kind: 'text', title: quote),
                  ],
                ),
              ],
              onEvent: (event) async {
                if (event.id == 'add' && event.type == 'activate') {
                  await _addReminder();
                } else if (event.type == 'customAction' &&
                    event.action == 'remove' &&
                    event.id?.startsWith('event_') == true) {
                  final i = int.tryParse(event.id!.substring(6));
                  if (i != null && i < _events.length) {
                    await _service.removeEvent(_events[i].id);
                    await _loadEvents();
                  }
                }
              },
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  capTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (holiday != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    holiday,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_events.isNotEmpty) ...[
                  Text(
                    l10n.reminders,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final ev in _events)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(_reminderLabel(ev)),
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
                  Text(
                    '${l10n.saintOfTheDay}: $_saint',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
                const SizedBox(height: 32),
                Text(
                  l10n.quoteOfTheDay,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  quote,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
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
