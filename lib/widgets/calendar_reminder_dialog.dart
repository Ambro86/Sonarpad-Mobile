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

  void _setHour(int hour) {
    setState(() => _time = _time.replacing(hour: hour.clamp(0, 23)));
  }

  void _setMinute(int minute) {
    setState(() => _time = _time.replacing(minute: minute.clamp(0, 59)));
  }

  Widget _timeSlider({
    required String id,
    required String label,
    required String semanticsLabel,
    required ValueGetter<int> readValue,
    required int maximum,
    required ValueChanged<int> onChanged,
  }) {
    final value = readValue();
    String format(int number) => number.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            AppLocalizations.of(
              context,
            ).radioScheduleLabeledValue(label, format(value)),
          ),
        ),
        Semantics(
          key: ValueKey('calendar_reminder_${id}_semantics'),
          slider: true,
          label: semanticsLabel,
          value: format(value),
          increasedValue: value < maximum ? format(value + 1) : null,
          decreasedValue: value > 0 ? format(value - 1) : null,
          onIncrease: value < maximum
              ? () => onChanged((readValue() + 1).clamp(0, maximum))
              : null,
          onDecrease: value > 0
              ? () => onChanged((readValue() - 1).clamp(0, maximum))
              : null,
          child: ExcludeSemantics(
            child: Slider(
              key: ValueKey('calendar_reminder_$id'),
              value: value.toDouble(),
              min: 0,
              max: maximum.toDouble(),
              divisions: maximum,
              label: format(value),
              onChanged: (value) => onChanged(value.round()),
            ),
          ),
        ),
      ],
    );
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
          if (_hasTime) ...[
            _timeSlider(
              id: 'hours',
              label: l10n.radioScheduleHours,
              semanticsLabel: l10n.radioScheduleSelectHours,
              readValue: () => _time.hour,
              maximum: 23,
              onChanged: _setHour,
            ),
            const SizedBox(height: 16),
            _timeSlider(
              id: 'minutes',
              label: l10n.radioScheduleMinutes,
              semanticsLabel: l10n.radioScheduleSelectMinutes,
              readValue: () => _time.minute,
              maximum: 59,
              onChanged: _setMinute,
            ),
          ],
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
