import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/calendar/calendar_service.dart';
import '../models/calendar_event.dart';
import 'calendar_day_screen.dart';
import 'package:sonarpad_mobile_starter/utils/accessibility_list_behavior.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _service = CalendarService();
  late final ScrollController _scrollController;
  final int _todayIndex =
      10000; // Un numero grande per simulare uno scroll infinito indietro
  List<CalendarEvent> _allEvents = [];

  @override
  void initState() {
    super.initState();
    // Iniziamo al centro della lista (Oggi)
    _scrollController =
        ScrollController(initialScrollOffset: _todayIndex * 80.0);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await _service.getEvents();
    if (mounted) {
      setState(() {
        _allEvents = events;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    _scrollController.animateTo(
      _todayIndex * 80.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = DateTime.now();
    // Azzeriamo le ore per confronto facile
    final baseToday = DateTime(today.year, today.month, today.day);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendar),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: l10n.backToToday,
            onPressed: _scrollToToday,
          )
        ],
      ),
      body: ListView.builder(
        scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
        controller: _scrollController,
        // Usiamo un itemExtent per un'altezza fissa che aiuta lo scroll
        itemExtent: 80.0,
        itemBuilder: (context, index) {
          final offset = index - _todayIndex;
          final date = baseToday.add(Duration(days: offset));

          final dayFormat = DateFormat('EEEE d MMMM yyyy', l10n.localeName);
          final titleStr = dayFormat.format(date);
          final capTitle = titleStr[0].toUpperCase() + titleStr.substring(1);

          final holiday = _service.getHoliday(date, l10n.localeName);
          final saint = _service.getSaint(date, l10n.localeName);
          final dayEvents = _allEvents
              .where((e) =>
                  e.date.year == date.year &&
                  e.date.month == date.month &&
                  e.date.day == date.day)
              .toList();

          String subtitle = '';
          if (holiday != null) subtitle += holiday;
          if (saint != null) {
            if (subtitle.isNotEmpty) subtitle += ' - ';
            subtitle += '${l10n.saintOfTheDay}: $saint';
          }
          if (dayEvents.isNotEmpty) {
            if (subtitle.isNotEmpty) subtitle += ' - ';
            subtitle += l10n.reminderSaved(dayEvents.length);
          }

          String prefix = '';
          if (offset == 0) {
            prefix = '${l10n.calendarToday}, ';
          } else if (offset == 1) {
            prefix = '${l10n.calendarTomorrow}, ';
          } else if (offset == -1) {
            prefix = '${l10n.calendarYesterday}, ';
          }

          final fullTitle = '$prefix$capTitle';

          return ListTile(
            title: Text(fullTitle,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CalendarDayScreen(date: date),
              ));
              // Ricarica eventi se ne sono stati aggiunti
              _loadEvents();
            },
          );
        },
      ),
    );
  }
}
