import 'package:intl/intl.dart';

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
  final language = _languageCode(localeName);
  final labels = switch (language) {
    'it' => const {
        0: 'oggi',
        -1: 'ieri',
        -2: "l'altro ieri",
        1: 'domani',
        2: 'dopodomani',
      },
    'fr' => const {
        0: "aujourd'hui",
        -1: 'hier',
        -2: 'avant-hier',
        1: 'demain',
        2: 'après-demain',
      },
    'es' => const {
        0: 'hoy',
        -1: 'ayer',
        -2: 'anteayer',
        1: 'mañana',
        2: 'pasado mañana',
      },
    'pt' => const {
        0: 'hoje',
        -1: 'ontem',
        -2: 'anteontem',
        1: 'amanhã',
        2: 'depois de amanhã',
      },
    'pl' => const {
        0: 'dzisiaj',
        -1: 'wczoraj',
        -2: 'przedwczoraj',
        1: 'jutro',
        2: 'pojutrze',
      },
    'cs' => const {
        0: 'dnes',
        -1: 'včera',
        -2: 'předevčírem',
        1: 'zítra',
        2: 'pozítří',
      },
    'de' => const {
        0: 'heute',
        -1: 'gestern',
        -2: 'vorgestern',
        1: 'morgen',
        2: 'übermorgen',
      },
    _ => const {
        0: 'today',
        -1: 'yesterday',
        -2: 'day before yesterday',
        1: 'tomorrow',
        2: 'day after tomorrow',
      },
  };
  return labels[dayDiff];
}

DateFormat _dateFormatter(String localeName) {
  final language = _languageCode(localeName);
  final pattern = language == 'en'
      ? 'MM/dd/yyyy'
      : (language == 'pl' || language == 'cs' || language == 'de')
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
