import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/global_recording_service.dart';
import '../services/tv_service.dart';
import '../utils/status_message.dart';
import 'universal_accessible_view.dart';

class _TvScheduledRecordingRequest {
  const _TvScheduledRecordingRequest({
    required this.start,
    required this.end,
    required this.title,
  });

  final DateTime start;
  final DateTime end;
  final String title;
}

DateTime tvProgramRecordingStart(TvProgram program) =>
    DateTime.fromMillisecondsSinceEpoch(
      program.startTime * 1000,
    ).subtract(const Duration(minutes: 10));

DateTime tvProgramRecordingEnd(TvProgram program) =>
    DateTime.fromMillisecondsSinceEpoch(
      program.endTime * 1000,
    ).add(const Duration(minutes: 10));

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

List<DateTime> tvRecordingDayChoices(DateTime today) {
  final normalizedToday = _dateOnly(today);
  return List.generate(
    6,
    (offset) => normalizedToday.add(Duration(days: offset)),
  );
}

String formatTvRecordingDayLabel(DateTime date, DateTime today) {
  final normalizedToday = _dateOnly(today);
  final normalizedDate = _dateOnly(date);
  final diff = normalizedDate.difference(normalizedToday).inDays;
  if (diff == -1) return 'Ieri';
  if (diff == 0) return 'Oggi';
  if (diff == 1) return 'Domani';
  if (diff == 2) return 'Dopodomani';

  const weekdays = [
    'Lunedì',
    'Martedì',
    'Mercoledì',
    'Giovedì',
    'Venerdì',
    'Sabato',
    'Domenica',
  ];
  const months = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];
  return '${weekdays[normalizedDate.weekday - 1]} '
      '${normalizedDate.day} ${months[normalizedDate.month - 1]}';
}

Future<DateTime?> showTvRecordingDaySelectionDialog(
  BuildContext context, {
  required DateTime selectedDate,
  required DateTime today,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppLocalizations.of(dialogContext).tvRecordingChooseDay),
      content: RadioGroup<DateTime>(
        groupValue: _dateOnly(selectedDate),
        onChanged: (value) {
          if (value != null) Navigator.pop(dialogContext, value);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: tvRecordingDayChoices(today)
                .map(
                  (date) => RadioListTile<DateTime>(
                    title: Text(formatTvRecordingDayLabel(date, today)),
                    value: date,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ),
  );
}

Future<TimeOfDay?> _showScheduledRecordingTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required String title,
}) async {
  int selectedHour = initialTime.hour;
  int selectedMinute = initialTime.minute;

  String twoDigits(int value) => value.toString().padLeft(2, '0');
  int clampInt(int value, int min, int max) => value.clamp(min, max).toInt();

  return showDialog<TimeOfDay>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final l10n = AppLocalizations.of(context);
          final nextHour = twoDigits(clampInt(selectedHour + 1, 0, 23));
          final previousHour = twoDigits(clampInt(selectedHour - 1, 0, 23));
          final nextMinute = twoDigits(clampInt(selectedMinute + 1, 0, 59));
          final previousMinute = twoDigits(clampInt(selectedMinute - 1, 0, 59));

          void setHour(int value) {
            setDialogState(() {
              selectedHour = clampInt(value, 0, 23);
            });
          }

          void setMinute(int value) {
            setDialogState(() {
              selectedMinute = clampInt(value, 0, 59);
            });
          }

          Widget buildValueSlider({
            required String visibleLabel,
            required String semanticsLabel,
            required int value,
            required int min,
            required int max,
            required String increasedValue,
            required String decreasedValue,
            required ValueChanged<int> onChanged,
          }) {
            final valueText = twoDigits(value);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Text(
                    l10n.radioScheduleLabeledValue(visibleLabel, valueText),
                  ),
                ),
                Semantics(
                  slider: true,
                  label: semanticsLabel,
                  value: valueText,
                  increasedValue: increasedValue,
                  decreasedValue: decreasedValue,
                  onIncrease: () => onChanged(value + 1),
                  onDecrease: () => onChanged(value - 1),
                  child: ExcludeSemantics(
                    child: Slider(
                      value: value.toDouble(),
                      min: min.toDouble(),
                      max: max.toDouble(),
                      divisions: max - min,
                      label: valueText,
                      onChanged: (newValue) => onChanged(newValue.round()),
                    ),
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildValueSlider(
                  visibleLabel: l10n.radioScheduleHours,
                  semanticsLabel: l10n.radioScheduleSelectHours,
                  value: selectedHour,
                  min: 0,
                  max: 23,
                  increasedValue: nextHour,
                  decreasedValue: previousHour,
                  onChanged: setHour,
                ),
                const SizedBox(height: 16),
                buildValueSlider(
                  visibleLabel: l10n.radioScheduleMinutes,
                  semanticsLabel: l10n.radioScheduleSelectMinutes,
                  value: selectedMinute,
                  min: 0,
                  max: 59,
                  increasedValue: nextMinute,
                  decreasedValue: previousMinute,
                  onChanged: setMinute,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  TimeOfDay(hour: selectedHour, minute: selectedMinute),
                ),
                child: Text(l10n.ok),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatScheduledDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

DateTime _replaceTime(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

String _tvRecordingTargetId(TvChannel channel) {
  final tvgId = channel.tvgId.trim().toLowerCase();
  if (tvgId.isNotEmpty) return 'tv:tvg:$tvgId';

  final resolverId = channel.resolverChannelId?.trim() ?? '';
  if (resolverId.isNotEmpty) {
    final resolver = channel.streamResolver?.trim().toLowerCase() ?? '';
    return 'tv:resolver:$resolver:$resolverId';
  }

  return 'tv:name:${TvService().normalizeChannelName(channel.name)}';
}

GlobalRecordingTarget tvRecordingTargetForChannel(
  TvChannel channel, {
  String? resolvedStreamUrl,
}) {
  final fallbackUrl = channel.url.trim();
  return GlobalRecordingTarget(
    id: _tvRecordingTargetId(channel),
    stationName: channel.name,
    streamUrl: resolvedStreamUrl?.trim().isNotEmpty == true
        ? resolvedStreamUrl!.trim()
        : fallbackUrl,
    includeVideo: true,
    tvChannel: channel,
  );
}

Future<void> showTvScheduleRecordingAction(
  BuildContext context,
  TvChannel channel, {
  TvProgram? program,
}) async {
  final l10n = AppLocalizations.of(context);
  final recordingService = GlobalRecordingService.instance;
  if (recordingService.hasAnyActiveRecording) {
    showStatusMessage(context, l10n.radioScheduleStopCurrentFirst);
    return;
  }

  final now = DateTime.now();
  DateTime start = program == null
      ? now.add(const Duration(minutes: 5))
      : tvProgramRecordingStart(program);
  DateTime end = program == null
      ? now.add(const Duration(minutes: 35))
      : tvProgramRecordingEnd(program);
  final today = _dateOnly(now);
  final lastAvailableDay = today.add(const Duration(days: 5));
  DateTime selectedDay = program == null
      ? _dateOnly(start)
      : _dateOnly(
          DateTime.fromMillisecondsSinceEpoch(program.startTime * 1000),
        );
  if (selectedDay.isBefore(today) || selectedDay.isAfter(lastAvailableDay)) {
    final replacementDay = selectedDay.isBefore(today)
        ? today
        : lastAvailableDay;
    final shift = replacementDay.difference(selectedDay);
    start = start.add(shift);
    end = end.add(shift);
    selectedDay = replacementDay;
  }
  final titleController = TextEditingController(text: program?.title ?? '');

  try {
    final request = await showDialog<_TvScheduledRecordingRequest>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDay() async {
              final picked = await showTvRecordingDaySelectionDialog(
                context,
                selectedDate: selectedDay,
                today: today,
              );
              if (picked != null) {
                final shift = picked.difference(selectedDay);
                setDialogState(() {
                  start = start.add(shift);
                  end = end.add(shift);
                  selectedDay = picked;
                });
              }
            }

            Future<void> pickStart() async {
              final picked = await _showScheduledRecordingTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(start),
                title: l10n.radioScheduleStartTime,
              );
              if (picked != null) {
                setDialogState(() => start = _replaceTime(start, picked));
              }
            }

            Future<void> pickEnd() async {
              final picked = await _showScheduledRecordingTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(end),
                title: l10n.radioScheduleEndTime,
              );
              if (picked != null) {
                setDialogState(() {
                  var candidate = _replaceTime(start, picked);
                  if (!candidate.isAfter(start)) {
                    candidate = candidate.add(const Duration(days: 1));
                  }
                  end = candidate;
                });
              }
            }

            return AlertDialog(
              title: Text(l10n.radioScheduleDialogTitle),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: useSharedAccessibleViewModel
                    ? UniversalAccessibleList(
                        sections: [
                          AccessibleListSection(
                            rows: [
                              AccessibleListRow(
                                id: 'info',
                                kind: 'text',
                                title: l10n.radioScheduleOpenRequirement,
                              ),
                              AccessibleListRow(
                                id: 'day',
                                title:
                                    'Giorno: ${formatTvRecordingDayLabel(selectedDay, today)}',
                              ),
                              AccessibleListRow(
                                id: 'start',
                                title: l10n.radioScheduleStartTimeValue(
                                  _formatScheduledDateTime(start),
                                ),
                              ),
                              AccessibleListRow(
                                id: 'end',
                                title: l10n.radioScheduleEndTimeValue(
                                  _formatScheduledDateTime(end),
                                ),
                              ),
                              AccessibleListRow(
                                id: 'title',
                                kind: 'textField',
                                title: l10n.radioScheduleOptionalTitle,
                                placeholder: l10n.radioScheduleTitleHint,
                                value: titleController.text,
                              ),
                            ],
                          ),
                        ],
                        onEvent: (event) {
                          if (event.id == 'day' && event.type == 'activate') {
                            pickDay();
                          } else if (event.id == 'start' &&
                              event.type == 'activate') {
                            pickStart();
                          } else if (event.id == 'end' &&
                              event.type == 'activate') {
                            pickEnd();
                          } else if (event.id == 'title' &&
                              event.type == 'textChanged') {
                            titleController.text =
                                event.value?.toString() ?? '';
                          }
                        },
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l10n.radioScheduleOpenRequirement),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: pickDay,
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                'Giorno: ${formatTvRecordingDayLabel(selectedDay, today)}',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: pickStart,
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                l10n.radioScheduleStartTimeValue(
                                  _formatScheduledDateTime(start),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: pickEnd,
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                l10n.radioScheduleEndTimeValue(
                                  _formatScheduledDateTime(end),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: l10n.radioScheduleOptionalTitle,
                                hintText: l10n.radioScheduleTitleHint,
                              ),
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      _TvScheduledRecordingRequest(
                        start: start,
                        end: end,
                        title: titleController.text.trim(),
                      ),
                    );
                  },
                  child: Text(l10n.radioScheduleAction),
                ),
              ],
            );
          },
        );
      },
    );

    if (request == null || !context.mounted) return;

    final scheduledStart = request.start;
    var scheduledEnd = request.end;
    if (!scheduledEnd.isAfter(scheduledStart)) {
      scheduledEnd = scheduledEnd.add(const Duration(days: 1));
    }

    final title = request.title.trim().isEmpty ? null : request.title.trim();
    try {
      recordingService.schedule(
        target: tvRecordingTargetForChannel(channel),
        start: scheduledStart,
        end: scheduledEnd,
        title: title,
      );
    } catch (error) {
      if (!context.mounted) return;
      showStatusMessage(
        context,
        l10n.radioScheduledRecordingError(l10n.technicalErrorGeneric),
      );
      return;
    }

    if (!context.mounted) return;
    showStatusMessage(
      context,
      l10n.radioScheduledRecordingRange(
        _formatScheduledDateTime(scheduledStart),
        _formatScheduledDateTime(scheduledEnd),
      ),
    );
  } finally {
    titleController.dispose();
  }
}
