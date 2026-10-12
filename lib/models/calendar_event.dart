class CalendarEvent {
  final String id;
  final DateTime date;
  final String text;
  final bool hasTime;
  final String? deviceCalendarId;
  final String? deviceEventId;

  CalendarEvent({
    required this.id,
    required this.date,
    required this.text,
    this.hasTime = false,
    this.deviceCalendarId,
    this.deviceEventId,
  });

  CalendarEvent withDeviceCalendar(String calendarId, String eventId) =>
      CalendarEvent(
        id: id,
        date: date,
        text: text,
        hasTime: hasTime,
        deviceCalendarId: calendarId,
        deviceEventId: eventId,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'text': text,
    'hasTime': hasTime,
    if (deviceCalendarId != null) 'deviceCalendarId': deviceCalendarId,
    if (deviceEventId != null) 'deviceEventId': deviceEventId,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      text: json['text'] as String,
      hasTime: json['hasTime'] == true,
      deviceCalendarId: json['deviceCalendarId'] as String?,
      deviceEventId: json['deviceEventId'] as String?,
    );
  }
}
