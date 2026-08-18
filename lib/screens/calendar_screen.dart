import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/calendar/calendar_service.dart';
import '../models/calendar_event.dart';
import 'calendar_day_screen.dart';
import '../widgets/universal_accessible_view.dart';

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
  final AccessibleListController _accessibleListController = AccessibleListController();
  static const int _accessiblePastDays = 2000;
  static const int _accessibleTotalDays = 4001;

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

  Future<void> _scrollToToday() async {
    if (useSharedAccessibleViewModel) {
      await _accessibleListController.focusTo('day_$_accessiblePastDays');
      return;
    }
    _scrollController.animateTo(
      _todayIndex * 80.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  String _accessibleDayTitle(DateTime date, DateTime baseToday, AppLocalizations l10n) {
    final dayFormat = DateFormat('EEEE d MMMM yyyy', l10n.localeName);
    final titleStr = dayFormat.format(date);
    final capTitle = titleStr[0].toUpperCase() + titleStr.substring(1);
    final offset = date.difference(baseToday).inDays;
    if (offset == 0) return '${l10n.calendarToday}, $capTitle';
    if (offset == 1) return '${l10n.calendarTomorrow}, $capTitle';
    if (offset == -1) return '${l10n.calendarYesterday}, $capTitle';
    return capTitle;
  }

  String? _accessibleDaySubtitle(DateTime date, AppLocalizations l10n) {
    final parts = <String>[];
    final holiday = _service.getHoliday(date, l10n.localeName);
    final saint = _service.getSaint(date, l10n.localeName);
    final dayEvents = _allEvents.where((e) =>
      e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
    if (holiday != null) parts.add(holiday);
    if (saint != null) parts.add('${l10n.saintOfTheDay}: $saint');
    if (dayEvents.isNotEmpty) parts.add(l10n.reminderSaved(dayEvents.length));
    return parts.isEmpty ? null : parts.join(' - ');
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
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              controller: _accessibleListController,
              initialFocusId: 'day_$_accessiblePastDays',
              sections: [AccessibleListSection(rows: [
                for (var i = 0; i < _accessibleTotalDays; i++)
                  AccessibleListRow(
                    id: 'day_$i',
                    title: _accessibleDayTitle(baseToday.add(Duration(days: i - _accessiblePastDays)), baseToday, l10n),
                    subtitle: _accessibleDaySubtitle(baseToday.add(Duration(days: i - _accessiblePastDays)), l10n),
                  ),
              ])],
              onEvent: (event) async {
                if (event.type != 'activate' || event.id == null) return;
                final i = int.tryParse(event.id!.replaceFirst('day_', ''));
                if (i == null || i < 0 || i >= _accessibleTotalDays) return;
                final date = baseToday.add(Duration(days: i - _accessiblePastDays));
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalendarDayScreen(date: date)));
                await _loadEvents();
              },
            )
          : ListView.builder(
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
