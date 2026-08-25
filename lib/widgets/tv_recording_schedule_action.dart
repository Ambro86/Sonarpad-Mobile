import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/global_recording_service.dart';
import '../services/tv_service.dart';
import '../utils/status_message.dart';
import 'universal_accessible_view.dart';

class _TvScheduledRecordingRequest {
  const _TvScheduledRecordingRequest({
    required this.startTime,
    required this.endTime,
    required this.title,
  });

  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String title;
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
          final previousMinute =
              twoDigits(clampInt(selectedMinute - 1, 0, 59));

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
                  child: Text(l10n.radioScheduleLabeledValue(visibleLabel, valueText)),
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

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatScheduledDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

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
  TvChannel channel,
) async {
  final l10n = AppLocalizations.of(context);
  final recordingService = GlobalRecordingService.instance;
  if (recordingService.hasAnyActiveRecording) {
    showStatusMessage(context, l10n.radioScheduleStopCurrentFirst);
    return;
  }

  final now = DateTime.now();
  TimeOfDay startTime = TimeOfDay.fromDateTime(
    now.add(const Duration(minutes: 5)),
  );
  TimeOfDay endTime = TimeOfDay.fromDateTime(
    now.add(const Duration(minutes: 35)),
  );
  final titleController = TextEditingController();

  try {
    final request = await showDialog<_TvScheduledRecordingRequest>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickStart() async {
              final picked = await _showScheduledRecordingTimePicker(
                context: context,
                initialTime: startTime,
                title: l10n.radioScheduleStartTime,
              );
              if (picked != null) {
                setDialogState(() => startTime = picked);
              }
            }

            Future<void> pickEnd() async {
              final picked = await _showScheduledRecordingTimePicker(
                context: context,
                initialTime: endTime,
                title: l10n.radioScheduleEndTime,
              );
              if (picked != null) {
                setDialogState(() => endTime = picked);
              }
            }

            return AlertDialog(
              title: Text(l10n.radioScheduleDialogTitle),
              content: SizedBox(
                width: double.maxFinite,
                height: 360,
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
                                id: 'start',
                                title: l10n.radioScheduleStartTimeValue(
                                  _formatTimeOfDay(startTime),
                                ),
                              ),
                              AccessibleListRow(
                                id: 'end',
                                title: l10n.radioScheduleEndTimeValue(
                                  _formatTimeOfDay(endTime),
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
                          if (event.id == 'start' &&
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
                              onPressed: pickStart,
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                l10n.radioScheduleStartTimeValue(
                                  _formatTimeOfDay(startTime),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: pickEnd,
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                l10n.radioScheduleEndTimeValue(
                                  _formatTimeOfDay(endTime),
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
                        startTime: startTime,
                        endTime: endTime,
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

    final current = DateTime.now();
    var start = DateTime(
      current.year,
      current.month,
      current.day,
      request.startTime.hour,
      request.startTime.minute,
    );
    if (!start.isAfter(current)) {
      start = start.add(const Duration(days: 1));
    }
    var end = DateTime(
      start.year,
      start.month,
      start.day,
      request.endTime.hour,
      request.endTime.minute,
    );
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    final title = request.title.trim().isEmpty ? null : request.title.trim();
    try {
      recordingService.schedule(
        target: tvRecordingTargetForChannel(channel),
        start: start,
        end: end,
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
        _formatScheduledDateTime(start),
        _formatScheduledDateTime(end),
      ),
    );
  } finally {
    titleController.dispose();
  }
}
