import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';

/// Collects a reminder without accessing the device calendar. The caller saves
/// the returned event after the dialog closes.
class CalendarReminderDialog extends StatefulWidget {
  const CalendarReminderDialog({super.key, required this.date});

  final DateTime date;

  @override
  State<CalendarReminderDialog> createState() => _CalendarReminderDialogState();
}

class _CalendarReminderDialogState extends State<CalendarReminderDialog> {
  final _textController = TextEditingController();
  bool _hasTime = false;
  TimeOfDay _time = TimeOfDay.now();

  Future<void> _pickTime() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final selected = await showTimePicker(
      context: context,
      initialTime: _time,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      hourLabelText: l10n.radioScheduleHours,
      minuteLabelText: l10n.radioScheduleMinutes,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (mounted && selected != null) setState(() => _time = selected);
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      CalendarEvent(
        id: const Uuid().v4(),
        date: DateTime(
          widget.date.year,
          widget.date.month,
          widget.date.day,
          _hasTime ? _time.hour : 0,
          _hasTime ? _time.minute : 0,
        ),
        text: text,
        hasTime: _hasTime,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final timeLabel = material.formatTimeOfDay(
      _time,
      alwaysUse24HourFormat: true,
    );
    return AlertDialog(
      title: Text(l10n.addReminder),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('calendar_reminder_text'),
            controller: _textController,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.writeReminder),
            textCapitalization: TextCapitalization.sentences,
          ),
          SwitchListTile(
            key: const ValueKey('calendar_reminder_has_time'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.calendarReminderHasTime),
            value: _hasTime,
            onChanged: (value) => setState(() => _hasTime = value),
          ),
          if (_hasTime)
            OutlinedButton.icon(
              key: const ValueKey('calendar_reminder_pick_time'),
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time),
              label: Text(
                l10n.radioScheduleLabeledValue(
                  material.timePickerDialHelpText,
                  timeLabel,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelReminder),
        ),
        FilledButton(
          key: const ValueKey('calendar_reminder_save'),
          onPressed: _save,
          child: Text(l10n.saveReminder),
        ),
      ],
    );
  }
}
