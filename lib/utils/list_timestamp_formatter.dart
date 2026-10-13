import 'package:intl/intl.dart';

import '../l10n/app_localizations_lookup.dart';

String titleWithListTimestamp(
  String title,
  DateTime? publishedAt,
  String localeName,
) {
  final timestamp = formatListTimestamp(publishedAt, localeName);
  if (timestamp == null || timestamp.isEmpty) return title;

  final trimmed = title.trim();
  if (trimmed.isEmpty) return timestamp;

  final separator = RegExp(r'[.!?:;…»”\)]$').hasMatch(trimmed) ? ' ' : '. ';
  return '$trimmed$separator$timestamp';
}

String? formatListTimestamp(DateTime? dateTime, String localeName) {
  if (dateTime == null) return null;

  final local = dateTime.toLocal();
  final now = DateTime.now().toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final itemDay = DateTime(local.year, local.month, local.day);
  final dayDiff = itemDay.difference(today).inDays;
  final timeText = _timeFormatter(localeName).format(local);

  final relativeDay = _relativeDayLabel(dayDiff, localeName);
  if (relativeDay != null) {
    return '$relativeDay $timeText';
  }

  return '${_dateFormatter(localeName).format(local)} $timeText';
}

String? _relativeDayLabel(int dayDiff, String localeName) {
  final strings = lookupSupportedAppLocalizations(localeName);
  return switch (dayDiff) {
    0 => strings.listTimestampToday,
    -1 => strings.listTimestampYesterday,
    -2 => strings.listTimestampDayBeforeYesterday,
    1 => strings.listTimestampTomorrow,
    2 => strings.listTimestampDayAfterTomorrow,
    _ => null,
  };
}

DateFormat _dateFormatter(String localeName) {
  final language = _languageCode(localeName);
  final pattern = language == 'en'
      ? 'MM/dd/yyyy'
      : language == 'zh'
          ? 'yyyy/MM/dd'
          : (language == 'pl' || language == 'cs' || language == 'de' || language == 'uk' || language == 'tr')
              ? 'dd.MM.yyyy'
              : 'dd/MM/yyyy';
  return DateFormat(pattern, localeName);
}

DateFormat _timeFormatter(String localeName) {
  final language = _languageCode(localeName);
  final pattern = language == 'en' ? 'h:mm a' : 'HH:mm';
  return DateFormat(pattern, localeName);
}

String _languageCode(String localeName) {
  if (localeName.isEmpty) return 'en';
  final normalized = localeName.replaceAll('_', '-').toLowerCase();
  return normalized.split('-').first;
}
